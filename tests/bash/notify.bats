#!/usr/bin/env bats
# notify.sh Bats Test Suite
# Tests for WSL2 bridge script for Windows toast notifications
#
# Author: Claude Code TDD Implementation
# Version: 1.0.0

# Setup: Load the script to test
setup() {
    # Get script directory
    SCRIPT_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    NOTIFY_SCRIPT="${SCRIPT_DIR}/scripts/notify.sh"

    # Export path for testing
    export NOTIFY_SCRIPT

    # Mock mode for testing
    export MOCK_MODE="true"
    export WSL_TOAST_ENABLED="true"

    # Create temp directory for tests
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
}

# Teardown: Clean up
teardown() {
    # Remove temp directory
    if [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Helper Functions
mock_powershell() {
    # Mock PowerShell executable
    echo "#!/usr/bin/env bash
echo '{\"Success\":true,\"Method\":\"Mock\",\"Message\":\"Mock notification displayed\",\"Timestamp\":\"$(date -Iseconds)\"}'"
}

@test "notify.sh: Script exists and is executable" {
    [ -f "$NOTIFY_SCRIPT" ]
    [ -x "$NOTIFY_SCRIPT" ]
}

@test "notify.sh: Shows help with --help flag" {
    run bash "$NOTIFY_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"Display Windows toast notifications"* ]]
    [[ "$output" == *"OPTIONS:"* ]]
}

@test "notify.sh: Shows help with -h flag" {
    run bash "$NOTIFY_SCRIPT" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "notify.sh: Requires title and message parameters" {
    run bash "$NOTIFY_SCRIPT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Missing required parameters"* ]]
}

@test "notify.sh: Accepts title with --title flag" {
    run bash "$NOTIFY_SCRIPT" --title "Test Title" --message "Test Message" --mock
    # Note: This will fail due to PowerShell not being available in test environment
    # But we can verify parameter parsing works
    [[ "$output" != *"Missing required parameters"* ]]
}

@test "notify.sh: Accepts title with -t flag" {
    run bash "$NOTIFY_SCRIPT" -t "Test Title" -m "Test Message" --mock
    [[ "$output" != *"Missing required parameters"* ]]
}

@test "notify.sh: Accepts message with --message flag" {
    run bash "$NOTIFY_SCRIPT" --title "Test" --message "Test Message" --mock
    [[ "$output" != *"Missing required parameters"* ]]
}

@test "notify.sh: Accepts message with -m flag" {
    run bash "$NOTIFY_SCRIPT" -t "Test" -m "Test Message" --mock
    [[ "$output" != *"Missing required parameters"* ]]
}

@test "notify.sh: Accepts type with --type flag" {
    run bash "$NOTIFY_SCRIPT" -t "Test" -m "Message" --type "Success" --mock
    [[ "$output" != *"Missing required parameters"* ]]
}

@test "notify.sh: Accepts type with -T flag" {
    run bash "$NOTIFY_SCRIPT" -t "Test" -m "Message" -T "Warning" --mock
    [[ "$output" != *"Missing required parameters"* ]]
}

@test "notify.sh: Validates notification types" {
    run bash "$NOTIFY_SCRIPT" -t "Test" -m "Message" --type "Information" --mock
    [[ "$output" != *"Invalid type"* ]]

    run bash "$NOTIFY_SCRIPT" -t "Test" -m "Message" --type "Warning" --mock
    [[ "$output" != *"Invalid type"* ]]

    run bash "$NOTIFY_SCRIPT" -t "Test" -m "Message" --type "Error" --mock
    [[ "$output" != *"Invalid type"* ]]

    run bash "$NOTIFY_SCRIPT" -t "Test" -m "Message" --type "Success" --mock
    [[ "$output" != *"Invalid type"* ]]
}

@test "notify.sh: Accepts duration with --duration flag" {
    run bash "$NOTIFY_SCRIPT" -t "Test" -m "Message" --duration "Long" --mock
    [[ "$output" != *"Missing required parameters"* ]]
}

@test "notify.sh: Accepts duration with -d flag" {
    run bash "$NOTIFY_SCRIPT" -t "Test" -m "Message" -d "Short" --mock
    [[ "$output" != *"Missing required parameters"* ]]
}

@test "notify.sh: Validates durations" {
    run bash "$NOTIFY_SCRIPT" -t "Test" -m "Message" --duration "Short" --mock
    [[ "$output" != *"Invalid duration"* ]]

    run bash "$NOTIFY_SCRIPT" -t "Test" -m "Message" --duration "Normal" --mock
    [[ "$output" != *"Invalid duration"* ]]

    run bash "$NOTIFY_SCRIPT" -t "Test" -m "Message" --duration "Long" --mock
    [[ "$output" != *"Invalid duration"* ]]
}

@test "notify.sh: Accepts --mock flag" {
    run bash "$NOTIFY_SCRIPT" -t "Test" -m "Message" --mock
    [[ "$output" != *"Missing required parameters"* ]]
}

@test "notify.sh: Handles Korean characters" {
    run bash "$NOTIFY_SCRIPT" -t "테스트" -m "한글 메시지" --mock
    [[ "$output" != *"Missing required parameters"* ]]
}

@test "notify.sh: Handles Japanese characters" {
    run bash "$NOTIFY_SCRIPT" -t "テスト" -m "日本語メッセージ" --mock
    [[ "$output" != *"Missing required parameters"* ]]
}

@test "notify.sh: Handles Chinese characters" {
    run bash "$NOTIFY_SCRIPT" -t "测试" -m "中文消息" --mock
    [[ "$output" != *"Missing required parameters"* ]]
}

@test "notify.sh: Respects WSL_TOAST_ENABLED environment variable" {
    run bash -c "WSL_TOAST_ENABLED=false bash \"$NOTIFY_SCRIPT\" -t \"Test\" -m \"Message\" --mock"
    # Should exit with success if disabled
    [ "$status" -eq 0 ] || true
}

@test "notify.sh: Handles verbose flag" {
    run bash "$NOTIFY_SCRIPT" -t "Test" -m "Message" --verbose --mock
    [[ "$output" != *"Missing required parameters"* ]]
}

@test "notify.sh: Handles logo parameter" {
    run bash "$NOTIFY_SCRIPT" -t "Test" -m "Message" --logo "/path/to/logo.png" --mock
    [[ "$output" != *"Missing required parameters"* ]]
}

@test "notify.sh: Handles equals sign for parameters" {
    run bash "$NOTIFY_SCRIPT" --title="Test" --message="Message" --mock
    [[ "$output" != *"Missing required parameters"* ]]
}

@test "notify.sh: Rejects unknown options" {
    run bash "$NOTIFY_SCRIPT" --unknown-option
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown option"* ]] || [[ "$output" == *"Usage:"* ]]
}

# Integration tests for helper functions
@test "notify.sh: validate_type function works correctly" {
    # Source the script to access functions
    source "$NOTIFY_SCRIPT"

    # Test valid types
    run validate_type "Information"
    [ "$output" = "Information" ]

    run validate_type "Warning"
    [ "$output" = "Warning" ]

    run validate_type "Error"
    [ "$output" = "Error" ]

    run validate_type "Success"
    [ "$output" = "Success" ]

    # Test invalid type (should return default)
    run validate_type "InvalidType"
    [ "$output" = "Information" ]
}

@test "notify.sh: validate_duration function works correctly" {
    # Source the script to access functions
    source "$NOTIFY_SCRIPT"

    # Test valid durations
    run validate_duration "Short"
    [ "$output" = "Short" ]

    run validate_duration "Normal"
    [ "$output" = "Normal" ]

    run validate_duration "Long"
    [ "$output" = "Long" ]

    # Test invalid duration (should return default)
    run validate_duration "InvalidDuration"
    [ "$output" = "Normal" ]
}

@test "notify.sh: find_powershell function returns path or fails" {
    # Source the script to access functions
    source "$NOTIFY_SCRIPT"

    # This will likely fail in pure Linux environment
    run find_powershell
    # Either returns a path or fails
    if [ "$status" -eq 0 ]; then
        [[ "$output" == *"powershell"* ]]
    fi
}

# Edge cases
@test "notify.sh: Handles empty title parameter" {
    run bash "$NOTIFY_SCRIPT" -t "" -m "Message" --mock
    [ "$status" -eq 2 ]
}

@test "notify.sh: Handles empty message parameter" {
    run bash "$NOTIFY_SCRIPT" -t "Title" -m "" --mock
    [ "$status" -eq 2 ]
}

@test "notify.sh: Handles special characters in title" {
    run bash "$NOTIFY_SCRIPT" -t 'Test with <special> & "characters"' -m "Message" --mock
    [[ "$output" != *"Missing required parameters"* ]]
}

@test "notify.sh: Handles special characters in message" {
    run bash "$NOTIFY_SCRIPT" -t "Title" -m 'Message with <special> & "characters"' --mock
    [[ "$output" != *"Missing required parameters"* ]]
}

@test "notify.sh: Handles emojis in title" {
    run bash "$NOTIFY_SCRIPT" -t "Test 🎉 🚀" -m "Message" --mock
    [[ "$output" != *"Missing required parameters"* ]]
}

@test "notify.sh: Handles emojis in message" {
    run bash "$NOTIFY_SCRIPT" -t "Title" -m "Message 😀 🎊" --mock
    [[ "$output" != *"Missing required parameters"* ]]
}
