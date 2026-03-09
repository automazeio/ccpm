# Test Plan: {session-name}

**Generated:** {datetime}
**Purpose:** Test cases organized by feature and user journey

---

## Test Coverage Summary

### By Feature

| Feature ID | Feature Name | Test Cases | Priority | Coverage |
|------------|--------------|------------|----------|----------|
| F-001 | {name} | 5 | High | 100% |
| F-002 | {name} | 3 | High | 100% |
| F-003 | {name} | 4 | Medium | 80% |

### By Journey

| Journey ID | Journey Name | Test Cases | E2E Tests |
|------------|--------------|------------|-----------|
| J-001 | {name} | 4 | 2 |
| J-002 | {name} | 3 | 1 |

---

## Test Cases by Feature

### F-001: {feature_name}

**Priority:** {priority}
**Description:** {description}

| TC ID | Description | Type | Steps | Expected Result | Priority |
|-------|-------------|------|-------|-----------------|----------|
| TC-001-01 | Happy path - {action} | Functional | 1. {step} 2. {step} | {expected} | High |
| TC-001-02 | Validation - empty input | Negative | 1. {step} | Error shown | Medium |
| TC-001-03 | Validation - invalid format | Negative | 1. {step} | Error shown | Medium |
| TC-001-04 | Edge case - max length | Boundary | 1. {step} | Handled gracefully | Low |
| TC-001-05 | Permission denied | Security | 1. {step} | Access denied | High |

#### TC-001-01: Happy path - {action}

**Preconditions:**
- User is logged in
- {other conditions}

**Steps:**
1. Navigate to {page}
2. Enter {input}
3. Click {button}
4. Verify {outcome}

**Expected Result:**
- {primary outcome}
- {secondary outcome}

**Postconditions:**
- {state after test}

---

### F-002: {feature_name}

{repeat structure}

---

## Journey-Based E2E Tests

### J-001: {journey_name}

**Actor:** {actor}
**Goal:** {goal}

| TC ID | Description | Covers Steps | Expected |
|-------|-------------|--------------|----------|
| TC-J001-01 | Complete journey | 1-5 | Journey completes successfully |
| TC-J001-02 | Abandon at step 3 | 1-3 | State preserved for resumption |
| TC-J001-03 | Error at step 2 | 1-2 | Graceful error handling |
| TC-J001-04 | Concurrent access | 1-5 | No data corruption |

#### TC-J001-01: Complete Journey

**Description:** Verify the complete {journey_name} journey from start to finish.

**Preconditions:**
- {actor} is logged in
- System is in initial state

**Steps:**
1. **Step 1 - {step_name}:** {action}
   - Expected: {intermediate result}
2. **Step 2 - {step_name}:** {action}
   - Expected: {intermediate result}
3. **Step 3 - {step_name}:** {action}
   - Expected: {intermediate result}
4. **Step 4 - {step_name}:** {action}
   - Expected: {intermediate result}
5. **Step 5 - {step_name}:** {action}
   - Expected: {final result}

**Expected Final State:**
- {outcome 1}
- {outcome 2}

**Cleanup:**
- {cleanup action}

---

### J-002: {journey_name}

{repeat structure}

---

## Integration Test Cases

### External Integrations

| Integration | Test Case | Description | Mock/Live |
|-------------|-----------|-------------|-----------|
| Stripe | INT-001 | Payment success | Mock |
| Stripe | INT-002 | Payment failure | Mock |
| Stripe | INT-003 | Webhook handling | Mock |

---

## Performance Test Cases

| ID | Description | Threshold | Journey/Feature |
|----|-------------|-----------|-----------------|
| PERF-001 | Page load time | < 2s | All |
| PERF-002 | API response time | < 500ms | All |
| PERF-003 | Concurrent users | 100 | J-001 |

---

## Security Test Cases

| ID | Description | OWASP Category | Feature |
|----|-------------|----------------|---------|
| SEC-001 | SQL injection | A03:2021 | F-002 |
| SEC-002 | XSS prevention | A03:2021 | F-001 |
| SEC-003 | Auth bypass | A01:2021 | All |
| SEC-004 | IDOR | A01:2021 | F-003 |

---

## Test Automation Strategy

### Unit Tests
- Framework: Jest / pytest
- Coverage target: 80%
- Location: `src/**/*.test.ts`

### Integration Tests
- Framework: Supertest / pytest
- Database: Test containers
- Location: `tests/integration/`

### E2E Tests
- Framework: Playwright
- Environment: Staging
- Location: `tests/e2e/`

### Test Data
- Fixtures: `tests/fixtures/`
- Factories: `tests/factories/`

---

## Test Execution Order

1. Unit tests (fast feedback)
2. Integration tests (API level)
3. E2E tests (critical paths only)
4. Performance tests (scheduled)
5. Security tests (pre-release)

---

## Notes

- All tests must pass before merge
- E2E tests run on staging environment
- Performance tests run nightly
- Security tests run weekly and pre-release
