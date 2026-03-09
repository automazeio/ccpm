---
allowed-tools: Bash, Read, Write, LS, Task
---

# Epic Start Core

Launch parallel agents to work on epic tasks in a shared branch.

**Core version for orchestration - no next step suggestions.**

## Usage
```
/pm:epic-start-core <epic_name>
```

## Quick Check

1. **Verify epic exists:**
   ```bash
   test -f .claude/epics/$ARGUMENTS/epic.md || echo "❌ Epic not found. Run: /pm:prd-parse $ARGUMENTS"
   ```

2. **Check GitHub sync:**
   Look for `github:` field in epic frontmatter.
   If missing: "❌ Epic not synced. Run: /pm:epic-sync $ARGUMENTS first"

3. **Check for branch:**
   ```bash
   git branch -a | grep "epic/$ARGUMENTS"
   ```

4. **Check for uncommitted changes:**
   ```bash
   git status --porcelain
   ```
   If output is not empty: "❌ You have uncommitted changes. Please commit or stash them before starting an epic"

## Instructions

### 1. Create or Enter Branch

Follow `/rules/branch-operations.md`:

```bash
# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
  echo "❌ You have uncommitted changes. Please commit or stash them before starting an epic."
  exit 1
fi

# If branch doesn't exist, create it
if ! git branch -a | grep -q "epic/$ARGUMENTS"; then
  git checkout main
  git pull origin main
  git checkout -b epic/$ARGUMENTS
  git push -u origin epic/$ARGUMENTS
  echo "✅ Created branch: epic/$ARGUMENTS"
else
  git checkout epic/$ARGUMENTS
  git pull origin epic/$ARGUMENTS
  echo "✅ Using existing branch: epic/$ARGUMENTS"
fi
```

### 2. Identify Ready Issues

Read all task files in `.claude/epics/$ARGUMENTS/`:
- Parse frontmatter for `status`, `depends_on`, `parallel` fields
- Check GitHub issue status if needed
- Build dependency graph

Categorize issues:
- **Ready**: No unmet dependencies, not started
- **Blocked**: Has unmet dependencies
- **In Progress**: Already being worked on
- **Complete**: Finished

### 3. Analyze Ready Issues

For each ready issue without analysis:
```bash
# Check for analysis
if ! test -f .claude/epics/$ARGUMENTS/{issue}-analysis.md; then
  echo "Analyzing issue #{issue}..."
  # Run analysis (inline or via Task tool)
fi
```

### 4. Launch Parallel Agents

For each ready issue with analysis:

```markdown
## Starting Issue #{issue}: {title}

Reading analysis...
Found {count} parallel streams:
  - Stream A: {description} (Agent-{id})
  - Stream B: {description} (Agent-{id})

Launching agents in branch: epic/$ARGUMENTS
```

Use Task tool to launch each stream.

**Prompt engineering notes:**
- XML tags separate assignment context from behavioral guidance
- Role prompting establishes parallel agent identity
- Exploration depth as DATA to interpret, not rigid rules
- Clear coordination expectations for multi-agent work

```yaml
Task:
  description: "Issue #{issue} Stream {X}"
  subagent_type: "{agent_type}"
  prompt: |
    <role>
    You are a focused implementation agent working as part of a parallel team on an epic.
    Your job is to complete your assigned stream while coordinating with other agents
    working on related streams. You commit frequently and stay within your assigned scope.
    </role>

    <assignment>
    <branch>epic/$ARGUMENTS</branch>
    <issue>#{issue} - {title}</issue>
    <stream>{stream_name}</stream>
    <files>{file_patterns}</files>
    <work>{stream_description}</work>
    </assignment>

    <exploration_boundaries depth="{exploration_depth}">
    Your exploration depth is "{exploration_depth}". Interpret this as:

    shallow: Only read specified files and their direct imports. Do not explore
    other directories. Ask before reaching outside your scope. Best for simple,
    well-defined changes where requirements are clear.

    moderate: Read specified files and their direct imports. May explore sibling
    files in the same directories to understand patterns. Stay within the general
    area of your assigned files. Do not explore unrelated parts of codebase.

    deep: Read specified files and explore related directories for patterns and
    conventions. Understand existing architecture before implementing. Focus on
    learning how similar features work in this codebase.
    </exploration_boundaries>

    <requirements>
    Read full requirements from these files before starting:
    - .claude/epics/$ARGUMENTS/{task_file}
    - .claude/epics/$ARGUMENTS/{issue}-analysis.md
    </requirements>

    <coordination>
    You are working in parallel with other agents. Follow these principles:
    - Commit frequently with message format: "Issue #{issue}: {specific change}"
    - Stay within your assigned file patterns to avoid conflicts
    - Update progress in: .claude/epics/$ARGUMENTS/updates/{issue}/stream-{X}.md
    - If you need files outside your scope, coordinate via progress file
    - See /rules/agent-coordination.md for detailed coordination rules
    </coordination>

    <deployment>
    If your changes affect runtime code:
    - Use /pm:build-deployment for building images
    - Use /pm:deploy for deploying to environment
    - Check execution-status.md for deploy lock before deploying
    </deployment>

    <output_expectations>
    Work autonomously to complete your stream. Commit as you go. Update your
    progress file with what you've completed and any blockers. When finished,
    mark your stream as complete in the progress file.
    </output_expectations>
```

