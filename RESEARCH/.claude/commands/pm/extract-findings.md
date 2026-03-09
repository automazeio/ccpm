# Extract Findings - Generate Scope Documents from Database

Transform database-stored interrogation data into **development-ready scope documents**. Data is already structured from `/pm:interrogate`, so extraction is a query-and-format operation.

## Usage
```
/pm:extract-findings <session-name> [--tables table1,table2,...] [--run <test-run-id>]
```

## Arguments
- `session-name` (required): Name of the interrogation session to extract
- `--tables` (optional): Comma-separated list of tables to extract (default: all)
- `--run` (optional): Test run ID for filtering test feedback tables (default: latest)

### Available Tables
**Interrogation tables:** `feature`, `journey`, `cross_cutting_concern`, `integration`, `user_type`
**Test feedback tables:** `test_results`, `feedback`, `issues`

## Output

**Directory:** `.claude/scopes/{session-name}/`

| File | Contents | Source Table(s) |
|------|----------|-----------------|
| `00_scope_document.md` | Unified comprehensive scope document | All tables |
| `01_features.md` | Confirmed features catalog | `feature` |
| `02_user_journeys.md` | Mapped user journeys | `journey` + `journey_steps_detailed` |
| `03_technical_ops.md` | Technical operations per journey step | `journey_steps_detailed` |
| `04_nfr_requirements.md` | Derived non-functional requirements | `cross_cutting_concern` |
| `05_technical_architecture.md` | Tech stack, integrations, ADRs | `integration` + `cross_cutting_concern` |
| `06_risk_assessment.md` | Risk analysis and mitigations | Derived |
| `07_gap_analysis.md` | Missing info and clarification questions | Validation |
| `08_test_plan.md` | Test cases organized by feature | `feature` + `journey` |
| `09_test_results.md` | Test execution results | `test_results` |
| `10_feedback.md` | Aggregated persona feedback | `feedback` |
| `11_issues.md` | Prioritized issues | `issues` |

---

## Extraction Flow

```
Database
   │
   ▼
┌─────────────────────────────────────────────────────────┐
│ QUERY: Get confirmed features                           │
│ SELECT * FROM feature WHERE session_name = ? AND        │
│ status = 'confirmed'                                    │
│ → 01_features.md                                        │
└─────────────────────────────────────────────────────────┘
   │
   ▼
┌─────────────────────────────────────────────────────────┐
│ QUERY: Get confirmed journeys with steps                │
│ SELECT j.*, js.* FROM journey j                         │
│ JOIN journey_steps_detailed js ON j.id = js.journey_id  │
│ → 02_user_journeys.md                                   │
│ → 03_technical_ops.md                                   │
└─────────────────────────────────────────────────────────┘
   │
   ▼
┌─────────────────────────────────────────────────────────┐
│ QUERY: Get cross-cutting concerns                       │
│ SELECT * FROM cross_cutting_concern WHERE session_name=?│
│ → 04_nfr_requirements.md (derive from config)           │
│ → 05_technical_architecture.md                          │
└─────────────────────────────────────────────────────────┘
   │
   ▼
┌─────────────────────────────────────────────────────────┐
│ QUERY: Get integrations and user types                  │
│ SELECT * FROM integration WHERE session_name = ?        │
│ SELECT * FROM user_type WHERE session_name = ?          │
│ → Include in architecture and scope                     │
└─────────────────────────────────────────────────────────┘
   │
   ▼
┌─────────────────────────────────────────────────────────┐
│ DERIVE: Risk assessment from data patterns              │
│ → 06_risk_assessment.md                                 │
└─────────────────────────────────────────────────────────┘
   │
   ▼
┌─────────────────────────────────────────────────────────┐
│ VALIDATE: Check for gaps in data                        │
│ → 07_gap_analysis.md                                    │
└─────────────────────────────────────────────────────────┘
   │
   ▼
┌─────────────────────────────────────────────────────────┐
│ GENERATE: Test cases per feature                        │
│ → 08_test_plan.md                                       │
└─────────────────────────────────────────────────────────┘
   │
   ▼
┌─────────────────────────────────────────────────────────┐
│ SYNTHESIZE: Compile into unified scope                  │
│ → 00_scope_document.md                                  │
└─────────────────────────────────────────────────────────┘
```

