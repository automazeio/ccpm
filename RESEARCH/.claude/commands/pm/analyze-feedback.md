# Analyze Feedback - Aggregate and Categorize Synthetic User Feedback

Analyze synthetic feedback from all personas to identify patterns, prioritize issues, and prepare for remediation.

## Usage
```
/pm:analyze-feedback <session-name> [--run <test-run-id>]
```

## Arguments
- `session-name` (required): Name of the scoped session
- `--run` (optional): Test run ID from `/pm:test-journey` (defaults to latest run)

## Input
**Required:**
- `.claude/testing/feedback/{session-name}-feedback.json`

**Optional:**
- `.claude/scopes/{session-name}/02_user_journeys.md` (for journey context)

## Output
**Files:**
- `.claude/testing/feedback/{session-name}-analysis.md` (Human-readable report)
- `.claude/testing/feedback/{session-name}-issues.json` (Structured issues for PRD generation)

---

## Process

### Step 1: Initialize and Validate

```bash
SESSION_NAME="$ARGUMENTS"
FEEDBACK_FILE=".claude/testing/feedback/$SESSION_NAME-feedback.json"
OUTPUT_DIR=".claude/testing/feedback"
```

Verify input exists:
```
If feedback file doesn't exist:
❌ Feedback not found: {feedback-file}

Run /pm:generate-feedback {session-name} first
```

Read feedback file and parse JSON.

---

### Step 1.5: Parse Test Run ID

```bash
TEST_RUN_ID=""
if [[ "$ARGUMENTS" == *"--run"* ]]; then
    TEST_RUN_ID=$(echo "$ARGUMENTS" | sed -n 's/.*--run[= ]*\([^ ]*\).*/\1/p')
fi

# If no run ID provided, get the latest from feedback table
if [[ -z "$TEST_RUN_ID" ]]; then
    TEST_RUN_ID=$(psql -t -c "SELECT test_run_id FROM feedback WHERE session_name='$SESSION_NAME' ORDER BY created_at DESC LIMIT 1" | tr -d ' ')
fi

if [[ -z "$TEST_RUN_ID" ]]; then
    echo "❌ No feedback found for session '$SESSION_NAME'"
    echo ""
    echo "Run: /pm:generate-feedback $SESSION_NAME first"
    exit 1
fi

echo "Analyzing test run: $TEST_RUN_ID"
```

---

### Step 2: Aggregate Metrics

Calculate aggregate statistics:

```typescript
interface AggregatedMetrics {
  // Overall satisfaction
  averageRating: number;        // 1-5 scale
  ratingDistribution: {
    1: number; 2: number; 3: number; 4: number; 5: number;
  };

  // NPS calculation
  npsScore: number;             // -100 to 100
  promoters: number;            // NPS 9-10
  passives: number;             // NPS 7-8
  detractors: number;           // NPS 0-6

  // Recommendation
  recommendationRate: number;
  recommendations: {
    yes: number; no: number; maybe: number;
  };

  // Test results correlation
  testSuccessRate: number;
  avgRatingBySuccessRate: {
    high: number;    // >90% success
    medium: number;  // 70-90% success
    low: number;     // <70% success
  };
}
```

---

### Step 3: Categorize Issues

Group issues by type and theme:

#### Bug Categorization
```typescript
interface CategorizedBugs {
  critical: Bug[];   // Blocks journey, data loss
  high: Bug[];       // Major feature broken
  medium: Bug[];     // Partial breakage
  low: Bug[];        // Minor issues

  byJourney: {
    [journeyId: string]: Bug[];
  };

  byTheme: {
    validation: Bug[];
    performance: Bug[];
    ui: Bug[];
    data: Bug[];
    auth: Bug[];
    other: Bug[];
  };
}
```

#### Frustration Categorization
```typescript
interface CategorizedFrustrations {
  themes: {
    theme: string;
    mentions: number;
    severity: 'minor' | 'moderate' | 'major';
    personas: string[];
    examples: string[];
  }[];
}
```

Identify themes using keyword clustering:
- **Performance:** slow, wait, loading, timeout
- **UX:** confusing, unclear, hard to find, too many clicks
- **Validation:** error, invalid, rejected, failed
- **Mobile:** phone, mobile, responsive, touch
- **Accessibility:** screen reader, keyboard, contrast

---

### Step 4: Calculate Priority Scores

Use RICE scoring adapted for feedback:

```typescript
interface PrioritizedIssue {
  id: string;
  type: 'bug' | 'frustration' | 'feature_request';
  title: string;
  description: string;

  // RICE components
  reach: number;        // Number of personas affected (1-10)
  impact: number;       // Severity score (1-10)
  confidence: number;   // How consistent across personas (1-10)
  effort: number;       // Estimated fix effort (1-10, inverse)

  // Final score
  riceScore: number;    // (R * I * C) / E

  // Source tracking
  reportedBy: string[];
  journeysAffected: string[];
  screenshots: string[];
}
```

