# Generate Remediation - Create PRDs from Feedback Analysis

Convert prioritized feedback issues into actionable PRDs for the remediation sprint.

## Usage
```
/pm:generate-remediation <session-name> [--max N]
```

## Arguments
- `session-name` (required): Name of the scoped session
- `--max N` (optional): Maximum number of PRDs to generate (default: 10)

## Input
**Required:**
- `.claude/testing/feedback/{session-name}-issues.json`

**Optional:**
- `.claude/testing/feedback/{session-name}-analysis.md` (for context)
- `.claude/scopes/{session-name}/` (for technical context)

## Output
**Files:**
- `.claude/prds/{NNN}-fix-{issue-name}.md` (PRD per critical/high issue)
- `.claude/prds/{NNN}-enhance-{feature-name}.md` (PRD per priority feature)
- `.claude/testing/feedback/{session-name}-remediation-plan.md` (Summary)

---

## Process

### Step 1: Initialize and Validate

```bash
SESSION_NAME="${ARGUMENTS%% *}"
MAX="${ARGUMENTS#*--max }"
[ "$MAX" = "$ARGUMENTS" ] && MAX=10
ISSUES_FILE=".claude/testing/feedback/$SESSION_NAME-issues.json"
PRD_DIR=".claude/prds"
```

Verify input exists:
```
If issues file doesn't exist:
❌ Issues not found: {issues-file}

Run /pm:analyze-feedback {session-name} first
```

Read issues file and parse JSON.

---

### Step 2: Select Issues for Remediation

Apply selection criteria:

```typescript
interface RemediationCandidate {
  id: string;
  type: 'bug' | 'frustration' | 'feature_request';
  riceScore: number;
  severity?: string;
  priority?: string;
  include: boolean;
  reason: string;
}

// Selection rules:
// 1. ALL critical bugs → Must include
// 2. ALL high bugs → Must include
// 3. Major frustrations with RICE > 50 → Include
// 4. Feature requests with votes >= 5 and priority "critical" → Include
// 5. Remaining by RICE score until max reached
```

**Priority Order:**
1. Critical bugs (RICE irrelevant - must fix)
2. High bugs (sorted by RICE)
3. Major frustrations (sorted by RICE)
4. Critical feature requests (sorted by votes)
5. Medium bugs (sorted by RICE)
6. Important feature requests (sorted by votes)

---

### Step 3: Determine Next PRD Number

```bash
# Find highest existing PRD number
LAST_PRD=$(ls -1 $PRD_DIR/*.md 2>/dev/null | grep -oP '\d{3}' | sort -n | tail -1)
NEXT_PRD=$((LAST_PRD + 1))
```

---

### Step 4: Generate Bug Fix PRDs

For each bug selected, create PRD:

**Template: `.claude/prds/{NNN}-fix-{slug}.md`**

```markdown
---
name: fix-{issue-slug}
description: {issue title}
status: backlog
type: bug-fix
priority: {P0|P1|P2}
source: synthetic-testing
session: {session-name}
issue-id: {BUG-XXX}
personas-affected: {count}
journeys-affected: {journey list}
created: {datetime}
updated: {datetime}
---

# Fix: {Issue Title}

## Problem Statement

{Issue description from feedback}

### Impact
- **Severity:** {Critical/High/Medium/Low}
- **Personas Affected:** {count}/{total} ({percentage}%)
- **Journeys Blocked:** {journey list}
- **RICE Score:** {score}

### Evidence from Users

> "{Quote from persona 1}"
> — {Persona name}, {Role}

> "{Quote from persona 2}"
> — {Persona name}, {Role}

### Screenshots
{If available, reference screenshot paths}

---

## Root Cause Analysis

Based on test failures and user feedback:
- **Suspected Cause:** {analysis}
- **Affected Components:** {list}
- **Related Code:** {file paths if known}

---

## Proposed Solution

{Technical approach to fix the issue}

### Implementation Steps
1. {Step 1}
2. {Step 2}
3. {Step 3}

### Files to Modify
- `{file1}` - {change description}
- `{file2}` - {change description}

---

## Acceptance Criteria

- [ ] {Criterion 1 - specific and testable}
- [ ] {Criterion 2}
- [ ] {Criterion 3}
- [ ] All affected personas can complete {journey} successfully
- [ ] Automated tests pass for {journey}

---

## Test Plan

### Manual Verification
1. {Test step 1}
2. {Test step 2}

### Automated Tests
- [ ] Update `{journey}.spec.ts` to verify fix
- [ ] Add regression test for {specific scenario}

### Persona Re-test
After fix, re-run synthetic tests for:
- {Affected persona 1}
- {Affected persona 2}

---

## Rollback Plan

If fix causes regressions:
1. {Rollback step 1}
2. {Rollback step 2}

---

## Dependencies

- Blocks: {None or list}
- Blocked by: {None or list}

---

## Metadata

| Field | Value |
|-------|-------|
| Source | Synthetic Testing |
| Session | {session-name} |
| Issue ID | {BUG-XXX} |
| Created | {datetime} |
```

