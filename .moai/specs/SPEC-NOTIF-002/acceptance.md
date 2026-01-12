---
id: SPEC-NOTIF-002
version: "1.0.0"
status: "draft"
created: "2026-01-11"
updated: "2026-01-11"
author: "Junguk Hur"
priority: "HIGH"
---

## ACCEPTANCE CRITERIA: Complete Windows Notification Framework for Claude Code CLI on WSL2

### Traceability Tags

- **NOTIF-CORE**: Core notification delivery functionality
- **NOTIF-HOOK**: Hook integration with Claude Code
- **NOTIF-BRIDGE**: WSL2-to-Windows communication bridge
- **NOTIF-CONFIG**: Configuration management
- **NOTIF-DEPLOY**: Deployment and installation automation
- **NOTIF-I18N**: Multi-language support and localization

---

## Test Scenarios (Given-When-Then Format)

### 1. PowerShell Toast Notification Delivery (NOTIF-CORE)

#### Scenario 1.1: Successful Toast Notification

**Given** Windows 10/11 with BurntToast module installed
**And** PowerShell execution policy allows script execution
**When** User executes `wsl-toast.ps1 -Title "Test" -Message "Hello World" -Type "info"`
**Then** Toast notification appears in Windows Action Center
**And** Notification title displays "Test"
**And** Notification message displays "Hello World"
**And** Notification displays with info icon
**And** Notification auto-dismisses after 5 seconds

#### Scenario 1.2: Notification with Multi-Language Content

**Given** Windows 10/11 with BurntToast module installed
**And** System locale configured for Korean
**When** User executes `wsl-toast.ps1 -Title "알림" -Message "한글 테스트 메시지입니다"`
**Then** Toast notification appears with Korean characters correctly displayed
**And** No character encoding corruption occurs
**And** Notification is readable in Windows Action Center

#### Scenario 1.3: Long Message Truncation

**Given** Windows 10/11 with BurntToast module installed
**When** User executes `wsl-toast.ps1 -Title "Test" -Message "[300+ character message]"`
**Then** Notification message is truncated to 200 characters
**And** Truncated message ends with "..." suffix
**And** Notification displays without corruption

### 2. WSL2 Bridge Script Execution (NOTIF-BRIDGE)

#### Scenario 2.1: Successful Bridge Invocation

**Given** WSL2 environment with bridge script installed
**And** Windows host is reachable
**When** User executes `./scripts/notify.sh "Test Title" "Test Message" "info"`
**Then** Bridge script returns immediately without blocking
**And** PowerShell process is spawned in background
**And** Toast notification appears on Windows desktop
**And** Bridge script exits with code 0

#### Scenario 2.2: Special Character Escaping

**Given** WSL2 environment with bridge script installed
**When** User executes `./scripts/notify.sh "Test 'Quotes'" 'Message with "double quotes"'`
**Then** Special characters are properly escaped for PowerShell
**And** Notification displays with correct quotes
**And** No PowerShell parsing errors occur

#### Scenario 2.3: Bridge Script Timeout

**Given** WSL2 environment with bridge script installed
**And** Windows host is unreachable (network isolated)
**When** User executes `./scripts/notify.sh "Test" "Message"`
**Then** Bridge script times out after 1 second
**And** Script returns without hanging
**And** No error message is displayed to user

### 3. PostToolUse Hook Notification (NOTIF-HOOK)

#### Scenario 3.1: PostToolUse Hook After Read Operation

**Given** Claude Code CLI with PostToolUse hook configured
**When** User executes Read tool on a file
**Then** PostToolUse hook fires after Read completes
**And** Toast notification appears with title "Claude Code: Read"
**And** Notification message shows "Status: success, Duration: [X]ms"
**And** Notification type is "info"
**And** Hook execution does not block Claude Code

#### Scenario 3.2: PostToolUse Hook After Write Operation

**Given** Claude Code CLI with PostToolUse hook configured
**When** User executes Write tool to create a file
**Then** PostToolUse hook fires after Write completes
**And** Toast notification appears with title "Claude Code: Write"
**And** Notification type is "success"
**And** Hook execution completes within 500ms

#### Scenario 3.3: PostToolUse Hook Failure Handling