---

## Instructions

### Step 1: Initialize

```bash
SESSION_NAME="$ARGUMENTS"
SCOPE_DIR=".claude/scopes/$SESSION_NAME"
mkdir -p "$SCOPE_DIR"
```

**Verify session exists in database:**

```sql
SELECT COUNT(*) FROM feature WHERE session_name = '{SESSION_NAME}' AND status = 'confirmed';
```

If count is 0:
```
❌ Session not found or no confirmed features: {session-name}

Run interrogation first: /pm:interrogate {session-name}
```

---

### Step 1.5: Parse Optional Arguments

```bash
# Parse --tables argument
TABLES=""
if [[ "$ARGUMENTS" == *"--tables"* ]]; then
    TABLES=$(echo "$ARGUMENTS" | sed -n 's/.*--tables[= ]*\([^ ]*\).*/\1/p')
fi

# Parse --run argument for test feedback tables
TEST_RUN_ID=""
if [[ "$ARGUMENTS" == *"--run"* ]]; then
    TEST_RUN_ID=$(echo "$ARGUMENTS" | sed -n 's/.*--run[= ]*\([^ ]*\).*/\1/p')
fi

# If extracting test feedback tables but no run ID, get latest
if [[ -z "$TEST_RUN_ID" ]] && [[ "$TABLES" == *"test_results"* || "$TABLES" == *"feedback"* || "$TABLES" == *"issues"* || -z "$TABLES" ]]; then
    TEST_RUN_ID=$(psql -t -c "SELECT test_run_id FROM test_results WHERE session_name='$SESSION_NAME' ORDER BY executed_at DESC LIMIT 1" 2>/dev/null | tr -d ' ')
fi
```

**Table-to-file mapping:**
```
TABLE_FILE_MAP = {
    # Interrogation tables
    "feature": ["01_features.md"],
    "journey": ["02_user_journeys.md", "03_technical_ops.md"],
    "cross_cutting_concern": ["04_nfr_requirements.md"],
    "integration": ["05_technical_architecture.md"],
    "user_type": ["05_technical_architecture.md"],

    # Test feedback tables
    "test_results": ["09_test_results.md"],
    "feedback": ["10_feedback.md"],
    "issues": ["11_issues.md"]
}
```

**Conditional extraction logic:**
```bash
should_extract() {
    local table="$1"
    # If no tables specified, extract all
    [[ -z "$TABLES" ]] && return 0
    # Otherwise check if table is in the list
    [[ ",$TABLES," == *",$table,"* ]] && return 0
    return 1
}
```

---

### Step 2: Extract Features → `01_features.md`

**Skip if:** `--tables` specified and doesn't include `feature`

**Query:**
```sql
SELECT
  feature_id,
  name,
  description,
  priority,
  user_story,
  acceptance_criteria,
  complexity,
  source
FROM feature
WHERE session_name = '{SESSION_NAME}'
  AND status = 'confirmed'
ORDER BY feature_id;
```

**Write `01_features.md`:**

```markdown
# Features Catalog: {session-name}

**Generated:** {datetime}
**Source:** Database (confirmed features)
**Total Features:** {count}

---

## Feature Summary

| ID | Feature | Priority | Complexity |
|----|---------|----------|------------|
| F-001 | {name} | {priority} | {complexity} |
| F-002 | {name} | {priority} | {complexity} |
...

---

## Feature Details

### F-001: {name}

**Description:** {description}

**Priority:** {priority}
**Complexity:** {complexity}
**Source:** {source}

**User Story:**
{user_story}

**Acceptance Criteria:**
{for each criterion in acceptance_criteria}
- [ ] {criterion}
{end for}

---

### F-002: {name}
...
```