---

### Step 5: Generate Frustration Fix PRDs

For UX frustrations, create PRD:

**Template: `.claude/prds/{NNN}-improve-{slug}.md`**

```markdown
---
name: improve-{slug}
description: {frustration theme}
status: backlog
type: ux-improvement
priority: {P1|P2}
source: synthetic-testing
session: {session-name}
personas-affected: {count}
created: {datetime}
updated: {datetime}
---

# Improve: {Frustration Theme}

## Problem Statement

Users report frustration with {theme description}.

### Impact
- **Severity:** {Major/Moderate/Minor}
- **Personas Affected:** {count}/{total}
- **RICE Score:** {score}

### User Feedback

> "{Quote 1}"
> — {Persona}, {Role} ({tech proficiency} tech proficiency)

> "{Quote 2}"
> — {Persona}, {Role}

---

## Current State

{Description of current UX that causes frustration}

### Pain Points
1. {Pain point 1}
2. {Pain point 2}

---

## Proposed Improvement

{Description of improved UX}

### Design Changes
- {Change 1}
- {Change 2}

### User Flow Comparison

**Before:**
1. {Old step 1}
2. {Old step 2}
3. {Old step 3}

**After:**
1. {New step 1}
2. {New step 2}

---

## Acceptance Criteria

- [ ] {Specific UX improvement}
- [ ] {Measurable outcome}
- [ ] User feedback score improves from {X} to {Y}

---

## Test Plan

### Persona Validation
Re-test with personas who reported frustration:
- {Persona 1}: Verify {improvement}
- {Persona 2}: Verify {improvement}

---

## Dependencies

- Blocks: {None or list}
- Blocked by: {None or list}
```

---

### Step 6: Generate Feature Request PRDs

For priority feature requests:

**Template: `.claude/prds/{NNN}-add-{feature-slug}.md`**

```markdown
---
name: add-{feature-slug}
description: {feature title}
status: backlog
type: enhancement
priority: {P1|P2}
source: synthetic-testing
session: {session-name}
votes: {count}
created: {datetime}
updated: {datetime}
---

# Add: {Feature Title}

## Problem Statement

{Feature description and user need}

### User Demand
- **Requested By:** {count}/{total} personas ({percentage}%)
- **Average Priority:** {critical/important/nice-to-have}
- **Estimated Impact:** {impact statement}

### User Requests

> "{Request quote 1}"
> — {Persona}, {Role}

> "{Request quote 2}"
> — {Persona}, {Role}

---

## Proposed Solution

{Feature description}

### User Stories

As a {user type}, I want to {action} so that {benefit}.

### Functional Requirements

1. **FR-1:** {Requirement}
2. **FR-2:** {Requirement}

---

## Acceptance Criteria

- [ ] {Criterion 1}
- [ ] {Criterion 2}
- [ ] {Criterion 3}

---

## Design Considerations

### UI/UX
- {Design consideration 1}
- {Design consideration 2}

### Technical
- {Technical consideration 1}
- {Technical consideration 2}

---

## Test Plan

### Persona Validation
Test with personas who requested feature:
- {Persona 1}: Verify feature meets expectations
- {Persona 2}: Verify feature meets expectations

---

## Dependencies

- Blocks: {None or list}
- Blocked by: {None or list}
```

---

### Step 7: Generate Remediation Plan

Create `.claude/testing/feedback/{session-name}-remediation-plan.md`:

