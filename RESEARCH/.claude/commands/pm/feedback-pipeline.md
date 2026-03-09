# Feedback Pipeline - Test-Driven Issue Resolution

Run automated test → feedback → research → fix cycle.

## Usage

```
/pm:feedback-pipeline <session-name>
```

Or via shell:
```bash
./interrogate.sh --feedback <session-name>
./.claude/scripts/feedback-pipeline.sh <session-name>
```

## Pipeline Steps

| Step | Action | DB Update |
|------|--------|-----------|
| 1 | Ensure feedback tables | Creates test_results, feedback, issues tables |
| 2 | test-journey (all personas) | → test_results |
| 3 | generate-feedback | → feedback |
| 4 | analyze-feedback | → issues (status='open') |
| 5 | /dr research (per issue) | issues.status='triaged' |
| 6 | fix-problem (per issue) | issues.status='resolved' or 'escalated' |

## Pipeline Flow

```
┌─────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  test-journey   │────▶│ generate-feedback│────▶│ analyze-feedback │
│  (all personas) │     │                  │     │                  │
└────────┬────────┘     └────────┬─────────┘     └────────┬─────────┘
         │                       │                        │
         ▼                       ▼                        ▼
   test_results            feedback table           issues table
      table                                        (status: open)
                                                         │
                                                         ▼
                                               ┌─────────────────┐
                                               │    /dr research │
                                               │  (per issue)    │
                                               └────────┬────────┘
                                                        │
                                                        ▼
                                               issues.status='triaged'
                                                        │
                                                        ▼
                                               ┌─────────────────┐
                                               │  fix-problem    │
                                               │  (per issue)    │
                                               └────────┬────────┘
                                                        │
                                                        ▼
                                               issues.status='resolved'
                                               (or 'escalated' if failed)
```

## Database Tables

The pipeline uses 3 tables (created by `create-feedback-schema.sh`):

### test_results
Stores journey test execution results:
- session_name, test_run_id
- journey_id, persona_id
- overall_status (pass/fail/partial)
- step_results, issues_found (JSONB)

### feedback
Stores synthetic persona feedback:
- session_name, test_run_id, persona_id
- overall_rating (1-5), nps_score (0-10)
- frustrations, bugs, feature_requests (JSONB)

### issues
Prioritized issues with fix tracking:
- session_name, test_run_id, issue_id
- title, description, category, severity
- rice_score, mentions
- research_context (from /dr)
- fix_attempts, resolved_at
- status: open → triaged → resolved/escalated

## Status Transitions

| Event | Status Change |
|-------|---------------|
| analyze-feedback creates issue | `open` |
| /dr completes research | `triaged` |
| fix-problem succeeds | `resolved` |
| fix-problem fails 3x | `escalated` |

## Prerequisites

- Session with user journeys (`.claude/scopes/<name>/02_user_journeys.md`)
- Personas file (auto-generated if missing)
- Application deployed (for actual testing)
- Database accessible

## Options

```bash
# Run full pipeline
./feedback-pipeline.sh <session-name>

# Resume from last step
./feedback-pipeline.sh <session-name> --resume

# Show pipeline status
./feedback-pipeline.sh <session-name> --status
```

## Output

```
========================================
Pipeline Complete
========================================

  Resolved:  5 issues
  Escalated: 1 issue

State: .claude/pipeline/<session>/feedback-state.yaml
```

## Output Files

| File | Description |
|------|-------------|
| `.claude/pipeline/<session>/feedback-state.yaml` | Pipeline state and stats |
| `.claude/pipeline/<session>/fix-issue-*.md` | Fix attempt logs per issue |

## Example

```bash
# After synthetic testing reveals issues
./interrogate.sh --feedback myapp

# Or as standalone
./.claude/scripts/feedback-pipeline.sh myapp

# Check status
./.claude/scripts/feedback-pipeline.sh myapp --status
```

## Integration with interrogate.sh

The feedback pipeline is step 15 in the full interrogate pipeline:

```bash
# Run as part of full pipeline (after remediation)
./interrogate.sh --feedback myapp

# Or integrated into build
# (Run after --synthetic and --remediation)
```

## Escalated Issues

Issues that fail to fix after 3 attempts are marked `escalated` and require manual intervention. Check the fix logs for details:

```bash
cat .claude/pipeline/myapp/fix-issue-I-001.md
```
