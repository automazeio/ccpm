# Claude Code PM

[![Automaze](https://img.shields.io/badge/By-automaze.io-4b3baf)](https://automaze.io)
&nbsp;
[![Claude Code](https://img.shields.io/badge/+-Claude%20Code-d97757)](https://github.com/automazeio/ccpm/blob/main/README.md)
[![GitHub Issues](https://img.shields.io/badge/+-GitHub%20Issues-1f2328)](https://github.com/automazeio/ccpm)
&nbsp;
[![Mentioned in Awesome Claude Code](https://awesome.re/mentioned-badge.svg)](https://github.com/hesreallyhim/awesome-claude-code?tab=readme-ov-file#general-)
&nbsp;
[![MIT License](https://img.shields.io/badge/License-MIT-28a745)](https://github.com/automazeio/ccpm/blob/main/LICENSE)
&nbsp;
[![Follow on 𝕏](https://img.shields.io/badge/𝕏-@aroussi-1c9bf0)](http://x.com/intent/follow?screen_name=aroussi)
&nbsp;
[![Star this repo](https://img.shields.io/github/stars/automazeio/ccpm?style=social&label=Star%20this%20repo&maxAge=60)](https://github.com/automazeio/ccpm)


## Transform PRDs into shipped features using spec-driven development

Stop losing context. Eliminate task blocking. Reduce shipped bugs.
This battle-tested system turns product requirements into production code
with full traceability at every step.

## Key Terminology

- **PRD (Product Requirements Document)** - A comprehensive specification defining what to build, including user stories, acceptance criteria, and technical constraints
- **Epic** - A technical implementation plan that breaks down a PRD into concrete development tasks with clear dependencies
- **Issues** - Individual development tasks synced to GitHub Issues for tracking and collaboration
- **Parallel Execution** - Multiple AI agents working simultaneously on different aspects of the same feature

![Claude Code PM](screenshot.webp)

## Quick Start (2 minutes)

### 1. Install CCPM

```bash
# Navigate to your project directory
cd /path/to/your/project

# Install CCPM template files
curl -sSL https://raw.githubusercontent.com/automazeio/ccpm/main/install/ccpm.sh | bash
```

The installer automatically:

- ✅ Downloads CCPM template files
- ✅ Backs up existing `.claude` directory
- ✅ Sets up project structure
- ✅ Preserves your customizations

### 2. Set Up Your Project

```bash
# Navigate to your project
cd /path/to/your/project

# Install CCPM template files
curl -sSL https://raw.githubusercontent.com/automazeio/ccpm/main/install/ccpm.sh | bash

# Initialize the PM system in Claude Code
/pm:init
```

### 3. Ship Your First Feature

```bash
# In Claude Code, create a comprehensive PRD
/pm:prd-new user-authentication

# Transform PRD into technical implementation plan
/pm:prd-parse user-authentication

# Break down and sync to GitHub in one command
/pm:epic-oneshot user-authentication

# Start implementing with parallel agents
/pm:issue-start 1234
```

🎉 **That's it!** You're now using spec-driven development with full GitHub integration.

## How It Works

```mermaid
graph LR
    A[PRD Creation] --> B[Epic Planning]
    B --> C[Task Decomposition]
    C --> D[GitHub Sync]
    D --> E[Parallel Execution]
```

### The 5-Phase Discipline

1. **🧠 Brainstorm** - Think deeper than comfortable
2. **📝 Document** - Write specs that leave nothing to interpretation
3. **📐 Plan** - Architect with explicit technical decisions
4. **⚡ Execute** - Build exactly what was specified
5. **📊 Track** - Maintain transparent progress at every step

### Why GitHub Issues?

- **🤝 True Team Collaboration** - Multiple Claude instances work simultaneously
- **🔄 Seamless Human-AI Handoffs** - Progress visible to everyone
- **📈 Scalable Beyond Solo Work** - Add team members without friction
- **🎯 Single Source of Truth** - Issues are the project state

## Installation

### Unix/Linux/macOS

```bash
cd path/to/your/project/
curl -sSL https://raw.githubusercontent.com/automazeio/ccpm/main/install/ccpm.sh | bash
```

### Windows (PowerShell)

```bash
cd path/to/your/project/
iwr -useb https://raw.githubusercontent.com/automazeio/ccpm/main/install/ccpm.bat | iex
```

### After Installation

```bash
# Initialize the PM system in Claude Code
/pm:init

# Create context for your project
/context:create
```

> 💡 **Note**: If you already have a `.claude` directory, it will be automatically backed up and your content preserved.

## Commands

### Claude Code Commands (/pm:*)

<details>
<summary><b>PRD Management</b></summary>

- `/pm:prd-new <name>` - Create new PRD through brainstorming
- `/pm:prd-parse <name>` - Convert PRD to implementation epic
- `/pm:prd-list` - List all PRDs
- `/pm:prd-edit <name>` - Edit existing PRD
- `/pm:prd-status <name>` - Show implementation status

</details>

<details>
<summary><b>Epic Management</b></summary>

- `/pm:epic-decompose <name>` - Break epic into tasks
- `/pm:epic-sync <name>` - Push to GitHub
- `/pm:epic-oneshot <name>` - Decompose and sync in one command
- `/pm:epic-show <name>` - Display epic and tasks
- `/pm:epic-start <name>` - Launch parallel agents
- `/pm:epic-close <name>` - Mark as complete

</details>

<details>
<summary><b>Issue Management</b></summary>

- `/pm:issue-start <id>` - Begin work with specialized agent
- `/pm:issue-sync <id>` - Push updates to GitHub
- `/pm:issue-show <id>` - Display issue details
- `/pm:issue-close <id>` - Mark as complete
- `/pm:issue-analyze <id>` - Identify parallelization opportunities

</details>

<details>
<summary><b>Workflow Commands</b></summary>

- `/pm:next` - Get next priority task with context
- `/pm:status` - Project dashboard
- `/pm:standup` - Daily standup report
- `/pm:blocked` - Show blocked tasks
- `/pm:in-progress` - List work in progress
- `/pm:sync` - Full GitHub sync
- `/pm:validate` - Check system integrity

</details>

> **Tip:** Type `/pm:help` in Claude Code for a quick reference.

## Advanced Features

### Parallel Execution

Traditional approach: One issue = One developer = Sequential work

#### CCPM approach: One issue = Multiple parallel work streams

Example: "Implement user authentication" becomes:

- **Agent 1**: Database schema and migrations
- **Agent 2**: Service layer and business logic  
- **Agent 3**: API endpoints and middleware
- **Agent 4**: UI components and forms
- **Agent 5**: Tests and documentation

All running **simultaneously** in the same worktree.

### Context Optimization

- Main conversation stays strategic
- Each agent handles its own context in isolation
- Implementation details never pollute main thread
- Use specialized agents:
  - `file-analyzer` - Summarize logs and verbose outputs
  - `code-analyzer` - Search code and trace logic
  - `test-runner` - Execute tests with full analysis
  - `parallel-worker` - Coordinate parallel work streams

### Team Collaboration

GitHub Issues enable:

- Multiple Claude instances working simultaneously
- Real-time progress visibility for all team members
- Seamless handoffs between AI and human developers
- Integration with existing GitHub workflows

## File Structure

```text
.claude/
├── prds/              # Product Requirements Documents
├── epics/             # Implementation plans
│   └── [epic-name]/
│       ├── epic.md    # Technical plan
│       ├── [#].md     # Task files (synced with GitHub)
│       └── updates/   # Work-in-progress
├── agents/            # Specialized task agents
├── commands/pm/       # PM command definitions
└── context/           # Project-wide context
```

## Troubleshooting

## Key Features

### ⚡ **Parallel Execution**

Ship faster with multiple agents working simultaneously. Tasks marked
`parallel: true` enable conflict-free concurrent development.

### 🔗 **GitHub Native**

Works with tools your team already uses. Issues are the source of truth,
comments provide history, and there is no dependency on the Projects API.

### 🤖 **Agent Specialization**

Right tool for every job. Different agents for UI, API, and database work.
Each reads requirements and posts updates automatically.

### 📊 **Full Traceability**

Every decision is documented. PRD → Epic → Task → Issue → Code → Commit.
Complete audit trail from idea to production.

### 🚀 **Developer Productivity**

Focus on building, not managing. Intelligent prioritization, automatic context
loading, and incremental sync when ready.

## Proven Results

Teams using this system report:

- **89% less time** lost to context switching – you'll use `/compact` and
  `/clear` a LOT less
- **5-8 parallel tasks** vs 1 previously – editing/testing multiple files at
  the same time
- **75% reduction** in bug rates – due to the breaking down features into
  detailed tasks
- **Up to 3x faster** feature delivery – based on feature size and complexity

## Example Flow

<details>
<summary><b>Installation Issues</b></summary>
**GitHub CLI not installing automatically?**

```bash
# macOS
brew install gh

# Ubuntu/Debian
sudo apt install gh

# Windows
winget install --id GitHub.cli
```

## Complete Workflow Example

```bash
# 1. Create comprehensive requirements
/pm:prd-new user-authentication

# 2. Transform into technical plan  
/pm:prd-parse user-authentication

# 3. Break down into tasks and sync to GitHub
/pm:epic-oneshot user-authentication

# 4. Start working on first issue
/pm:issue-start 1234

# 5. Track progress
/pm:status
```

That's the complete cycle from idea to implementation!

**Installation not working?**

Try the alternative installation methods:

```bash
# Using wget instead of curl
wget -qO- https://raw.githubusercontent.com/automazeio/ccpm/main/install/ccpm.sh | bash

# Manual download and run
wget https://raw.githubusercontent.com/automazeio/ccpm/main/install/ccpm.sh
chmod +x ccpm.sh
./ccpm.sh
```

</details>

<details>
<summary><b>GitHub Authentication</b></summary>

```bash
# Re-authenticate
gh auth login

# Check status
gh auth status

# Verify extensions
gh extension list
```

</details>

<details>
<summary><b>Claude Code Integration</b></summary>

If Claude Code commands aren't working:

1. Ensure Claude Code is installed: <https://claude.ai/code>
2. Verify CCPM setup completed: `ccpm validate`
3. Check `.claude/` directory exists in your project
4. Re-initialize if needed: `ccpm init`

</details>

## Platform Support

- 🐧 **Linux** - Ubuntu, Debian, Fedora, RHEL, etc.
- 🍎 **macOS** - Intel and Apple Silicon
- 🪟 **Windows** - 10, 11, Server 2019+

## FAQ

<details>
<summary><b>Can I use CCPM with existing projects?</b></summary>

Yes! CCPM preserves existing `.claude` directories and merges content
intelligently. Run `ccpm setup` in any project.

</details>

<details>
<summary><b>Does this work with private repositories?</b></summary>

Yes, CCPM uses your GitHub authentication through the GitHub CLI. It works with
any repository you have access to.

</details>

<details>
<summary><b>Can multiple developers use CCPM on the same project?</b></summary>

Absolutely! That's the power of using GitHub Issues. All developers see the same
state and can collaborate seamlessly.

</details>

<details>
<summary><b>How do I update CCPM?</b></summary>

Run `ccpm update` to get the latest version while preserving your
customizations.

</details>

## Support This Project

Claude Code PM was developed at [Automaze](https://automaze.io) **for developers
who ship, by developers who ship**.

If Claude Code PM helps your team ship better software:

- ⭐ **[Star this repository](https://github.com/automazeio/ccpm)** to show your
  support
- 🐦 **[Follow @aroussi on X](https://x.com/aroussi)** for updates and tips

---

> [!TIP]
> **Ship faster with Automaze.** We partner with founders to bring their vision
> to life. **[Visit Automaze.io ›](https://automaze.io)**

---

## Star History

![Star History Chart](https://api.star-history.com/svg?repos=automazeio/ccpm)
