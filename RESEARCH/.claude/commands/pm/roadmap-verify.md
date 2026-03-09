# Roadmap Verify - Gap Analysis

Audit generated roadmap against scope documents for gaps, missing features, invalid dependencies, and feasibility issues.

## Usage
```
/pm:roadmap-verify <session-name>
```

## Arguments
- `session-name` (required): Name of the scope session

## Input
**Required:** `.claude/scopes/{session-name}/` containing:
- `07_roadmap.md` (primary input)
- `00_scope_document.md`
- `01_features.md`
- `02_user_journeys.md`

## Output
**File:** `.claude/scopes/{session-name}/08_roadmap_verification.md`

---

## Instructions

You are auditing the generated roadmap against scope documents to ensure complete coverage and valid structure.

### Step 1: Load All Context

```bash
SESSION_DIR=".claude/scopes/$ARGUMENTS"
ROADMAP="$SESSION_DIR/07_roadmap.md"
SCOPE="$SESSION_DIR/00_scope_document.md"
FEATURES="$SESSION_DIR/01_features.md"
JOURNEYS="$SESSION_DIR/02_user_journeys.md"

echo "Verifying roadmap: $ARGUMENTS"
echo ""

# Check roadmap exists
if [ ! -f "$ROADMAP" ]; then
  echo "❌ Roadmap not found: $ROADMAP"
  echo "Run /pm:roadmap-generate $ARGUMENTS first"
  exit 1
fi

# List all scope files
echo "Scope files:"
ls -la "$SESSION_DIR"/*.md 2>/dev/null
```

**Read all files:**
1. `07_roadmap.md` - The roadmap to verify
2. `00_scope_document.md` - Original scope and vision
3. `01_features.md` - Feature list with MoSCoW priorities
4. `02_user_journeys.md` - User journeys to map

---

### Step 2: Extract Items for Verification

Build inventories from each source:

#### From Features (01_features.md)
```
For each feature:
  - ID (F-001, etc.)
  - Name
  - Priority (Must Have / Should Have / Could Have / Won't Have)
  - Dependencies listed
```

#### From Journeys (02_user_journeys.md)
```
For each journey:
  - ID (J-001, etc.)
  - Name
  - Steps count
  - Features referenced
```

#### From Roadmap (07_roadmap.md)
```
For each phase:
  - Phase number and name
  - Features included
  - Exit criteria defined
  - Dependencies listed
  - RICE scores (if present)
```

---

### Step 3: Run Verification Checks

Execute the following verification techniques:

#### Check 1: Structure Validation
```
✓ All 4 phases defined? (0: Foundation, 1: MVP Core, 2: Enhancement, 3+: Post-MVP)
✓ Each phase has exit criteria?
✓ Exit criteria are measurable (not vague)?
✓ Walking skeleton (Phase 0) covers all layers?
```

**Gap type:** `structural`
**Severity:** HIGH if phase missing, MEDIUM if exit criteria vague

#### Check 2: Feature Coverage (Bidirectional Traceability)
```
For each feature in 01_features.md:
  - Is it included in roadmap? (mapped to a phase)
  - Is it explicitly excluded as Won't Have?
  - If Must Have: Is it in Phase 1?
  - If Should Have: Is it in Phase 1 or 2?

For each feature in roadmap:
  - Does it exist in 01_features.md?
  - Is it scope creep? (not in original scope)
```

**Gap type:** `coverage`
**Severity:** HIGH if Must Have missing, MEDIUM if Should Have missing, LOW if Could Have unplaced

#### Check 3: Dependency Validation (Topological Sort)
```
Build dependency graph from roadmap features:
  G = {F-001: [deps], F-002: [deps], ...}

Run cycle detection (Kahn's algorithm):
  in_degree = {f: count of deps for f in G}
  queue = [f for f in G if in_degree[f] == 0]
  sorted = []

  while queue:
    f = queue.pop(0)
    sorted.append(f)
    for dependent in G[f].enables:
      in_degree[dependent] -= 1
      if in_degree[dependent] == 0:
        queue.append(dependent)

  if len(sorted) < len(G):
    # Circular dependency detected
    remaining = [f for f in G if f not in sorted]
    → GAP: Circular dependency involving {remaining}
```

**Gap type:** `dependency`
**Severity:** HIGH if circular, MEDIUM if orphan nodes

#### Check 4: Phase Sequencing Validation
```
For each phase:
  For each feature in phase:
    - Are all its dependencies in earlier phases or same phase?
    - If dependency is in later phase → GAP

Example:
  Phase 1: [F-003]
  Phase 2: [F-001]  # F-001 is dependency of F-003
  → GAP: F-003 depends on F-001 but F-001 is in later phase
```

