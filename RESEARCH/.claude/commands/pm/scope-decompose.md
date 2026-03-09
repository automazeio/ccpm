# Scope Decompose - Break Discovery into PRDs

Read discovery.md and propose a breakdown into multiple focused PRDs.

## Usage
```
/pm:scope-decompose <scope-name>
```

## Arguments
- `scope-name` (required): Name of the scope session

## Instructions

You are a product strategist breaking down a discovered scope into multiple well-bounded PRDs.

### Load Context

```bash
SESSION_DIR=".claude/scopes/$ARGUMENTS"
DISCOVERY="$SESSION_DIR/discovery.md"

# Verify discovery exists and is complete
if [ ! -f "$DISCOVERY" ]; then
  echo "Error: No discovery.md found. Run /pm:scope-discover first."
  exit 1
fi

# Read discovery
cat "$DISCOVERY"
```

Read the discovery.md file to understand the full scope.

### Decomposition Strategies

Choose the most appropriate strategy (or combine them):

**By User Journey:**
```
Registration → Onboarding → Core Usage → Advanced Features → Retention
```

**By System Layer:**
```
Data Layer → API Layer → Business Logic → Frontend → Infrastructure
```

**By Business Capability:**
```
Authentication → Authorization → Core Feature A → Core Feature B → Analytics
```

**By Timeline/Phase:**
```
Phase 1 (MVP) → Phase 2 (Enhancement) → Phase 3 (Scale)
```

**By Risk:**
```
Foundation (low risk) → Core (medium risk) → Experimental (high risk)
```

### PRD Design Principles

Each PRD must be:
- **Independent**: Can be developed without other PRDs (except explicit dependencies)
- **Valuable**: Delivers standalone value to users
- **Estimable**: Clear enough to estimate effort
- **Small**: Completable in reasonable timeframe
- **Testable**: Has clear acceptance criteria

### Decomposition Process

1. **Identify natural boundaries** from discovery:
   - Different user personas → separate PRDs
   - Different systems/integrations → separate PRDs
   - Different phases mentioned → separate PRDs

2. **Check for dependencies**:
   - What must exist before other things can work?
   - Are there shared foundations (auth, data models)?

3. **Validate INVEST principles** for each PRD

4. **Assign priorities**:
   - P0 (critical): Must have for MVP
   - P1 (high): Important but not blocking
   - P2 (medium): Nice to have

### Get Next PRD Number

```bash
# Find highest existing PRD number
HIGHEST=$(ls .claude/prds/*.md 2>/dev/null | sed 's/.*\/\([0-9]*\)-.*/\1/' | sort -n | tail -1)
NEXT=$((HIGHEST + 1))
echo "Next PRD number: $NEXT"
```

### Output Format (decomposition.md)

Write to `.claude/scopes/{scope-name}/decomposition.md`:

```markdown
# Decomposition: {scope-name}

Based on: discovery.md
Strategy: {chosen strategy}
Created: {datetime}

## Overview

{1-2 paragraph summary of the decomposition approach}

## PRD Breakdown

### PRD: {number}-{name}

**Description:** {one-line summary}

**Priority:** P0|P1|P2

**In Scope:**
- {what this PRD covers}
- {specific features/capabilities}

**Out of Scope:**
- {what this PRD does NOT cover}
- {things handled by other PRDs}

**Dependencies:**
- {other PRD numbers this depends on, or "None"}

**Key Requirements:**
1. {requirement from discovery}
2. {requirement from discovery}

**Success Criteria:**
- {measurable outcome}

---

### PRD: {number}-{name}
...

---

## Dependency Graph

```
{number}-{name} ──┬──> {number}-{name}
{number}-{name} ──┘
                 └──> {number}-{name}
```

## Execution Order

### Phase 1: Foundation
- {prd-number}: {name} (no dependencies)
- {prd-number}: {name} (no dependencies)

### Phase 2: Core
- {prd-number}: {name} (after Phase 1)
- {prd-number}: {name} (after Phase 1)

### Phase 3: Enhancement
- {prd-number}: {name} (after Phase 2)

## Coverage Check

| Discovery Item | Covered By |
|----------------|------------|
| {requirement from discovery} | PRD {number} |
| {user story from discovery} | PRD {number} |
| {integration from discovery} | PRD {number} |

## Not Covered (Explicit)

These items from discovery are intentionally out of scope:
- {item}: {reason}
```

### Validation Checklist

Before finishing, verify:
- [ ] Every requirement from discovery is assigned to a PRD
- [ ] No circular dependencies exist
- [ ] Each PRD has clear boundaries (in/out of scope)
- [ ] PRDs are properly numbered (continuing from existing)
- [ ] Dependencies form a valid DAG (directed acyclic graph)
- [ ] Coverage check accounts for all discovery items

### Red Flags to Fix

- **PRD too big**: If >10 requirements, split it
- **PRD too small**: If just 1-2 requirements, merge with related PRD
- **Infrastructure-only PRD**: Add user value or merge with feature PRD
- **Circular dependency**: Extract shared component into new PRD
- **Unclear boundaries**: Make in-scope/out-of-scope explicit

### Output

After writing decomposition.md:

```
Decomposition complete for: {scope-name}

Proposed {N} PRDs:
  {number}-{name} (P0) - {description}
  {number}-{name} (P1, depends: {n}) - {description}
  ...

Dependency graph:
  {visual representation}

Saved to: .claude/scopes/{scope-name}/decomposition.md

Review the decomposition, then:
  .claude/scripts/prd-scope.sh {scope-name} --generate
```
