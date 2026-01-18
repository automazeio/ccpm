# Agentic Orchestrator Architecture

This document defines the autonomous orchestration layer for CCPM. The orchestrator runs the full workflow from a single accepted idea through completion of every epic in the roadmap, using GitHub as the authoritative project state and a local state cache for resiliency.

## Goals

- **Fully autonomous execution** after the initial idea is accepted.
- **Roadmap-first planning** to sequence multiple epics before execution.
- **Stateful orchestration** with resilient retries and automatic recovery.
- **Skill-based execution** built from CCPM commands (converted into deterministic skills).
- **Parallel delivery** with up to **12 workers**, without creating merge bottlenecks.
- **Safe, no-human-review merging** via an **integration branch merge gate**.
- **End-to-end delivery** including test/run/fix loops until the roadmap is complete.

## Authoritative State: GitHub + Local Cache

### GitHub as Source of Truth

GitHub Issues remain the authoritative state for:

- Roadmap progress (epics checklist)
- Epic issues and task issues
- Issue status (open/closed, labels, comments)
- Sync visibility and audit trail

### Local Cache for Orchestration

A lightweight local cache stores orchestration-only state for resumability and debugging:

- current phase and pointers
- retry counters and error classification
- worker assignments and merge queue bookkeeping
- last successful checkpoints and timestamps

Local state must be reconstructable from GitHub + filesystem at startup.

## Roadmap Layer

### Roadmap Lives in GitHub (Authoritative)

The roadmap is represented as a single GitHub Issue (for example, titled `Roadmap` or `Roadmap: <project>`), containing a checklist of epics.

**Canonical structure (recommended):**

- [ ] epic-name-1 — short intent summary
- [ ] epic-name-2 — short intent summary

Optionally include sequencing rationale, risks, constraints, and links to epic issues.

### Local Roadmap Mirror (Convenience)

Maintain a local mirror for easy navigation (fixed location for consistency):

```
.claude/roadmap.md
```

This file is generated/updated from GitHub and should be treated as a cache.

**Suggested structure**:

```markdown
---
name: roadmap
status: active
created: <ISO8601>
updated: <ISO8601>
github_issue: <url>
---

# Roadmap

## Epics
- [ ] epic-name-1 — short intent summary
- [x] epic-name-2 — short intent summary

## Notes
- Constraints, sequencing rationale, high-level risks
```

**Invariant:** Roadmap epic identifiers must map 1:1 to:

- PRD file: `.claude/prds/<epic>.md`
- Epic folder: `.claude/epics/<epic>/`
- Epic issue in GitHub (once synced)

## Orchestrator Files and Layout

```
.claude/orchestrator/
  config.yaml
  state.json
  events.ndjson
  workers/
    <worker_id>.json
  help/
    <timestamp>.md
  STOP
```

- `config.yaml`: policy knobs (parallelism, sync policy, testing lanes, safety)
- `state.json`: orchestration cache for resume
- `events.ndjson`: append-only event log (debug/audit)
- `workers/`: per-worker status/heartbeat files
- `help/`: escalation help packets
- `STOP`: kill-switch file; if present, orchestrator halts safely

## Orchestrator Configuration (Default Policy)

Example defaults (adjust as needed):

```yaml
parallelism:
  max_workers: 12

sync:
  mode: event_and_periodic
  periodic_minutes: 30
  post_level: epic_summary   # avoid spam from workers
  always_post_on_error: true

git:
  main_branch: main
  integration_branch_prefix: integration/
  issue_branch_prefix: issue/
  merge_strategy: merge_commit   # simplest & most recoverable

testing:
  lanes:
    fast:
      required: true
      skill: testing:fast
    gate:
      required: true
      skill: testing:gate
    full:
      required: true
      skill: testing:full

retries:
  transient_max: 2
  step_max_if_previously_succeeded: 3

safety:
  kill_switch_file: .claude/orchestrator/STOP
  require_clean_worktree_for_merge: true
```

## Orchestrator State

Track orchestration state in a lightweight local file:

```
.claude/orchestrator/state.json
```

This file records:
- current phase (`idea`, `roadmap`, `prd`, `epic`, `tasks`, `sync`, `parallel_execution`, `integration`, `closeout`, `verification`, `complete`)
- active epic identifier
- active issue ids and mapping to local task files
- worker pool state (assigned workers, last heartbeat)
- merge queue state (ready branches, ordering, conflicts)
- retry counters by step and last error summary
- transition timestamps and last successful checkpoint

**Key principle:** At startup, the orchestrator reconciles GitHub + filesystem and repairs `state.json` if missing/stale.

