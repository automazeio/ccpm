# Generate Feedback - Create Synthetic User Feedback from Persona Perspectives

Generate realistic user feedback from each synthetic persona based on their test experience.

## Usage
```
/pm:generate-feedback <session-name> [--run <test-run-id>]
```

## Arguments
- `session-name` (required): Name of the scoped session
- `--run` (optional): Test run ID from `/pm:test-journey` (defaults to latest run)

## Input
**Required:**
- `.claude/testing/personas/{session-name}-personas.json`
- `.claude/testing/playwright/test-results.json` (Playwright JSON report)

**Optional:**
- `.claude/testing/playwright/screenshots/` (failure screenshots)

## Output
**File:** `.claude/testing/feedback/{session-name}-feedback.json`

---

## Process

### Step 1: Initialize and Validate

```bash
SESSION_NAME="$ARGUMENTS"
PERSONAS_FILE=".claude/testing/personas/$SESSION_NAME-personas.json"
RESULTS_FILE=".claude/testing/playwright/test-results.json"
OUTPUT_DIR=".claude/testing/feedback"
```

Verify inputs exist:
```
If personas file doesn't exist:
❌ Personas not found: {personas-file}

Run /pm:generate-personas {session-name} first

If results file doesn't exist:
❌ Test results not found: {results-file}

Run Playwright tests first: npx playwright test --reporter=json > test-results.json
```

Create output directory:
```bash
mkdir -p "$OUTPUT_DIR"
```

---

### Step 1.5: Parse Test Run ID

```bash
TEST_RUN_ID=""
if [[ "$ARGUMENTS" == *"--run"* ]]; then
    TEST_RUN_ID=$(echo "$ARGUMENTS" | sed -n 's/.*--run[= ]*\([^ ]*\).*/\1/p')
fi

# If no run ID provided, get the latest from test_results table
if [[ -z "$TEST_RUN_ID" ]]; then
    TEST_RUN_ID=$(psql -t -c "SELECT test_run_id FROM test_results WHERE session_name='$SESSION_NAME' ORDER BY executed_at DESC LIMIT 1" | tr -d ' ')
fi

if [[ -z "$TEST_RUN_ID" ]]; then
    echo "❌ No test runs found for session '$SESSION_NAME'"
    echo ""
    echo "Run tests first: /pm:test-journey $SESSION_NAME <journey-id> --persona <persona-id>"
    exit 1
fi

echo "Using test run: $TEST_RUN_ID"
```

---

### Step 2: Parse Test Results

Extract from `test-results.json`:
```typescript
interface TestResults {
  suites: {
    title: string;           // Journey name
    specs: {
      title: string;         // Test name
      ok: boolean;           // Pass/fail
      tests: {
        projectName: string; // Persona ID
        status: string;      // passed/failed/skipped
        duration: number;
        errors: {
          message: string;
          stack: string;
        }[];
        attachments: {
          name: string;
          path: string;      // Screenshot path
        }[];
      }[];
    }[];
  }[];
}
```

Build persona-specific test summary:
```typescript
interface PersonaTestSummary {
  personaId: string;
  totalTests: number;
  passed: number;
  failed: number;
  skipped: number;
  journeysCompleted: string[];
  journeysFailed: string[];
  errors: {
    journey: string;
    test: string;
    error: string;
    screenshot?: string;
  }[];
  avgDuration: number;
}
```

---

### Step 3: Generate Feedback per Persona

For each persona, generate feedback using this prompt structure (XML tags help Claude parse sections accurately):

