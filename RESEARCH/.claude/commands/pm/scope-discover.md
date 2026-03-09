# Scope Discover - Merge Discovery Sections

Merge all 12 completed discovery sections into a single `discovery.md` file with summary.

## Usage
```
/pm:scope-discover <scope-name>
```

## Arguments
- `scope-name` (required): Name of the scope session

## Prerequisites

All 12 discovery sections must be complete:
- `company_background.md`
- `stakeholders.md`
- `timeline_budget.md`
- `problem_definition.md`
- `business_goals.md`
- `project_scope.md`
- `technical_environment.md`
- `users_audience.md`
- `user_types.md`
- `competitive_landscape.md`
- `risks_assumptions.md`
- `data_reporting.md`

## Instructions

You are merging the 12 completed discovery sections into a comprehensive `discovery.md` file.

### Check Prerequisites

```bash
SESSION_DIR=".claude/scopes/$ARGUMENTS"
SECTIONS_DIR="$SESSION_DIR/sections"

echo "Checking discovery sections for: $ARGUMENTS"
echo ""

SECTIONS="company_background stakeholders timeline_budget problem_definition business_goals project_scope technical_environment users_audience user_types competitive_landscape risks_assumptions data_reporting"

missing=0
for section in $SECTIONS; do
  if [ -f "$SECTIONS_DIR/${section}.md" ]; then
    echo "✓ $section"
  else
    echo "✗ $section (MISSING)"
    missing=$((missing + 1))
  fi
done

if [ $missing -gt 0 ]; then
  echo ""
  echo "❌ $missing sections missing. Complete them first:"
  echo "  .claude/scripts/prd-scope.sh $ARGUMENTS --discover"
  exit 1
fi
```

### Read All Sections

Read all 12 section files to gather content:

1. `sections/company_background.md`
2. `sections/stakeholders.md`
3. `sections/timeline_budget.md`
4. `sections/problem_definition.md`
5. `sections/business_goals.md`
6. `sections/project_scope.md`
7. `sections/technical_environment.md`
8. `sections/users_audience.md`
9. `sections/user_types.md`
10. `sections/competitive_landscape.md`
11. `sections/risks_assumptions.md`
12. `sections/data_reporting.md`

### Generate Discovery Document

Create `.claude/scopes/{scope-name}/discovery.md` with this structure:

```markdown
# Discovery: {scope-name}

discovery_complete: true
started: {earliest section datetime}
completed: {current datetime}

---

## Company Background

{Content from company_background.md - key points only}

---

## Stakeholders

{Content from stakeholders.md - key points only}

---

## Timeline & Budget

{Content from timeline_budget.md - key points only}

---

## Problem Definition

{Content from problem_definition.md - key points only}

---

## Business Goals

{Content from business_goals.md - key points only}

---

## Project Scope

{Content from project_scope.md - key points only}

---

## Technical Environment

{Content from technical_environment.md - key points only}

---

## Users & Audience

{Content from users_audience.md - key points only}

---

## User Types

{Content from user_types.md - key points only}

---

## Competitive Landscape

{Content from competitive_landscape.md - key points only}

---

## Risks & Assumptions

{Content from risks_assumptions.md - key points only}

---

## Data & Reporting

{Content from data_reporting.md - key points only}

---

## Executive Summary

### Core Vision
{1-2 sentence summary synthesized from all sections}

### Problem Being Solved
{Brief problem statement from problem_definition}

### Target Users
- {User type 1 from user_types}
- {User type 2}
- ...

### Key Business Goals
1. {Primary goal from business_goals}
2. {Secondary goals}

### Technical Approach
- Stack: {from technical_environment}
- Integrations: {list from technical_environment}
- Security: {requirements from technical_environment}

### Scope Boundaries

**In Scope:**
{From project_scope}

**Out of Scope:**
{From project_scope}

### Timeline & Constraints
- Target Launch: {from timeline_budget}
- Key Milestones: {from timeline_budget}
- Constraints: {from project_scope and technical_environment}

### Known Risks
{From risks_assumptions}

### Unknowns (Require Research)
{List all items marked UNKNOWN from any section}

---

discovery_complete: true
```

### Content Guidelines

When merging sections:

1. **Extract key points** - Don't copy raw Q&A format
2. **Consolidate duplicates** - Same info may appear in multiple sections
3. **Highlight unknowns** - Collect all UNKNOWN items in one place
4. **Create coherent narrative** - The summary should tell a story
5. **Preserve decisions** - Any decisions made should be clear

### Handle UNKNOWN Items

Scan all sections for `**Answer:** UNKNOWN` and collect them:

```markdown
### Unknowns (Require Research)

| Item | Section | Research Hint |
|------|---------|---------------|
| {question} | {section_name} | {hint if provided} |
| ... | ... | ... |
```

### Output

After writing discovery.md:

```
Discovery merge complete for: {scope-name}

Summary:
- 12/12 sections merged
- {count} unknowns flagged for research
- Executive summary generated

Saved to: .claude/scopes/{scope-name}/discovery.md

Next step:
  .claude/scripts/prd-scope.sh {scope-name} --decompose
```

### Important Rules

1. **All 12 sections required** - Don't merge partial discovery
2. **Extract, don't copy** - Merge intelligently, remove Q&A format
3. **Flag unknowns** - These need attention before decomposition
4. **Create summary** - Executive summary is critical for next phases
5. **Set complete flag** - Mark `discovery_complete: true`