### 5. Track Active Agents

Create/update `.claude/epics/$ARGUMENTS/execution-status.md`:

```markdown
---
started: {datetime}
branch: epic/$ARGUMENTS
---

# Execution Status

## Active Agents
- Agent-1: Issue #1234 Stream A (Database) - Started {time}
- Agent-2: Issue #1234 Stream B (API) - Started {time}
- Agent-3: Issue #1235 Stream A (UI) - Started {time}

## Queued Issues
- Issue #1236 - Waiting for #1234
- Issue #1237 - Waiting for #1235

## Completed
- {None yet}
```

### 6. Monitor and Coordinate

Set up monitoring:
```bash
echo "
Agents launched successfully!
"
```

### 7. Handle Dependencies

As agents complete streams:
- Check if any blocked issues are now ready
- Launch new agents for newly-ready work
- Update execution-status.md

## Output Format

```
🚀 Epic Execution Started: $ARGUMENTS

Branch: epic/$ARGUMENTS

Launching {total} agents across {issue_count} issues:

Issue #1234: Database Schema
  ├─ Stream A: Schema creation (Agent-1) ✓ Started
  └─ Stream B: Migrations (Agent-2) ✓ Started

Issue #1235: API Endpoints
  ├─ Stream A: User endpoints (Agent-3) ✓ Started
  ├─ Stream B: Post endpoints (Agent-4) ✓ Started
  └─ Stream C: Tests (Agent-5) ⏸ Waiting for A & B

Blocked Issues (2):
  - #1236: UI Components (depends on #1234)
  - #1237: Integration (depends on #1235, #1236)
```

**DO NOT suggest next steps or mention other commands.**

## Error Handling

If agent launch fails:
```
❌ Failed to start Agent-{id}
  Issue: #{issue}
  Stream: {stream}
  Error: {reason}

Continue with other agents? (yes/no)
```

If uncommitted changes are found:
```
❌ You have uncommitted changes. Please commit or stash them before starting an epic.

To commit changes:
  git add .
  git commit -m "Your commit message"

To stash changes:
  git stash push -m "Work in progress"
  # (Later restore with: git stash pop)
```

If branch creation fails:
```
❌ Cannot create branch
  {git error message}

Try: git branch -d epic/$ARGUMENTS
Or: Check existing branches with: git branch -a
```

## Agent Deploy Capability

Agents can deploy after completing their work if the epic's scope has deploy enabled.

### When Agents Should Deploy

1. **After completing a task** that changes runtime code (not just tests)
2. **When testing requires a running app** (E2E, integration tests)
3. **When explicitly instructed** in the task/issue

### How Agents Deploy

Include in agent prompt when deploy is enabled:
```markdown
After completing your changes, if they affect runtime code:
1. Commit your changes
2. Run `/pm:deploy {scope}` to build and deploy
3. Verify pods are healthy: `kubectl get pods -n {namespace}`
4. Continue with next task or report completion
```

### Deploy Coordination

When multiple agents are working:
- Only ONE agent should deploy at a time
- Use the execution-status.md to coordinate:
  ```markdown
  ## Deploy Lock
  - Locked by: Agent-{id}
  - Since: {timestamp}
  - Reason: Deploying after Issue #{number}
  ```
- Other agents wait for deploy to complete before deploying
- Lock is released after `kubectl wait` succeeds

## Important Notes

- Follow `/rules/branch-operations.md` for git operations
- Follow `/rules/agent-coordination.md` for parallel work
- Agents work in the SAME branch (not separate branches)
- Maximum parallel agents should be reasonable (e.g., 5-10)
- Monitor system resources if launching many agents
- When deploy is enabled, agents can call `/pm:deploy` after completing work
