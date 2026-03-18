# CCPM — Claude Code Project Manager

[![Agent Skills](https://img.shields.io/badge/Agent_Skills-compatible-4b3baf)](https://agentskills.io)
[![MIT License](https://img.shields.io/badge/License-MIT-28a745)](LICENSE)
[![Follow on 𝕏](https://img.shields.io/badge/𝕏-@aroussi-1c9bf0)](http://x.com/intent/follow?screen_name=aroussi)
[![Star this repo](https://img.shields.io/github/stars/automazeio/ccpm.svg?style=social&label=Star&maxAge=60)](https://github.com/automazeio/ccpm)

**Spec-driven development for AI agents.** Turn a feature idea into shipped code — PRD → Epic → GitHub Issues → parallel agents — with full traceability at every step.

Works with any [Agent Skills–compatible](https://agentskills.io) harness: Factory, Claude Code, Amp, OpenCode, Codex, Cursor, and more.

---

## The Workflow

```
Idea → PRD → Technical Epic → GitHub Issues → Parallel Agents → Shipped
```

CCPM gives your agent a structured PM brain. Instead of vibe-coding features from scratch each session, it maintains requirements in files, decomposes work into parallelizable tasks, coordinates multiple agents, and keeps GitHub in sync throughout.

### Five phases

| Phase | What happens |
|---|---|
| **Plan** | Brainstorm and write a PRD, then convert it to a technical epic |
| **Structure** | Decompose the epic into numbered task files with dependencies and parallelization hints |
| **Sync** | Push the epic and tasks to GitHub as issues (with sub-issue support) |
| **Execute** | Analyze an issue for parallel work streams, launch multiple agents simultaneously |
| **Track** | Status, standup, what's next, what's blocked — all from fast bash scripts |

---

## Install

CCPM is a standard Agent Skill. Installation is two steps: add the skill, point your agent at it.

### Factory / Droid

```bash
# Clone into your skills directory
git clone https://github.com/automazeio/ccpm.git ~/.factory/skills/ccpm
# or symlink if you want to stay in sync with updates:
ln -s /path/to/ccpm/skill/ccpm ~/.factory/skills/ccpm
```

### Claude Code

Add to your project's `.claude/` or global Claude Code skills directory:

```bash
git clone https://github.com/automazeio/ccpm.git
# Then point Claude Code at: ccpm/skill/ccpm/
```

### Any other Agent Skills–compatible harness

Point it at the `skill/ccpm/` directory. That's it. The skill follows the [agentskills.io](https://agentskills.io) standard so it works out of the box.

---

## Usage

CCPM activates automatically when your agent detects PM intent. Just talk naturally:

```
"I want to build a notification system — where do we start?"
→ Triggers brainstorming + PRD creation

"break down the notification-system epic"
→ Decomposes into parallelizable tasks

"sync the notification-system epic to GitHub"
→ Creates epic issue + sub-issues, sets up worktree

"start working on issue 42"
→ Analyzes parallel streams, launches multiple agents

"what's our standup for today?"
→ Runs status script, reports what's in progress and what's next

"what's blocked?"
→ Reports blocked tasks instantly
```

No special syntax required. CCPM understands natural language across all of these phases.

---

## What's in the skill

```
skill/ccpm/
├── SKILL.md                  # Entry point — phase router
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

**Deterministic operations** (status, standup, list, search, validate) run as bash scripts — fast, consistent, no LLM token cost. **Agentic operations** (PRD writing, analysis, parallel coordination) use the LLM where reasoning actually adds value.

---

## Prerequisites

- `git` and `gh` CLI (authenticated: `gh auth login`)
- A GitHub repository for your project
- An Agent Skills–compatible AI harness

---

## Project file structure

CCPM keeps everything in `.claude/` in your project root:

```
.claude/
├── prds/                     # Product requirement documents
├── epics/
│   └── <feature>/
│       ├── epic.md           # Technical epic
│       ├── <N>.md            # Task files (named by GitHub issue number)
│       ├── <N>-analysis.md   # Parallel work stream analysis
│       └── updates/          # Agent progress tracking
└── (archived epics)
```

Files are the source of truth. No external services, no databases — just markdown that lives in your repo.

---

## Looking for the original Claude Code slash commands?

The original `/pm:*` command system (v1) is preserved on the [`v1` branch](https://github.com/automazeio/ccpm/tree/v1). It still works perfectly with Claude Code's slash command system.

---

## License

MIT — see [LICENSE](LICENSE).

Built by [automaze.io](https://automaze.io) · Follow [@aroussi](http://x.com/intent/follow?screen_name=aroussi) for updates
