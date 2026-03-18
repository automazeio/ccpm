# Plan — Capture Requirements

This phase turns an idea into a structured PRD, then converts the PRD into a technical epic ready for decomposition.

---

## Writing a PRD

**Trigger**: User wants to plan a new feature, product requirement, or area of work.

### Preflight
- Check if `.claude/prds/<name>.md` already exists — if so, confirm overwrite before proceeding.
- Ensure `.claude/prds/` directory exists; create it if not.
- Feature name must be kebab-case (lowercase, letters/numbers/hyphens, starts with a letter). If not: "❌ Feature name must be kebab-case. Example: user-auth, payment-v2"

### Process

Conduct a genuine brainstorming session before writing anything. Ask the user:
- What problem does this solve?
- Who are the users affected?
- What does success look like?
- What's explicitly out of scope?
- What are the constraints (tech, time, resources)?

Then write `.claude/prds/<name>.md` with this frontmatter and structure:

```markdown
---
name: <feature-name>
description: <one-line summary>
status: backlog
created: <run: date -u +"%Y-%m-%dT%H:%M:%SZ">
---

# PRD: <feature-name>

## Executive Summary
## Problem Statement
## User Stories
## Functional Requirements
## Non-Functional Requirements
## Success Criteria
## Constraints & Assumptions
## Out of Scope
## Dependencies
```

**Quality gates before saving:**
- No placeholder text in any section
- User stories include acceptance criteria
- Success criteria are measurable
- Out of scope is explicitly listed

**After creation**: Confirm "✅ PRD created: `.claude/prds/<name>.md`" and suggest: "Ready to create technical epic? Say: parse the <name> PRD"

---

## Parsing a PRD into a Technical Epic

**Trigger**: User wants to convert an existing PRD into a technical implementation plan.

### Preflight
- Verify `.claude/prds/<name>.md` exists with valid frontmatter (name, description, status, created).
- Check if `.claude/epics/<name>/epic.md` already exists — confirm overwrite if so.

### Process

Read the PRD fully, then produce `.claude/epics/<name>/epic.md`:

```markdown
---
name: <feature-name>
status: backlog
created: <run: date -u +"%Y-%m-%dT%H:%M:%SZ">
progress: 0%
prd: .claude/prds/<name>.md
github: (will be set on sync)
---

# Epic: <feature-name>

## Overview
## Architecture Decisions
## Technical Approach
### Frontend Components
### Backend Services
### Infrastructure
## Implementation Strategy
## Task Breakdown Preview
## Dependencies
## Success Criteria (Technical)
## Estimated Effort
```

**Key constraints:**
- Aim for ≤10 tasks total — prefer simplicity over completeness.
- Look for ways to leverage existing functionality before creating new code.
- Identify parallelization opportunities in the task breakdown preview.

**After creation**: Confirm "✅ Epic created: `.claude/epics/<name>/epic.md`" and suggest: "Ready to decompose into tasks? Say: decompose the <name> epic"

---

## Editing a PRD or Epic

Read the file first, make targeted edits preserving all frontmatter. Update the `updated` frontmatter field with current datetime.
