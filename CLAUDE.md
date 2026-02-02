# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CCPM (Claude Code Project Manager) is a project management system that transforms PRDs into GitHub Issues and production code through specialized AI agents. It uses GitHub Issues as a distributed database for human-AI collaboration, enabling parallel agent execution with full traceability.

**Key innovation**: One issue can explode into multiple parallel work streams (5-8 agents simultaneously) while the main thread stays clean.

## Repository Structure

```
ccpm/                     # The PM system (copy to project's .claude/)
├── agents/               # 4 specialized agents (code-analyzer, file-analyzer, test-runner, parallel-worker)
├── commands/             # Markdown command definitions
│   ├── context/          # /context:create, /context:update, /context:prime
│   ├── pm/               # 30+ project management commands
│   └── testing/          # /testing:prime, /testing:run
├── rules/                # 11 reusable pattern files
├── scripts/pm/           # Shell scripts for commands
├── prds/                 # PRD storage
├── epics/                # Local epic workspace (.gitignore'd)
├── ccpm.config           # GitHub repo detection
└── settings.local.json   # Security permissions
```

## Testing & Validation

No formal test suite - this is a bash/markdown system. Validate with:
```bash
bash ccpm/scripts/pm/validate.sh    # Check system integrity
bash ccpm/scripts/pm/status.sh      # Project dashboard
```

## Key Commands

Commands are markdown files in `ccpm/commands/` that Claude interprets as instructions.

**Workflow**: `/pm:prd-new` → `/pm:prd-parse` → `/pm:epic-decompose` → `/pm:epic-sync` → `/pm:issue-start`

**Essential**:
- `/pm:init` - Setup GitHub CLI and labels
- `/pm:help` - Command reference
- `/pm:status` - Project dashboard
- `/pm:next` - Get next priority task

## Architecture Patterns

### Command Structure
Commands use frontmatter for tool permissions:
```yaml
---
allowed-tools: Bash, Read, Write, LS, Task
---
```

### Agent Pattern
Agents are "context firewalls" - they do heavy work and return concise summaries:
- `code-analyzer` - Hunt bugs across files, return bug report
- `file-analyzer` - Summarize verbose files (80-90% size reduction)
- `test-runner` - Run tests, return summary with failure analysis
- `parallel-worker` - Coordinate multiple work streams, consolidate results

### Error Handling
```
❌ {What failed}: {Exact solution}
```

### File Naming
Tasks: `001.md`, `002.md` during creation → `{issue-id}.md` after GitHub sync

### Frontmatter Format
```yaml
---
name: "Task name"
status: open          # open, in-progress, completed
created: 2024-01-15T10:30:00Z
parallel: true
depends_on: [001]
---
```

## GitHub Integration

Uses `gh` CLI exclusively. The `ccpm.config` script auto-detects repository from git remote.

**Safety**: Commands check remote origin to prevent accidental syncs to the CCPM template repo.

**Labels**: `epic:feature-name`, `task:feature-name`

## Development Guidelines

### When Modifying Commands
- Follow patterns in `ccpm/rules/standard-patterns.md`
- Minimal preflight checks - trust the system usually works
- Reference rules files instead of duplicating instructions
- Keep output concise - no decorative emoji spam

### When Modifying Agents
- Single purpose per agent
- Return 10-20% of what you process
- No "specialist" roleplay - agents are task executors
- Error handling must be clear and actionable

### When Modifying Scripts
- Scripts live in `ccpm/scripts/pm/`
- Use `ccpm.config` functions for GitHub operations
- Exit with clear error messages on failure