**Gap type:** `dependency`
**Severity:** HIGH (blocks execution)

#### Check 5: RICE Score Consistency
```
For features with RICE scores:
  - Impact in valid range? (0.25, 0.5, 1, 2, 3)
  - Confidence in valid range? (50%, 80%, 100%)
  - Effort > 0?
  - Score calculation correct? RICE = (Reach × Impact × Confidence) / Effort

For infrastructure features:
  - Impact should be 0.5-1 (not 2-3)
  - Flag if infrastructure has Impact > 1

Statistical outliers (if >10 features):
  - Calculate mean and std dev of RICE scores
  - Flag features with z-score > 3 (extremely high)
  - Flag features with z-score < -2 (unusually low)
```

**Gap type:** `scoring`
**Severity:** MEDIUM if unrealistic scores, LOW if minor miscalculations

#### Check 6: Journey Mapping Validation
```
For each user journey in 02_user_journeys.md:
  - Are all features needed for journey in roadmap?
  - Is journey achievable by end of some phase?
  - Which phase completes which journeys?

MVP Definition check:
  - Primary journey (J-001) should complete by Phase 1
  - If not → GAP: MVP doesn't enable primary user journey
```

**Gap type:** `coverage`
**Severity:** HIGH if primary journey not in Phase 1, MEDIUM otherwise

#### Check 7: Walking Skeleton Completeness
```
Phase 0 should touch all architecture layers:
  - Frontend/UI layer
  - API/Backend layer
  - Business logic layer
  - Database/persistence layer
  - Infrastructure/deployment layer

Check if Phase 0 deliverables cover all layers.
Missing layer → GAP
```

**Gap type:** `feasibility`
**Severity:** MEDIUM (skeleton should be complete)

#### Check 8: External Dependency Risk
```
For each external dependency mentioned:
  - Is there a mitigation strategy listed?
  - Does any feature depend on it without fallback?

High-risk external dependencies:
  - Third-party APIs without alternatives
  - Vendor work with no timeline
  - Regulatory approvals pending
```

**Gap type:** `dependency`
**Severity:** MEDIUM if no mitigation, LOW if mitigation exists

---

### Step 4: Compile Gap Report

For each gap found, record:

```yaml
GAP-{NNN}:
  category: {structural|coverage|dependency|scoring|feasibility}
  severity: {HIGH|MEDIUM|LOW}
  source: "{where the gap was detected}"
  description: "{what the gap is}"
  research_query: "{suggested /dr query to fill this gap}"
```

---

### Step 5: Write Verification Report

Get current datetime:
```bash
CURRENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
```

Write to `.claude/scopes/{session-name}/08_roadmap_verification.md`:

```markdown
# Roadmap Verification: {session-name}

**Verified:** {datetime}
**Roadmap:** 07_roadmap.md
**Status:** {PASS|FAIL|WARN}

---

## Summary

| Check | Status | Gaps Found |
|-------|--------|------------|
| Structure | {PASS/FAIL} | {count} |
| Feature Coverage | {PASS/FAIL} | {count} |
| Dependencies | {PASS/FAIL} | {count} |
| Phase Sequencing | {PASS/FAIL} | {count} |
| RICE Scores | {PASS/WARN} | {count} |
| Journey Mapping | {PASS/FAIL} | {count} |
| Walking Skeleton | {PASS/WARN} | {count} |
| External Dependencies | {PASS/WARN} | {count} |

**Total Gaps:** {count}
- HIGH severity: {count}
- MEDIUM severity: {count}
- LOW severity: {count}

---

## Gaps Requiring Research

{For each gap with severity >= MEDIUM:}

### GAP-{NNN}: {Short description}

| Field | Value |
|-------|-------|
| Category | {category} |
| Severity | {severity} |
| Source | {where detected} |

**Description:**
{detailed description of the gap}

**Research Query:**
```
{suggested /dr query to fill this gap}
```

---

## Coverage Matrix

### Features → Phases

| Feature ID | Name | Priority | Phase | Status |
|------------|------|----------|-------|--------|
| F-001 | {name} | Must Have | 1 | ✓ |
| F-002 | {name} | Should Have | 2 | ✓ |
| F-003 | {name} | Must Have | - | ❌ MISSING |
| F-004 | {name} | Could Have | 3 | ✓ |

### Journeys → Phases

| Journey ID | Name | Completion Phase | Status |
|------------|------|------------------|--------|
| J-001 | {name} | 1 | ✓ Primary in MVP |
| J-002 | {name} | 2 | ✓ |
| J-003 | {name} | - | ❌ Not achievable |

---

## Dependency Graph Validation

```
{Visual representation of dependency graph}

