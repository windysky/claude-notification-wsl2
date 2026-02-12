# PROJECT_LOG.md

---

## Session 2026-02-11 22:30-23:15

**Coding CLI used**: Claude Code CLI

**Phase(s) worked on**:
- Hook improvements (detailed notifications)
- Documentation updates
- Bug fix (duplicate notifications)

**Concrete changes implemented**:
1. Updated Stop.sh to extract last assistant message from transcript (like Codex CLI)
2. Updated Notification.sh to properly extract message field from payload
3. Removed duplicate hooks from ~/.claude/settings.json (user-level)
4. Updated README.md with current hooks and detailed notifications feature
5. Updated docs/HOOKS.md with current hook types and best practices
6. Bumped version to 1.2.0

**Files/modules/functions touched**:
- hooks/Stop.sh - Added transcript parsing, message extraction
- hooks/Notification.sh - Added message field extraction
- ~/.claude/settings.json - Removed hooks (kept project-level only)
- README.md - Updated features, hooks config, version
- docs/HOOKS.md - Complete rewrite for current hooks

**Key technical decisions and rationale**:
- **Transcript reading**: Stop hook now reads transcript_path from payload and extracts last assistant message, providing detailed notifications like Codex CLI's last-assistant-message feature
- **Project-level only**: Hooks should only be configured in project-level settings to avoid duplicates

**Problems encountered and resolutions**:
- **Duplicate notifications**: User reported receiving duplicate notifications. Investigation revealed hooks were configured in both user-level (~/.claude/settings.json) and project-level (.claude/settings.json). Fixed by removing hooks from user-level settings.

**Items explicitly completed**:
- Detailed notifications feature (Codex CLI style)
- Duplicate notification fix
- Documentation update for v1.2.0

**Verification performed**:
- Tested Python extraction logic - correctly extracts last assistant message
- Tested notify.sh directly - notifications sent successfully
- Analyzed logs to confirm duplicate notification cause

**Commits**:
- `ebe4251` feat: Extract last assistant message for detailed notifications
- `fd767ac` docs: Update documentation for v1.2.0 with detailed notifications