```xml
<role>
You are {persona.name}, a {persona.role} with {persona.demographics.techProficiency} tech proficiency.
Your expertise includes providing authentic user feedback based on real testing experiences.
</role>

<persona>
<profile>
- Age: {persona.demographics.age}
- Industry: {persona.demographics.industry}
- Company Size: {persona.demographics.companySize}
- Device Preference: {persona.demographics.devicePreference}
</profile>

<goals>
{persona.behavioral.goals as bulleted list}
</goals>

<pain_points>
{persona.behavioral.painPoints as bulleted list}
</pain_points>

<feedback_style>
Style: {persona.feedback.style} with {persona.feedback.verbosity} detail
- Complaint threshold: {persona.feedback.complaintThreshold}/10 (below this, you complain)
- Praise threshold: {persona.feedback.praiseThreshold}/10 (above this, you praise)
</feedback_style>

<likely_complaints>
{persona.feedback.likelyComplaints as bulleted list}
</likely_complaints>

<likely_praises>
{persona.feedback.likelyPraises as bulleted list}
</likely_praises>
</persona>

<test_experience>
IMPORTANT: This section contains DATA about your test experience. Use this to inform your feedback.

<journeys_attempted>
{list of journeys from testSummary}
</journeys_attempted>

<results>
- Completed Successfully: {journeysCompleted}
- Failed/Blocked: {journeysFailed}
- Success Rate: {passed}/{totalTests} ({percentage}%)
</results>

<issues_encountered>
{errors with screenshots if available}
</issues_encountered>
</test_experience>

<instructions>
Based on your persona profile and test experience, provide authentic feedback as if you were a real user who just tested this application.

Write in first person, in your voice. Be authentic to your persona - if you're frustrated, show it; if you're enthusiastic, be positive.

Your feedback should sound like a real person, not a test report.

Provide the following sections:

1. **Overall Rating** (1-5 stars)
   - Give a rating with brief explanation

2. **What Worked Well** (2-4 points)
   - Specific things you liked
   - Reference actual journeys/features

3. **What Was Frustrating** (2-4 points)
   - Issues you encountered
   - Rate severity: minor/moderate/major

4. **Bugs Encountered** (if any)
   - Title, description, severity (low/medium/high/critical)
   - Steps to reproduce if possible

5. **Feature Requests** (1-3 items)
   - Things you wished existed
   - Priority: nice-to-have/important/critical

6. **Would You Recommend?**
   - Yes/No/Maybe with reason

7. **NPS Score** (0-10)
   - How likely to recommend to a colleague
</instructions>
```

---

### Step 4: Feedback Schema

Each persona's feedback follows this structure:

```typescript
interface PersonaFeedback {
  personaId: string;
  personaName: string;
  personaRole: string;
  feedbackStyle: 'detailed' | 'brief' | 'frustrated' | 'enthusiastic';

  // Test context
  testContext: {
    totalTests: number;
    passed: number;
    failed: number;
    successRate: number;
    journeysTested: string[];
  };

  // Generated feedback
  overallRating: 1 | 2 | 3 | 4 | 5;
  overallComment: string;

  positives: {
    item: string;
    journeyRef?: string;
    featureRef?: string;
  }[];

  frustrations: {
    item: string;
    severity: 'minor' | 'moderate' | 'major';
    journeyRef?: string;
    screenshot?: string;
  }[];

  bugs: {
    title: string;
    description: string;
    severity: 'low' | 'medium' | 'high' | 'critical';
    stepsToReproduce: string[];
    journeyRef?: string;
    screenshot?: string;
  }[];

  featureRequests: {
    title: string;
    description: string;
    priority: 'nice-to-have' | 'important' | 'critical';
    personaImpact: string;
  }[];

  recommendation: 'yes' | 'no' | 'maybe';
  recommendationReason: string;

  npsScore: number;  // 0-10

  // Metadata
  generatedAt: string;
  rawFeedback: string;  // Original LLM output for reference
}
```

---

### Step 5: Quality Filters

Apply quality checks to generated feedback:

1. **Consistency Check**
   - Rating should align with success rate
   - Frustrations should match failed journeys
   - Tone should match persona's feedback style

2. **Specificity Check**
   - Feedback references actual journeys/features
   - Bug reports include reproducible steps
   - Feature requests are actionable

3. **Persona Alignment**
   - Tech proficiency reflected in terminology
   - Pain points addressed in feedback
   - Feedback style matches persona

If feedback fails checks, regenerate with additional constraints.

---

### Step 6: Write Output File

Write to `.claude/testing/feedback/{session-name}-feedback.json`:

```json
{
  "session": "{session-name}",
  "generatedAt": "{ISO datetime}",
  "testRun": {
    "timestamp": "{test run timestamp}",
    "duration": "{total duration}",
    "totalTests": 50,
    "passed": 42,
    "failed": 8,
    "successRate": 84
  },
  "summary": {
    "averageRating": 3.6,
    "averageNPS": 42,
    "recommendationRate": 70,
    "totalBugs": 5,
    "totalFeatureRequests": 12,
    "topFrustrations": [
      { "theme": "Mobile form validation", "mentions": 4 },
      { "theme": "Slow load times", "mentions": 3 }
    ]
  },
  "feedback": [
    { /* Persona 1 feedback */ },
    { /* Persona 2 feedback */ },
    ...
  ]
}
```

