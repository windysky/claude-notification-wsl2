#!/usr/bin/env bash
# _attention.sh - Attention signal helpers for wsl-toast hooks.
#
# attention_flash <project_dir> [event] [session_id] [notification_type]
#   Two attention channels (v1.4.x), each config-gated under "attention":
#   - "flash"  (default true): flash the Windows Terminal window that owns the
#     session (taskbar pulses orange until the window is focused). Matching
#     uses tokens of the directory basename against normalized window titles,
#     working with launcher-fixed titles ("HG_MyProject") and path titles.
#   - "signal" (default true): write one JSON event file to the Windows side
#     (%LOCALAPPDATA%\wsl-toast\attention\) for a resident consumer such as
#     TerminalOrganizer (Phase 2 border overlay). One file per event, named
#     att-<epochms>-<rand>.json - concurrent sessions never race on one file.
#     The consumer reads-and-deletes; files older than 5 minutes self-prune.
#   Per-project window-name override:
#     "attention": { "enabled": true,
#                    "hints": { "/full/project/dir": "ExactWindowTitle" } }
#   Never blocks or fails the hook.
#
# toast_dedup_check <key>  - returns 0 (send) the first time a key is seen and
#   when >60s have elapsed since the last identical key; returns 1 (duplicate)
#   when the exact same key re-appears within 60s. The key should combine
#   session id + title + message, so only byte-identical repeats are dropped
#   while different messages always go through.

ATTENTION_DIR="${HOME}/.wsl-toast"
ATTENTION_DEDUP_SECONDS=60
_ATTENTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Reuse the spinner's tty discovery / state-file naming when not already loaded.
if ! declare -F _spinner_find_user_tty >/dev/null 2>&1; then
    # shellcheck disable=SC1091
    [ -f "${_ATTENTION_DIR}/_spinner.sh" ] && . "${_ATTENTION_DIR}/_spinner.sh"
fi

# Find attention.ps1 with the same layout chain notify.sh uses:
# same dir/windows -> parent/windows -> grandparent/windows.
_attention_find_windows_dir() {
    local dir="${_ATTENTION_DIR}"
    local i
    for i in 1 2 3; do
        if [ -d "${dir}/windows" ] && [ -f "${dir}/windows/attention.ps1" ]; then
            echo "${dir}/windows"
            return 0
        fi
        dir="$(cd "${dir}/.." && pwd)"
    done
    return 1
}

# Resolve the Windows username once, cached under ~/.wsl-toast/windowsuser.
# Uses powershell.exe (cmd.exe may not be on the WSL interop PATH).
_attention_win_user() {
    local cache="${ATTENTION_DIR}/windowsuser"
    if [ -s "$cache" ]; then
        cat "$cache" 2>/dev/null
        return 0
    fi
    local ps u
    ps="$(command -v powershell.exe 2>/dev/null)" || return 1
    u="$(timeout 5 "$ps" -NoProfile -NonInteractive -Command '$env:USERNAME' 2>/dev/null | tr -d '\r\n ')" || u=""
    if [ -z "$u" ] || [ "$u" = "\$env:USERNAME" ]; then
        return 1
    fi
    printf '%s' "$u" > "$cache" 2>/dev/null
    echo "$u"
}

# _attention_write_signal <project_dir> <event> <session_id> <ntype> <needle>
# Returns 0 only when a non-empty signal file actually landed on disk.
_attention_write_signal() {
    local project_dir="$1" event="$2" session_id="$3" ntype="$4" needle="$5"
    local user sig_dir
    user=$(_attention_win_user) || return 1
    sig_dir="/mnt/c/Users/${user}/AppData/Local/wsl-toast/attention"
    mkdir -p "$sig_dir" 2>/dev/null || return 1

    local fname
    fname="att-$(date +%s%3N 2>/dev/null || date +%s)-$RANDOM.json"
    ATT_DIR="$project_dir" ATT_EVENT="$event" ATT_SESSION="$session_id" \
        ATT_NTYPE="$ntype" ATT_NEEDLE="$needle" \
        python3 - > "${sig_dir}/${fname}" <<'PY' 2>/dev/null || true
import json, os, datetime
print(json.dumps({
    "version": 1,
    "event": os.environ.get("ATT_EVENT", ""),
    "notification_type": os.environ.get("ATT_NTYPE") or None,
    "session_id": os.environ.get("ATT_SESSION", ""),
    "cwd": os.environ.get("ATT_DIR", ""),
    "needle": os.environ.get("ATT_NEEDLE", ""),
    "timestamp": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
}))
PY
    if [ ! -s "${sig_dir}/${fname}" ]; then
        rm -f "${sig_dir}/${fname}" 2>/dev/null
        return 1
    fi
    # Self-prune: no consumer yet (or a dead one) should not accumulate files.
    find "$sig_dir" -maxdepth 1 -name 'att-*.json' -mmin +5 -delete 2>/dev/null &
    return 0
}