Phase 0: [Infrastructure]
    ↓
Phase 1: [F-001] → [F-002] → [F-003]
    ↓
Phase 2: [F-004] → [F-005]
```

**Cycle Detection:** {NONE FOUND | Cycles: [list]}
**Orphan Features:** {NONE | [list of features with no deps and nothing depends on them]}
**Sequencing Issues:** {NONE | [list of out-of-order dependencies]}

---

## Walking Skeleton Assessment

| Layer | Phase 0 Coverage | Status |
|-------|------------------|--------|
| Frontend | {deliverable} | ✓ |
| API | {deliverable} | ✓ |
| Business Logic | {deliverable} | ✓ |
| Database | {deliverable} | ✓ |
| Infrastructure | {deliverable} | ✓ |

---

## RICE Score Analysis

{If >10 features:}

**Statistical Summary:**
- Mean RICE: {value}
- Std Dev: {value}
- Range: {min} - {max}

**Outliers Detected:**
| Feature | RICE | Z-Score | Issue |
|---------|------|---------|-------|
| F-XXX | {score} | {z} | Unusually high |

**Infrastructure Scoring:**
| Feature | Type | Impact | Issue |
|---------|------|--------|-------|
| F-XXX | Infrastructure | 3 | Should be 0.5-1 |

---

## External Dependencies Risk

| Dependency | Features Affected | Mitigation | Risk Level |
|------------|-------------------|------------|------------|
| {vendor} | F-001, F-002 | {strategy} | {HIGH/MED/LOW} |

---

## Recommendations

### Critical (Must Fix Before Proceeding)
{List HIGH severity gaps}

1. **{GAP-001}:** {action needed}
   - Impact: {what breaks if not fixed}
   - Fix: {specific action}

### Important (Should Fix)
{List MEDIUM severity gaps}

1. **{GAP-002}:** {action needed}

### Minor (Consider)
{List LOW severity gaps}

---

## Verification Complete

{If no HIGH/MEDIUM gaps:}
✅ **Roadmap verified.** Ready for decomposition.

Next: `/pm:decompose {session-name}`

{If HIGH gaps exist:}
❌ **Critical gaps found.** Must resolve before proceeding.

Options:
1. **Auto-fill:** `/pm:roadmap-research {session-name}` - Research and update roadmap
2. **Manual fix:** Edit `07_roadmap.md` directly, re-run verify

{If only MEDIUM gaps:}
⚠️ **Minor gaps found.** Can proceed but recommend fixing.

Options:
1. **Auto-fill:** `/pm:roadmap-research {session-name}` - Research and update roadmap
2. **Accept:** Continue with `/pm:decompose {session-name}` (gaps noted)
```

---

### Step 6: Output Summary

```
Verification complete for: {session-name}

Status: {PASS|FAIL|WARN}

Gaps Found:
  HIGH: {count}
  MEDIUM: {count}
  LOW: {count}

{If gaps with severity >= MEDIUM:}
Gaps needing research:
  - GAP-{NNN}: {short description}
  - GAP-{NNN}: {short description}

Saved: .claude/scopes/{session-name}/08_roadmap_verification.md

{If HIGH gaps:}
❌ Critical gaps - Run /pm:roadmap-research {session-name}

{If only MEDIUM gaps:}
⚠️ Minor gaps - Consider /pm:roadmap-research {session-name}

{If no HIGH/MEDIUM gaps:}
✅ Ready - Run /pm:decompose {session-name}
```

---

## Important Rules

1. **READ-ONLY**: This command only audits, it doesn't modify the roadmap
2. **Be thorough**: Check every feature from scope documents
3. **Be specific**: Point to exact features, phases, line numbers
4. **Suggest actions**: Don't just report gaps, suggest research queries
5. **Validate dependencies**: Check for cycles and sequencing errors
6. **Statistical analysis**: Use z-scores for RICE outlier detection when possible
7. **Prioritize gaps**: HIGH blocks progress, MEDIUM should fix, LOW is optional

---

## Gap Detection Techniques Reference

| Technique | Purpose | Source |
|-----------|---------|--------|
| Bidirectional Traceability Matrix | Coverage gaps | NASA SWE-072 |
| Topological Sort (Kahn's Algorithm) | Cycle detection | Graph theory |
| DFS + Degree Analysis | Orphan node detection | Graph theory |
| Z-Score Outlier Detection | RICE score validation | Statistics |
| Reference Class Forecasting | Effort validation | Kahneman |