**Given** Claude Code CLI with PostToolUse hook configured
**And** Bridge script is corrupted or missing
**When** User executes any tool operation
**Then** PostToolUse hook fires and fails gracefully
**And** No error message is displayed to user
**And** Claude Code continues normal operation
**And** Tool operation completes successfully

### 4. SessionEnd Summary Notification (NOTIF-HOOK)

#### Scenario 4.1: SessionEnd with Statistics

**Given** Claude Code CLI with SessionEnd hook configured
**And** User has executed 5 tools during session
**And** Session duration is 10 minutes
**When** User closes Claude Code session
**Then** SessionEnd hook fires with session context
**And** Toast notification appears with title "Claude Code Session Complete"
**And** Notification message shows "Duration: [10 minutes], Tools: 5, Operations: [X]"
**And** Notification type is "success"

#### Scenario 4.2: SessionEnd with Multi-Language

**Given** Claude Code CLI with SessionEnd hook configured
**And** User language is configured as Korean (ko)
**When** User closes Claude Code session
**Then** Toast notification appears with Korean title "Claude Code 세션 완료"
**And** Notification message shows Korean text "기간: [X], 도구: [Y], 작업: [Z]"
**And** Korean characters display correctly without corruption

### 5. Deployment Script Installation (NOTIF-DEPLOY)

#### Scenario 5.1: Fresh Installation

**Given** Fresh WSL2 environment with Claude Code CLI
**And** No notification framework previously installed
**When** User executes `./scripts/install-notifications.sh`
**Then** Installation script creates `$HOME/.wsl-toast/` directory
**And** PowerShell script is copied to Windows accessible location
**And** BurntToast module is installed via PowerShell Gallery
**And** Claude Code hooks are configured in settings.json
**And** Installation completes with success message
**And** Installation takes less than 30 seconds

#### Scenario 5.2: Idempotent Installation

**Given** WSL2 environment with notification framework already installed
**When** User executes `./scripts/install-notifications.sh` again
**Then** Installation script detects existing installation
**And** No duplicate files are created
**And** Existing configuration is preserved
**And** Installation completes successfully
**And** System remains functional

#### Scenario 5.3: Installation Failure Handling

**Given** WSL2 environment without internet access
**When** User executes `./scripts/install-notifications.sh`
**Then** Installation script detects BurntToast installation failure
**And** Clear error message is displayed with manual instructions
**And** Partial installation is cleaned up
**And** Script exits with error code

### 6. Multi-language Notification Support (NOTIF-I18N)

#### Scenario 6.1: Korean Language Notification

**Given** Claude Code CLI with user language configured as Korean (ko)
**And** Korean template exists in `templates/notifications/ko.json`
**When** PostToolUse hook fires after Read operation
**Then** Toast notification uses Korean template
**And** Notification title shows "Claude Code: Read" (tool name remains English)
**And** Notification message shows "상태: success, 소요 시간: [X]ms"
**And** Korean characters display correctly

#### Scenario 6.2: Japanese Language Notification

**Given** Claude Code CLI with user language configured as Japanese (ja)
**And** Japanese template exists in `templates/notifications/ja.json`
**When** SessionEnd hook fires at session close
**Then** Toast notification uses Japanese template
**And** Notification title shows "Claude Code セッション完了"
**And** Japanese characters display correctly without encoding issues

#### Scenario 6.3: Missing Template Fallback to English

**Given** Claude Code CLI with user language configured as Chinese (zh)
**And** Chinese template is missing from templates directory
**When** Any hook fires requiring notification
**Then** System falls back to English template
**And** Notification displays in English
**And** Warning is logged (but not shown to user)
**And** Notification is delivered successfully

### 7. Notification Throttling (NOTIF-CONFIG)

#### Scenario 7.1: Duplicate Notification Prevention

**Given** Claude Code CLI with throttling configured to 1000ms
**When** User executes two Read operations within 500ms
**Then** First Read operation triggers toast notification
**And** Second Read operation does not trigger notification (throttled)
**And** Only one notification appears in Windows Action Center

#### Scenario 7.2: Throttle Window Expiration

**Given** Claude Code CLI with throttling configured to 1000ms
**When** User executes Read operation, waits 1500ms, then executes another Read
**Then** First Read operation triggers toast notification
**And** Second Read operation triggers toast notification (throttle window expired)
**And** Two notifications appear in Windows Action Center

