# CCPM Local Mode

CCPM works perfectly in local-only mode without any GitHub integration. All management is done through local markdown files.

## Local-Only Workflow

### 1. Create Requirements (PRD)
```bash
/pm:prd-new user-authentication
```
- Creates: `ccpm/prds/user-authentication.md`
- Output: Complete PRD with requirements and user stories

### 2. Convert to Technical Plan (Epic)
```bash
/pm:prd-parse user-authentication
```
- Creates: `ccpm/epics/user-authentication/epic.md`
- Output: Technical implementation plan

### 3. Break Down Into Tasks
```bash
/pm:epic-decompose user-authentication
```
- Creates: `ccpm/epics/user-authentication/001.md`, `002.md`, etc.
- Output: Individual task files with acceptance criteria

### 4. View Your Work
```bash
/pm:epic-show user-authentication    # View epic and all tasks
/pm:status                           # Project dashboard
/pm:prd-list                         # List all PRDs
```

### 5. Work on Tasks
```bash
# View specific task details
cat ccpm/epics/user-authentication/001.md

# Update task status manually
vim ccpm/epics/user-authentication/001.md
```

## What Gets Created Locally

```text
ccpm/
├── prds/
│   └── user-authentication.md      # Requirements document
├── epics/
│   └── user-authentication/
│       ├── epic.md                 # Technical plan
│       ├── 001.md                  # Task: Database schema
│       ├── 002.md                  # Task: API endpoints
│       └── 003.md                  # Task: UI components
└── context/
    └── README.md                   # Project context
```

## Commands That Work Locally

### ✅ Fully Local Commands
- `/pm:prd-new <name>` - Create requirements
- `/pm:prd-parse <name>` - Generate technical plan
- `/pm:epic-decompose <name>` - Break into tasks
- `/pm:epic-show <name>` - View epic and tasks
- `/pm:status` - Project dashboard
- `/pm:prd-list` - List PRDs
- `/pm:search <term>` - Search content
- `/pm:validate` - Check file integrity

### 🚫 GitHub-Only Commands (Skip These)
- `/pm:epic-sync <name>` - Push to GitHub Issues
- `/pm:issue-sync <id>` - Update GitHub Issue
- `/pm:issue-start <id>` - Requires GitHub Issue ID
- `/pm:epic-oneshot <name>` - Includes GitHub sync

## Benefits of Local Mode

- **✅ No external dependencies** - Works without GitHub account/internet
- **✅ Full privacy** - All data stays local
- **✅ Version control friendly** - All files are markdown
- **✅ Team collaboration** - Share `ccpm/` directory via git
- **✅ Customizable** - Edit templates and workflows freely
- **✅ Fast** - No API calls or network delays

## Manual Task Management

Tasks are stored as markdown files with frontmatter:

```markdown
---
name: Implement user login API
status: open          # open, in-progress, completed
created: 2024-01-15T10:30:00Z
updated: 2024-01-15T10:30:00Z
parallel: true
depends_on: [001]
---

# Task: Implement user login API

## Description
Create POST /api/auth/login endpoint...

## Acceptance Criteria
- [ ] Endpoint accepts email/password
- [ ] Returns JWT token on success
- [ ] Validates credentials against database
```

Update the `status` field manually as you work:
- `open` → `in-progress` → `completed`

That's it! You have a complete project management system that works entirely offline.