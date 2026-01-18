# Skills

Complete reference of all skills available in the Claude Code PM system.

In this fork, skills are the primary interface for orchestration. Claude Code loads skill metadata from `skills/` at startup, and the orchestrator uses those skills to advance phases.

> **Note**: Skill names mirror the historical `/pm:*` command names documented in the main [README.md](README.md#skill-reference).

## Table of Contents

- [Context Skills](#context-skills)
- [Testing Skills](#testing-skills)
- [Utility Skills](#utility-skills)
- [Review Skills](#review-skills)

## Context Skills

Skills for managing project context in `.claude/context/`.

### `/context:create`
- **Purpose**: Create initial project context documentation
- **Usage**: `/context:create`
- **Description**: Analyzes the project structure and creates comprehensive baseline documentation in `.claude/context/`. Includes project overview, architecture, dependencies, and patterns.
- **When to use**: At project start or when context needs full rebuild
- **Output**: Multiple context files covering different aspects of the project

### `/context:update`
- **Purpose**: Update existing context with recent changes
- **Usage**: `/context:update`
- **Description**: Refreshes context documentation based on recent code changes, new features, or architectural updates. Preserves existing context while adding new information.
- **When to use**: After significant changes or before major work sessions
- **Output**: Updated context files with change tracking

### `/context:prime`
- **Purpose**: Load context into current conversation
- **Usage**: `/context:prime`
- **Description**: Reads all context files and loads them into the current conversation's memory. Essential for maintaining project awareness.
- **When to use**: At the start of any work session
- **Output**: Confirmation of loaded context

## Testing Skills

Skills for test configuration and execution.

### `/testing:prime`
- **Purpose**: Configure testing setup
- **Usage**: `/testing:prime`
- **Description**: Detects and configures the project's testing framework, creates testing configuration, and prepares the test-runner agent.
- **When to use**: Initial project setup or when testing framework changes
-  **Output**: `.claude/testing-config.md` with test commands and patterns

### `/testing:run`
- **Purpose**: Execute tests with intelligent analysis
- **Usage**: `/testing:run [test_target]`
- **Description**: Runs tests using the test-runner agent which captures output to logs and returns only essential results to preserve context.
- **Options**:
   - No arguments: Run all tests
   - File path: Run specific test file
   - Pattern: Run tests matching pattern
- **Output**: Test summary with failures analyzed, no verbose output in main thread

### `/testing:fast`
- **Purpose**: Run the fast test lane on worker branches
- **Usage**: `/testing:fast`
- **Description**: Executes the fast lane if configured; otherwise maps to the default test runner and reports the scope as fast.
- **Output**: Fast lane test summary with failure analysis

### `/testing:gate`
- **Purpose**: Run the merge-gate test lane on integration branches
- **Usage**: `/testing:gate`
- **Description**: Executes the gate lane if configured; otherwise maps to the default test runner and reports the scope as gate.
- **Output**: Gate lane test summary with failure analysis

### `/testing:full`
- **Purpose**: Run the full verification test lane
- **Usage**: `/testing:full`
- **Description**: Executes the full lane if configured; otherwise maps to the default test runner and reports the scope as full.
- **Output**: Full lane test summary with failure analysis

## Utility Skills

General utility and maintenance skills.

### `/prompt`
- **Purpose**: Handle complex prompts with multiple references
- **Usage**: Write your prompt in the file, then type `/prompt`
- **Description**: Ephemeral command for when complex prompts with numerous @ references fail in direct input. The prompt is written to the command file first, then executed.
- **When to use**: When Claude's UI rejects complex prompts
- **Output**: Executes the written prompt

### `/re-init`
- **Purpose**: Update or create CLAUDE.md with PM rules
- **Usage**: `/re-init`
- **Description**: Updates the project's CLAUDE.md file with rules from `.claude/CLAUDE.md`, ensuring Claude instances have proper instructions.
- **When to use**: After cloning PM system or updating rules
- **Output**: Updated CLAUDE.md in project root

## Review Skills

Skills for handling external code review tools.

### `/code-rabbit`
- **Purpose**: Process CodeRabbit review comments intelligently
- **Usage**: `/code-rabbit` then paste comments
- **Description**: Evaluates CodeRabbit suggestions with context awareness, accepting valid improvements while ignoring context-unaware suggestions. Spawns parallel agents for multi-file reviews.
- **Features**:
   - Understands CodeRabbit lacks full context
   - Accepts: Real bugs, security issues, resource leaks
   - Ignores: Style preferences, irrelevant patterns
   - Parallel processing for multiple files
- **Output**: Summary of accepted/ignored suggestions with reasoning

## Skill Patterns

All skills follow consistent patterns:

### Allowed Tools
Each skill specifies its required tools in frontmatter:
- `Read, Write, LS` - File operations
- `Bash` - System commands
- `Task` - Sub-agent spawning
- `Grep` - Code searching

### Error Handling
Skills follow fail-fast principles:
- Check prerequisites first
- Clear error messages with solutions
- Never leave partial state

### Context Preservation
Skills that process lots of information:
- Use agents to shield main thread from verbose output
- Return summaries, not raw data
- Preserve only essential information

## Creating Custom Skills

To add new skills:

1. **Create file**: `skills/category/skill-name.md`
2. **Add frontmatter**:
   ```yaml
   ---
   allowed-tools: Read, Write, LS
   ---
   ```
3. **Structure content**:
   - Purpose and usage
   - Preflight checks
   - Step-by-step instructions
   - Error handling
   - Output format

4. **Follow patterns**:
   - Keep it simple (no over-validation)
   - Fail fast with clear messages
   - Use agents for heavy processing
   - Return concise output

## Integration with Agents

Skills often use agents for heavy lifting:

- **test-runner**: Executes tests, analyzes results
- **file-analyzer**: Summarizes verbose files
- **code-analyzer**: Hunts bugs across codebase
- **parallel-worker**: Coordinates parallel execution

This keeps the main conversation context clean while doing complex work.

## Notes

- Skills are markdown files interpreted as instructions
- Skill names mirror the historical `/pm:*` command names
- Skills can spawn agents for context preservation
- All PM skills (`/pm:*`) are documented in the main README
- Skills follow rules defined in `/rules/`