### 8. Graceful Error Handling (NOTIF-CORE)

#### Scenario 8.1: Missing BurntToast Module

**Given** Windows environment without BurntToast module installed
**And** PowerShell Gallery is accessible
**When** Bridge script invokes `wsl-toast.ps1`
**Then** PowerShell script attempts auto-installation of BurntToast
**And** If installation succeeds, notification is delivered
**And** If installation fails, script exits silently without error

#### Scenario 8.2: PowerShell Execution Policy Blocking

**Given** Windows environment with Restricted execution policy
**When** Bridge script invokes PowerShell with `-ExecutionPolicy Bypass`
**Then** Script executes successfully despite restricted policy
**And** Notification is delivered normally
**And** No policy errors are displayed

#### Scenario 8.3: WSL2-Windows Communication Failure

**Given** WSL2 environment with Windows host unreachable
**When** Bridge script attempts to invoke PowerShell.exe
**Then** Bridge script times out after 1 second
**And** Script returns without blocking
**And** No error message is displayed to user
**And** Claude Code continues normal operation

---

## Edge Cases

### 1. BurntToast Module Not Installed
**Scenario**: User runs installation on Windows without BurntToast
**Expected Behavior**: Installation script auto-installs BurntToast module. If installation fails, provide manual installation instructions.

### 2. PowerShell Execution Policy Blocking
**Scenario**: Windows system has PowerShell execution policy set to Restricted
**Expected Behavior**: Bridge script uses `-ExecutionPolicy Bypass` flag to override policy. Documentation includes manual policy configuration instructions.

### 3. Character Encoding for Non-English Text
**Scenario**: Korean, Japanese, or Chinese text contains multi-byte characters
**Expected Behavior**: UTF-8 encoding is explicitly set in PowerShell script. Special character escaping handles quotes and backslashes. ASCII-safe fallback for problematic characters.

### 4. WSL2-Windows Communication Failure
**Scenario**: WSL2 networking is down or Windows host is unreachable
**Expected Behavior**: Bridge script times out after 1 second and returns silently. No error messages shown to user. Claude Code operations unaffected.

### 5. Notification Spam Prevention
**Scenario**: User executes 20 tool operations in rapid succession
**Expected Behavior**: Throttling limits notifications to 1 per 1000ms (configurable). Only first notification in each throttle window is delivered.

### 6. Hook Timeout
**Scenario**: Hook execution takes longer than configured timeout (500ms or 1000ms)
**Expected Behavior**: Hook execution is terminated after timeout. Notification is skipped but Claude Code operation continues normally.

### 7. Missing Template for Language
**Scenario**: User language is set to unsupported language (e.g., French)
**Expected Behavior**: System falls back to English template. Warning logged but not shown to user. Notification delivered successfully in English.

### 8. Bridge Script Permissions
**Scenario**: Bridge script is not executable (no +x permission)
**Expected Behavior**: Installation script sets executable permissions automatically. Manual chmod +x documented in troubleshooting guide.

### 9. Concurrent Hook Executions
**Scenario**: Multiple hooks fire simultaneously (e.g., PostToolUse and Notification)
**Expected Behavior**: Each hook executes independently. No race conditions or notification corruption. All notifications delivered successfully.

### 10. Empty or Null Parameters
**Scenario**: Hook passes empty string or null for title or message
**Expected Behavior**: Bridge script validates parameters and provides defaults (Title: "Claude Code", Message: "Notification"). No PowerShell errors occur.

---

## Success Criteria

### Functional Criteria

- [ ] **Notification Delivery**: Toast notifications appear in Windows Action Center for all hook events
- [ ] **Non-Blocking**: All hook executions complete within timeout limits (500ms for PostToolUse, 1000ms for SessionEnd)
- [ ] **Multi-Language Support**: EN, KO, JA, ZH languages display correctly with proper encoding
- [ ] **Graceful Degradation**: All errors are handled silently without affecting Claude Code operations
- [ ] **Throttling**: Duplicate notifications prevented within 1000ms throttle window
- [ ] **Installation**: Automated installation completes within 30 seconds without manual intervention

### Performance Criteria