```markdown
# Remediation Plan: {session-name}

**Generated:** {datetime}
**Source:** Synthetic User Feedback Analysis
**PRDs Generated:** {count}

---

## Executive Summary

Based on synthetic testing with {N} personas, we identified {X} issues requiring remediation. This plan prioritizes fixes to improve user satisfaction from {current rating}/5 to target 4.0/5.

### Current State
| Metric | Current | Target | Gap |
|--------|---------|--------|-----|
| Avg Rating | 3.6/5 | 4.0/5 | -0.4 |
| NPS Score | 42 | 50 | -8 |
| Would Recommend | 70% | 80% | -10% |

### Expected Outcome
After implementing these PRDs:
- Rating improvement: +{X} points
- NPS improvement: +{X} points
- All critical bugs resolved
- Top frustrations addressed

---

## Remediation PRDs

### Critical (Must Fix Before Launch)

| PRD | Type | Issue | Personas | RICE |
|-----|------|-------|----------|------|
| {NNN} | Bug Fix | {title} | {count} | {score} |
| {NNN} | Bug Fix | {title} | {count} | {score} |

### High Priority (First Sprint)

| PRD | Type | Issue | Personas | RICE |
|-----|------|-------|----------|------|
| {NNN} | Bug Fix | {title} | {count} | {score} |
| {NNN} | UX | {title} | {count} | {score} |

### Medium Priority (Backlog)

| PRD | Type | Issue | Personas | RICE |
|-----|------|-------|----------|------|
| {NNN} | Feature | {title} | {count} | {score} |
| {NNN} | UX | {title} | {count} | {score} |

---

## Implementation Order

Based on dependencies and priority:

```
Phase 1 (Critical):
├── PRD-{NNN}: {title}
├── PRD-{NNN}: {title}
└── [Re-test critical personas]

Phase 2 (High Priority):
├── PRD-{NNN}: {title}
├── PRD-{NNN}: {title}
└── [Re-test affected journeys]

Phase 3 (Medium Priority):
├── PRD-{NNN}: {title}
├── PRD-{NNN}: {title}
└── [Full persona re-test]
```

---

## Validation Plan

After each phase:
1. Re-run synthetic tests for affected journeys
2. Generate new feedback from affected personas
3. Compare metrics to baseline
4. Proceed to next phase if targets met

### Success Criteria
- [ ] All critical bugs resolved (0 critical issues)
- [ ] Avg rating >= 4.0/5
- [ ] NPS >= 50
- [ ] Would recommend >= 80%

---

## Not Included (Deferred)

Issues not included in this remediation cycle:

| Issue | Reason | Future Consideration |
|-------|--------|---------------------|
| {title} | Low RICE score | v2.0 backlog |
| {title} | Feature creep | Post-launch evaluation |

---

## Files Generated

```
.claude/prds/
├── {NNN}-fix-{slug}.md
├── {NNN}-fix-{slug}.md
├── {NNN}-improve-{slug}.md
└── {NNN}-add-{slug}.md
```

---

## Next Steps

1. Review generated PRDs
2. Run batch process: `/pm:batch-process`
3. After implementation, re-test: `/pm:generate-tests {session-name} && npx playwright test`
4. Generate new feedback: `/pm:generate-feedback {session-name}`
5. Compare metrics to validate improvements
```

---

### Step 8: Present Summary

```
✅ Remediation PRDs generated: {session-name}

PRDs Created: {count}
- Bug Fixes: {count} (Critical: {N}, High: {N})
- UX Improvements: {count}
- New Features: {count}

PRD Files:
├── {NNN}-fix-mobile-validation.md (P0)
├── {NNN}-fix-slow-dashboard.md (P0)
├── {NNN}-improve-submit-flow.md (P1)
├── {NNN}-add-bulk-upload.md (P1)
└── {count} more...

Expected Impact:
- Rating: 3.6 → 4.0+ (+0.4)
- NPS: 42 → 50+ (+8)
- Recommend: 70% → 80%+ (+10%)

Output: .claude/testing/feedback/{session-name}-remediation-plan.md

Next Steps:
1. Review PRDs: ls .claude/prds/*fix*.md
2. Process PRDs: /pm:batch-process
3. After fixes, re-test: /pm:generate-tests {session-name}
```

---

## Important Rules

1. **Evidence-based** - Every PRD cites user feedback
2. **Prioritized** - Critical bugs always come first
3. **Testable** - Clear acceptance criteria
4. **Traceable** - Link back to source issues and personas
5. **Scoped** - Don't exceed max PRDs per run
6. **Actionable** - Include implementation guidance

---

## PRD Naming Convention

| Type | Pattern | Example |
|------|---------|---------|
| Bug Fix | `{NNN}-fix-{slug}` | `301-fix-mobile-validation` |
| UX Improvement | `{NNN}-improve-{slug}` | `302-improve-submit-flow` |
| Feature | `{NNN}-add-{slug}` | `303-add-bulk-upload` |

---

## Sources

Based on research from:
- RICE prioritization framework
- Bug triage best practices
- PRD writing standards