## Workflow State Machine

### 0. Bootstrap + Reconcile

- Ensure CCPM is initialized (`pm:init`), context primed, and required tooling validated.
- Reconcile state from GitHub and local `.claude/` artifacts:
  - find or create Roadmap issue
  - parse roadmap checklist
  - locate existing PRDs, epics, tasks, and GitHub issue mappings
- Hydrate/repair `state.json`

### 1. Idea Intake (User Involved)

- Brainstorm with the user.
- Output: accepted idea summary + constraints.
- Once accepted, the orchestrator runs autonomously.

### 2. Roadmap Creation / Update

- Create or update Roadmap issue checklist in GitHub.
- Mirror to `.claude/roadmap.md`.
- Select the next unchecked epic.

### 3. PRD Generation

- Generate `.claude/prds/<epic>.md` using PRD skill.
- Confirm acceptance criteria, constraints, and non-goals are explicit.

### 4. Epic Planning

- Parse PRD into `.claude/epics/<epic>/epic.md`.

### 5. Task Decomposition

- Create task files in `.claude/epics/<epic>/` with:
  - scope/ownership hints (files/directories/modules)
  - dependencies
  - acceptance criteria
  - parallelizability flags

### 6. GitHub Sync

- Create Epic + Task issues in GitHub and link them.
- Establish stable mapping: local task file ↔ GitHub issue id.
- Prepare worktrees/branches as needed.

### 7. Parallel Implementation (up to 12 workers)

- Select work items based on dependencies and readiness.
- Spawn workers up to `max_workers`.
- Each worker:
  - works in its own worktree/branch
  - commits changes on its branch
  - runs fast test lane (`testing:fast`)
  - reports status and marks issue “ready-to-merge” when complete

### 8. Integration & Merge Gate (serialized merges, parallel work continues)

- Orchestrator maintains a merge queue for “ready-to-merge” branches.
- Uses an epic integration branch:

```
integration/<epic>
```

Merge sequence:

1. Merge one ready branch into `integration/<epic>`
2. Run gate test lane (`testing:gate`)
3. If green, continue with next merge queue item
4. If conflict or failure:
   - classify error (conflict vs failing tests)
   - resolve via a dedicated “fix/conflict” worker or orchestrator action
   - retry the merge-gate step

When all tasks are merged and gate tests are green:

- Merge `integration/<epic>` → `main`
- Run full test lane (`testing:full`) as epic closeout verification

### 9. Epic Closeout

- Close completed task issues and epic issue (GitHub is authoritative).
- Update Roadmap checklist item to checked in GitHub.
- Mirror roadmap locally.
- Produce an epic summary comment (what changed, verification status, any follow-ups).

### 10. Completion

- Repeat for the next unchecked epic.
- Finish when all roadmap epics are checked.
- Run a final roadmap completion verification (full lane and any long-running suite if configured).

## Error Handling

### Failure Classification

- **Transient**: network timeouts, GitHub rate limits, tool hiccups
- **Invariant/Environment**: dirty git state, missing worktree, auth problems
- **Conflict**: merge conflicts, overlapping file edits
- **Verification**: failing tests (fast/gate/full)
- **Spec/Requirement ambiguity**: missing acceptance criteria, unclear expected behavior

### Retry Policy

- **Automatic retries** on recoverable failures.
- **Transient**: retry up to `transient_max`.
- **Previously succeeded steps**: allow up to `step_max_if_previously_succeeded`.
- **Conflicts/tests**: attempt bounded remediation loops, then escalate.

### Stateful Recovery

- State file records last step, last error, and retry counts.
- On restart: reconcile + resume from last safe checkpoint.

### Escalation

If retries are exhausted:

- orchestrator halts safely
- writes a help packet to `.claude/orchestrator/help/<timestamp>.md` containing:
  - current state snapshot
  - last error logs
  - proposed next actions
- posts a GitHub update indicating it needs help

### Kill Switch

If `.claude/orchestrator/STOP` exists:

- stop scheduling new work
- finish any safe in-flight step if possible
- persist state and halt

## Skills Inventory

Commands are treated as skills. The orchestrator chooses from these based on state:

### Core Workflow Skills
- `pm:init`
- `pm:prd-new`
- `pm:prd-parse`
- `pm:epic-decompose`
- `pm:epic-sync`
- `pm:epic-oneshot`
- `pm:issue-analyze`
- `pm:issue-start`
- `pm:issue-sync`
- `pm:issue-close`
- `pm:epic-close`
- `pm:epic-merge`
- `pm:next`
### Testing Skills (Lanes)