- [ ] **Notification Latency**: P95 notification delivery latency < 1 second from hook trigger to toast appearance
- [ ] **Hook Overhead**: Hook execution adds < 50ms overhead to Claude Code operations
- [ ] **Memory Usage**: Bridge script process memory footprint < 10MB
- [ ] **CPU Usage**: Background PowerShell process uses < 5% CPU for notification delivery

### Quality Criteria

- [ ] **Code Coverage**: Unit test coverage > 85% for all components
- [ ] **Zero Blocking Incidents**: No confirmed instances of Claude Code blocking during notification delivery
- [ ] **Encoding Accuracy**: 100% of multi-language character sets display correctly (EN, KO, JA, ZH)
- [ ] **Installation Success Rate**: > 95% successful installations on fresh WSL2 environments

### Usability Criteria

- [ ] **Zero Configuration**: System works out of the box with default configuration
- [ ] **Clear Documentation**: Installation guide covers all common scenarios and troubleshooting
- [ ] **Error Messages**: Installation errors provide clear, actionable error messages
- [ ] **Uninstallation**: Complete uninstallation removes all files and hooks

---

## Verification Methods

### 1. Manual Testing

**Test Environment Setup**:
- Windows 10/11 virtual machine or physical machine
- WSL2 with Ubuntu 22.04 LTS
- Fresh Claude Code CLI installation

**Test Cases**:
- Execute installation script and verify all components installed
- Run Claude Code operations and verify notifications appear
- Test with all supported languages (EN, KO, JA, ZH)
- Test error scenarios (network failure, missing dependencies)

### 2. Automated Testing

**Unit Tests**:
- Bridge script parameter escaping (pytest)
- Template loading and rendering (pytest)
- Configuration validation (pytest)

**Integration Tests**:
- End-to-end notification delivery (pytest + PowerShell)
- Hook execution timing (pytest)
- Multi-language encoding (pytest + PowerShell)

### 3. Performance Testing

**Metrics**:
- Notification delivery latency (timing from hook trigger to toast appearance)
- Hook execution duration (timing of hook handler execution)
- Memory usage (process memory monitoring)
- CPU usage (CPU profiling during notification delivery)

**Tools**:
- Python time module for latency measurement
- PowerShell Measure-Command for script execution timing
- Windows Performance Monitor for resource usage

### 4. Compatibility Testing

**Test Matrix**:
- Windows 10 (versions 21H2, 22H2)
- Windows 11 (versions 21H2, 22H2, 23H2)
- WSL2 distributions: Ubuntu 22.04, Debian 11, Fedora 37
- PowerShell versions: 5.1, 7.2, 7.3

**Verification**:
- Installation succeeds on all platform combinations
- Notifications deliver correctly on all platforms
- No platform-specific errors or failures

---

## Definition of Done

A feature is considered complete when:

- [ ] All acceptance criteria tests pass
- [ ] All edge cases are handled gracefully
- [ ] Code coverage exceeds 85%
- [ ] Documentation is complete and reviewed
- [ ] Installation tested on fresh WSL2 environment
- [ ] Multi-language support verified for EN, KO, JA, ZH
- [ ] Performance criteria met (latency < 1s, zero blocking)
- [ ] Zero critical bugs remaining
- [ ] Uninstallation tested and verified
- [ ] User acceptance testing completed successfully

---

## Traceability Matrix

| Acceptance Criterion | SPEC Requirement | Implementation Component | Test Scenario |
|---------------------|------------------|-------------------------|---------------|
| Toast notification delivery | NOTIF-CORE | wsl-toast.ps1 | Scenario 1.1 |
| Multi-language support | NOTIF-I18N | Templates, loader | Scenario 6.1 |
| WSL2 bridge invocation | NOTIF-BRIDGE | notify.sh | Scenario 2.1 |
| PostToolUse hook | NOTIF-HOOK | Hook handler | Scenario 3.1 |
| SessionEnd hook | NOTIF-HOOK | Hook handler | Scenario 4.1 |
| Deployment automation | NOTIF-DEPLOY | install-notifications.sh | Scenario 5.1 |
| Notification throttling | NOTIF-CONFIG | Config manager | Scenario 7.1 |
| Graceful error handling | NOTIF-CORE | All components | Scenario 8.1 |