---

### Step 3: Extract User Journeys → `02_user_journeys.md`

**Query:**
```sql
SELECT
  j.journey_id,
  j.name,
  j.actor,
  j.trigger_event,
  j.goal,
  j.preconditions,
  j.postconditions,
  j.frequency,
  j.complexity
FROM journey j
WHERE j.session_name = '{SESSION_NAME}'
  AND j.confirmation_status = 'confirmed'
ORDER BY j.journey_id;
```

**For each journey, get steps:**
```sql
SELECT
  step_number,
  step_name,
  user_action,
  user_decision_point,
  decision_options
FROM journey_steps_detailed
WHERE journey_id = {journey_id}
ORDER BY step_number;
```

**Write `02_user_journeys.md`:**

```markdown
# User Journeys: {session-name}

**Generated:** {datetime}
**Total Journeys:** {count}

---

## Journey Summary

| ID | Journey | Actor | Frequency |
|----|---------|-------|-----------|
| J-001 | {name} | {actor} | {frequency} |
...

---

## Journey Details

### J-001: {name}

**Actor:** {actor}
**Trigger:** {trigger_event}
**Goal:** {goal}
**Frequency:** {frequency}
**Complexity:** {complexity}

**Pre-conditions:**
{preconditions}

**Steps:**
1. {step_name}: {user_action}
2. {step_name}: {user_action}
3. {step_name}: {user_action}
...

**Post-conditions:**
{postconditions}

**Related Features:** {list from feature_journey table}

---
```

---

### Step 4: Extract Technical Operations → `03_technical_ops.md`

**Query:**
```sql
SELECT
  j.journey_id,
  j.name AS journey_name,
  js.step_number,
  js.step_name,
  js.user_action,
  js.frontend_event_type,
  js.api_operation_type,
  js.api_operation_name,
  js.backend_service,
  js.backend_method,
  js.db_operation,
  js.db_tables_affected
FROM journey j
JOIN journey_steps_detailed js ON j.id = js.journey_id
WHERE j.session_name = '{SESSION_NAME}'
  AND j.confirmation_status = 'confirmed'
ORDER BY j.journey_id, js.step_number;
```

**Write `03_technical_ops.md`:**

```markdown
# Technical Operations: {session-name}

**Generated:** {datetime}
**Purpose:** Maps each journey step to technical implementation

---

## Operations by Journey

### J-001: {journey_name}

| Step | User Action | Frontend | API | Backend | DB |
|------|------------|----------|-----|---------|-----|
| 1 | {user_action} | {event_type} | {api_op} | {service}.{method} | {db_op} |
| 2 | {user_action} | {event_type} | {api_op} | {service}.{method} | {db_op} |
...

#### Step 1: {step_name}
- **User Action:** {user_action}
- **Frontend:** {frontend_event_type} event triggers {api_operation_name}
- **API:** {api_operation_type} {api_operation_name}
- **Backend:** {backend_service}.{backend_method}()
- **Database:** {db_operation} on {db_tables_affected}

#### Step 2: {step_name}
...

---

### J-002: {journey_name}
...
```

---

### Step 5: Derive NFR Requirements → `04_nfr_requirements.md`

**Query cross-cutting concerns:**
```sql
SELECT concern_type, config
FROM cross_cutting_concern
WHERE session_name = '{SESSION_NAME}';
```

**Query user scale:**
```sql
SELECT config->>'expected_users' AS scale
FROM cross_cutting_concern
WHERE session_name = '{SESSION_NAME}'
  AND concern_type = 'scaling';
```

**Write `04_nfr_requirements.md`:**