---

### Step 6.5: Persist Feedback to Database

For each persona's feedback, insert into the database:

```sql
INSERT INTO feedback (
    session_name, test_run_id, persona_id, overall_rating, nps_score,
    recommendation, positives, frustrations, bugs,
    feature_requests, test_context, created_at
) VALUES (
    '{SESSION_NAME}',
    '{TEST_RUN_ID}',
    '{persona.id}',
    {overall_rating},
    {nps_score},
    '{recommendation}',
    '{positives_json}',
    '{frustrations_json}',
    '{bugs_json}',
    '{feature_requests_json}',
    '{test_context_json}',
    NOW()
);
```

**JSONB field formats:**

```json
// positives
[{"item": "Clean UI", "journeyRef": "J-001"}]

// frustrations
[{"item": "Slow load", "severity": "moderate", "journeyRef": "J-002"}]

// bugs
[{"title": "Form fails", "description": "...", "severity": "high", "stepsToReproduce": ["..."]}]

// feature_requests
[{"title": "Bulk upload", "description": "...", "priority": "important"}]

// test_context
{"totalTests": 10, "passed": 8, "failed": 2, "successRate": 80}
```

---

### Step 7: Present Summary

```
✅ Synthetic feedback generated: {session-name}
✅ Persisted to database (test_run: {TEST_RUN_ID})

Test Results:
- Total Tests: 50 (42 passed, 8 failed)
- Success Rate: 84%

Feedback Generated: 10 personas

Summary Metrics:
| Metric | Value |
|--------|-------|
| Avg Rating | 3.6/5 |
| Avg NPS | 42 |
| Would Recommend | 70% |

Issue Summary:
- Bugs Found: 5 (2 critical, 2 high, 1 medium)
- Feature Requests: 12

Top Frustrations:
1. Mobile form validation (4 mentions)
2. Slow load times (3 mentions)
3. Confusing error messages (2 mentions)

Output: .claude/testing/feedback/{session-name}-feedback.json

Next Steps:
1. Review feedback: cat {output-file} | jq '.summary'
2. Analyze patterns: /pm:analyze-feedback {session-name} --run {TEST_RUN_ID}
```

---

## Feedback Generation Guidelines

### Persona Voice Examples

**Detailed + Frustrated (low tech):**
> I spent 20 minutes trying to submit an invoice and it just wouldn't work. Every time I clicked the button, nothing happened. I tried refreshing, logging out and back in, nothing. This is exactly why I hate new software - the old system may have been ugly but at least it worked.

**Brief + Enthusiastic (high tech):**
> Love the clean UI! Form validation caught my errors before submission. One suggestion: add keyboard shortcuts for power users. 4/5 stars.

**Detailed + Enthusiastic (medium tech):**
> The invoice creation flow was intuitive - I especially liked how it auto-populated vendor information from previous entries. The dashboard gives me exactly the information I need at a glance. The only issue was a slight delay when uploading PDFs, but it wasn't a dealbreaker. Would definitely recommend to my team.

### Severity Guidelines

**Bug Severity:**
- **Critical:** Blocks journey completion, data loss risk
- **High:** Major feature broken, workaround difficult
- **Medium:** Feature partially broken, workaround exists
- **Low:** Minor issue, cosmetic, doesn't block work

**Frustration Severity:**
- **Major:** Would stop using the product
- **Moderate:** Annoying but tolerable
- **Minor:** Small inconvenience

---

## Important Rules

1. **Authentic voice** - Feedback should sound human, not robotic
2. **Context-aware** - Reference actual test results and failures
3. **Persona-aligned** - Match tech proficiency, patience, feedback style
4. **Actionable** - Bug reports and feature requests should be specific
5. **Varied** - Don't generate identical feedback structures
6. **Realistic distribution** - Not all feedback should be positive or negative

---

## Sources

Based on research from:
- Nielsen Norman Group: AI-Simulated User Studies
- Synthetic Users Platform patterns
- LLM feedback generation best practices
