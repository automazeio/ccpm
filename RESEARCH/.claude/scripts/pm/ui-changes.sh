#!/bin/bash
# ui-changes.sh - Orchestrate UI-to-PRD pipeline
#
# Each step can be run independently or as part of the full pipeline.
#
# Individual Steps:
#   ./ui-changes.sh --generate <name>          # Step 1: Generate UI PRD via /pm:ui-generate
#   ./ui-changes.sh --scope <name>             # Step 2: Create scope documents from PRD
#   ./ui-changes.sh --roadmap <name>           # Step 3: Generate roadmap via /pm:roadmap-generate
#   ./ui-changes.sh --decompose <name>         # Step 4: Decompose into PRDs via /pm:decompose
#
# Pipeline Commands:
#   ./ui-changes.sh <name> [--type TYPE]       # Run full pipeline
#   ./ui-changes.sh --build <name>             # Run full pipeline (explicit)
#   ./ui-changes.sh --resume <name>            # Resume from last step
#
# Session Management:
#   ./ui-changes.sh --list                     # List all UI sessions
#   ./ui-changes.sh --status <name>            # Show session status
#
# Pipeline Flow:
#   ui-generate → scope-bridge → roadmap-generate → decompose

set -e

# Get script directory for sourcing library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
UI_TYPE="page"
PROJECT_NAME=""
DRY_RUN=false
FIGMA_URL=""
SCREENSHOT=""

# Directories
PRD_DIR=".claude/prds"
SCOPE_BASE=".claude/scopes"
PIPELINE_DIR=".claude/pipeline"

# Show help
show_help() {
  cat << 'EOF'
UI Changes - UI-to-PRD Pipeline Orchestrator

Usage:
  ./ui-changes.sh <name> [--type TYPE]       Full pipeline: ui-generate → scope → roadmap → PRDs
  ./ui-changes.sh --help                     Show this help

Individual Steps (run independently):
  1. ./ui-changes.sh --generate <name>       Generate UI PRD (interactive)
  2. ./ui-changes.sh --scope <name>          Create scope documents from PRD
  3. ./ui-changes.sh --roadmap <name>        Generate MVP roadmap
  4. ./ui-changes.sh --decompose <name>      Decompose roadmap into PRDs

Pipeline Commands:
  ./ui-changes.sh --build <name>             Run full pipeline from step 1
  ./ui-changes.sh --resume <name>            Resume from last completed step

Session Management:
  ./ui-changes.sh --list                     List all UI sessions
  ./ui-changes.sh --status <name>            Show session status

Options:
  --type TYPE           UI type: page, component, layout, feature (default: page)
  --figma-url URL       Figma design URL for reference
  --screenshot PATH     Screenshot path for visual reference
  --dry-run             Preview without writing files

Examples:
  ./ui-changes.sh dashboard --type page
  ./ui-changes.sh user-card --type component
  ./ui-changes.sh --generate checkout-flow --figma-url "https://figma.com/..."
  ./ui-changes.sh --resume dashboard

Output Files:
  .claude/prds/<name>.md                     Initial UI PRD
  .claude/scopes/<name>-ui/                  Scope documents
    00_scope_document.md                     Executive summary
    01_features.md                           Feature catalog
    02_user_journeys.md                      User journeys
    04_technical_architecture.md             Tech stack
    07_roadmap.md                            MVP roadmap
  .claude/prds/<name>-ui/                    Decomposed PRDs

Pipeline State:
  .claude/pipeline/<name>-ui/state.yaml      Pipeline progress tracking
EOF
}

