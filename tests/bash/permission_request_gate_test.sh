#!/usr/bin/env bash
# permission_request_gate_test.sh - plain-bash tests for the PermissionRequest
# organizer-mode gate (v1.5.4).
# Run: bash tests/bash/permission_request_gate_test.sh   (exit code = number of failures)
#
# A permission prompt fires BOTH Notification (permission_prompt -> attention
# signal -> the TerminalOrganizer plays its ask sound) and PermissionRequest.
# While the organizer heartbeat is fresh the overlay owns attention, so the
# PermissionRequest toast (and its sound) must be skipped - otherwise one
# prompt sounds twice. A stale heartbeat keeps the standalone toast fallback.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

FAILS=0
check() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "ok   - $label"
    else
        echo "FAIL - $label: expected [$expected] got [$actual]"
        FAILS=$((FAILS + 1))
    fi
}

# run_hook <alive:0|1> -> "toast" when notify.sh was invoked, "none" otherwise.
# The hook runs from a scratch install dir with a recording notify.sh and a
# stub _attention.sh whose heartbeat answer is fixed; HOME is scratch too, so
# no real config or log is touched.
run_hook() {
    local alive="$1" dir
    dir="$(mktemp -d)"
    cp "${ROOT}/hooks/PermissionRequest.sh" "${dir}/PermissionRequest.sh"
    cat > "${dir}/notify.sh" <<'SH'
#!/usr/bin/env bash
echo called > "$(dirname "${BASH_SOURCE[0]}")/toast.marker"
SH
    cat > "${dir}/_attention.sh" <<SH
_attention_organizer_alive() { return $([ "$alive" = 1 ] && echo 0 || echo 1); }
SH
    chmod +x "${dir}/notify.sh" "${dir}/PermissionRequest.sh"
    mkdir -p "${dir}/home"
    printf '{"tool_name":"Bash","tool_input":{"command":"ls"}}' \
        | HOME="${dir}/home" bash "${dir}/PermissionRequest.sh" >/dev/null 2>&1
    if [ -f "${dir}/toast.marker" ]; then echo toast; else echo none; fi
    rm -rf "$dir"
}

check "fresh heartbeat: organizer owns attention, toast skipped" "none" "$(run_hook 1)"
check "stale/missing heartbeat: standalone toast fallback still fires" "toast" "$(run_hook 0)"

echo "failures: $FAILS"
exit "$FAILS"
