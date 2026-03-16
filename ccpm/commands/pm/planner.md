---
allowed-tools: Bash, Read, Write, LS, Grep, Task, AskUserQuestion, Skill
---

# Planner - Interactive Sprint Planning with INVEST Validation

Generate prioritized, INVEST-validated task checklists through structured interrogation. Tasks are persisted to the PostgreSQL `checklist` and `checklist_item` tables.

## Research Foundation

This skill implements findings from deep research on effective sprint planning:
- **5-Phase Progressive Disclosure** (Context → Elicit → Validate → Split → Prioritize)
- **W-Framework Questions** (Who/What/Why/When/Where/How)
- **INVEST Criteria Scoring** (1-5 Likert scale per criterion)
- **SPIDR Splitting Patterns** (Spike/Path/Interface/Data/Rules)
- **MoSCoW Prioritization** (Must/Should/Could/Won't)

## Usage
```
/pm:planner [session-name]
```

## Arguments
- `session-name` (optional): Name for this planning session. Defaults to timestamp.

## Output
- PostgreSQL `checklist` table - Session metadata
- PostgreSQL `checklist_item` table - Individual tasks with INVEST scores
- `.claude/planner/{session}/session.md` - Human-readable session record

---

## Instructions

### Step 1: Initialize Session

Get current datetime and set up session:

```bash
CURRENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SESSION_NAME="${ARGUMENTS:-sprint-$(date +%Y%m%d-%H%M%S)}"
SESSION_DIR=".claude/planner/$SESSION_NAME"
mkdir -p "$SESSION_DIR"
```

Create initial session.md:
```markdown
# Sprint Planning Session: {session-name}

Started: {CURRENT_DATE}
Phase: context

---

## Tasks Captured
{to be filled during session}
```

Create database record:
```bash
# Insert into PostgreSQL via kubectl
PGPASSWORD=planning123 kubectl exec -n planning postgresql-planning-0 -- \
  psql -U planning -d planning -c "
INSERT INTO checklist (session_name, title, phase)
VALUES ('$SESSION_NAME', 'Sprint: $SESSION_NAME', 'context')
ON CONFLICT (session_name) DO UPDATE SET updated_at = NOW();
"
```

---

## Phase 1: Context Gathering

### Purpose
Understand the team, sprint constraints, and stakeholder needs before capturing tasks.

### Questions

**Q1: Sprint Goal**
```
question: "What is the primary goal for this sprint?"
header: "Goal"
options:
  - label: "Ship a feature"
    description: "Deliver a complete user-facing feature"
  - label: "Fix critical bugs"
    description: "Address production issues"
  - label: "Technical debt"
    description: "Improve codebase quality"
  - label: "Research/discovery"
    description: "Investigate unknowns"
```

**Q2: Team Capacity**
```
question: "What's your team's capacity for this sprint?"
header: "Capacity"
options:
  - label: "1-2 developers"
    description: "Small team, focused work"
  - label: "3-5 developers"
    description: "Medium team, some parallelism"
  - label: "6+ developers"
    description: "Large team, significant parallelism"
  - label: "Just me"
    description: "Solo developer"
```

**Q3: Sprint Duration**
```
question: "How long is this sprint?"
header: "Duration"
options:
  - label: "1 week"
    description: "Short sprint, high focus"
  - label: "2 weeks"
    description: "Standard sprint"
  - label: "3-4 weeks"
    description: "Extended sprint"
  - label: "Continuous"
    description: "No fixed timeboxes"
```

**Q4: Known Constraints**
```
question: "Are there any known constraints or blockers?"
header: "Constraints"
multiSelect: true
options:
  - label: "External dependencies"
    description: "Waiting on other teams/services"
  - label: "Resource constraints"
    description: "Limited infrastructure/budget"
  - label: "Knowledge gaps"
    description: "Need to learn new tech"
  - label: "No constraints"
    description: "Clear path forward"
```

Record context to database:
```bash
PGPASSWORD=planning123 kubectl exec -n planning postgresql-planning-0 -- \
  psql -U planning -d planning -c "
UPDATE checklist SET
  team_context = '{\"capacity\": \"$CAPACITY\", \"duration\": \"$DURATION\"}',
  sprint_context = '{\"goal\": \"$GOAL\", \"constraints\": $CONSTRAINTS}',
  phase = 'elicitation',
  updated_at = NOW()
WHERE session_name = '$SESSION_NAME';
"
```

---

## Phase 2: Task Elicitation

### Purpose
Extract tasks using W-Framework questions. Ask about each task the user mentions.

### Questions for Each Task

**Q1: What is the task?**
```
question: "Describe the task you want to add to the checklist."
header: "Task"
options:
  - label: "I'll describe it"
    description: "Free-form task description"
  - label: "It's a user story"
    description: "As a X, I want Y, so that Z"
  - label: "It's a bug fix"
    description: "Something broken that needs fixing"
  - label: "It's a spike"
    description: "Research/investigation needed"
```

After getting the description, probe with W-Framework:

**Who is affected?**
- Who will use this feature?
- Who requested it?
- Who needs to approve it?

**What is the outcome?**
- What does "done" look like?
- What will be different after this is complete?

**Why is this important?**
- Why now, not later?
- What happens if we don't do this?

**When is this needed?**
- Is there a deadline?
- Are there dependencies on timing?

**Where does this apply?**
- Which part of the system?
- Which users/environments?

**How will we verify?**
- How will we know it works?
- What tests should pass?

### Capture Task

After gathering W-Framework answers, insert into database:

```bash
# Get next item number
ITEM_NUM=$(PGPASSWORD=planning123 kubectl exec -n planning postgresql-planning-0 -- \
  psql -U planning -d planning -t -c "
SELECT COALESCE(MAX(item_number), 0) + 1
FROM checklist_item ci
JOIN checklist c ON ci.checklist_id = c.id
WHERE c.session_name = '$SESSION_NAME';
")

# Insert item
PGPASSWORD=planning123 kubectl exec -n planning postgresql-planning-0 -- \
  psql -U planning -d planning -c "
INSERT INTO checklist_item (
  checklist_id,
  item_number,
  title,
  description,
  who_affected,
  what_outcome,
  why_important,
  when_needed,
  where_applies,
  how_verified
)
SELECT
  id,
  $ITEM_NUM,
  '$TITLE',
  '$DESCRIPTION',
  '$WHO',
  '$WHAT',
  '$WHY',
  '$WHEN',
  '$WHERE',
  '$HOW'
FROM checklist WHERE session_name = '$SESSION_NAME';
"
```

### Continue Adding

```
question: "Do you have more tasks to add?"
header: "More"
options:
  - label: "Yes, add another"
    description: "Continue adding tasks"
  - label: "No, validate tasks"
    description: "Move to INVEST validation"
```

---

## Phase 3: INVEST Validation

### Purpose
Score each task against INVEST criteria. Items scoring < 3 on any criterion need improvement.

### INVEST Criteria (Score 1-5 for each)

For each task, evaluate:

**I - Independent (Can it be done without other tasks?)**
- 1: Heavily dependent on multiple other tasks
- 3: Some dependencies, but manageable
- 5: Completely standalone

**N - Negotiable (Can scope be adjusted?)**
- 1: Rigid requirements, no flexibility
- 3: Some room for negotiation
- 5: Fully negotiable implementation

**V - Valuable (Does it deliver user/business value?)**
- 1: Technical only, no direct value
- 3: Indirect value, enables other work
- 5: Direct, measurable value to users

**E - Estimable (Can we estimate the effort?)**
- 1: Too many unknowns
- 3: Rough estimate possible
- 5: Clear scope, confident estimate

**S - Small (Fits in one sprint?)**
- 1: Multi-sprint epic
- 3: Full sprint, risky
- 5: Days or less

**T - Testable (Clear pass/fail criteria?)**
- 1: No clear way to verify
- 3: Some criteria defined
- 5: Explicit acceptance tests

### Present for User Validation

For each task, present INVEST assessment:

```
Task: "{title}"

INVEST Assessment:
- Independent: {score}/5 - {rationale}
- Negotiable:  {score}/5 - {rationale}
- Valuable:    {score}/5 - {rationale}
- Estimable:   {score}/5 - {rationale}
- Small:       {score}/5 - {rationale}
- Testable:    {score}/5 - {rationale}

Total: {sum}/30 | Status: {PASS if all >= 3, else NEEDS WORK}
```

```
question: "Is this assessment accurate?"
header: "Confirm"
options:
  - label: "Yes, accurate"
    description: "Accept the INVEST scores"
  - label: "Adjust scores"
    description: "I'll provide corrections"
  - label: "Split this task"
    description: "It's too big, needs splitting"
  - label: "Remove task"
    description: "Don't include in this sprint"
```

### Update Database

```bash
PGPASSWORD=planning123 kubectl exec -n planning postgresql-planning-0 -- \
  psql -U planning -d planning -c "
UPDATE checklist_item SET
  invest_independent = $I_SCORE,
  invest_negotiable = $N_SCORE,
  invest_valuable = $V_SCORE,
  invest_estimable = $E_SCORE,
  invest_small = $S_SCORE,
  invest_testable = $T_SCORE,
  invest_issues = '$ISSUES_JSON',
  updated_at = NOW()
WHERE id = $ITEM_ID;
"
```

---

## Phase 4: SPIDR Splitting

### Purpose
Split tasks that fail INVEST validation using SPIDR patterns.

### When to Split

Split when:
- **S**mall score < 3 → Task too big
- **E**stimable score < 3 → Too many unknowns (create spike)
- Multiple user paths → Split by path
- Multiple interfaces → Split by interface

### SPIDR Split Patterns

**Spike (Technical Uncertainty)**
- Original: "Implement payment processing"
- Split: "Spike: Research payment gateway options (2h timebox)"
- Reason: Unknown technology, need investigation first

**Path (Different User Flows)**
- Original: "User can checkout"
- Split: "Guest checkout flow" + "Logged-in user checkout flow"
- Reason: Different paths for different users

**Interface (Different UIs/APIs)**
- Original: "Add search feature"
- Split: "Search API endpoint" + "Search UI component"
- Reason: Can be developed independently

**Data (CRUD Operations)**
- Original: "Manage user profiles"
- Split: "Create profile" + "Read profile" + "Update profile" + "Delete profile"
- Reason: Each operation is independently valuable

**Rules (Business Logic)**
- Original: "Calculate shipping costs"
- Split: "Domestic shipping calc" + "International shipping calc" + "Free shipping threshold"
- Reason: Different business rules

### Present Split Options

```
question: "How should we split '{task_title}'?"
header: "Split"
options:
  - label: "Create spike first"
    description: "Need research before implementation"
  - label: "Split by user path"
    description: "Different flows for different users"
  - label: "Split by interface"
    description: "API vs UI vs mobile"
  - label: "Split by data operation"
    description: "Create/Read/Update/Delete"
```

### Create Child Tasks

```bash
# Insert split child
PGPASSWORD=planning123 kubectl exec -n planning postgresql-planning-0 -- \
  psql -U planning -d planning -c "
INSERT INTO checklist_item (
  checklist_id,
  item_number,
  title,
  description,
  parent_item_id,
  spidr_type,
  split_reason,
  source
)
SELECT
  checklist_id,
  (SELECT MAX(item_number) + 1 FROM checklist_item WHERE checklist_id = ci.checklist_id),
  '$CHILD_TITLE',
  '$CHILD_DESC',
  $PARENT_ID,
  '$SPIDR_TYPE',
  '$SPLIT_REASON',
  'split'
FROM checklist_item ci WHERE id = $PARENT_ID;
"
```

---

## Phase 5: MoSCoW Prioritization

### Purpose
Prioritize all validated tasks using MoSCoW framework.

### MoSCoW Categories

**Must Have** - Critical for sprint success
- Sprint fails without these
- Non-negotiable requirements
- Committed deliverables

**Should Have** - Important but not critical
- High value, low risk
- Included if time permits
- Can slip without sprint failure

**Could Have** - Nice to have
- Enhance the deliverable
- First to be dropped if needed
- Low impact if excluded

**Won't Have** - Explicitly excluded
- Out of scope for this sprint
- Documented for future reference
- Prevents scope creep

### Present for Prioritization

```
## Tasks to Prioritize

1. {task_1} - INVEST: {score}/30
2. {task_2} - INVEST: {score}/30
3. {task_3} - INVEST: {score}/30
...

Based on your sprint goal "{goal}" and capacity "{capacity}":
```

```
question: "Prioritize '{task_title}' for this sprint"
header: "Priority"
options:
  - label: "Must Have"
    description: "Sprint fails without this"
  - label: "Should Have"
    description: "Important, include if possible"
  - label: "Could Have"
    description: "Nice to have, can drop"
  - label: "Won't Have"
    description: "Explicitly out of scope"
```

### Update Database

```bash
PGPASSWORD=planning123 kubectl exec -n planning postgresql-planning-0 -- \
  psql -U planning -d planning -c "
UPDATE checklist_item SET
  priority = '$PRIORITY',
  priority_rationale = '$RATIONALE',
  story_points = $POINTS,
  updated_at = NOW()
WHERE id = $ITEM_ID;
"
```

---

## Phase 6: Generate Summary

### Update Session Status

```bash
PGPASSWORD=planning123 kubectl exec -n planning postgresql-planning-0 -- \
  psql -U planning -d planning -c "
UPDATE checklist SET
  phase = 'complete',
  completed_at = NOW(),
  updated_at = NOW()
WHERE session_name = '$SESSION_NAME';
"
```

### Query Final Checklist

```bash
PGPASSWORD=planning123 kubectl exec -n planning postgresql-planning-0 -- \
  psql -U planning -d planning -c "
SELECT
  ci.item_number,
  ci.title,
  ci.priority,
  ci.invest_total,
  ci.invest_passed,
  ci.story_points,
  ci.status
FROM checklist_item ci
JOIN checklist c ON ci.checklist_id = c.id
WHERE c.session_name = '$SESSION_NAME'
ORDER BY
  CASE ci.priority
    WHEN 'must' THEN 1
    WHEN 'should' THEN 2
    WHEN 'could' THEN 3
    WHEN 'wont' THEN 4
  END,
  ci.item_number;
"
```

### Generate Summary Report

Write to session.md:

```markdown
# Sprint Planning Complete: {session_name}

## Sprint Goal
{goal from context}

## Team Capacity
{capacity from context}

## Prioritized Checklist

### Must Have ({count} items, {points} points)
- [ ] {item_1} - {points}pts
- [ ] {item_2} - {points}pts

### Should Have ({count} items, {points} points)
- [ ] {item_3} - {points}pts

### Could Have ({count} items, {points} points)
- [ ] {item_4} - {points}pts

### Won't Have (Deferred)
- {item_5} - Reason: {rationale}

## Metrics
- Total Tasks: {total}
- INVEST Pass Rate: {pass_rate}%
- Total Story Points: {points}
- Spikes Needed: {spike_count}

## Next Steps
1. Review checklist with team
2. Address any spikes first
3. Begin "Must Have" items
4. Track progress daily
```

---

## Phase 7: Task Execution (Hybrid Integration)

### Purpose
When a checklist item is marked complete (especially a spike), automatically trigger the appropriate next action using a hybrid approach:
- **Spike completion** → Interactive `/pm:feature` via Skill (user can provide input on architecture)
- **User confirms plan** → Autonomous implementation via Task (runs without interruption)

### Trigger Detection

After any checklist item status changes to `completed`:

```bash
# Check if completed item is a spike with a parent feature
PGPASSWORD=planning123 kubectl exec -n planning postgresql-planning-0 -- \
  psql -U planning -d planning -t -c "
SELECT
  ci.id,
  ci.title,
  ci.is_spike,
  ci.parent_item_id,
  parent.title as parent_title,
  parent.description as parent_description
FROM checklist_item ci
LEFT JOIN checklist_item parent ON ci.parent_item_id = parent.id
WHERE ci.id = $COMPLETED_ITEM_ID
  AND ci.status = 'completed';
"
```

### Decision Logic

```
IF completed_item.is_spike AND completed_item.parent_item_id IS NOT NULL:
    # Spike completed - trigger interactive feature planning
    → Phase 7A: Interactive Feature Planning (Skill)

ELIF completed_item has INVEST score >= 24 AND priority = 'must':
    # High-quality, high-priority item ready for implementation
    → Phase 7B: Ask user about execution mode

ELSE:
    # Regular task completion - just update status
    → Continue to Output Summary
```

### Phase 7A: Interactive Feature Planning (Spike → Feature)

When a spike completes, invoke `/pm:feature` interactively so the user can participate in architecture decisions:

```
question: "Spike '{spike_title}' is complete. Ready to plan the implementation of '{parent_title}'?"
header: "Start Feature"
options:
  - label: "Yes, start planning"
    description: "Launch /pm:feature interactively"
  - label: "Not yet"
    description: "I need to review the spike findings first"
  - label: "Skip feature"
    description: "Don't auto-trigger, I'll handle manually"
```

**If user confirms "Yes, start planning":**

1. **Extract full context from database:**
```bash
# Use the context extraction script to pull all W-Framework data
PARENT_ITEM_ID={parent_item_id from spike}
FEATURE_INPUT=".claude/planner/$SESSION_NAME/feature-context-${PARENT_ITEM_ID}.md"

# Extract context from checklist tables
.claude/scripts/extract-checklist-context.sh "$PARENT_ITEM_ID" "$FEATURE_INPUT"
```

This script extracts:
- Full W-Framework answers (who/what/why/when/where/how)
- INVEST scores and priority
- Sprint context (goal, capacity, constraints)
- Parent feature requirements
- Sibling tasks for context
- Pre-answered questions table for feature to skip

2. **Invoke feature skill interactively:**
```
Skill: pm:feature
args: "$FEATURE_INPUT"
```

This runs in the main conversation, allowing user to:
- Answer Phase 0 clarifying questions
- Confirm flow diagrams
- Adjust scope before autonomous execution begins

3. **Link checklist item to feature session:**
```bash
PGPASSWORD=planning123 kubectl exec -n planning postgresql-planning-0 -- \
  psql -U planning -d planning -c "
UPDATE checklist_item SET
  notes = COALESCE(notes, '') || E'\n\n[Feature Session: $FEATURE_SESSION_NAME]',
  status = 'in_progress',
  updated_at = NOW()
WHERE id = $PARENT_ITEM_ID;
"
```

### Phase 7B: Direct Implementation (Non-Spike Tasks)

For high-quality tasks ready for implementation:

```
question: "Task '{title}' is validated and prioritized. How should we proceed?"
header: "Execute"
options:
  - label: "Interactive (Recommended)"
    description: "Run /pm:feature with user interaction"
  - label: "Autonomous"
    description: "Run implementation as background Task"
  - label: "Manual"
    description: "I'll implement this myself"
```

**If "Interactive":**
```
Skill: pm:feature
args: "{task description from checklist_item}"
```

**If "Autonomous":**
```yaml
Task:
  subagent_type: "general-purpose"
  description: "Implement {task_title}"
  prompt: |
    Execute /pm:feature for this task autonomously:

    Task: {title}
    Description: {description}
    Acceptance Criteria: {how_verified}

    Run through all phases without stopping.
    Report back when complete or if escalation needed.
```

### Phase 7C: Update Parent on Child Completion

When implementation completes (either path), update the parent checklist item:

```bash
PGPASSWORD=planning123 kubectl exec -n planning postgresql-planning-0 -- \
  psql -U planning -d planning -c "
UPDATE checklist_item SET
  status = 'completed',
  completed_at = NOW(),
  updated_at = NOW()
WHERE id = $PARENT_ITEM_ID;

-- Also update session metrics
UPDATE checklist SET
  completed_items = (
    SELECT COUNT(*) FROM checklist_item
    WHERE checklist_id = checklist.id AND status = 'completed'
  ),
  updated_at = NOW()
WHERE session_name = '$SESSION_NAME';
"
```

### Execution Flow Summary

```
Checklist Item Completed
         │
         ▼
    Is it a spike?
    ┌────┴────┐
   Yes        No
    │          │
    ▼          ▼
Has parent?   INVEST >= 24?
    │          │
   Yes        Yes → Ask execution mode
    │          │
    ▼          ▼
Ask: Start   Interactive → Skill: pm:feature
feature?     Autonomous → Task: pm:feature
    │        Manual → Skip
   Yes
    │
    ▼
Skill: pm:feature (interactive)
    │
    ▼
User participates in Phase 0
    │
    ▼
User confirms flow diagrams
    │
    ▼
Autonomous execution begins
    │
    ▼
Update parent item status
```

---

## Output Summary

Present final output to user:

```
✅ Sprint planning complete: {session_name}

Checklist saved to:
- PostgreSQL: checklist + checklist_item tables
- File: .claude/planner/{session}/session.md

Summary:
- Must Have: {count} tasks ({points} pts)
- Should Have: {count} tasks ({points} pts)
- Could Have: {count} tasks ({points} pts)
- INVEST Pass Rate: {rate}%

Next: Review with team or run `/pm:planner --view {session_name}`
```

---

## Utility Commands

### View Existing Session
```bash
/pm:planner --view {session-name}
```

Query and display existing checklist from database.

### Export to Markdown
```bash
/pm:planner --export {session-name}
```

Generate markdown checklist file for external use.

### List Sessions
```bash
/pm:planner --list
```

Show all planning sessions from database:
```bash
PGPASSWORD=planning123 kubectl exec -n planning postgresql-planning-0 -- \
  psql -U planning -d planning -c "
SELECT session_name, title, phase, total_items, invest_pass_rate, created_at
FROM checklist
ORDER BY created_at DESC
LIMIT 10;
"
```

---

## Error Handling

### Database Connection Failed
```
❌ Cannot connect to PostgreSQL
Fix: Ensure kubectl access to planning namespace
```

### Session Already Exists
```
⚠️ Session '{name}' exists. Resume or create new?
```

### No Tasks Added
```
❌ No tasks to validate. Add at least one task.
```

---

## Integration with Other Skills

### Automatic Integrations (Phase 7)

- `/pm:feature` - **Automatically triggered** when:
  - A spike completes → Interactive mode (user participates in architecture decisions)
  - High-priority task ready → User chooses interactive or autonomous mode

### Manual Integrations

- `/pm:interrogate` - Full feature interrogation (pre-planning)
- `/pm:epic-decompose` - Break features into epics
- `/pm:issue-start` - Start work on a checklist item
- `/pm:troubleshoot` - Diagnose blocked items

### Integration Data Flow

```
checklist_item.is_spike = true
         │
         ▼ (on completion)
checklist_item.parent_item_id → parent task
         │
         ▼
/pm:feature (interactive via Skill)
         │
         ▼ (after user confirms plan)
/pm:feature Phase 4+ (autonomous via Task)
         │
         ▼
checklist_item.status = 'completed'
checklist_item.notes += "[Feature Session: {name}]"
```

### Database Links

The `checklist_item` table links to feature sessions via:
- `notes` field contains `[Feature Session: {session_name}]`
- Future: Add `feature_session` column for direct foreign key
