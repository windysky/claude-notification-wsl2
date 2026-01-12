# Technology Stack

## Core Technologies

### Python (Primary Language)

Python serves as the primary implementation language for hooks, utilities, and automation scripts within the MoAI-ADK framework.

**Usage Areas:**
- Hook implementations (.claude/hooks/moai/)
- Utility libraries (lib/)
- Event-driven automation
- Configuration management
- Git operations

**Key Libraries:**
- Standard library for file I/O, processes, networking
- Custom libraries for project management, timeouts, check pointing

### YAML (Configuration)

YAML provides the configuration format for the modular MoAI configuration system.

**Usage Areas:**
- Agent definitions (.claude/agents/moai/*.md)
- Command definitions (.claude/commands/moai/*.md)
- Configuration sections (.moai/config/sections/*.yaml)
- MCP server configuration (.mcp.json)

**Benefits:**
- Human-readable and writable
- Supports complex data structures
- Good for documentation-like configs
- Widely supported in DevOps tools

### JSON (Settings)

JSON is used for MCP server configuration and Claude Code settings.

**Usage Areas:**
- MCP server definitions (.mcp.json)
- Claude Code settings (settings.json)
- Data interchange between components

## Framework and Architecture

### MoAI-ADK Framework

The Model-based AI Assistant Development Kit provides the foundational architecture.

**Core Principles:**
- TRUST 5 Framework (Test-first, Readable, Unified, Secured, Trackable)
- SPEC-First TDD (Specification-driven test-driven development)
- Orchestrator-Agent pattern
- Progressive disclosure for content organization
- Token optimization for LLM efficiency

**Components:**
- Alfred (strategic orchestrator)
- 20 specialized agents (Manager, Expert, Builder)
- Hook system (event-driven automation)
- Plugin system (extensible architecture)
- Skill modules (domain knowledge)

### Claude Code CLI Integration

The project extends Claude Code CLI through its extensibility model.

**Extension Points:**
- Hooks: PreToolUse, PostToolUse, SessionStart, SessionEnd, Notification
- Agents: Specialized sub-agents via Task() delegation
- Commands: User-invoked slash commands
- Skills: Model-invoked extensions with progressive disclosure
- Memory: CLAUDE.md and rules files

### WSL2-Windows Bridge

Technical approach for Windows notification delivery from WSL2.

**Implementation Options:**
1. **WSL2 Interop**: Windows-specific WSL2 interoperability features
2. **Named Pipes**: IPC via Windows named pipes from WSL2
3. **Network Sockets**: Local network communication
4. **Shared Files**: File-based communication via shared filesystem

**Preferred Approach:**
WSL2 interop with `powershell.exe` or `cmd.exe` to trigger Windows toast notifications directly from WSL2.

## Dependencies

### MCP (Model Context Protocol)

The project uses MCP for server integration.

**Configuration:**
```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    }
  }
}
```

**Purpose:**
- Context7 library resolution and documentation access
- Dynamic best practices loading
- Real-time validation against standards

### Git

Git provides version control and workflow automation.

**Integration:**
- Hook-based Git operations
- Automated commit message generation
- Branch management workflows
- Release automation

### GitHub

GitHub provides hosting and CI/CD.

**GitHub Actions:**
- Automated workflows in .github/workflows/
- Documentation build and deployment
- Quality gate validation
- Release automation

## Windows Notification Technologies

### Windows Notification APIs

Options for native Windows toast notifications:

1. **PowerShell BurntToast** (Recommended)
   - Cross-platform PowerShell module
   - Simple scripting from WSL2
   - Rich notification support

2. **Windows.UI.Notifications** (COM)
   - Native Windows Runtime API
   - Direct access via Python COM interop
   - More complex but more control

3. **Command-line tools**
   - `notify-send` equivalent for Windows
   - Custom wrapper scripts
   - Simple but limited

### Implementation Example (PowerShell from WSL2)

```bash
# From WSL2, trigger Windows toast notification
powershell.exe -Command '
  New-BurntToastNotification -Text "Claude Code", "Operation completed successfully"
'
```

## Development Tools

### Documentation Tools

The project uses multiple documentation approaches:

**Markdown:**
- Primary documentation format
- Agent definitions
- Command documentation
- Project docs (.moai/project/)

**Mermaid Diagrams:**
- Architecture visualization
- Flow diagrams
- Sequence diagrams
- 21 diagram types supported

**Nextra (Future):**
- Documentation site generation
- MDX support
- Search functionality

### Quality Tools

**TRUST 5 Framework:**
- Test-first: pytest with 85% coverage threshold
- Readable: ruff linting
- Unified: black formatting, isort imports
- Secured: OWASP compliance checks
- Trackable: Structured commit messages

**Validation:**
- Pre-commit hooks for automated quality gates
- Agent-based quality validation
- CI/CD pipeline integration

## Security Considerations

### Sandboxing

Claude Code provides OS-level sandboxing for secure execution.

**Linux (WSL2):**
- bubblewrap (bwrap) for namespace-based isolation
- Filesystem restrictions
- Network domain allowlists

### Secrets Management

The project uses a `.gitignore` policy to protect credentials.

**Protected Patterns:**
- Environment files (.env, .env.*)
- Certificate files (*.pem, *.p12, *.pfx)
- Private keys (*-key.*, *_key.*)
- API tokens (*_token=*, *_secret=*)

### Access Control

**IAM-style permissions:**
- Tool access restrictions per agent type
- Read-only, write-limited, full-access agents
- System-level agents with elevated permissions

## Performance Considerations

### Token Optimization

The framework optimizes LLM token usage through:

**Progressive Disclosure:**
- Level 1: Metadata (100 tokens per skill)
- Level 2: Instructions (5K tokens)
- Level 3: Resources (unlimited, on-demand)

**Phase Separation:**
- SPEC phase: 30K tokens
- TDD phase: 180K tokens
- Docs phase: 40K tokens
- Context reset between phases via `/clear`

### Caching Strategy

**Session-Level Caching:**
- Documentation cache
- Configuration cache
- Context-aware eviction

**File-Based Caching:**
- `.moai/cache/` directory
- 30-day retention with auto-cleanup
- Efficient cache warming

## Deployment

### Distribution

The project uses Git-based distribution with:

**Version Control:**
- Single source of truth: pyproject.toml for version
- Automated version sync across files
- Release workflows via GitHub Actions

**Installation:**
- Clone repository
- Install dependencies via requirements
- Configure MCP servers
- Initialize MoAI configuration

### CI/CD Pipeline

**GitHub Actions:**
- Automated testing on push
- Documentation build validation
- Quality gate enforcement
- Automated releases

## Future Technology Considerations

### Potential Enhancements

1. **Rust Extension**: Performance-critical notification bridge
2. **TypeScript/Node.js**: Additional notification options
3. **Containerization**: Docker for reproducible environments
4. **Cross-platform**: macOS and Linux desktop notification support
5. **Mobile Companion**: Push notification mobile app

### Technology Migration Path

The current architecture supports gradual migration:

- Python remains core for hooks
- Additional languages for specific components
- API-first design for language-agnostic extensions
- Plugin system for modular enhancement
