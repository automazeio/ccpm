# Scope Status - Show Session State

Display current status of a scope session or list all scopes.

## Usage
```
/pm:scope-status [scope-name]
```

## Arguments
- `scope-name` (optional): Name of scope to check. If omitted, lists all scopes.

## Instructions

### If No Scope Name Provided

List all scope sessions:

```bash
echo "=== Active Scopes ==="
echo ""

if [ -d ".claude/scopes" ]; then
  for session in .claude/scopes/*/session.yaml; do
    if [ -f "$session" ]; then
      dir=$(dirname "$session")
      name=$(basename "$dir")
      phase=$(grep "^phase:" "$session" | cut -d: -f2 | tr -d ' ')
      updated=$(grep "^updated:" "$session" | cut -d: -f2- | tr -d ' ')

      # Count completed sections
      sections_done=0
      for section in company_background stakeholders timeline_budget problem_definition \
                     business_goals project_scope technical_environment users_audience \
                     user_types competitive_landscape risks_assumptions data_reporting; do
        [ -f "$dir/sections/${section}.md" ] && sections_done=$((sections_done + 1))
      done

      echo "$name"
      echo "  Phase: $phase"
      echo "  Discovery: $sections_done/12 sections"
      echo "  Updated: $updated"
      echo ""
    fi
  done
else
  echo "No scopes found."
  echo ""
  echo "Create one with:"
  echo "  .claude/scripts/prd-scope.sh <scope-name>"
fi
```

### If Scope Name Provided

Show detailed status:

```bash
SESSION_DIR=".claude/scopes/$ARGUMENTS"
SESSION_FILE="$SESSION_DIR/session.yaml"
SECTIONS_DIR="$SESSION_DIR/sections"

if [ ! -d "$SESSION_DIR" ]; then
  echo "Scope not found: $ARGUMENTS"
  echo ""
  echo "Available scopes:"
  ls .claude/scopes/ 2>/dev/null || echo "  (none)"
  exit 1
fi
```

**Read session.yaml** and display:

```
=== Scope: {scope-name} ===

Phase: {current phase}
Created: {datetime}
Updated: {datetime}

--- Discovery Sections ---

[x] Company Background
[x] Stakeholders
[x] Timeline & Budget
[x] Problem Definition
[ ] Business Goals         <- next
[ ] Project Scope
[ ] Technical Environment
[ ] Users & Audience
[ ] User Types
[ ] Competitive Landscape
[ ] Risks & Assumptions
[ ] Data & Reporting

Progress: {done}/12 sections

--- Phase Progress ---

Discovery:
  Status: {complete|in-progress|not started}
  Sections: {done}/12
  Unknowns: {count of UNKNOWN items in discovery.md}
  File: {discovery.md exists|missing}

Research (Optional):
  Status: {complete|available|not needed}
  Gaps Found: {count}
  Gaps Resolved: {count}
  File: {research.md exists|missing}

Decomposition:
  Status: {complete|in-progress|not started}
  PRDs Proposed: {count}
  File: {exists|missing}

Generation:
  Total PRDs: {count}
  Generated: {count}
  Remaining: {count}
  Files: {list}

Verification:
  Status: {complete|not run}
  Gaps Found: {count|n/a}
  File: {exists|missing}

--- Files ---

{list all files in session directory with sizes}

--- Next Action ---

{Based on current phase, suggest next command}
```

### Section Status Display

For discovery sections, show checkbox status:

```bash
SECTIONS="company_background stakeholders timeline_budget problem_definition \
          business_goals project_scope technical_environment users_audience \
          user_types competitive_landscape risks_assumptions data_reporting"

declare -A SECTION_NAMES
SECTION_NAMES[company_background]="Company Background"
SECTION_NAMES[stakeholders]="Stakeholders"
SECTION_NAMES[timeline_budget]="Timeline & Budget"
SECTION_NAMES[problem_definition]="Problem Definition"
SECTION_NAMES[business_goals]="Business Goals"
SECTION_NAMES[project_scope]="Project Scope"
SECTION_NAMES[technical_environment]="Technical Environment"
SECTION_NAMES[users_audience]="Users & Audience"
SECTION_NAMES[user_types]="User Types"
SECTION_NAMES[competitive_landscape]="Competitive Landscape"
SECTION_NAMES[risks_assumptions]="Risks & Assumptions"
SECTION_NAMES[data_reporting]="Data & Reporting"

echo "Discovery Sections:"
next_section=""
for section in $SECTIONS; do
  name="${SECTION_NAMES[$section]}"
  if [ -f "$SECTIONS_DIR/${section}.md" ]; then
    echo "  [x] $name"
  else
    if [ -z "$next_section" ]; then
      echo "  [ ] $name  <- next"
      next_section="$section"
    else
      echo "  [ ] $name"
    fi
  fi
done
```

### Phase-Specific Next Actions

**discovery (sections incomplete):**
```
Next: Continue discovery session
  .claude/scripts/prd-scope.sh {scope-name} --discover

Or complete specific section:
  /pm:scope-discover-section {scope-name} {next-section}
```

**discovery (all sections complete, no discovery.md):**
```
Next: Merge discovery sections
  /pm:scope-discover {scope-name}
```

**discovery complete with UNKNOWNs:**
```
{count} items still marked UNKNOWN.

Option 1: Research remaining unknowns
  .claude/scripts/prd-scope.sh {scope-name} --research

Option 2: Continue to decomposition (unknowns will be flagged)
  .claude/scripts/prd-scope.sh {scope-name} --decompose
```

**decomposition:**
```
Next: Review and approve decomposition
  cat .claude/scopes/{scope-name}/decomposition.md

Then generate PRDs:
  .claude/scripts/prd-scope.sh {scope-name} --generate
```

**generation:**
```
Next: Continue generating PRDs
  .claude/scripts/prd-scope.sh {scope-name} --generate

Generated so far:
  {list of PRD files}
```

**verification:**
```
Next: Review verification results
  cat .claude/scopes/{scope-name}/verification.md

{If gaps found:}
Fix gaps, then re-verify:
  .claude/scripts/prd-scope.sh {scope-name} --verify

{If no gaps:}
Finalize to move PRDs to .claude/prds/:
  .claude/scripts/prd-scope.sh {scope-name} --verify
```

**complete:**
```
Scope complete!

PRDs created:
  {list PRDs in .claude/prds/ from this scope}

To process PRDs:
  .claude/scripts/batch-prd-complete.sh {prd-numbers}
```

### Output Format

```
=== Scope: {name} ===

Phase: {phase}
Created: {date}
Updated: {date}

Discovery Sections:
  [x] Company Background
  [x] Stakeholders
  [x] Timeline & Budget
  [x] Problem Definition
  [x] Business Goals
  [x] Project Scope
  [x] Technical Environment
  [x] Users & Audience
  [ ] User Types          <- next
  [ ] Competitive Landscape
  [ ] Risks & Assumptions
  [ ] Data & Reporting

Progress: 8/12 sections

Progress Summary:
  [ ] Discovery (8/12 sections)
  [ ] Research (optional - {count} unknowns)
  [ ] Decomposition
  [ ] Generation
  [ ] Verification

Files:
  sections/
    company_background.md    (4KB)
    stakeholders.md          (3KB)
    ...
  discovery.md               (not yet created)
  decomposition.md           (not yet created)

Next:
  Continue discovery:
  .claude/scripts/prd-scope.sh {name} --discover
```

### Session Health Check

Also check for issues:

```
Warnings:
  - Discovery incomplete but decomposition started
  - PRDs generated but decomposition not approved
  - Verification has gaps but marked complete
```

### Output

Display the status report to the user. No files are modified by this command.