```markdown
# Non-Functional Requirements: {session-name}

**Generated:** {datetime}

---

## 1. Performance

Based on expected scale ({scale}):

| Metric | Target |
|--------|--------|
| Page Load Time | < 2s |
| API Response Time | < 500ms |
| Concurrent Users | {derived from scale} |

---

## 2. Security

Authentication: {from cross_cutting_concern.authentication.method}

| Requirement | Status |
|-------------|--------|
| Authentication | {method} |
| Authorization | RBAC (based on user_type table) |
| Data Encryption | TLS in transit, AES at rest |
| Session Management | Required |

---

## 3. Scalability

| Aspect | Requirement |
|--------|-------------|
| Expected Users | {scale} |
| Data Growth | TBD |
| Geographic Distribution | TBD |

---

## 4. Reliability

| Metric | Target |
|--------|--------|
| Uptime | 99.9% |
| RTO | 1 hour |
| RPO | 15 minutes |

---

## 5. Compliance

{Derived from domain - e-commerce needs PCI, health needs HIPAA, etc.}

---
```

---

### Step 6: Technical Architecture → `05_technical_architecture.md`

**Query integrations:**
```sql
SELECT platform, direction, purpose
FROM integration
WHERE session_name = '{SESSION_NAME}'
  AND status = 'confirmed';
```

**Query deployment target:**
```sql
SELECT config->>'target' AS target
FROM cross_cutting_concern
WHERE session_name = '{SESSION_NAME}'
  AND concern_type = 'deployment';
```

**Write `05_technical_architecture.md`:**

```markdown
# Technical Architecture: {session-name}

**Generated:** {datetime}

---

## Technology Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| Frontend | Angular / React | Modern SPA framework |
| Backend | Python / FastAPI | High performance async |
| Database | PostgreSQL | Relational with JSONB |
| API | GraphQL | Flexible queries |
| Infrastructure | {deployment_target} | User selected |

---

## Integrations

| Platform | Direction | Purpose |
|----------|-----------|---------|
{for each integration}
| {platform} | {direction} | {purpose} |
{end for}

---

## User Types

{Query user_type table}

| Type | Description | Feature Access |
|------|-------------|----------------|
{for each user_type with feature counts}
| {name} | {description} | {count} features |
{end for}

---

## Architecture Decisions

### ADR-001: Authentication Method
**Decision:** {auth_method from cross_cutting_concern}
**Rationale:** User specified during interrogation

### ADR-002: Deployment Target
**Decision:** {deployment_target}
**Rationale:** User specified during interrogation

---
```

---

### Step 7: Risk Assessment → `06_risk_assessment.md`

**Derive risks from data patterns:**

```markdown
# Risk Assessment: {session-name}

**Generated:** {datetime}

---

## Identified Risks

| ID | Risk | Category | Likelihood | Impact | Score |
|----|------|----------|------------|--------|-------|
{Generate based on:
- Number of integrations (more = higher integration risk)
- Scale expectation (higher = performance risk)
- Number of features (more = scope risk)
- Complexity of journeys (more steps = technical risk)
}

---

## Risk Details

### R-001: Integration Complexity
**Category:** Technical
**Likelihood:** {based on integration count}
**Impact:** Medium
**Mitigation:** Early integration testing, fallback handling

### R-002: Scalability Challenges
**Category:** Technical
**Likelihood:** {based on scale expectation}
**Impact:** High
**Mitigation:** Load testing, caching strategy, CDN

---
```

---

### Step 8: Gap Analysis → `07_gap_analysis.md`

**Check for missing data:**

```sql
-- Features without acceptance criteria
SELECT name FROM feature
WHERE session_name = '{SESSION_NAME}'
  AND status = 'confirmed'
  AND (acceptance_criteria IS NULL OR acceptance_criteria = '[]');

-- Journeys without steps
SELECT j.name FROM journey j
LEFT JOIN journey_steps_detailed js ON j.id = js.journey_id
WHERE j.session_name = '{SESSION_NAME}'
  AND j.confirmation_status = 'confirmed'
  AND js.id IS NULL;

-- Missing cross-cutting concerns
SELECT concern_type FROM (
  VALUES ('authentication'), ('deployment'), ('scaling')
) AS expected(concern_type)
WHERE concern_type NOT IN (
  SELECT concern_type FROM cross_cutting_concern
  WHERE session_name = '{SESSION_NAME}'
);
```