# List all UI sessions
list_sessions() {
  echo "UI Change Sessions:"
  echo ""

  # Check for UI-related PRDs
  if [ -d "$PRD_DIR" ]; then
    for prd in "$PRD_DIR"/*.md; do
      if [ -f "$prd" ]; then
        name=$(basename "$prd" .md)
        scope_dir="$SCOPE_BASE/${name}-ui"
        pipeline_state="$PIPELINE_DIR/${name}-ui/state.yaml"

        # Check status
        status="prd-only"
        if [ -d "$scope_dir" ]; then
          status="scope"
          if [ -f "$scope_dir/07_roadmap.md" ]; then
            status="roadmap"
          fi
        fi

        # Check pipeline state
        pipeline_info=""
        if [ -f "$pipeline_state" ]; then
          last_step=$(grep "^last_completed_step:" "$pipeline_state" 2>/dev/null | cut -d: -f2 | tr -d ' ')
          pipe_status=$(grep "^status:" "$pipeline_state" 2>/dev/null | head -1 | cut -d: -f2 | tr -d ' ')
          if [ "$pipe_status" = "complete" ]; then
            pipeline_info="[complete]"
          elif [ -n "$last_step" ] && [ "$last_step" != "0" ]; then
            pipeline_info="[step $last_step/4]"
          fi
        fi

        printf "  %-30s %-12s %s\n" "$name" "[$status]" "$pipeline_info"
      fi
    done
  else
    echo "  No UI sessions found."
    echo ""
    echo "  Start one with: ./ui-changes.sh <name>"
  fi

  echo ""
  echo "Commands:"
  echo "  New:     ./ui-changes.sh <name> --type page"
  echo "  Resume:  ./ui-changes.sh --resume <name>"
  echo "  Status:  ./ui-changes.sh --status <name>"
}

# Show session status
show_status() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./ui-changes.sh --status <name>"
    exit 1
  fi

  local prd="$PRD_DIR/$name.md"
  local scope_dir="$SCOPE_BASE/${name}-ui"
  local pipeline_state="$PIPELINE_DIR/${name}-ui/state.yaml"

  echo "=== UI Session: $name ==="
  echo ""

  # Step 1: PRD
  if [ -f "$prd" ]; then
    echo "Step 1 - UI PRD: ✓ $prd"
    # Extract type from frontmatter if present
    prd_type=$(grep "^type:" "$prd" 2>/dev/null | head -1 | cut -d: -f2 | tr -d ' ')
    [ -n "$prd_type" ] && echo "         Type: $prd_type"
  else
    echo "Step 1 - UI PRD: Not generated"
    echo ""
    echo "Next: ./ui-changes.sh --generate $name"
    exit 0
  fi

  # Step 2: Scope
  if [ -d "$scope_dir" ]; then
    echo "Step 2 - Scope: ✓ $scope_dir/"
    # Count scope files
    scope_count=$(ls -1 "$scope_dir"/*.md 2>/dev/null | wc -l)
    echo "         Files: $scope_count"
  else
    echo "Step 2 - Scope: Not generated"
    echo ""
    echo "Next: ./ui-changes.sh --scope $name"
    exit 0
  fi

  # Step 3: Roadmap
  if [ -f "$scope_dir/07_roadmap.md" ]; then
    echo "Step 3 - Roadmap: ✓ $scope_dir/07_roadmap.md"
  else
    echo "Step 3 - Roadmap: Not generated"
    echo ""
    echo "Next: ./ui-changes.sh --roadmap $name"
    exit 0
  fi

  # Step 4: Decomposed PRDs
  local decomposed_dir="$PRD_DIR/${name}-ui"
  if [ -d "$decomposed_dir" ]; then
    prd_count=$(ls -1 "$decomposed_dir"/*.md 2>/dev/null | wc -l)
    echo "Step 4 - PRDs: ✓ $decomposed_dir/ ($prd_count files)"
  else
    echo "Step 4 - PRDs: Not generated"
    echo ""
    echo "Next: ./ui-changes.sh --decompose $name"
    exit 0
  fi

  echo ""
  echo "✅ Pipeline complete"
  echo ""
  echo "Next steps:"
  echo "  Parse PRDs: /pm:prd-parse ${name}-ui/<prd-name>"
  echo "  View PRDs:  ls $decomposed_dir/"
}

# Initialize pipeline state
init_pipeline_state() {
  local name="$1"
  local state_dir="$PIPELINE_DIR/${name}-ui"
  local state_file="$state_dir/state.yaml"

  mkdir -p "$state_dir"

  if [ ! -f "$state_file" ]; then
    local current_date
    current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    cat > "$state_file" << EOF
session: ${name}-ui
status: in_progress
started: $current_date
last_completed_step: 0
steps:
  1_generate: pending
  2_scope: pending
  3_roadmap: pending
  4_decompose: pending
EOF
  fi
}

# Update pipeline state
update_pipeline_state() {
  local name="$1"
  local step="$2"
  local status="$3"
  local state_file="$PIPELINE_DIR/${name}-ui/state.yaml"

  if [ -f "$state_file" ]; then
    # Update step status
    sed -i "s/${step}: .*/${step}: $status/" "$state_file"

    # Update last completed step if complete
    if [ "$status" = "complete" ]; then
      step_num=$(echo "$step" | grep -o '^[0-9]')
      sed -i "s/last_completed_step: .*/last_completed_step: $step_num/" "$state_file"
    fi
  fi
}

