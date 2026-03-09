# Scope Verify - Gap Analysis

Audit generated PRDs against discovery for gaps, missing integrations, and completeness.

## Usage
```
/pm:scope-verify <scope-name>
```

## Arguments
- `scope-name` (required): Name of the scope session

## Instructions

You are auditing the generated PRDs against the original discovery to ensure complete coverage.

### Load All Context

```bash
SESSION_DIR=".claude/scopes/$ARGUMENTS"
DISCOVERY="$SESSION_DIR/discovery.md"
DECOMP="$SESSION_DIR/decomposition.md"
PRDS_DIR="$SESSION_DIR/prds"

echo "Verifying scope: $ARGUMENTS"
echo ""

# List generated PRDs
echo "Generated PRDs:"
ls -la "$PRDS_DIR"/*.md 2>/dev/null || echo "No PRDs found!"
```

**Read all files:**
1. `discovery.md` - Original requirements and context
2. `decomposition.md` - Proposed PRD breakdown
3. All PRD files in `prds/` directory

### Verification Process

#### 1. Extract Items from Discovery

Build lists of:
- **User Stories**: Every "As a... I want... so that..." or equivalent
- **Requirements**: Every explicit requirement mentioned
- **Integrations**: Every external system, API, or service mentioned
- **Constraints**: Every technical, timeline, or resource constraint
- **Personas**: Every user type mentioned
- **Risks**: Every risk or unknown mentioned

#### 2. Build Coverage Matrix

For each item extracted, determine:
- Which PRD covers it?
- Is it fully covered or partially covered?
- Is it explicitly marked out of scope?

#### 3. Identify Gaps

**Missing Requirements:**
- Items from discovery not covered by any PRD
- Items partially covered (mentioned but no acceptance criteria)

**Missing Integrations:**
- External systems mentioned in discovery but no PRD handles them

**Missing User Stories:**
- User journeys from discovery with no PRD coverage

**Dependency Issues:**
- Circular dependencies between PRDs
- Missing dependencies (PRD A references PRD B, but B doesn't exist)
- Orphan PRDs (nothing depends on them, they depend on nothing - suspicious)

**Scope Leakage:**
- Items in PRD that weren't in discovery (scope creep)
- Items marked "out of scope" in PRD but not in another PRD

### Output Format (verification.md)

Write to `.claude/scopes/{scope-name}/verification.md`:

```markdown
# Scope Verification: {scope-name}

Verified: {datetime}
Discovery: discovery.md
PRDs Checked: {count}

## Coverage Summary

| Category | Total | Covered | Partial | Missing | Coverage |
|----------|-------|---------|---------|---------|----------|
| User Stories | {n} | {n} | {n} | {n} | {%} |
| Requirements | {n} | {n} | {n} | {n} | {%} |
| Integrations | {n} | {n} | {n} | {n} | {%} |
| Constraints | {n} | {n} | {n} | {n} | {%} |

**Overall Coverage: {percentage}%**

## Gaps Found

{If no gaps: "No gaps found. All discovery items are covered by PRDs."}

### Missing Requirements

| Requirement | Discovery Location | Suggested Action |
|-------------|-------------------|------------------|
| "{requirement text}" | discovery.md line {n} | Add to PRD {number} |
| "{requirement text}" | discovery.md line {n} | Create new PRD |

### Missing Integrations

| Integration | Mentioned In | Current Status | Suggested Action |
|-------------|--------------|----------------|------------------|
| {service name} | discovery.md | NOT COVERED | Create PRD {n}-{name} |
| {API name} | discovery.md | Partial in PRD {n} | Expand PRD {n} |

### Missing User Stories

| User Story | Discovery Location | Suggested PRD |
|------------|-------------------|---------------|
| "As a {persona}..." | discovery.md | PRD {number} |

### Dependency Issues

**Circular Dependencies:**
- {prd-a} -> {prd-b} -> {prd-a} (CIRCULAR)

**Missing Dependencies:**
- PRD {n} references "{name}" but no such PRD exists

**Orphan PRDs:**
- PRD {n} has no dependencies and nothing depends on it

### Scope Leakage

**Items in PRDs not in Discovery:**
| Item | PRD | Risk |
|------|-----|------|
| "{item}" | PRD {n} | Scope creep - remove or add to discovery |

**Out of Scope with No Home:**
| Item | Marked Out of Scope In | Should Be In |
|------|------------------------|--------------|
| "{item}" | PRD {n} | PRD {m} or New PRD |

## Recommendations

### Critical (Must Fix)
1. {action}: {reason}
2. {action}: {reason}

### Important (Should Fix)
1. {action}: {reason}

### Minor (Consider)
1. {action}: {reason}

## Full Coverage Matrix

| Discovery Item | Type | Covered By | Status |
|----------------|------|------------|--------|
| "{item}" | Requirement | PRD {n} | Full |
| "{item}" | Integration | PRD {n} | Partial |
| "{item}" | User Story | - | MISSING |
| "{item}" | Constraint | PRD {n}, {m} | Full |

## PRD Dependency Graph (Validated)

```
{prd-1} ──┬──> {prd-3} ──> {prd-5}
{prd-2} ──┘         └──> {prd-6}
          └──> {prd-4}
```

Status: {VALID - no cycles | INVALID - cycles found}

## Verification Complete

{If gaps found:}
Action Required: Review gaps above and either:
1. Update decomposition.md and regenerate PRDs
2. Manually create additional PRDs for missing items
3. Accept gaps and document rationale

{If no gaps:}
All discovery items are covered. PRDs are ready for implementation.
```

### Decision Logic

**Critical gaps (must address):**
- Core requirement with no coverage
- Required integration with no PRD
- Circular dependency

**Important gaps (should address):**
- User story with no coverage
- Partial coverage of important feature
- Missing dependency reference

**Minor gaps (consider):**
- Nice-to-have with no coverage (may be intentional)
- Orphan PRD (may be intentional)

### Output

After writing verification.md:

```
Verification complete for: {scope-name}

Coverage: {percentage}%

{If gaps found:}
Gaps detected:
- {count} missing requirements
- {count} missing integrations
- {count} dependency issues

Review: .claude/scopes/{scope-name}/verification.md

Options:
1. Fix gaps: Edit decomposition.md, re-run --decompose
2. Accept: Continue to finalize PRDs

{If no gaps:}
All items covered. No gaps found.

PRDs are ready to be moved to .claude/prds/
Run: .claude/scripts/prd-scope.sh {scope-name} --verify
```

### Important Rules

1. **READ-ONLY**: This command only audits, it doesn't modify PRDs
2. **Be thorough**: Check every item from discovery
3. **Be specific**: Point to exact locations (line numbers, PRD names)
4. **Suggest actions**: Don't just report gaps, suggest fixes
5. **Validate dependencies**: Check for cycles and missing references
