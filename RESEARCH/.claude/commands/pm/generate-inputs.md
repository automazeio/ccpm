# Generate Inputs

Analyzes a script or command to identify input prompts, then researches context and generates viable test inputs. Outputs a reusable inputs file that can be referenced in subsequent runs.

## Usage

```bash
/pm:generate-inputs <script_or_command> [--output <inputs_file>] [--dry-run] [--force]
```

**Arguments:**
| Parameter | Default | Description |
|-----------|---------|-------------|
| `script_or_command` | required | The script or command to analyze |
| `--output` | `.claude/inputs/{script_name}-inputs.yaml` | Output file for generated inputs |
| `--dry-run` | false | Show what inputs would be generated without writing file |
| `--force` | false | Overwrite existing inputs file |

## CRITICAL: Deterministic Input Generation

**This skill must produce reproducible, testable inputs.**

Do NOT:
- Guess at input values without evidence
- Generate random or arbitrary values
- Auto-fill credentials or passwords (EVER)

DO:
- Research context from project files before generating
- Document reasoning for each generated input
- Mark uncertain inputs as `deferred: true`

## Quick Check

```bash
SCRIPT="$ARGUMENTS"
test -f "$SCRIPT" || test -n "$(command -v ${SCRIPT%% *})" || echo "❌ Script/command not found: $SCRIPT"
```

## Instructions

### Step 1: Initialize

```bash
SCRIPT="$ARGUMENTS"
SCRIPT_NAME=$(basename "$SCRIPT" | sed 's/[^a-zA-Z0-9]/-/g')
OUTPUT_FILE="${OUTPUT:-.claude/inputs/${SCRIPT_NAME}-inputs.yaml}"
mkdir -p "$(dirname "$OUTPUT_FILE")"
```

**Verify:** Output directory exists
```bash
test -d "$(dirname "$OUTPUT_FILE")" && echo "✓ Output directory ready"
```

### Step 2: Analyze Script for Input Prompts

**Action:** Read the script and extract all input prompts using pattern matching.

**Shell Input Patterns:**
```bash
# Bash read
read -p "Enter name: " name
read -r confirm
read -s password  # SKIP - never auto-fill passwords

# Select
select opt in "Option 1" "Option 2"; do

# Interactive commands
npm init          # Has known prompts
npx create-react-app  # Has known prompts
```

**Detection Commands:**
```bash
# For shell scripts
grep -n "read -p\|read -r\|select.*in\|read\s" "$SCRIPT"

# For known interactive commands - check known-commands database
cat .claude/config/known-commands.yaml 2>/dev/null | grep -A20 "${SCRIPT%% *}"
```

**Verify:** Count detected prompts
```bash
PROMPT_COUNT=$(grep -c "read\|select\|expect" "$SCRIPT" 2>/dev/null || echo "0")
echo "Detected prompts: $PROMPT_COUNT"
test "$PROMPT_COUNT" -gt 0 || echo "⚠️ No prompts found - script may not be interactive"
```

### Step 3: Research Context for Viable Inputs

**Action:** For each detected input prompt, gather context to generate appropriate values.

| Prompt Type | Context Sources | Generation Strategy |
|-------------|-----------------|---------------------|
| **Project name** | `basename $(pwd)`, package.json | Use existing project name |
| **Author/email** | git config, .env | Pull from git config |
| **Version** | package.json, existing versions | Default "1.0.0" or increment |
| **License** | Existing LICENSE file, package.json | Match existing or "MIT" |
| **Description** | README.md, scope docs | Extract from existing docs |
| **Port numbers** | .env, docker-compose.yml | Scan for existing ports, default 3000 |
| **File paths** | Project structure | Infer from existing patterns |
| **Y/N confirms** | Safety classification | "y" for safe, "n" for destructive |
| **Selections** | Options list | First option or marked default |
| **Component names** | Codebase conventions | Analyze existing naming patterns |

**Context Gathering Commands:**
```bash
# Project context
PROJECT_NAME=$(basename "$(pwd)" | tr '_' '-')
GIT_USER=$(git config user.name 2>/dev/null || echo "developer")
GIT_EMAIL=$(git config user.email 2>/dev/null || echo "dev@example.com")

# Package info
PKG_NAME=$(jq -r '.name // empty' package.json 2>/dev/null)
PKG_VERSION=$(jq -r '.version // "1.0.0"' package.json 2>/dev/null)

# Framework detection
FRAMEWORK=$(jq -r '.dependencies | keys[]' package.json 2>/dev/null | grep -E "react|vue|angular|express" | head -1)
```

**Verify:** Context gathered
```bash
echo "Context: project=$PROJECT_NAME, user=$GIT_USER, framework=$FRAMEWORK"
```