# Step 1: Generate UI PRD via /pm:ui-generate
generate_ui_prd() {
  local name="$1"
  local type="${2:-page}"
  local figma="${3:-}"
  local screenshot="${4:-}"

  if [ -z "$name" ]; then
    echo "❌ Project name required"
    echo "Usage: ./ui-changes.sh --generate <name> [--type TYPE]"
    exit 1
  fi

  echo "=== Step 1: Generate UI PRD ==="
  echo ""
  echo "Project: $name"
  echo "Type: $type"
  [ -n "$figma" ] && echo "Figma: $figma"
  [ -n "$screenshot" ] && echo "Screenshot: $screenshot"
  echo ""

  # Ensure PRD directory exists
  mkdir -p "$PRD_DIR"

  # Initialize pipeline state
  init_pipeline_state "$name"
  update_pipeline_state "$name" "1_generate" "in_progress"

  # Build command arguments
  local cmd="/pm:ui-generate $name --type $type"
  [ -n "$figma" ] && cmd="$cmd --figma-url \"$figma\""
  [ -n "$screenshot" ] && cmd="$cmd --screenshot \"$screenshot\""

  # Check if we're running interactively (has a TTY)
  if [ -t 0 ]; then
    # Interactive mode - launch Claude for user interaction
    echo "This step requires interactive input to describe your UI requirements."
    echo ""
    echo "When Claude starts, it will ask you questions about:"
    echo "  - What UI you're building"
    echo "  - Visual references (optional)"
    echo "  - Behavior requirements"
    echo ""
    echo "Command that will run: $cmd"
    echo ""
    echo "Press Enter to launch Claude..."
    read

    # Launch interactive Claude
    claude --dangerously-skip-permissions "$cmd"
  else
    # Non-interactive mode
    echo "Running in non-interactive mode."
    echo "Note: Interactive prompts may require manual input."
    echo ""
    claude --dangerously-skip-permissions "$cmd"
  fi

  echo ""
  echo "---"
  echo ""

  # Check result
  if [ -f "$PRD_DIR/$name.md" ]; then
    echo "✅ UI PRD generated: $PRD_DIR/$name.md"
    update_pipeline_state "$name" "1_generate" "complete"
    echo ""
    echo "Next: ./ui-changes.sh --scope $name"
  else
    echo "❌ PRD generation failed or was cancelled"
    update_pipeline_state "$name" "1_generate" "failed"
    exit 1
  fi
}