**Write `07_gap_analysis.md`:**

```markdown
# Gap Analysis: {session-name}

**Generated:** {datetime}

---

## Summary

| Gap Type | Count | Severity |
|----------|-------|----------|
| Missing Acceptance Criteria | {count} | Medium |
| Journeys Without Steps | {count} | High |
| Missing Infrastructure Config | {count} | Low |

---

## Detailed Gaps

### Missing Acceptance Criteria
{list features}

### Journeys Needing Step Details
{list journeys}

### Infrastructure Gaps
{list missing concerns}

---

## Recommended Actions

1. {action for each gap}

---
```

---

### Step 9: Test Plan → `08_test_plan.md`

**Generate test cases per feature:**

```markdown
# Test Plan: {session-name}

**Generated:** {datetime}

---

## Test Coverage Summary

| Feature | Test Cases | Priority |
|---------|------------|----------|
{for each feature}
| {name} | {generated count} | {priority} |
{end for}

---

## Test Cases by Feature

### F-001: {feature_name}

| TC | Description | Steps | Expected Result |
|----|-------------|-------|-----------------|
| TC-001-01 | Happy path | 1. {step} 2. {step} | {result} |
| TC-001-02 | Edge case | 1. {step} | {result} |
| TC-001-03 | Error handling | 1. {step} | {result} |

---

### F-002: {feature_name}
...

---

## Journey-Based Tests

### J-001: {journey_name}

| TC | Description | Covers Steps | Expected |
|----|-------------|--------------|----------|
| TC-J001-01 | Full journey | 1-{n} | Journey completes |
| TC-J001-02 | Abandon mid-journey | 1-3 | State preserved |

---
```

---

### Step 10: Synthesize Scope Document → `00_scope_document.md`

Compile all extracted data into the unified scope document:

```markdown
# Scope Document: {Project Name}

**Version:** 1.0
**Generated:** {datetime}
**Session:** {session-name}
**Status:** Draft - Pending Review

---

## 1. Executive Overview

### 1.1 Project Summary
{From conversation.md Topic field}

### 1.2 Key Metrics
- **Features:** {count from feature table}
- **User Journeys:** {count from journey table}
- **User Types:** {count from user_type table}
- **Integrations:** {count from integration table}

### 1.3 Success Criteria
{Derived from features and journeys}

---

## 2. Functional Requirements

### 2.1 Feature Catalog
See: `01_features.md`

| ID | Feature | Priority |
|----|---------|----------|
{summary table}

### 2.2 User Journeys
See: `02_user_journeys.md`

| ID | Journey | Actor |
|----|---------|-------|
{summary table}

---

## 3. Technical Specifications

### 3.1 Technical Operations
See: `03_technical_ops.md`

### 3.2 Architecture
See: `05_technical_architecture.md`

---

## 4. Non-Functional Requirements
See: `04_nfr_requirements.md`

---

## 5. Risk Assessment
See: `06_risk_assessment.md`

---

## 6. Open Items
See: `07_gap_analysis.md`

---

## 7. Test Plan
See: `08_test_plan.md`

---

## 8. Next Steps

1. Review this document with stakeholders
2. Address gaps in `07_gap_analysis.md`
3. Generate MVP roadmap: `/pm:roadmap-generate {session-name}`
4. Decompose into PRDs: `/pm:scope-decompose {session-name}`

---
```

---

### Step 11: Extract Test Results → `09_test_results.md`

**Skip if:** `--tables` specified and doesn't include `test_results`
**Skip if:** No test runs exist for this session

