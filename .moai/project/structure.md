# Project Structure

## Architecture Overview

Claude Notification WSL2 follows the MoAI-ADK (Model-based AI Assistant Development Kit) architectural pattern, implementing an Orchestrator-Agent system with event-driven hooks for notification delivery. The system leverages Claude Code's extensibility through hooks, agents, skills, and commands.

## Directory Organization

```
claude_notification_wsl2/
|
+-- .claude/                 # Claude Code extension directory
|   +-- agents/moai/        # Agent definitions (20 YAML files)
|   +-- commands/moai/      # Command definitions (8 workflow commands)
|   +-- hooks/moai/         # Hook implementations (Python event handlers)
|   +-- skills/             # Skill modules (15 domain-specific skills)
|   +-- output-styles/      # Response formatting styles
|   +-- logs/               # Agent execution logs
|
+-- .moai/                  # MoAI framework configuration
|   +-- config/             # Configuration files (YAML sections)
|   +-- memory/             # Long-term knowledge storage
|   +-- project/            # Project documentation (this directory)
|   +-- specs/              # EARS format specifications
|   +-- announcements/      # Multilingual announcements
|   +-- reports/            # Quality and validation reports
|   +-- cache/              # Cached data (auto-cleanup)
|   +-- llm-configs/        # LLM-specific configurations
|
+-- .github/                # GitHub CI/CD workflows
|   +-- workflows/          # Automation workflows
|
+-- CLAUDE.md               # Alfred execution directives
+-- .gitignore              # Git ignore patterns
+-- .mcp.json               # MCP server configuration
```

## Core Components

### 1. Agent System (.claude/agents/moai/)

The agent system contains 20 specialized agents organized into three tiers:

**Manager Agents (8)**
- `manager-git`: Git workflow automation and version control
- `manager-spec`: EARS specification generation and management
- `manager-tdd`: Test-driven development orchestration
- `manager-docs`: Documentation generation and validation
- `manager-quality`: Quality assurance and TRUST 5 validation
- `manager-project`: Project configuration and setup
- `manager-strategy`: System design and architecture planning
- `manager-claude-code`: Claude Code integration management

**Expert Agents (8)**
- `expert-backend`: Backend API development
- `expert-frontend`: Frontend UI implementation
- `expert-security`: Security analysis and implementation
- `expert-devops`: DevOps and infrastructure
- `expert-performance`: Performance optimization
- `expert-debug`: Debugging and troubleshooting
- `expert-testing`: Test implementation and strategy
- `expert-refactoring`: Code refactoring and optimization

**Builder Agents (4)**
- `builder-agent`: New agent creation
- `builder-command`: Command definition creation
- `builder-skill`: Skill module generation
- `builder-plugin`: Plugin package development

### 2. Command System (.claude/commands/moai/)

Workflow commands following the Plan-Run-Sync pattern:

- `0-project.md`: Project configuration management
- `1-plan.md`: Specification generation (SPEC phase)
- `2-run.md`: TDD implementation (Run phase)
- `3-sync.md`: Documentation synchronization (Sync phase)
- `alfred.md`: Intelligent routing automation
- `fix.md`: Quick fixes and loops
- `loop.md`: Loop execution control
- `cancel-loop.md`: Loop cancellation
- `9-feedback.md`: Improvement feedback collection

### 3. Hook System (.claude/hooks/moai/)

Event-driven automation with Python hook implementations:

**Session Hooks**
- `session_start__show_project_info.py`: Display project context on session start
- `session_end__auto_cleanup.py`: Automatic cleanup on session end
- `session_end__rank_submit.py`: Quality ranking submission

**Tool Hooks**
- `pre_tool__security_guard.py`: Security validation before tool execution
- `post_tool__linter.py`: Linting after code modifications
- `post_tool__code_formatter.py`: Code formatting after modifications
- `post_tool__lsp_diagnostic.py`: LSP diagnostic collection
- `post_tool__ast_grep_scan.py`: AST-based code scanning

**Support Libraries** (lib/)
- `config_manager.py`: Configuration management
- `project.py`: Project utilities
- `git_operations_manager.py`: Git operations
- `unified_timeout_manager.py`: Timeout handling
- `checkpoint.py`: Checkpoint management
- `tool_registry.py`: Tool registration
- `path_utils.py`: Path utilities
- `language_validator.py`: Language validation
- `config_validator.py`: Configuration validation

### 4. Skill System (.claude/skills/)

Domain knowledge modules with progressive disclosure:

**Foundation Skills**
- `moai-foundation-claude`: Claude Code authoring patterns
- `moai-foundation-core`: TRUST 5, SPEC-First TDD, delegation
- `moai-foundation-context`: Context optimization
- `moai-foundation-quality`: Quality assurance patterns

**Library Skills**
- `moai-library-mermaid`: Diagram generation (21 diagram types)
- `moai-library-nextra`: Nextra documentation framework

**Workflow Skills**
- `moai-workflow-docs`: Documentation workflows
- `moai-workflow-jit-docs`: Just-in-time documentation
- `moai-workflow-testing`: Testing workflows
- `moai-workflow-project`: Project management

**Domain Skills**
- `moai-domain-backend`: Backend patterns
- `moai-domain-frontend`: Frontend patterns
- `moai-domain-database`: Database patterns
- `moai-domain-uiux`: UI/UX patterns

**Format Skills**
- `moai-docs-generation`: Documentation generation
- `moai-formats-data`: Data format optimization

**Platform Skills**
- `moai-platform-clerk`: Clerk authentication
- `moai-platform-convex`: Convex database

### 5. Configuration System (.moai/config/)

Modular YAML configuration split into sections:

- `sections/user.yaml`: User personalization
- `sections/language.yaml`: Language preferences
- `sections/project.yaml`: Project metadata
- `sections/git-strategy.yaml`: Git workflow settings
- `sections/quality.yaml`: TDD and quality configuration
- `sections/system.yaml`: MoAI system version

## Notification Extension Architecture

The Windows notification capability extends this framework through:

### Hook Integration
- Custom hooks for Windows notification delivery
- Event detection from Claude Code operations
- WSL2-to-Windows bridge implementation

### Agent Extension
- Notification-focused agent for event processing
- Integration with existing agent workflows
- Custom notification rule processing

### Configuration
- Notification settings in MoAI config
- WSL2-specific Windows host configuration
- Notification template management

## Data Flow

1. **Claude Code Operation**: User initiates operation via CLI
2. **Hook Trigger**: Event triggers pre/post tool hook
3. **Notification Agent**: Notification agent processes event
4. **WSL2 Bridge**: Bridge sends notification to Windows host
5. **Windows Display**: Windows displays native toast notification
6. **Action Center**: Notification persists in Action Center

## Extension Points

The system provides multiple extension points:

1. **Custom Hooks**: Add new event types for notification
2. **Agent Modification**: Extend agents with notification logic
3. **Skill Creation**: Create domain-specific notification skills
4. **Command Addition**: Add notification management commands
5. **Configuration**: Customize notification behavior per project
