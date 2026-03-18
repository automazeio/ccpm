# CCPM – The Project Manager Agent

[![Agent Skills](https://img.shields.io/badge/Agent_Skills-compatible-4b3baf)](https://agentskills.io)
&nbsp;
[![Eval Score](https://img.shields.io/badge/eval_score-100%25-brightgreen)](#proven-results)
&nbsp;
[![GitHub Issues](https://img.shields.io/badge/+-GitHub%20Issues-1f2328)](https://github.com/automazeio/ccpm)
&nbsp;
[![MIT License](https://img.shields.io/badge/License-MIT-28a745)](LICENSE)
&nbsp;
[![Follow on 𝕏](https://img.shields.io/badge/𝕏-@aroussi-1c9bf0)](http://x.com/intent/follow?screen_name=aroussi)
&nbsp;
[![Star this repo](https://img.shields.io/github/stars/automazeio/ccpm.svg?style=social&label=Star%20this%20repo&maxAge=60)](https://github.com/automazeio/ccpm)

### Spec-driven development for AI agents – ship ~~faster~~ _better_ using PRDs, GitHub issues, and multiple agents running in parallel.

Stop losing context. Stop blocking on tasks. Stop shipping bugs. CCPM gives your AI agent a structured PM brain: turn ideas into PRDs, PRDs into epics, epics into GitHub issues, and issues into production code — with full traceability at every step.

---

> [!IMPORTANT]
> 📢 **CCPM is now an AGENT SKILL!** It works with any [Agent Skills–compatible](https://agentskills.io) harness that supports skills: **Claude Code, Codex, OpenCode, Factory, Amp, Cursor, and more.**

---

![CCPM](screenshot.webp)

## Table of Contents

- [Background](#background)
- [The Workflow](#the-workflow)
- [What Makes This Different](#what-makes-this-different)
- [Why GitHub Issues](#why-github-issues)
- [Core Principle: No Vibe Coding](#core-principle-no-vibe-coding)
- [The Parallel Execution System](#the-parallel-execution-system)
- [Key Features & Benefits](#key-features--benefits)
- [Install](#install)
- [Usage](#usage)
- [Workflow Phases](#workflow-phases)
- [Skill Structure](#skill-structure)
- [Example Flow](#example-flow)
- [Proven Results](#proven-results)
- [Local vs Remote](#local-vs-remote)
- [Technical Notes](#technical-notes)
- [Who's Behind this Project](#whos-behind-this-project)

---

> [!NOTE]
> Check out **[proof](https://github.com/automazeio/proof)** to get your agents capture visual proof of work of terminal output, browser interactions, and mobile simulator recordings.

---

## Background

Every team struggles with the same problems:
- **Context evaporates** between sessions, forcing constant re-discovery
- **Parallel work creates conflicts** when multiple agents touch the same code
- **Requirements drift** as verbal decisions override written specs
- **Progress becomes invisible** until the very end

CCPM solves all of that.

---

## The Workflow

```mermaid
graph LR
    A[PRD Creation] --> B[Epic Planning]
    B --> C[Task Decomposition]
    C --> D[GitHub Sync]
    D --> E[Parallel Execution]
```

### See It In Action

```
"I want to build a notification system — where do we start?"
→ Guided brainstorming + PRD creation

"break down the notification-system epic"
→ Parallelizable task files with dependencies

"sync the notification-system epic to GitHub"
→ Epic issue + sub-issues + worktree

"start working on issue 42"
→ Parallel stream analysis + multiple agents launched

"what's our standup for today?"
→ Instant report from project files
```

---

## What Makes This Different

| Traditional AI Development | CCPM |
|---|---|
| Context lost between sessions | **Persistent context** across all work |
| One agent, one task | **Parallel agents** on independent streams |
| Vibe coding from memory | **Spec-driven** with full traceability |
| Progress hidden in chat logs | **Transparent audit trail** in GitHub |
| Scattered status updates | **Structured standup, blocked, next** |

---

## Why GitHub Issues

Most AI coding workflows operate in isolation — a single session with no shared state. CCPM uses GitHub Issues as the source of truth, which unlocks something fundamentally different:

**Team collaboration** — multiple agents (or humans) work on the same project simultaneously. Progress is visible in real-time through issue comments.

**Seamless handoffs** — an agent can start a task, a human can finish it, or vice versa. No "what did the AI do?" meetings.

**Single source of truth** — no separate databases or project management tools. Issue state is project state. Comments are the audit trail.

**Works with what you have** — no dependency on GitHub Projects. Integrates with existing labels, milestones, and PR workflows.

---

## Core Principle: No Vibe Coding

> **Every line of code must trace back to a specification.**

CCPM enforces a strict 5-phase discipline:

1. **🧠 Brainstorm** — think deeper than comfortable
2. **📝 Document** — write specs that leave nothing to interpretation
3. **📐 Plan** — architect with explicit technical decisions
4. **⚡ Execute** — build exactly what was specified
5. **📊 Track** — maintain transparent progress at every step

No shortcuts. No assumptions. No regrets.

---

## The Parallel Execution System

### Issues Aren't Atomic

Traditional thinking: **one issue = one agent = one task**

Reality: a single "Implement user authentication" issue is actually:

- **Agent 1**: Database tables and migrations
- **Agent 2**: Service layer and business logic
- **Agent 3**: API endpoints and middleware
- **Agent 4**: UI components and forms
- **Agent 5**: Test suites and documentation

All running **simultaneously** in the same worktree.

### The Math of Velocity

| Approach | Agents working | Wall time |
|---|---|---|
| Traditional (serial) | 1 | 5x |
| CCPM (parallel streams) | 5 | 1x |

### Context Stays Clean

Each agent handles its own context in isolation. Your main conversation becomes the conductor — it never drowns in implementation details. Agents read from `.claude/epics/` and commit progress back through Git.

---

## Key Features & Benefits

**🧠 Context preservation** — project state lives in files, not in your head or chat history. Start a session anywhere, any time.

**⚡ Parallel execution** — tasks marked `parallel: true` run concurrently across multiple agents without conflicts.

**🔗 GitHub native** — works with tools your team already uses. No dependency on the Projects API.

**📊 Full traceability** — every decision documented. PRD → Epic → Task → Issue → Code → Commit.

**🤖 Deterministic ops run as scripts** — status, standup, search, validate all run as bash scripts: fast, consistent, no LLM token cost.

**🌐 Harness-agnostic** — follows the [agentskills.io](https://agentskills.io) open standard. Works with Factory, Claude Code, Amp, OpenCode, Codex, Cursor, and more.

---

## Install

CCPM is a standard [Agent Skill](https://agentskills.io). Point your harness at `skill/ccpm/` — that's it.

### Clone the repo

```bash
git clone https://github.com/automazeio/ccpm.git
```

### Factory / Droid

```bash
# Symlink into your skills directory
ln -s /path/to/ccpm/skill/ccpm ~/.factory/skills/ccpm
```

### Claude Code

In your project root, add a `skills/` directory and symlink or copy the skill:

```bash
ln -s /path/to/ccpm/skill/ccpm .claude/skills/ccpm
```

### Any other Agent Skills–compatible harness

Point it at `skill/ccpm/`. It follows the [agentskills.io](https://agentskills.io) standard and works out of the box.

### Prerequisites

- `git` and `gh` CLI (authenticated: `gh auth login`)
- A GitHub repository for your project

---

## Usage

CCPM activates automatically when your agent detects PM intent. Just talk naturally — no special syntax needed.

### Natural language triggers

| What you say | What happens |
|---|---|
| "I want to build X" / "let's plan X" | Brainstorming + PRD creation |
| "parse the X PRD" / "create an epic for X" | PRD → technical epic |
| "break down the X epic" | Epic decomposition into tasks |
| "sync the X epic to GitHub" | Issues created, worktree set up |
| "start working on issue N" | Analysis + parallel agents launched |
| "standup" / "what's our status" | Bash script runs instantly |
| "what's next" / "what's blocked" | Priority queue from project files |
| "close issue N" | Local + GitHub updated |
| "merge the X epic" | Tests, merge, cleanup |

---

## Workflow Phases

### 1. Plan — Capture requirements

```
"I want to build a notification system — push, email, and in-app"
```

CCPM conducts guided brainstorming before writing anything. It asks about the problem, users, success criteria, constraints, and what's out of scope — then creates a structured PRD at `.claude/prds/<name>.md`.

When ready: "parse the notification-system PRD" → produces a technical epic at `.claude/epics/notification-system/epic.md` with architecture decisions, technical approach, and task preview.

### 2. Structure — Break it down

```
"break down the notification-system epic into tasks"
```

Each task gets a file with acceptance criteria, effort estimate, `depends_on`, `parallel`, and `conflicts_with` metadata. Tasks are intelligently batched for parallel creation. ≤10 tasks per epic by default.

### 3. Sync — Push to GitHub

```
"sync the notification-system epic to GitHub"
```

Creates an epic issue, creates sub-issues for each task, renames local files to match GitHub issue numbers, sets up a dedicated worktree (`../epic-notification-system/`), and creates a mapping file for reference.

### 4. Execute — Start building

```
"start working on issue 42"
```

Analyzes the issue for independent work streams, launches parallel agents scoped to their own files, and sets up progress tracking. Each agent commits with `Issue #N: description` and coordinates through Git.

### 5. Track — Know where things stand

```
"standup" / "what's blocked" / "what's next"
```

All tracking operations run as bash scripts — instant output, no LLM overhead. The scripts scan `.claude/epics/` and report what's in progress, what's next, and what's blocked.

---

## Skill Structure

```
skill/ccpm/
├── SKILL.md                  # Entry point — detects intent, routes to reference
└── references/
    ├── plan.md               # PRD writing + parsing to epic
    ├── structure.md          # Epic decomposition into tasks
    ├── sync.md               # GitHub sync, progress comments, close, merge
    ├── execute.md            # Issue analysis + parallel agent launch
    ├── track.md              # Status, standup, search, next, blocked
    ├── conventions.md        # File formats, frontmatter schemas, git rules
    └── scripts/              # Bash scripts for deterministic operations
        ├── status.sh
        ├── standup.sh
        ├── epic-list.sh
        ├── search.sh
        └── ...               # 14 scripts total
```

Your project files live in `.claude/` in your project root:

```
.claude/
├── prds/                     # Product requirement documents
├── epics/
│   └── <feature>/
│       ├── epic.md           # Technical epic
│       ├── <N>.md            # Task files (named by GitHub issue number after sync)
│       ├── <N>-analysis.md   # Parallel work stream analysis
│       └── updates/          # Agent progress tracking
└── (archived epics)
```

Files are the source of truth — plain markdown that lives in your repo, no external services.

---

## Example Flow

```
You: "I want to build a payment integration with Stripe — subscriptions and one-time charges"

CCPM: Asks 5 clarifying questions about scope, users, success criteria...

You: [answers]

CCPM: ✅ PRD created: .claude/prds/payment-integration.md
      Ready to create the technical epic?

You: "yes, parse it"

CCPM: ✅ Epic created: .claude/epics/payment-integration/epic.md
      8 task categories identified. Ready to decompose?

You: "break it down"

CCPM: ✅ Created 7 tasks — 5 parallel, 2 sequential
      Ready to push to GitHub?

You: "sync it"

CCPM: ✅ Epic #1234 created
      ✅ 7 sub-issues created (#1235–#1241)
      ✅ Worktree: ../epic-payment-integration/

You: "start working on issue 1235"

CCPM: Analyzed 3 parallel streams:
      Stream A: Stripe client setup ✓ Started
      Stream B: Webhook handler ✓ Started
      Stream C: Database models ⏸ Waiting on A

You: "what's our standup?"

CCPM: [runs standup.sh instantly]
      📅 Daily Standup — 2026-03-18
      🔄 In Progress: Issue #1235 (payment-integration) — 60%
      ⏭️ Next: Issue #1236 — Subscription billing logic
      📊 Tasks: 2 in progress, 5 open, 0 closed
```

---

## Proven Results

Teams using this system report:
- **89% less time** lost to context switching
- **5–8 parallel tasks** vs 1 previously
- **75% reduction** in bug rates — due to detailed task breakdown before coding
- **Up to 3× faster** feature delivery

### Benchmark

In structured evals comparing CCPM-equipped agents vs baseline (no skill):

| Scenario | With CCPM | Without |
|---|---|---|
| PRD creation (brainstorm-first, correct paths) | ✅ 4/4 | ❌ 2/4 |
| Issue execution (analysis + worktree checks) | ✅ 4/4 | ❌ 0/4 |
| Standup (runs script, real data) | ✅ 3/3 | ❌ 1/3 |
| **Overall** | **100%** | **27.7%** |

---

## Local vs Remote

| Operation | Local | GitHub |
|---|---|---|
| PRD creation | ✅ | — |
| Implementation planning | ✅ | — |
| Task breakdown | ✅ | ✅ (on sync) |
| Execution | ✅ | — |
| Progress updates | ✅ | ✅ (on sync) |
| Final deliverables | — | ✅ |

---

## Technical Notes

**GitHub integration** — uses `gh-sub-issue` extension for proper parent-child relationships. Falls back to task lists if not installed. Install with: `gh extension install yahsan2/gh-sub-issue`

**File naming** — tasks start as `001.md`, `002.md` during decomposition. After GitHub sync, renamed to `{issue-id}.md` (e.g. `1234.md`). Issue #1234 = file `1234.md`.

**Design decisions** — intentionally avoids GitHub Projects API complexity. All operations work on local files first for speed. GitHub sync is explicit and controlled. Worktrees provide clean git isolation for parallel work.

**Looking for v1?** — The original `/pm:*` Claude Code slash command system is preserved on the [`v1` branch](https://github.com/automazeio/ccpm/tree/v1).

---

## Who's behind this project

CCPM was developed at [Automaze](https://automaze.io) **for developers who ship, by developers who ship**.

If CCPM helps your team ship better software:

- ⭐ **[Star this repository](https://github.com/automazeio/ccpm)** to show your support
- 🐦 **[Follow @aroussi on X](https://x.com/aroussi)** for updates and tips

---

> [!TIP]
> **Ship faster with Automaze.** We partner with founders to bring their vision to life, scale their business, and optimize for success.
> **[Visit Automaze to book a call ›](https://automaze.io)**

---

![Star History Chart](https://api.star-history.com/svg?repos=automazeio/ccpm)
