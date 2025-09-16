# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Code PM (CCPM) is a comprehensive project management system for Claude Code that implements spec-driven development using GitHub Issues, Git worktrees, and parallel AI agents. It transforms PRDs into epics, epics into GitHub issues, and issues into production code with full traceability.

## Core PM Commands

### Essential Workflow
```bash
/pm:prd-new <name>        # Create comprehensive PRD through brainstorming
/pm:prd-parse <name>      # Transform PRD into technical epic  
/pm:epic-decompose <name> # Break epic into actionable tasks
/pm:epic-sync <name>      # Push epic and tasks to GitHub
/pm:epic-start <name>     # Launch parallel agent execution
```

### Quick Actions
```bash
/pm:next                  # Get next priority task with epic context
/pm:status               # View project dashboard
/pm:issue-start <num>    # Begin work on specific issue
/pm:issue-sync <num>     # Push progress updates to GitHub
```

For complete command reference: `/pm:help`

## Architecture

### Directory Structure
```text
.claude/
├── prds/              # Product Requirements Documents
├── epics/             # Implementation plans and tasks
│   └── [epic-name]/
│       ├── epic.md    # Technical implementation plan
│       ├── [#].md     # Individual task files (synced with GitHub issues)
│       └── updates/   # Work-in-progress updates
├── agents/            # Specialized task agents
├── scripts/pm/        # PM automation scripts
└── context/           # Project-wide context files
```

### Specialized Agents

**Always use these agents for their specific purposes:**

- **file-analyzer**: Analyze and summarize log files or verbose outputs to reduce context usage
- **code-analyzer**: Search code, analyze bugs, trace logic flow across files
- **test-runner**: Execute tests with comprehensive logging and analysis
- **parallel-worker**: Execute parallel work streams in git worktrees

## Development Workflow

### 1. Feature Development Process
- Start with `/pm:prd-new` to create comprehensive requirements
- Use `/pm:prd-parse` to generate technical implementation plan
- Break down with `/pm:epic-decompose` into parallel-executable tasks
- Sync to GitHub with `/pm:epic-sync` or `/pm:epic-oneshot`
- Execute with specialized agents via `/pm:issue-start`

### 2. Testing
```bash
# Prime testing environment
/testing:prime

# Run tests with the test-runner agent
/testing:run

# Use test script for logging
bash .claude/scripts/test-and-log.sh path/to/test.py [log_name]
```

### 3. GitHub Integration
- All work tracked through GitHub Issues
- Use `gh` CLI for all GitHub operations
- Parent-child relationships via gh-sub-issue extension
- Labels automatically managed: `epic:<name>`, `task:<name>`

## Key Principles

### No Vibe Coding
Every line of code must trace back to a specification. Follow the 5-phase discipline:
1. **Brainstorm** - Think deeper than comfortable
2. **Document** - Write specs that leave nothing to interpretation  
3. **Plan** - Architect with explicit technical decisions
4. **Execute** - Build exactly what was specified
5. **Track** - Maintain transparent progress at every step

### Parallel Execution
Issues aren't atomic - they're multiple parallel work streams:
- Database migrations
- Service layer
- API endpoints  
- UI components
- Tests and documentation

All running simultaneously in the same worktree.

### Context Optimization
- Main conversation stays strategic
- Each agent handles its own context in isolation
- Implementation details never pollute main thread
- Use sub-agents aggressively to preserve context

## Important Notes

- **GitHub Issues as Database**: Issues are the single source of truth for project state
- **Transparent Progress**: All updates visible in GitHub issue comments
- **No Mocking**: Always use real implementations in tests
- **Sequential Test Execution**: Avoid parallel test issues
- **Git Worktrees**: Enable conflict-free parallel development
- **Always Sync**: Use `/pm:issue-sync` to push local progress to GitHub

## Script Permissions

These commands can be run without user approval:
- All PM scripts: `bash .claude/scripts/pm/*`
- Test runner: `bash .claude/scripts/test-and-log.sh`
- GitHub CLI operations: `gh *`
- Git operations: `git *`
- the current repository is <https://github.com/jeremymanning/ccpm>