**Query:**
```sql
SELECT
    tr.test_run_id,
    j.journey_id,
    j.name as journey_name,
    tr.persona_id,
    tr.overall_status,
    tr.steps_passed,
    tr.steps_failed,
    tr.screenshots_count,
    tr.executed_at
FROM test_results tr
LEFT JOIN journey j ON tr.journey_id = j.id
WHERE tr.session_name = '{SESSION_NAME}'
  AND tr.test_run_id = '{TEST_RUN_ID}'
ORDER BY tr.executed_at;
```

**Write `09_test_results.md`:**

```markdown
# Test Results: {session-name}

**Generated:** {datetime}
**Test Run:** {TEST_RUN_ID}

---

## Summary

| Metric | Value |
|--------|-------|
| Total Tests | {count} |
| Passed | {passed_count} |
| Failed | {failed_count} |
| Success Rate | {rate}% |

---

## Results by Journey

### J-001: {journey_name}

| Persona | Status | Passed | Failed | Screenshots |
|---------|--------|--------|--------|-------------|
| persona-01 | PASS | 5 | 0 | 2 |
| persona-02 | FAIL | 3 | 2 | 4 |

**Issues Found:**
- Step 3: {description from issues_found JSONB}

---
```

---

### Step 12: Extract Feedback → `10_feedback.md`

**Skip if:** `--tables` specified and doesn't include `feedback`
**Skip if:** No feedback exists for this session/run

**Query:**
```sql
SELECT
    persona_id,
    overall_rating,
    nps_score,
    recommendation,
    positives,
    frustrations,
    bugs,
    feature_requests,
    test_context
FROM feedback
WHERE session_name = '{SESSION_NAME}'
  AND test_run_id = '{TEST_RUN_ID}'
ORDER BY persona_id;
```

**Aggregate metrics:**
```sql
SELECT
    AVG(overall_rating) as avg_rating,
    AVG(nps_score) as avg_nps,
    COUNT(CASE WHEN recommendation = 'yes' THEN 1 END)::float / COUNT(*) * 100 as recommend_rate
FROM feedback
WHERE session_name = '{SESSION_NAME}'
  AND test_run_id = '{TEST_RUN_ID}';
```

**Write `10_feedback.md`:**

```markdown
# Feedback Analysis: {session-name}

**Generated:** {datetime}
**Test Run:** {TEST_RUN_ID}
**Personas Surveyed:** {count}

---

## Metrics

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Average Rating | {avg}/5 | 4.0 | {✅/⚠️} |
| NPS Score | {nps} | 50 | {✅/⚠️} |
| Recommendation Rate | {rate}% | 80% | {✅/⚠️} |

---

## Top Frustrations

| Theme | Severity | Mentions | Personas |
|-------|----------|----------|----------|
{aggregated from frustrations JSONB}

---

## Bugs Reported

| Title | Severity | Reported By | Journey |
|-------|----------|-------------|---------|
{aggregated from bugs JSONB}

---

## Feature Requests

| Title | Priority | Votes |
|-------|----------|-------|
{aggregated from feature_requests JSONB}

---
```

---

### Step 13: Extract Issues → `11_issues.md`

**Skip if:** `--tables` specified and doesn't include `issues`
**Skip if:** No issues exist for this session/run

**Query:**
```sql
SELECT
    issue_id,
    title,
    description,
    category,
    severity,
    mentions,
    rice_score,
    journey_refs,
    persona_refs,
    status
FROM issues
WHERE session_name = '{SESSION_NAME}'
  AND test_run_id = '{TEST_RUN_ID}'
ORDER BY rice_score DESC;
```

**Write `11_issues.md`:**