**Scoring Guidelines:**

| Factor | Score 10 | Score 5 | Score 1 |
|--------|----------|---------|---------|
| Reach | 8+ personas | 4-7 personas | 1-3 personas |
| Impact | Critical/Major | Moderate | Minor |
| Confidence | All agree | Most agree | Mixed opinions |
| Effort | Quick fix | Medium | Large refactor |

---

### Step 5: Identify Patterns

Analyze cross-persona patterns:

```typescript
interface PatternAnalysis {
  // Consistent issues (high confidence)
  consistentIssues: {
    issue: string;
    agreedBy: number;    // Count of personas
    severity: string;
  }[];

  // Persona-specific issues
  personaSpecific: {
    personaType: string;  // e.g., "low tech proficiency"
    uniqueIssues: string[];
  }[];

  // Journey hotspots
  problematicJourneys: {
    journeyId: string;
    issueCount: number;
    avgRating: number;
    commonIssues: string[];
  }[];

  // Positive patterns (preserve these)
  strengths: {
    feature: string;
    praisedBy: number;
    quotes: string[];
  }[];
}
```

---

### Step 6: Generate Analysis Report

Write `.claude/testing/feedback/{session-name}-analysis.md`:

```markdown
# Synthetic User Feedback Analysis

**Session:** {session-name}
**Generated:** {datetime}
**Personas Analyzed:** {count}

---

## Executive Summary

| Metric | Value | Benchmark |
|--------|-------|-----------|
| Average Rating | {X}/5 | Target: 4.0 |
| NPS Score | {X} | Target: 50 |
| Would Recommend | {X}% | Target: 80% |
| Test Success Rate | {X}% | Target: 95% |

### Key Findings
1. {Top finding 1}
2. {Top finding 2}
3. {Top finding 3}

### Immediate Actions Required
- {Critical issue 1}
- {Critical issue 2}

---

## Satisfaction Analysis

### Rating Distribution
```
5 stars: ████████ {count} ({%})
4 stars: ██████ {count} ({%})
3 stars: ████ {count} ({%})
2 stars: ██ {count} ({%})
1 star:  █ {count} ({%})
```

### NPS Breakdown
- **Promoters (9-10):** {count} personas
- **Passives (7-8):** {count} personas
- **Detractors (0-6):** {count} personas
- **NPS Score:** {score}

---

## Critical Issues (P0)

Issues requiring immediate attention before launch:

### BUG-001: {Title}
- **Severity:** Critical
- **Reported By:** {persona list}
- **Journeys Affected:** {journey list}
- **Description:** {description}
- **Priority Score:** {RICE score}

### BUG-002: {Title}
...

---

## High Priority Issues (P1)

### {Issue Title}
- **Type:** {bug/frustration/feature}
- **Reported By:** {count} personas
- **Impact:** {description}
- **Priority Score:** {RICE score}

---

## Medium Priority Issues (P2)

| Issue | Type | Personas | RICE Score |
|-------|------|----------|------------|
| {title} | {type} | {count} | {score} |
| ... | ... | ... | ... |

---

## Feature Requests (Prioritized)

| Feature | Votes | Priority | Est. Impact |
|---------|-------|----------|-------------|
| {feature 1} | {count} | Critical | {impact} |
| {feature 2} | {count} | Important | {impact} |
| {feature 3} | {count} | Nice-to-have | {impact} |

---

## Journey Analysis

### Most Problematic Journeys

| Journey | Issues | Avg Rating | Top Problem |
|---------|--------|------------|-------------|
| J-001 | 5 | 2.8/5 | Form validation |
| J-003 | 3 | 3.2/5 | Load time |

### Journey Success Rates

| Journey | Pass Rate | Common Failures |
|---------|-----------|-----------------|
| J-001 | 70% | Submit button |
| J-002 | 95% | - |
| J-003 | 80% | Timeout |

---

## Persona Insights

### By Tech Proficiency

| Proficiency | Avg Rating | Top Issues |
|-------------|------------|------------|
| Low | 3.0/5 | Error messages unclear |
| Medium | 3.8/5 | Too many clicks |
| High | 4.2/5 | Missing shortcuts |

### By Feedback Style

| Style | Avg Rating | Avg NPS | Common Themes |
|-------|------------|---------|---------------|
| Frustrated | 2.5/5 | 15 | Performance, errors |
| Detailed | 3.5/5 | 40 | UX improvements |
| Brief | 4.0/5 | 55 | Works well |
| Enthusiastic | 4.5/5 | 75 | Clean UI |

---

## Strengths to Preserve

Features praised by multiple personas:

| Feature | Praised By | Sample Quote |
|---------|------------|--------------|
| {feature} | {count} | "{quote}" |
| ... | ... | ... |

---

## Recommendations

### Immediate (Before Launch)
1. Fix {critical bug 1}
2. Fix {critical bug 2}
3. Address {major frustration}

### Short-term (First Sprint Post-Launch)
1. Implement {high-priority feature}
2. Improve {UX issue}
3. Optimize {performance issue}

### Long-term (Backlog)
1. Consider {nice-to-have feature}
2. Evaluate {enhancement}

---

## Appendix: Raw Data

### All Bugs by Severity
{table of all bugs}

### All Frustrations by Theme
{table of all frustrations}

### All Feature Requests
{table of all feature requests}
```

