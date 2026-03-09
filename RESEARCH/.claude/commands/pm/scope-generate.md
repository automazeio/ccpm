# Scope Generate - Create a Single PRD

Generate a full PRD from the decomposition specification.

## Usage
```
/pm:scope-generate <scope-name> <prd-name>
```

## Arguments
- `scope-name` (required): Name of the scope session
- `prd-name` (required): PRD identifier from decomposition.md (e.g., "85-user-auth")

## Instructions

You are generating a single PRD based on the decomposition specification.

### Load Context

```bash
SESSION_DIR=".claude/scopes/$ARGUMENTS"
# Arguments are space-separated: "scope-name prd-name"
SCOPE_NAME=$(echo "$ARGUMENTS" | cut -d' ' -f1)
PRD_NAME=$(echo "$ARGUMENTS" | cut -d' ' -f2)

DECOMP="$SESSION_DIR/decomposition.md"
DISCOVERY="$SESSION_DIR/discovery.md"
OUTPUT="$SESSION_DIR/prds/${PRD_NAME}.md"

echo "Generating PRD: $PRD_NAME"
echo "From scope: $SCOPE_NAME"
```

**Read decomposition.md** to find this PRD's specification:
- Description
- Priority
- In Scope / Out of Scope
- Dependencies
- Key Requirements
- Success Criteria

**Read discovery.md** for additional context:
- User personas
- User journeys
- Technical constraints
- Business context

### PRD Template

Generate the PRD following this exact structure:

```markdown
---
name: {prd-name}
description: {one-line from decomposition}
status: backlog
priority: {P0-critical|P1-high|P2-medium}
created: {current ISO datetime}
updated: {current ISO datetime}
dependencies:
  - {dependency-prd-name}: {what we need from it}
scope_session: {scope-name}
---

# {PRD Title}

## Executive Summary

{2-3 sentences: What is this, who benefits, what's the value}
{Pull from decomposition description and discovery context}

## Problem Statement

### The Problem
{What problem are we solving - from discovery pain points}

### Why Now
{Why this is important now - from discovery drivers}

### Impact of Not Solving
{What happens if we don't build this}

## User Stories

### Primary Persona: {Name}
{Description from discovery personas}

### User Journeys

1. **{Journey Name}**
   - As a {persona}, I want to {action} so that {benefit}
   - Steps: {from discovery user journeys}

2. **{Journey Name}**
   ...

## Requirements

### Functional Requirements

{For each item in "Key Requirements" from decomposition:}

1. **{Requirement Name}**
   - Description: {detailed description}
   - Acceptance Criteria:
     - [ ] {specific testable criterion}
     - [ ] {specific testable criterion}
   - Priority: Must Have | Should Have | Could Have

2. **{Requirement Name}**
   ...

### Non-Functional Requirements

- **Performance**: {from discovery constraints or reasonable defaults}
- **Security**: {from discovery or standard requirements}
- **Scalability**: {from discovery or reasonable defaults}
- **Reliability**: {uptime, error handling expectations}

## Success Criteria

{From decomposition success criteria, expanded:}

| Metric | Current | Target | How Measured |
|--------|---------|--------|--------------|
| {metric} | {baseline or N/A} | {goal} | {measurement method} |

## Scope

### In Scope
{From decomposition "In Scope" section}
- {item}
- {item}

### Out of Scope
{From decomposition "Out of Scope" section}
- {item} (covered by PRD {number})
- {item} (future consideration)

## Dependencies

### Prerequisite PRDs
{From decomposition dependencies}
- **{prd-name}**: {what we need from it and why}

### External Dependencies
{From discovery dependencies}
- {API, service, team, decision}

## Technical Notes

{High-level technical context from discovery constraints}
- Recommended approach: {if obvious from discovery}
- Key integrations: {from discovery}
- Constraints: {from discovery}

## Open Questions

{Any unresolved questions from discovery related to this PRD}
- [ ] {question}

## Appendix

### Related Discovery Context

Key excerpts from discovery.md relevant to this PRD:
- {relevant quote or summary}
```

### Get Current DateTime

```bash
date -u +"%Y-%m-%dT%H:%M:%SZ"
```

### Write the PRD

```bash
mkdir -p "$SESSION_DIR/prds"
# Write PRD content to $OUTPUT
```

### Validation

Before finishing, verify:
- [ ] All sections populated (no placeholders)
- [ ] Requirements have acceptance criteria
- [ ] Dependencies reference actual PRDs from decomposition
- [ ] In/Out of scope matches decomposition
- [ ] Success criteria are measurable
- [ ] Frontmatter is complete and valid YAML

### Output

After creating the PRD:

```
PRD generated: {prd-name}

Summary:
- Priority: {P0|P1|P2}
- Requirements: {count}
- Dependencies: {list or "None"}

Saved to: .claude/scopes/{scope-name}/prds/{prd-name}.md

Remaining PRDs to generate: {count}
```

### Important Rules

1. **Don't invent requirements** - Only include what's in decomposition + discovery
2. **Keep it focused** - This PRD only covers its assigned scope
3. **Reference other PRDs** - For out-of-scope items, mention which PRD handles them
4. **Be specific** - Acceptance criteria must be testable
5. **Use real datetime** - Always get current time from system
