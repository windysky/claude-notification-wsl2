---
id: SPEC-NOTIF-002
version: "1.0.0"
status: "draft"
created: "2026-01-11"
updated: "2026-01-11"
author: "Junguk Hur"
priority: "HIGH"
---

## IMPLEMENTATION PLAN: Complete Windows Notification Framework for Claude Code CLI on WSL2

### Traceability Tags

- **NOTIF-CORE**: Core notification delivery functionality
- **NOTIF-HOOK**: Hook integration with Claude Code
- **NOTIF-BRIDGE**: WSL2-to-Windows communication bridge
- **NOTIF-CONFIG**: Configuration management
- **NOTIF-DEPLOY**: Deployment and installation automation
- **NOTIF-I18N**: Multi-language support and localization

---

## Implementation Steps by Priority

### Primary Goal: Core Notification Delivery

**Priority**: HIGH
**Traceability**: NOTIF-CORE, NOTIF-BRIDGE

#### Step 1: Create PowerShell Toast Notification Script

**File**: `wsl-toast.ps1`
**Location**: Windows accessible path (`%USERPROFILE%\.wsl-toast\`)

**Implementation Tasks**:
1. Create PowerShell script with parameter validation
2. Implement BurntToast module auto-installation
3. Add notification type support (info, success, warning, error)
4. Implement UTF-8 encoding handling for multi-language content
5. Add error handling with silent failure mode
6. Test notification delivery on Windows 10/11

**Acceptance Criteria**:
- Script accepts Title, Message, Type, and Duration parameters
- BurntToast module auto-installs if not present
- Notifications display in Windows Action Center
- Non-English characters display correctly
- Script exits without errors when BurntToast unavailable

#### Step 2: Create WSL2 Bridge Script

**File**: `scripts/notify.sh`
**Location**: WSL2 project root

**Implementation Tasks**:
1. Create bash wrapper script with parameter parsing
2. Implement PowerShell command escaping for special characters
3. Add background execution with disown to avoid blocking
4. Implement timeout protection (1 second maximum)
5. Add shebang and executable permissions
6. Test WSL2-to-Windows invocation

**Acceptance Criteria**:
- Script accepts TITLE, MESSAGE, and TYPE arguments
- Special characters (quotes, backslashes) properly escaped
- Script returns immediately without blocking Claude Code
- Process backgrounds successfully with disown
- Works with UTF-8 multi-byte characters

#### Step 3: Implement Notification Hooks

**Files**: `settings.json` configuration, Hook handlers
**Traceability**: NOTIF-HOOK

**Implementation Tasks**:
1. Implement PostToolUse hook handler
2. Implement SessionEnd hook handler
3. Implement Notification hook handler
4. Add async execution to prevent blocking
5. Implement timeout protection (500ms for PostToolUse, 1000ms for SessionEnd)
6. Add structured context extraction (tool name, status, duration)

**Acceptance Criteria**:
- PostToolUse hook fires after every tool execution
- SessionEnd hook fires at session end with summary statistics
- Notification hook delivers custom notifications
- All hooks execute asynchronously without blocking
- Hook failures do not affect Claude Code operations

---

### Secondary Goal: Deployment and Configuration

**Priority**: MEDIUM
**Traceability**: NOTIF-DEPLOY, NOTIF-CONFIG

#### Step 4: Create Deployment Automation

**File**: `scripts/install-notifications.sh`
**Traceability**: NOTIF-DEPLOY

**Implementation Tasks**:
1. Create installation script with prerequisite checking
2. Implement idempotent installation (safe to run multiple times)
3. Add PowerShell module installation with error handling
4. Implement automatic hook configuration
5. Create uninstallation script (`scripts/uninstall-notifications.sh`)
6. Add user feedback and error messages

**Acceptance Criteria**:
- Installation script creates required directories
- BurntToast module installs automatically
- Claude Code hooks configure without manual intervention
- Installation is idempotent (can be run repeatedly)
- Uninstallation removes all files and hooks
- Clear error messages for installation failures

#### Step 5: Implement Configuration Management

**Files**: `settings.json` updates, Configuration loader
**Traceability**: NOTIF-CONFIG

**Implementation Tasks**:
1. Add notification configuration section to settings.json
2. Implement configuration loader with defaults
3. Add enable/disable toggle for notifications
4. Implement notification throttling (default: 1000ms)
5. Add quiet hours configuration (optional)
6. Create configuration validation

**Acceptance Criteria**:
- Configuration stored in MoAI settings.json
- Default values used when configuration missing
- Notifications can be disabled via config
- Throttling prevents duplicate notifications within window
- Quiet hours suppress notifications during configured times

#### Step 6: Add Error Handling and Logging

**Traceability**: NOTIF-CORE, NOTIF-HOOK

**Implementation Tasks**:
1. Implement graceful error handling for all components
2. Add silent failure mode (no errors shown to user)
3. Implement error logging to file (optional)
4. Add PowerShell execution policy bypass
5. Handle missing BurntToast module gracefully
6. Handle WSL2-Windows communication failures

**Acceptance Criteria**:
- All errors are caught and handled silently
- Claude Code operations never block on errors
- Error logging available for troubleshooting (optional)
- PowerShell execution policy issues bypassed automatically
- System degrades gracefully when components unavailable

---

### Tertiary Goal: Multi-language and Customization

**Priority**: LOW
**Traceability**: NOTIF-I18N, NOTIF-CONFIG

#### Step 7: Create Multi-language Notification Templates

**Files**: `templates/notifications/{language}.json`
**Traceability**: NOTIF-I18N

**Implementation Tasks**:
1. Create English notification template
2. Create Korean notification template
3. Create Japanese notification template
4. Create Chinese notification template
5. Implement template loader with fallback to English
6. Add language detection from MoAI config

**Acceptance Criteria**:
- Templates exist for EN, KO, JA, ZH languages
- Templates use localized text for titles and messages
- Missing templates fall back to English
- User language detected from configuration
- Multi-byte characters display correctly in notifications

#### Step 8: Add Custom Notification Rules

**Traceability**: NOTIF-CONFIG

**Implementation Tasks**:
1. Implement per-tool notification filtering
2. Add custom notification type mapping
3. Support user-defined notification templates
4. Add notification priority levels
5. Implement notification grouping (optional)
6. Support clickable notification actions (optional)

**Acceptance Criteria**:
- Users can filter notifications by tool type
- Custom type mappings override defaults
- User templates override system templates
- Priority levels control notification urgency
- Notifications group by session or tool type (optional)

---

## Technology Stack with Versions

### Core Components

**PowerShell Environment**:
- PowerShell 5.1+ (Windows 10/11 built-in minimum)
- Windows Management Framework 5.1+ (for Windows 7/8.1 compatibility)
- ExecutionPolicy: Bypass (for script invocation)

**PowerShell Modules**:
- BurntToast 0.8.0+ (Windows toast notification module)
- Installation via PowerShell Gallery (Install-Module)
- Scope: CurrentUser (no admin required)

**Python Environment**:
- Python 3.10+ (WSL2 standard installation)
- Standard library only (no external Python dependencies)

**Bash Environment**:
- Bash 4.0+ (WSL2 standard)
- Common Unix tools: sed, grep, mkdir, cp
- Standard WSL2 utilities

**Configuration**:
- JSON format for settings
- MoAI-ADK settings.json integration
- UTF-8 encoding for all text files

### Version Specifications

```
# PowerShell Module Requirements
BurntToast: >=0.8.0
PowerShell: >=5.1

# Python Requirements (no external packages)
Python: >=3.10

# Bash Requirements
Bash: >=4.0
```

### Compatibility Matrix

| Windows Version | PowerShell Version | BurntToast Support |
|----------------|-------------------|-------------------|
| Windows 11     | 5.1 / 7.x         | Fully Supported   |
| Windows 10     | 5.1               | Fully Supported   |
| Windows 8.1    | 5.1 (WMF 5.1)     | Supported         |
| Windows 7      | 5.1 (WMF 5.1)     | Supported         |

---

## Technical Approach

### Architecture Design

```
Claude Code CLI (WSL2)
    |
    v
Hook Event (PostToolUse/SessionEnd/Notification)
    |
    v
Hook Handler (async, timeout protected)
    |
    v
Notification Bridge (scripts/notify.sh)
    |
    v
PowerShell.exe Invocation (escaped parameters)
    |
    v
PowerShell Script (wsl-toast.ps1)
    |
    v
BurntToast Module
    |
    v
Windows Action Center
```

### Design Principles

1. **Non-Blocking**: All notification delivery happens asynchronously
2. **Graceful Degradation**: Failures never affect Claude Code operations
3. **Idempotent**: Installation safe to run multiple times
4. **Zero Configuration**: Works out of the box with sensible defaults
5. **Silent Operation**: No error messages shown to user during normal operation

### Component Interactions

**Hook Execution Flow**:
1. Claude Code triggers hook event (PostToolUse, SessionEnd, Notification)
2. Hook handler extracts context (tool name, status, duration)
3. Handler loads notification template based on user language
4. Handler formats message with template and context
5. Handler invokes bridge script with formatted message
6. Bridge script backgrounds immediately and returns
7. Bridge script invokes PowerShell.exe asynchronously
8. PowerShell script delivers toast notification to Windows
9. All errors are caught and logged silently

**Error Handling Flow**:
1. Any component catches exceptions
2. Error logged to optional log file
3. Execution continues without blocking
4. User sees no error messages
5. Claude Code operations unaffected

---

## Risk Analysis and Mitigation

### Risk 1: PowerShell Execution Policy Blocking

**Probability**: Medium
**Impact**: High (notifications fail completely)

**Mitigation**:
- Use `-ExecutionPolicy Bypass` flag in all PowerShell invocations
- Document manual ExecutionPolicy configuration in installation guide
- Add execution policy check in installation script
- Fallback to silent failure if bypass fails

**Contingency**:
- Provide manual PowerShell execution policy instructions
- Alternative: Use PowerShell `-Command` with script content instead of `-File`

### Risk 2: BurntToast Module Installation Failure

**Probability**: Medium
**Impact**: High (core dependency unavailable)

**Mitigation**:
- Implement auto-installation with silent failure handling
- Provide manual installation instructions
- Check for module availability before use
- Fallback to native Windows toast notifications (if possible)

**Contingency**:
- Alternative: Use Windows COM objects for toast notifications
- Document manual PowerShell Gallery installation steps

### Risk 3: Character Encoding Issues

**Probability**: Medium
**Impact**: Medium (non-English text corrupted)

**Mitigation**:
- Explicit UTF-8 encoding in PowerShell scripts
- Test with KO, JA, ZH character sets
- Implement encoding fallback to ASCII
- Add encoding detection and normalization

**Contingency**:
- Use ASCII-safe fallback for problematic characters
- Document encoding limitations
- Provide character escaping utilities

### Risk 4: WSL2-Windows Communication Failure

**Probability**: Low
**Impact**: Medium (notifications fail)

**Mitigation**:
- Add timeout protection (1 second maximum)
- Test on various WSL2 distributions (Ubuntu, Debian, etc.)
- Implement graceful failure handling
- Add connectivity checks in installation script

**Contingency**:
- Provide troubleshooting guide for WSL2 networking issues
- Alternative: Use file-based communication (shared filesystem)

### Risk 5: Notification Spam

**Probability**: Medium
**Impact**: Low (user annoyance)

**Mitigation**:
- Implement throttling (default: 1000ms)
- Add notification grouping
- Support quiet hours configuration
- Allow per-tool filtering

**Contingency**:
- Provide configuration guide for reducing notification frequency
- Add "disable all notifications" option

### Risk 6: Hook Timeout Blocking Claude Code

**Probability**: Low
**Impact**: High (Claude Code becomes unresponsive)

**Mitigation**:
- Implement strict timeout limits (500ms, 1000ms)
- Use background execution with disown
- Test timeout handling under load
- Add timeout monitoring in tests

**Contingency**:
- Provide timeout configuration tuning guide
- Document hook failure symptoms and solutions

### Risk 7: Installation Script Failures

**Probability**: Low
**Impact**: Medium (manual setup required)

**Mitigation**:
- Implement prerequisite checking
- Add idempotent installation (safe to rerun)
- Provide clear error messages
- Test on fresh WSL2 installations

**Contingency**:
- Provide manual installation step-by-step guide
- Support installation via alternative methods

---

## Testing Strategy

### Unit Testing

**Components**:
- Bridge script parameter escaping
- Template loading and rendering
- Configuration validation
- Language detection

### Integration Testing

**Scenarios**:
- End-to-end notification delivery (WSL2 → Windows)
- Hook execution and async behavior
- Multi-language character encoding
- Throttling and duplicate prevention

### Acceptance Testing

**Environments**:
- Windows 10 with WSL2 Ubuntu
- Windows 11 with WSL2 Ubuntu
- Different WSL2 distributions (Debian, Fedora)
- Different PowerShell versions (5.1, 7.x)

---

## Definition of Done

- [ ] All three SPEC files created and approved
- [ ] PowerShell toast notification script created and tested
- [ ] WSL2 bridge script created and tested
- [ ] Hook handlers implemented for PostToolUse, SessionEnd, Notification
- [ ] Deployment automation script created and tested
- [ ] Uninstallation script created and tested
- [ ] Configuration management implemented
- [ ] Multi-language templates created for EN, KO, JA, ZH
- [ ] Error handling and graceful degradation implemented
- [ ] Acceptance criteria tests passing
- [ ] Documentation complete (README, installation guide)
- [ ] Zero blocking of Claude Code operations verified
- [ ] Multi-language character encoding verified
- [ ] Notification latency < 1 second verified

---

## Success Metrics

**Functional Metrics**:
- Notification delivery success rate: > 95%
- Notification latency: < 1 second (P95)
- Zero blocking incidents: 100%
- Multi-language support: EN, KO, JA, ZH verified

**Quality Metrics**:
- Code coverage: > 85%
- Zero critical bugs in production
- Graceful degradation: 100% (no errors shown to users)

**Usability Metrics**:
- Installation time: < 30 seconds
- Manual configuration required: None
- User-reported issues: < 5%