---

### Step 7: Generate Issues JSON

Write `.claude/testing/feedback/{session-name}-issues.json` for PRD generation:

```json
{
  "session": "{session-name}",
  "analyzedAt": "{datetime}",
  "metrics": {
    "averageRating": 3.6,
    "npsScore": 42,
    "recommendationRate": 70,
    "testSuccessRate": 84
  },
  "prioritizedIssues": [
    {
      "id": "BUG-001",
      "type": "bug",
      "title": "Mobile form validation fails",
      "description": "...",
      "severity": "critical",
      "reach": 4,
      "impact": 10,
      "confidence": 9,
      "effort": 3,
      "riceScore": 120,
      "reportedBy": ["persona-03", "persona-07", "persona-08", "persona-10"],
      "journeysAffected": ["J-001", "J-003"],
      "screenshots": ["screenshots/bug-001.png"],
      "suggestedFix": "Update validation logic for mobile viewports"
    },
    ...
  ],
  "featureRequests": [
    {
      "id": "FR-001",
      "title": "Bulk invoice upload",
      "description": "...",
      "votes": 7,
      "avgPriority": "important",
      "requestedBy": ["persona-01", "persona-02", ...],
      "estimatedImpact": "+15% efficiency"
    },
    ...
  ],
  "strengths": [
    {
      "feature": "Clean, modern UI",
      "mentions": 8,
      "preserve": true
    },
    ...
  ]
}
```

---

### Step 7.5: Persist Issues to Database

For each prioritized issue, insert into the database:

```sql
INSERT INTO issues (
    session_name, test_run_id, issue_id, title, description,
    category, severity, mentions, rice_score,
    journey_refs, persona_refs, status, created_at
) VALUES (
    '{SESSION_NAME}',
    '{TEST_RUN_ID}',
    '{issue.id}',
    '{issue.title}',
    '{issue.description}',
    '{issue.category}',  -- 'bug', 'ux', 'performance', 'feature_request'
    '{issue.severity}',  -- 'critical', 'high', 'medium', 'low'
    {issue.mentions},
    {issue.riceScore},
    '{journeys_json}',   -- ["J-001", "J-003"]
    '{personas_json}',   -- ["persona-01", "persona-02"]
    'open',
    NOW()
);
```

**Category mapping:**
- Bugs with severity critical/high → category='bug'
- UX frustrations → category='ux'
- Performance issues → category='performance'
- Feature requests → category='feature_request'

---

### Step 8: Present Summary

```
✅ Feedback analysis complete: {session-name}
✅ Persisted {count} issues to database (test_run: {TEST_RUN_ID})

Key Metrics:
| Metric | Value | Status |
|--------|-------|--------|
| Avg Rating | 3.6/5 | ⚠️ Below target (4.0) |
| NPS Score | 42 | ⚠️ Below target (50) |
| Recommend | 70% | ⚠️ Below target (80%) |

Issues Found:
- Critical Bugs: 2 (require immediate fix)
- High Priority: 5
- Medium Priority: 8
- Feature Requests: 12

Top 3 Issues to Address:
1. BUG-001: Mobile form validation (RICE: 120)
2. BUG-002: Slow dashboard load (RICE: 95)
3. UX-001: Too many clicks to submit (RICE: 80)

Output Files:
- Analysis: .claude/testing/feedback/{session-name}-analysis.md
- Issues: .claude/testing/feedback/{session-name}-issues.json

Next Steps:
1. Review analysis: cat {analysis-file}
2. Generate remediation PRDs: /pm:generate-remediation {session-name}
```

---

## Important Rules

1. **Quantitative + Qualitative** - Use both metrics and quotes
2. **RICE prioritization** - Score all issues consistently
3. **Pattern recognition** - Group similar issues together
4. **Actionable output** - Every issue should have a clear fix
5. **Preserve strengths** - Note what's working well
6. **Journey mapping** - Track issues back to specific journeys

---

## Sources

Based on research from:
- RICE prioritization framework (Intercom)
- NPS calculation methodology
- Feedback categorization best practices