```markdown
# Prioritized Issues: {session-name}

**Generated:** {datetime}
**Test Run:** {TEST_RUN_ID}
**Total Issues:** {count}

---

## Issues by Priority (RICE Score)

| ID | Title | Category | Severity | RICE | Status |
|----|-------|----------|----------|------|--------|
| I-001 | {title} | bug | critical | 120 | open |
| I-002 | {title} | ux | high | 95 | open |
| I-003 | {title} | performance | medium | 80 | open |

---

## Critical Issues (Immediate Action)

### I-001: {title}
- **Category:** {category}
- **Severity:** {severity}
- **RICE Score:** {rice_score}
- **Reported By:** {persona_refs count} personas
- **Journeys Affected:** {journey_refs}
- **Description:** {description}

---

## Issue Breakdown

| Category | Count |
|----------|-------|
| Bug | {count} |
| UX | {count} |
| Performance | {count} |
| Feature Request | {count} |

---

## Next Steps

1. Address critical issues before launch
2. Create remediation PRDs: `/pm:generate-remediation {session-name}`
3. Re-run tests after fixes: `/pm:test-journey {session-name} ...`

---
```

---

### Step 14: Present Summary

```
✅ Scope extracted: {session-name}
{if TEST_RUN_ID} Test Run: {TEST_RUN_ID} {endif}

Summary:
- Features: {count}
- User Journeys: {count}
- User Types: {count}
- Integrations: {count}
- Test Cases: {count}
{if test feedback data exists}
- Test Results: {count}
- Feedback Entries: {count}
- Issues: {count}
{endif}

Output Directory: .claude/scopes/{session-name}/

Files Created:
- 00_scope_document.md (comprehensive scope)
- 01_features.md
- 02_user_journeys.md
- 03_technical_ops.md
- 04_nfr_requirements.md
- 05_technical_architecture.md
- 06_risk_assessment.md
- 07_gap_analysis.md
- 08_test_plan.md
{if test feedback data exists}
- 09_test_results.md (test run: {TEST_RUN_ID})
- 10_feedback.md
- 11_issues.md
{endif}

Gaps Found: {count} (see 07_gap_analysis.md)

Next Steps:
1. Review 00_scope_document.md
2. Address gaps: /pm:scope-research {session-name} "{question}"
3. Generate roadmap: /pm:roadmap-generate {session-name}
4. Decompose to PRDs: /pm:scope-decompose {session-name}
```

---

## Important Rules

1. **Query database** - Don't parse conversation, use SQL
2. **Only confirmed data** - Filter by `status = 'confirmed'`
3. **Generate tech ops** - Create `03_technical_ops.md`
4. **Generate test plan** - Create `08_test_plan.md`
5. **Derive NFRs** - Infer from cross-cutting concerns and scale
6. **Identify gaps** - Check for missing data
7. **Link files** - Reference related files in scope document

---

## Database Queries Reference

```sql
-- All confirmed features for session
SELECT * FROM feature
WHERE session_name = ? AND status = 'confirmed';

-- All confirmed journeys with steps
SELECT j.*, js.*
FROM journey j
LEFT JOIN journey_steps_detailed js ON j.id = js.journey_id
WHERE j.session_name = ? AND j.confirmation_status = 'confirmed';

-- User types with feature access
SELECT ut.name, COUNT(utf.feature_id) as feature_count
FROM user_type ut
LEFT JOIN user_type_feature utf ON ut.id = utf.user_type_id
WHERE ut.session_name = ?
GROUP BY ut.id, ut.name;

-- All integrations
SELECT * FROM integration
WHERE session_name = ? AND status = 'confirmed';

-- Cross-cutting concerns
SELECT * FROM cross_cutting_concern
WHERE session_name = ?;

-- Session summary
SELECT * FROM session_summary_view
WHERE session_name = ?;

-- Test results for a specific run
SELECT tr.*, j.journey_id, j.name as journey_name
FROM test_results tr
LEFT JOIN journey j ON tr.journey_id = j.id
WHERE tr.session_name = ? AND tr.test_run_id = ?;

-- Feedback for a specific run
SELECT * FROM feedback
WHERE session_name = ? AND test_run_id = ?;

-- Issues for a specific run (ordered by priority)
SELECT * FROM issues
WHERE session_name = ? AND test_run_id = ?
ORDER BY rice_score DESC;

-- Get latest test run ID for a session
SELECT test_run_id FROM test_results
WHERE session_name = ?
ORDER BY executed_at DESC LIMIT 1;
```