### Step 4: Classify Each Prompt

**Action:** For each detected prompt, determine type and appropriate value.

**Classification Logic:**
```
Prompt contains "password|secret|token|key|credential" → type: credential, deferred: true
Prompt contains "[y/n]|yes/no" → type: binary
Prompt contains "delete|remove|format|overwrite" → type: destructive, value: "n"
Prompt contains "path:|file:|directory:" → type: path
Prompt contains "name:|enter.*name" → type: naming
Prompt contains "port:|timeout:|number:" → type: config
Prompt contains "choose|select|[1-9]" → type: selection
Otherwise → type: unknown, deferred: true
```

### Step 5: Generate Inputs File

**Action:** Write the YAML inputs file with all detected prompts and generated values.

**Template:**
```yaml
# {OUTPUT_FILE}
---
version: 1
generated: {CURRENT_DATETIME}
script: "{SCRIPT}"
context:
  project_name: {PROJECT_NAME}
  git_user: {GIT_USER}
  framework: {FRAMEWORK}

inputs:
  - prompt: "{DETECTED_PROMPT_1}"
    type: {CLASSIFIED_TYPE}
    value: "{GENERATED_VALUE}"
    confidence: {0.0-1.0}
    reasoning: "{WHY_THIS_VALUE}"
    deferred: {true if credential or unknown}

expect_script: |
  spawn {SCRIPT}
  {FOR EACH INPUT}
  expect "{PROMPT}"
  send "{VALUE}\r"
  {END FOR}
  expect eof
```

**Verify:** File created
```bash
test -f "$OUTPUT_FILE" && echo "✓ Inputs file created: $OUTPUT_FILE"
```

### Step 6: Report Results

**Action:** Output summary of generated inputs.

## Output Format

### Success
```
✅ Inputs Generated

Script: {script}
Output: {output_file}

Detected Inputs: {count}

| # | Prompt | Type | Value | Confidence |
|---|--------|------|-------|------------|
| 1 | {prompt} | {type} | {value} | {confidence}% |
...

Deferred Inputs: {count}
- {prompt}: Add to .env before running

Usage:
  /pm:fix-problem --command "{script}" --inputs {output_file}
```

### Failure
```
❌ Input Generation Failed

Script: {script}
Error: {reason}

Issues:
- {issue_1}
- {issue_2}

Suggestions:
1. Run script manually once, capture prompts
2. Create inputs file manually: {output_file}
3. Use --dry-run on script if available
```

## Anti-Pattern Prevention

**FORBIDDEN:**
- ❌ Auto-filling any credential, API key, or password
- ❌ Generating inputs without checking project context first
- ❌ Using "y" for destructive confirmations (delete, format, overwrite)
- ❌ Generating inputs for GUI-based prompts (not supported)
- ❌ Guessing values for unknown prompt types

**REQUIRED:**
- ✅ Check git config for author/email values
- ✅ Check package.json/setup.py for project metadata
- ✅ Check .env for environment-specific values
- ✅ Mark ALL credentials as `deferred: true`
- ✅ Log confidence scores for each generated input
- ✅ Include reasoning for every value

## Important Rules

1. **Never auto-fill credentials** - API keys, passwords, tokens always deferred
2. **Research before generating** - Check project files for context
3. **Default to safe options** - "n" for destructive, "y" for non-destructive
4. **Document reasoning** - Every input needs a `reasoning` field
5. **Validate timestamps** - Check script modification vs inputs file age
6. **Fail on unknown prompts** - Don't guess, mark as deferred

## Known Command Database

Check `.claude/config/known-commands.yaml` for pre-defined prompts:

```yaml
npm_init:
  command: "npm init"
  prompts:
    - pattern: "package name:"
      type: naming
      default_source: "directory_name"
    - pattern: "version:"
      type: config
      default: "1.0.0"
    - pattern: "Is this OK?"
      type: binary
      default: "yes"

create_react_app:
  command: "npx create-react-app"
  prompts:
    - pattern: "Ok to proceed?"
      type: binary
      default: "y"
```

## Relationship with Other Commands

| Command | Integration |
|---------|-------------|
| `/pm:fix-problem --auto` | Spawns this as sub-task to generate inputs |
| `/pm:batch-process` | Uses inputs for PRD processing scripts |
| `/pm:deploy` | Uses inputs for deployment confirmations |

## Notes

- Inputs files are git-tracked (no secrets)
- Deferred inputs pull from .env at runtime
- Confidence scores help identify unreliable inputs
- Expect script format for complex shell automation
- Reuse existing inputs: check for file before regenerating