- `testing:fast`
- `testing:gate`
- `testing:full`

### Supporting Skills
- `context:create`
- `context:update`
- `context:prime`
- `pm:epic-start`
- `pm:epic-start-worktree`
- `pm:epic-refresh`
- `pm:epic-status`
- `pm:issue-status`
- `pm:issue-show`
- `pm:issue-edit`
- `pm:issue-reopen`
- `pm:blocked`
- `pm:in-progress`
- `pm:status`
- `pm:standup`
- `pm:search`
- `pm:sync`
- `pm:validate`
- `pm:import`
- `pm:clean`
- `pm:epic-list`
- `pm:epic-show`
- `pm:epic-edit`
- `pm:prd-list`
- `pm:prd-status`
- `pm:prd-edit`
- `pm:help`

### Not required as skills for autonomous workflow
These are useful interactively, but not required for the orchestrator loop itself:
- `prompt` (UI workaround)
- `re-init` (manual CLAUDE.md sync)
- `code-rabbit` (external review tool integration)
- `pm:test-reference-update` (manual bookkeeping)

### Skill Discovery (Recommended)

Rather than hardcoding forever, the orchestrator should dynamically discover available skills from CCPM’s `.claude/commands/**` directory and build a registry. The list above is the preferred subset for the autonomous loop.

## Skill Invocation Policy

- Skills can be invoked without user action once the idea is accepted.
- The orchestrator should prefer the minimal skill that advances the workflow.
- For irreversible actions (e.g., creating issues, merging to main):
  - run quick preflight checks (auth, clean git state, required files present)
  - proceed automatically under the merge-gate policy
- Use explicit idempotency checks:
  - artifact already exists? (PRD/epic/task files)
  - issues already created? (GitHub ids present)
  - branch already merged? (merge-base checks)

## Worker Runtime (Concrete Mechanism)

To support true parallelism, introduce a worker runtime that the orchestrator controls.

### Worker Responsibilities

- Checkout correct worktree/branch for an assigned issue.
- Load a prompt bundle:
  - issue spec (GitHub + local task md)
  - repo conventions and constraints
  - explicit file scope/ownership boundaries
- Implement, commit, and run `testing:fast`.
- Update status to GitHub (via orchestrator or direct minimal comments).
- Write heartbeat/status to `.claude/orchestrator/workers/<worker_id>.json`.

### Worker Outputs (Machine-Readable)

Each worker must end by producing:

- `result: success | blocked | failed`
- `branch: <issue branch>`
- `files_touched: [...]` (best effort)
- `fast_tests: pass | fail`
- `ready_to_merge: true/false`
- `notes:` short summary for GitHub update

### Worker Safety/Scope Control

- Each task should include a scope hint (directories/files/modules).
- Orchestrator attempts to avoid concurrent workers modifying the same scope.
- If overlap is detected, serialize those tasks or adjust assignments.

## Sync Policy (GitHub Updates)

### Event-Driven + Periodic Summary (Default)

- Sync on state transitions:
  - task started, task blocked, task ready-to-merge, merged, tests failed/passed, epic closed
- Post an epic-level summary every ~30 minutes (configurable).
- Avoid spam from each worker; orchestrator aggregates.

### Always Sync on Errors

If any step fails beyond retry limits, orchestrator posts:

- what failed
- classification (transient vs conflict vs test failure)
- what remediation is being attempted
- what help is needed (if escalating)

## Testing Strategy (Three Lanes)

To minimize complexity while ensuring quality, define three test lanes:

1. **Fast (Worker Lane)**
   - runs on worker branches
   - should be quick: lint/typecheck/unit subset
   - objective: catch obvious failures early

2. **Gate (Integration Lane)**
   - runs on `integration/<epic>` after each merge (or small batches)
   - objective: prevent regressions entering `main`

3. **Full (Closeout Lane)**
   - runs after merging epic to `main`, and again at roadmap completion
   - objective: high confidence the system remains healthy

**Note:** If the repo doesn’t yet have distinct commands, lanes can initially map to the same underlying test runner, but the lane abstraction must exist.

## Tests and Fixes

## Roadmap Completion Rule

The orchestration loop continues until every epic checkbox in the GitHub Roadmap issue is checked off. The orchestrator mirrors this into `.claude/roadmap.md` locally.

At roadmap completion:

- run `testing:full` (and any configured long-running suite)
- produce a final GitHub summary with:
  - epics completed
  - verification results
  - notable risks/known issues
  - suggested follow-ups