# Step 2: Create scope documents from PRD (bridge logic)
create_scope_from_prd() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Project name required"
    echo "Usage: ./ui-changes.sh --scope <name>"
    exit 1
  fi

  local prd="$PRD_DIR/$name.md"
  local scope_dir="$SCOPE_BASE/${name}-ui"

  if [ ! -f "$prd" ]; then
    echo "❌ PRD not found: $prd"
    echo ""
    echo "First run: ./ui-changes.sh --generate $name"
    exit 1
  fi

  echo "=== Step 2: Create Scope Documents ==="
  echo ""
  echo "Source PRD: $prd"
  echo "Output: $scope_dir/"
  echo ""

  # Initialize pipeline state
  init_pipeline_state "$name"
  update_pipeline_state "$name" "2_scope" "in_progress"

  # Create scope directory
  mkdir -p "$scope_dir"

  # Get current datetime
  local current_date
  current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Extract PRD content (skip frontmatter)
  local prd_content
  prd_content=$(sed '1,/^---$/d; 1,/^---$/d' "$prd" 2>/dev/null || cat "$prd")

  # Extract PRD frontmatter values
  local prd_name
  prd_name=$(grep "^name:" "$prd" 2>/dev/null | head -1 | cut -d: -f2- | tr -d ' "' || echo "$name")
  local prd_description
  prd_description=$(grep "^description:" "$prd" 2>/dev/null | head -1 | cut -d: -f2- | sed 's/^ *//')

  # Detect stack from codebase
  local stack_info=""
  local has_react=false
  local has_shadcn=false
  local has_tailwind=false

  if [ -f "package.json" ]; then
    grep -q '"react"' package.json 2>/dev/null && has_react=true
    grep -q '"@radix-ui"' package.json 2>/dev/null && has_shadcn=true
    grep -q '"tailwindcss"' package.json 2>/dev/null && has_tailwind=true
  fi
  [ -f "components.json" ] && has_shadcn=true
  [ -f "tailwind.config.js" ] || [ -f "tailwind.config.ts" ] && has_tailwind=true

  # Build stack string
  $has_react && stack_info="React"
  $has_shadcn && stack_info="$stack_info + shadcn/ui"
  $has_tailwind && stack_info="$stack_info + Tailwind CSS"
  [ -z "$stack_info" ] && stack_info="To be determined"

  echo "Detected stack: $stack_info"
  echo ""

  # Generate 00_scope_document.md
  echo "Creating 00_scope_document.md..."
  cat > "$scope_dir/00_scope_document.md" << EOF
# Scope Document: ${name}-ui

**Generated:** $current_date
**Source:** $prd
**Status:** Draft

---

## Executive Summary

${prd_description:-UI implementation scope for $name}

## Source PRD

