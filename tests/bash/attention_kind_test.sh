#!/usr/bin/env bash
# attention_kind_test.sh - plain-bash tests for _attention_kind (v1.5.2).
# Run: bash tests/bash/attention_kind_test.sh   (exit code = number of failures)
#
# The signal "kind" tells the TerminalOrganizer overlay how long to blink:
# ask = until the window is focused, info = a short visible-seconds cap,
# absent = the organizer's event-policy default. Claude Code's idle_prompt
# ("Claude is waiting for your input") fires ~60 s after EVERY finished turn,
# whatever the reply said, so it must not re-arm an until-focus blink.

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

check "permission_prompt is a real ask (blink until focused)" "ask" \
    "$(_attention_kind notification permission_prompt)"
check "idle_prompt is only a reminder (info: short blink, no until-focus)" "info" \
    "$(_attention_kind notification idle_prompt)"
check "elicitation_dialog asks the user something (ask)" "ask" \
    "$(_attention_kind notification elicitation_dialog)"
check "auth_success is informational (info)" "info" \
    "$(_attention_kind notification auth_success)"
check "an unknown notification type stays absent (organizer default)" "" \
    "$(_attention_kind notification some_future_type)"
check "a notification without a type stays absent" "" \
    "$(_attention_kind notification "")"
check "stop events stay absent (unchanged v1.5.0 behavior)" "" \
    "$(_attention_kind stop "")"

echo "failures: $FAILS"
exit "$FAILS"
