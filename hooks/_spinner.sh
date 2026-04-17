#!/usr/bin/env bash
# _spinner.sh - Terminal progress indicator for wsl-toast hooks.
#
# Design:
#   - Title is written ONCE (no loop, no flicker) with the classic
#     "user@host: ~/path" string so you always know which session is busy.
#   - The actual "spinning" animation is Windows Terminal's taskbar icon
#     pulse (OSC 9;4;3), which is self-animated and flicker-free.
#   - State files are keyed per-tty so concurrent Claude Code sessions in
#     separate terminal tabs don't clobber each other.
#
# Exposes:
#   spinner_start  - set static title + enable taskbar pulse
#   spinner_stop   - clear the taskbar pulse (leaves title in place)
#
# Disable CC's own title updates with `"spinnerTipsEnabled": false`.

SPINNER_DIR="${HOME}/.wsl-toast"

# Walk up the parent-process chain to find the user's terminal device.
_spinner_find_user_tty() {
    local pid=$PPID tty hops=0
    while [ -n "$pid" ] && [ "$pid" != "0" ] && [ "$pid" != "1" ] && [ "$hops" -lt 20 ]; do
        tty=$(readlink "/proc/$pid/fd/0" 2>/dev/null)
        if [[ "$tty" == /dev/pts/* || "$tty" == /dev/tty* ]]; then
            echo "$tty"; return 0
        fi
        tty=$(readlink "/proc/$pid/fd/1" 2>/dev/null)
        if [[ "$tty" == /dev/pts/* || "$tty" == /dev/tty* ]]; then
            echo "$tty"; return 0
        fi
        pid=$(awk '/^PPid:/ {print $2}' "/proc/$pid/status" 2>/dev/null)
        hops=$((hops + 1))
    done
    return 1
}

# Build a classic shell-style title: "user@host: ~/path".
_spinner_build_title() {
    local user="${USER:-$(whoami 2>/dev/null)}"
    local host="${HOSTNAME:-$(hostname 2>/dev/null)}"
    local cwd="${PWD}"
    if [ -n "$HOME" ] && [[ "$cwd" == "$HOME"* ]]; then
        cwd="~${cwd#$HOME}"
    fi
    printf '%s@%s: %s' "$user" "$host" "$cwd"
}

# Convert /dev/pts/3 → dev_pts_3 for use in a filename.
_spinner_file_prefix() {
    local tty="$1"
    local key="${tty#/}"
    key="${key//\//_}"
    echo "${SPINNER_DIR}/spinner-${key}"
}

# One-time cleanup of pre-v1.3.1 single-instance state files.
_spinner_cleanup_legacy() {
    rm -f "${SPINNER_DIR}/spinner.pid" \
          "${SPINNER_DIR}/spinner.tty" \
          "${SPINNER_DIR}/spinner.title" 2>/dev/null || true
}

spinner_stop() {
    _spinner_cleanup_legacy
    local tty prefix
    tty=$(_spinner_find_user_tty) || tty=""
    [ -z "$tty" ] && return 0
    prefix=$(_spinner_file_prefix "$tty")
    if [ -w "$tty" ]; then
        # Clear Windows Terminal taskbar pulse; leave title alone.
        printf '\033]9;4;0;0\033\\' >"$tty" 2>/dev/null || true
    fi
    rm -f "${prefix}.tty" "${prefix}.title" "${prefix}.pid" 2>/dev/null || true
}

spinner_start() {
    mkdir -p "$SPINNER_DIR"
    _spinner_cleanup_legacy

    local tty
    tty=$(_spinner_find_user_tty) || tty=""
    if [ -z "$tty" ] || [ ! -w "$tty" ]; then
        return 0
    fi

    local prefix title
    prefix=$(_spinner_file_prefix "$tty")
    title=$(_spinner_build_title)

    echo "$tty"  >"${prefix}.tty"
    printf '%s' "$title" >"${prefix}.title"

    # Static title + Windows Terminal indeterminate taskbar pulse.
    printf '\033]0;%s\007\033]9;4;3;0\033\\' "$title" >"$tty" 2>/dev/null || true
}