This scope was generated from the UI PRD at \`$prd\`.

## Key Metrics

- Features: See 01_features.md
- User Journeys: See 02_user_journeys.md
- Technical Stack: See 04_technical_architecture.md

## Files

- 01_features.md - Feature catalog derived from PRD
- 02_user_journeys.md - User journeys derived from PRD
- 04_technical_architecture.md - Technical stack and integrations

## Next Steps

1. Review this scope
2. Generate roadmap: \`./ui-changes.sh --roadmap $name\`
3. Decompose into PRDs: \`./ui-changes.sh --decompose $name\`
EOF

  # Generate 01_features.md
  echo "Creating 01_features.md..."
  cat > "$scope_dir/01_features.md" << EOF
# Features Catalog: ${name}-ui

**Generated:** $current_date
**Source:** $prd

---

## Features

| ID | Feature | Priority | Complexity |
|----|---------|----------|------------|
| F-001 | Core UI Implementation | Must Have | M |
| F-002 | Responsive Design | Must Have | S |
| F-003 | Accessibility Support | Must Have | S |
| F-004 | Loading States | Should Have | S |
| F-005 | Error Handling | Should Have | S |

---

## Feature Details

### F-001: Core UI Implementation

**User Story:** As a user, I want the ${name} UI to be functional and visually correct, so that I can accomplish my tasks.

**Priority:** Must Have

**Acceptance Criteria:**
- [ ] UI renders correctly based on design
- [ ] All interactive elements function properly
- [ ] Data is displayed correctly

### F-002: Responsive Design

**User Story:** As a user, I want the UI to work on different screen sizes, so that I can use it on mobile and desktop.

**Priority:** Must Have

**Acceptance Criteria:**
- [ ] Works at 320px width (mobile)
- [ ] Works at 768px width (tablet)
- [ ] Works at 1024px+ width (desktop)

### F-003: Accessibility Support

**User Story:** As a user with accessibility needs, I want the UI to be accessible, so that I can use it with assistive technologies.

**Priority:** Must Have

**Acceptance Criteria:**
- [ ] Proper ARIA labels on interactive elements
- [ ] Keyboard navigation works
- [ ] Focus states are visible

### F-004: Loading States

**User Story:** As a user, I want to see loading indicators when data is being fetched, so that I know the system is working.

**Priority:** Should Have

**Acceptance Criteria:**
- [ ] Loading skeleton or spinner shown during data fetch
- [ ] Loading state is accessible

### F-005: Error Handling

**User Story:** As a user, I want to see clear error messages when something goes wrong, so that I know what happened.

**Priority:** Should Have

**Acceptance Criteria:**
- [ ] Error messages are user-friendly
- [ ] Recovery action is suggested where possible

---

*Note: Review and customize these features based on the specific PRD requirements.*
EOF

  # Generate 02_user_journeys.md
  echo "Creating 02_user_journeys.md..."
  cat > "$scope_dir/02_user_journeys.md" << EOF
# User Journeys: ${name}-ui

**Generated:** $current_date
**Source:** $prd

---

## J-001: Primary User Journey

**Actor:** End User
**Goal:** Use the ${name} UI to accomplish their task
**Benefit:** Complete their intended action efficiently

**Steps:**
1. User navigates to the ${name} UI
2. UI loads and displays initial state
3. User interacts with UI elements
4. UI responds to user actions
5. User completes their task

**Related Features:** F-001, F-002, F-003

---

## J-002: Error Recovery Journey

**Actor:** End User
**Goal:** Recover from an error state
**Benefit:** Continue using the application despite issues

**Steps:**
1. User encounters an error
2. Error message is displayed
3. User understands what went wrong
4. User takes corrective action
5. User continues with their task

**Related Features:** F-005

---

*Note: Review and customize these journeys based on the specific PRD requirements.*
EOF

  # Generate 04_technical_architecture.md
  echo "Creating 04_technical_architecture.md..."
  cat > "$scope_dir/04_technical_architecture.md" << EOF
# Technical Architecture: ${name}-ui

**Generated:** $current_date
**Source:** $prd

---

## Technology Stack

### Frontend Framework
EOF

  if $has_react; then
    echo "- **React** - Detected from package.json" >> "$scope_dir/04_technical_architecture.md"
  else
    echo "- **Framework:** To be determined" >> "$scope_dir/04_technical_architecture.md"
  fi

  cat >> "$scope_dir/04_technical_architecture.md" << EOF

### UI Components
EOF

  if $has_shadcn; then
    echo "- **shadcn/ui** - Detected from components.json" >> "$scope_dir/04_technical_architecture.md"
    echo "- Uses Radix UI primitives" >> "$scope_dir/04_technical_architecture.md"
  else
    echo "- Component library: To be determined" >> "$scope_dir/04_technical_architecture.md"
  fi

  cat >> "$scope_dir/04_technical_architecture.md" << EOF

### Styling
EOF

  if $has_tailwind; then
    echo "- **Tailwind CSS** - Detected from config" >> "$scope_dir/04_technical_architecture.md"
  else
    echo "- Styling approach: To be determined" >> "$scope_dir/04_technical_architecture.md"
  fi

  cat >> "$scope_dir/04_technical_architecture.md" << EOF

### Icons
- **lucide-react** (recommended for shadcn/ui compatibility)

---

## Component Architecture

\`\`\`
${name}/
├── ${name}.tsx           # Main component
├── ${name}.test.tsx      # Tests
├── components/           # Sub-components (if complex)
│   ├── Header.tsx
│   ├── Content.tsx
│   └── Footer.tsx
└── hooks/                # Custom hooks (if needed)
    └── use${name^}Data.ts
\`\`\`

---

## Integrations

| Integration | Type | Purpose |
|-------------|------|---------|
| Backend API | REST/GraphQL | Data fetching |

---

## Constraints

1. **shadcn/ui Only** - Use existing shadcn/ui components
2. **Tailwind Only** - No custom CSS files
3. **TypeScript** - Full type safety
4. **Accessibility** - WCAG 2.1 AA compliance

---

*Note: Review and update based on actual project requirements.*
EOF

  echo ""
  echo "---"
  echo ""

  # Verify files were created
  local file_count
  file_count=$(ls -1 "$scope_dir"/*.md 2>/dev/null | wc -l)

  if [ "$file_count" -ge 4 ]; then
    echo "✅ Scope documents created: $scope_dir/"
    echo "   Files: $file_count"
    update_pipeline_state "$name" "2_scope" "complete"
    echo ""
    echo "Review the generated scope documents and customize as needed."
    echo ""
    echo "Next: ./ui-changes.sh --roadmap $name"
  else
    echo "❌ Scope generation failed"
    update_pipeline_state "$name" "2_scope" "failed"
    exit 1
  fi
}

# Step 3: Generate roadmap via /pm:roadmap-generate
generate_roadmap() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Project name required"
    echo "Usage: ./ui-changes.sh --roadmap <name>"
    exit 1
  fi

  local scope_dir="$SCOPE_BASE/${name}-ui"

  if [ ! -d "$scope_dir" ]; then
    echo "❌ Scope directory not found: $scope_dir"
    echo ""
    echo "First run: ./ui-changes.sh --scope $name"
    exit 1
  fi

  echo "=== Step 3: Generate Roadmap ==="
  echo ""
  echo "Scope: $scope_dir/"
  echo ""

  # Initialize pipeline state
  init_pipeline_state "$name"
  update_pipeline_state "$name" "3_roadmap" "in_progress"

  # Run roadmap-generate
  claude --dangerously-skip-permissions --print "/pm:roadmap-generate ${name}-ui"

  echo ""
  echo "---"
  echo ""

  local roadmap="$scope_dir/07_roadmap.md"
  if [ -f "$roadmap" ]; then
    echo "✅ Roadmap generated: $roadmap"
    update_pipeline_state "$name" "3_roadmap" "complete"
    echo ""
    echo "Next: ./ui-changes.sh --decompose $name"
  else
    echo "❌ Roadmap generation failed"
    update_pipeline_state "$name" "3_roadmap" "failed"
    exit 1
  fi
}

# Step 4: Decompose into PRDs via /pm:decompose
decompose_to_prds() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Project name required"
    echo "Usage: ./ui-changes.sh --decompose <name>"
    exit 1
  fi

  local scope_dir="$SCOPE_BASE/${name}-ui"
  local roadmap="$scope_dir/07_roadmap.md"

  if [ ! -f "$roadmap" ]; then
    echo "❌ Roadmap not found: $roadmap"
    echo ""
    echo "First run: ./ui-changes.sh --roadmap $name"
    exit 1
  fi

  echo "=== Step 4: Decompose into PRDs ==="
  echo ""
  echo "Roadmap: $roadmap"
  echo "Output: $PRD_DIR/${name}-ui/"
  echo ""

  # Initialize pipeline state
  init_pipeline_state "$name"
  update_pipeline_state "$name" "4_decompose" "in_progress"

  # Create a roadmap item file for decompose
  local item_file="$scope_dir/roadmap-item.md"

  # Extract roadmap name and create item file
  local current_date
  current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  cat > "$item_file" << EOF
---
id: ${name}-ui
title: ${name} UI Implementation
description: UI implementation based on generated PRD and scope documents
type: epic
created: $current_date
---

# ${name} UI Implementation

## Overview

Implementation of the ${name} UI based on the generated scope documents.

## Source Documents

- PRD: \`$PRD_DIR/$name.md\`
- Scope: \`$scope_dir/\`
- Roadmap: \`$roadmap\`

## Goals

1. Implement the UI as specified in the PRD
2. Follow the roadmap phases
3. Ensure accessibility and responsiveness

## Constraints

- Use shadcn/ui components
- Use Tailwind CSS for styling
- TypeScript required
EOF

  # Run decompose
  claude --dangerously-skip-permissions --print "/pm:decompose $item_file --output-dir $PRD_DIR/${name}-ui"

  echo ""
  echo "---"
  echo ""

  local decomposed_dir="$PRD_DIR/${name}-ui"
  if [ -d "$decomposed_dir" ]; then
    local prd_count
    prd_count=$(ls -1 "$decomposed_dir"/*.md 2>/dev/null | wc -l)

    if [ "$prd_count" -gt 0 ]; then
      echo "✅ Decomposed into $prd_count PRDs: $decomposed_dir/"
      update_pipeline_state "$name" "4_decompose" "complete"

      # Mark pipeline as complete
      local state_file="$PIPELINE_DIR/${name}-ui/state.yaml"
      [ -f "$state_file" ] && sed -i 's/status: .*/status: complete/' "$state_file"

      echo ""
      echo "=== Pipeline Complete ==="
      echo ""
      echo "Files created:"
      echo "  PRD: $PRD_DIR/$name.md"
      echo "  Scope: $scope_dir/"
      echo "  Roadmap: $roadmap"
      echo "  PRDs: $decomposed_dir/ ($prd_count files)"
      echo ""
      echo "Next steps:"
      echo "  Parse PRDs: /pm:prd-parse ${name}-ui/<prd-name>"
      echo "  List PRDs:  ls $decomposed_dir/"
    else
      echo "⚠️ Decompose completed but no PRDs found"
      update_pipeline_state "$name" "4_decompose" "partial"
    fi
  else
    echo "❌ Decomposition failed"
    update_pipeline_state "$name" "4_decompose" "failed"
    exit 1
  fi
}

# Full pipeline
build_full() {
  local name="$1"
  local type="${2:-page}"
  local start_step="${3:-1}"

  if [ -z "$name" ]; then
    echo "❌ Project name required"
    echo "Usage: ./ui-changes.sh <name> [--type TYPE]"
    exit 1
  fi

  echo "=== UI Changes Pipeline: $name ==="
  echo ""
  echo "Pipeline: ui-generate → scope → roadmap → decompose"
  echo "Type: $type"
  echo ""

  # Run steps based on start_step
  if [ "$start_step" -le 1 ]; then
    generate_ui_prd "$name" "$type" "$FIGMA_URL" "$SCREENSHOT"
    echo ""
  fi

  if [ "$start_step" -le 2 ]; then
    create_scope_from_prd "$name"
    echo ""
  fi

  if [ "$start_step" -le 3 ]; then
    generate_roadmap "$name"
    echo ""
  fi

  if [ "$start_step" -le 4 ]; then
    decompose_to_prds "$name"
  fi
}

# Resume pipeline from last completed step
resume_pipeline() {
  local name="$1"
  local state_file="$PIPELINE_DIR/${name}-ui/state.yaml"

  if [ ! -f "$state_file" ]; then
    echo "❌ No pipeline state found for: $name"
    echo ""
    echo "Start fresh with: ./ui-changes.sh $name"
    exit 1
  fi

  # Get last completed step
  local last_step
  last_step=$(grep "^last_completed_step:" "$state_file" 2>/dev/null | cut -d: -f2 | tr -d ' ')

  if [ -z "$last_step" ] || [ "$last_step" = "0" ]; then
    echo "No steps completed yet. Starting from step 1."
    build_full "$name" "$UI_TYPE" 1
  elif [ "$last_step" = "4" ]; then
    echo "Pipeline already complete for: $name"
    echo ""
    show_status "$name"
    exit 0
  else
    local next_step=$((last_step + 1))
    echo "Resuming from step $next_step (last completed: $last_step)"
    echo ""
    build_full "$name" "$UI_TYPE" "$next_step"
  fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      show_help
      exit 0
      ;;
    --list|-l)
      list_sessions
      exit 0
      ;;
    --status|-s)
      show_status "$2"
      exit 0
      ;;
    --generate|-g)
      shift
      generate_ui_prd "$1" "$UI_TYPE" "$FIGMA_URL" "$SCREENSHOT"
      exit 0
      ;;
    --scope)
      shift
      create_scope_from_prd "$1"
      exit 0
      ;;
    --roadmap|-r)
      shift
      generate_roadmap "$1"
      exit 0
      ;;
    --decompose|-d)
      shift
      decompose_to_prds "$1"
      exit 0
      ;;
    --build|-b)
      shift
      PROJECT_NAME="$1"
      shift
      ;;
    --resume)
      shift
      resume_pipeline "$1"
      exit 0
      ;;
    --type|-t)
      shift
      UI_TYPE="$1"
      shift
      ;;
    --figma-url)
      shift
      FIGMA_URL="$1"
      shift
      ;;
    --screenshot)
      shift
      SCREENSHOT="$1"
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -*)
      echo "❌ Unknown option: $1"
      echo "Run ./ui-changes.sh --help for usage"
      exit 1
      ;;
    *)
      # Positional argument - project name
      if [ -z "$PROJECT_NAME" ]; then
        PROJECT_NAME="$1"
      fi
      shift
      ;;
  esac
done

# Default: run full pipeline if project name provided
if [ -n "$PROJECT_NAME" ]; then
  build_full "$PROJECT_NAME" "$UI_TYPE" 1
else
  show_help
fi
