#!/usr/bin/env bash
# attention_needle_test.sh - plain-bash tests for _attention_needle (v1.5.1).
# Run: bash tests/bash/attention_needle_test.sh   (exit code = number of failures)
#
# The needle is the name the organizer overlay matches against terminal tab
# titles. v1.5.1: inside a launcher tmux session the session name IS the tab's
# session title ("RU_CisEx"), so it beats the folder-basename guess
# ("jang cisex"), which missed tabs whose names drop folder prefixes.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
. "${ROOT}/hooks/_attention.sh"

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

# Fake tmux as an EXECUTABLE first on PATH (the hook calls it through
# `timeout`, which never sees shell functions): prints FAKE_TMUX_NAME, exits 1
# when FAKE_TMUX_FAIL=1. Never touches a real tmux server.
FAKE_BIN="$(mktemp -d)"
trap 'rm -rf "$FAKE_BIN"' EXIT
cat > "${FAKE_BIN}/tmux" <<'SH'
#!/usr/bin/env bash
[ "${FAKE_TMUX_FAIL:-0}" = "1" ] && exit 1
printf '%s\n' "${FAKE_TMUX_NAME:-}"
SH
chmod +x "${FAKE_BIN}/tmux"
export PATH="${FAKE_BIN}:${PATH}"
export FAKE_TMUX_NAME FAKE_TMUX_FAIL

DIR=/home/u/PROJECTS/50_bio/jang_CisEx

unset TMUX TMUX_PANE
check "outside tmux: folder basename tokens" "jang cisex" "$(_attention_needle "$DIR" '{}')"

export TMUX=/tmp/tmux-1000/default,1,0 TMUX_PANE=%3
FAKE_TMUX_NAME=RU_CisEx
check "launcher tmux session: the session name verbatim" "RU_CisEx" "$(_attention_needle "$DIR" '{}')"

FAKE_TMUX_NAME=JH_ProjectDashboard
check "plural/shape mismatch fixed: session name wins over folder" "JH_ProjectDashboard" \
    "$(_attention_needle /home/u/PROJECTS/30_infra/projects-dashboard '{}')"

FAKE_TMUX_NAME=HLab_richR
check "worktree cwd still rings the session's tab" "HLab_richR" \
    "$(_attention_needle /home/u/PROJECTS/20_libs/richR/.claude/worktrees/spec-richr-002 '{}')"

FAKE_TMUX_NAME=RU_CisEx
check "an explicit hint still overrides the tmux name" "MyWindow" \
    "$(_attention_needle "$DIR" '{"hints": {"/home/u/PROJECTS/50_bio/jang_CisEx": "MyWindow"}}')"

FAKE_TMUX_NAME=0
check "non-launcher tmux session (no GROUP_ part) falls back to the folder" "jang cisex" \
    "$(_attention_needle "$DIR" '{}')"

FAKE_TMUX_NAME=main
check "plain word tmux session falls back to the folder" "jang cisex" "$(_attention_needle "$DIR" '{}')"

FAKE_TMUX_FAIL=1
check "tmux query failing falls back to the folder" "jang cisex" "$(_attention_needle "$DIR" '{}')"
FAKE_TMUX_FAIL=0

echo "failures: $FAILS"
exit "$FAILS"