# attention_flash <project_dir> [event] [session_id] [notification_type]
attention_flash() {
    local project_dir="${1:-$PWD}"
    local event="${2:-stop}"
    local session_id="${3:-}"
    local ntype="${4:-}"
    local log_file="${ATTENTION_DIR}/logs/hooks.log"
    local config_file="${ATTENTION_DIR}/config.json"

    # Config gates: attention.enabled / .flash / .signal (all default true).
    local attention_cfg="{}"
    if command -v python3 >/dev/null 2>&1 && [ -f "$config_file" ]; then
        attention_cfg=$(python3 -c "import json; print(json.dumps(json.load(open('$config_file')).get('attention', {})))" 2>/dev/null || echo '{}')
    fi
    local enabled flash signal
    enabled=$(python3 -c "import json; print(json.loads('''$attention_cfg''').get('enabled', True))" 2>/dev/null || echo "True")
    [ "$enabled" != "True" ] && return 0
    flash=$(python3 -c "import json; print(json.loads('''$attention_cfg''').get('flash', True))" 2>/dev/null || echo "True")
    signal=$(python3 -c "import json; print(json.loads('''$attention_cfg''').get('signal', True))" 2>/dev/null || echo "True")

    # Match needle: explicit hint override for this directory, else tokens of
    # the directory basename (split on -, _, . and whitespace).
    local needle
    needle=$(WSL_TOAST_ATTENTION_CFG="$attention_cfg" python3 - "$project_dir" <<'PY' 2>/dev/null
import json, sys, os, re
cfg = json.loads(os.environ.get("WSL_TOAST_ATTENTION_CFG", "{}"))
project_dir = sys.argv[1] if len(sys.argv) > 1 else ""
hints = cfg.get("hints", {}) if isinstance(cfg, dict) else {}
hint = hints.get(project_dir) or hints.get(os.path.realpath(project_dir))
if hint:
    print(hint)
else:
    base = os.path.basename(project_dir.rstrip("/")) or project_dir
    tokens = [t for t in re.split(r"[-_.\s]+", base.lower()) if t]
    print(" ".join(tokens))
PY
    )
    [ -z "$needle" ] && return 0

    # Channel 1: taskbar flash via attention.ps1. Bounded by timeout so a
    # hung powershell.exe can never stall the hook.
    local result=""
    if [ "$flash" = "True" ]; then
        local windows_dir ps_path powershell_exe
        windows_dir=$(_attention_find_windows_dir) && \
        powershell_exe="$(command -v powershell.exe 2>/dev/null)" && \
        ps_path="$(wslpath -w "${windows_dir}/attention.ps1" 2>/dev/null)" && \
        result=$(timeout 5 "$powershell_exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass \
            -File "$ps_path" -Needle "$needle" 2>/dev/null | head -1)
        [ -n "$result" ] || result="flash: no output (needle: ${needle})"
    fi

    # Channel 2: signal file for a resident consumer (TerminalOrganizer).
    if [ "$signal" = "True" ]; then
        if _attention_write_signal "$project_dir" "$event" "$session_id" "$ntype" "$needle"; then
            result="${result:+$result · }signal written"
        else
            result="${result:+$result · }signal FAILED"
        fi
    fi

    [ -n "$result" ] && echo "[attention] ${result}" >> "$log_file" 2>/dev/null
    return 0
}

# toast_dedup_check <key>  ->  0 = send, 1 = duplicate within window
toast_dedup_check() {
    local key="$1"
    local hash state now epoch
    hash=$(printf '%s' "$key" | md5sum 2>/dev/null | cut -d' ' -f1)
    [ -z "$hash" ] && return 0
    state="${ATTENTION_DIR}/dedup-${hash:0:24}"
    now=$(date +%s)

    if [ -f "$state" ]; then
        epoch=$(cat "$state" 2>/dev/null)
        if [[ "$epoch" =~ ^[0-9]+$ ]] && [ $((now - epoch)) -lt "$ATTENTION_DEDUP_SECONDS" ]; then
            return 1
        fi
    fi
    printf '%s' "$now" > "$state" 2>/dev/null

    # Opportunistic hygiene: drop dedup state files older than a day.
    find "${ATTENTION_DIR}" -maxdepth 1 -name 'dedup-*' -mmin +1440 -delete 2>/dev/null &
    return 0
}
