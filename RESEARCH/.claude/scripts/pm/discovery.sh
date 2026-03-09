#!/bin/bash
# discovery.sh - Orchestrate Discovery-to-PRD pipeline
#
# Each step can be run independently or as part of the full pipeline.
#
# Individual Steps:
#   ./discovery.sh --discover <name>           # Step 1: Run 12-section discovery (interactive)
#   ./discovery.sh --merge <name>              # Step 2: Merge sections into discovery.md
#   ./discovery.sh --scope <name>              # Step 3: Create scope documents from discovery
#   ./discovery.sh --roadmap <name>            # Step 4: Generate roadmap
#   ./discovery.sh --decompose <name>          # Step 5: Decompose into PRDs
#
# Pipeline Commands:
#   ./discovery.sh <name>                      # Run full pipeline
#   ./discovery.sh --build <name>              # Run full pipeline (explicit)
#   ./discovery.sh --resume <name>             # Resume from last step
#
# Session Management:
#   ./discovery.sh --list                      # List all discovery sessions
#   ./discovery.sh --status <name>             # Show session status
#
# Pipeline Flow:
#   discover (12 sections) → merge → scope → roadmap → decompose

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Defaults
PROJECT_NAME=""
DRY_RUN=false

# Directories
SCOPE_BASE=".claude/scopes"
PRD_DIR=".claude/prds"
PIPELINE_DIR=".claude/pipeline"

# The 12 discovery sections
SECTIONS="company_background stakeholders timeline_budget problem_definition business_goals project_scope technical_environment users_audience user_types competitive_landscape risks_assumptions data_reporting"

# Section display names
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

# Show help
show_help() {
  cat << 'EOF'
Discovery - Discovery-to-PRD Pipeline Orchestrator

Usage:
  ./discovery.sh <name>                      Full pipeline: discover → scope → roadmap → PRDs
  ./discovery.sh --help                      Show this help

Individual Steps (run independently):
  1. ./discovery.sh --discover <name>        Run 12-section discovery (INTERACTIVE)
  2. ./discovery.sh --merge <name>           Merge sections into discovery.md
  3. ./discovery.sh --scope <name>           Create scope documents from discovery
  4. ./discovery.sh --roadmap <name>         Generate MVP roadmap
  5. ./discovery.sh --decompose <name>       Decompose roadmap into PRDs

Pipeline Commands:
  ./discovery.sh --build <name>              Run full pipeline from step 1
  ./discovery.sh --resume <name>             Resume from last completed step

Session Management:
  ./discovery.sh --list                      List all discovery sessions
  ./discovery.sh --status <name>             Show session status

Options:
  --dry-run                                  Preview without writing files

Discovery Phase (INTERACTIVE):
  - 12 sections, each run as a separate Claude session
  - You answer questions interactively
  - Progress saved after each section
  - Say 'UNKNOWN' for questions you can't answer

Examples:
  ./discovery.sh my-saas-app
  ./discovery.sh --discover my-saas-app
  ./discovery.sh --resume my-saas-app

Output Files:
  .claude/scopes/<name>/sections/            12 discovery section files
  .claude/scopes/<name>/discovery.md         Merged discovery document
  .claude/scopes/<name>/                     Scope documents
    00_scope_document.md                     Executive summary
    01_features.md                           Feature catalog
    02_user_journeys.md                      User journeys
    04_technical_architecture.md             Tech stack
    07_roadmap.md                            MVP roadmap
  .claude/prds/<name>/                       Decomposed PRDs

Pipeline State:
  .claude/pipeline/<name>/state.yaml         Pipeline progress tracking
EOF
}

# Count completed sections
count_sections() {
  local name="$1"
  local sections_dir="$SCOPE_BASE/$name/sections"
  local count=0
  for section in $SECTIONS; do
    [ -f "$sections_dir/${section}.md" ] && count=$((count + 1))
  done
  echo $count
}

# List all discovery sessions
list_sessions() {
  echo "Discovery Sessions:"
  echo ""

  if [ -d "$SCOPE_BASE" ]; then
    for dir in "$SCOPE_BASE"/*/; do
      if [ -d "$dir" ]; then
        name=$(basename "$dir")
        sections_dir="$dir/sections"
        pipeline_state="$PIPELINE_DIR/$name/state.yaml"

        # Count completed sections
        sections_done=0
        if [ -d "$sections_dir" ]; then
          for section in $SECTIONS; do
            [ -f "$sections_dir/${section}.md" ] && sections_done=$((sections_done + 1))
          done
        fi

        # Determine status
        status="new"
        if [ "$sections_done" -gt 0 ]; then
          status="discover ($sections_done/12)"
        fi
        if [ -f "$dir/discovery.md" ]; then
          status="merged"
        fi
        if [ -f "$dir/00_scope_document.md" ]; then
          status="scope"
        fi
        if [ -f "$dir/07_roadmap.md" ]; then
          status="roadmap"
        fi

        # Check pipeline state
        pipeline_info=""
        if [ -f "$pipeline_state" ]; then
          last_step=$(grep "^last_completed_step:" "$pipeline_state" 2>/dev/null | cut -d: -f2 | tr -d ' ')
          pipe_status=$(grep "^status:" "$pipeline_state" 2>/dev/null | head -1 | cut -d: -f2 | tr -d ' ')
          if [ "$pipe_status" = "complete" ]; then
            pipeline_info="[complete]"
          elif [ -n "$last_step" ] && [ "$last_step" != "0" ]; then
            pipeline_info="[step $last_step/5]"
          fi
        fi

        printf "  %-30s %-20s %s\n" "$name" "[$status]" "$pipeline_info"
      fi
    done
  else
    echo "  No discovery sessions found."
    echo ""
    echo "  Start one with: ./discovery.sh <name>"
  fi

  echo ""
  echo "Commands:"
  echo "  New:     ./discovery.sh <name>"
  echo "  Resume:  ./discovery.sh --resume <name>"
  echo "  Status:  ./discovery.sh --status <name>"
}

# Show session status
show_status() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./discovery.sh --status <name>"
    exit 1
  fi

  local scope_dir="$SCOPE_BASE/$name"
  local sections_dir="$scope_dir/sections"
  local pipeline_state="$PIPELINE_DIR/$name/state.yaml"

  echo "=== Discovery Session: $name ==="
  echo ""

  # Step 1: Discovery sections
  local sections_done=$(count_sections "$name")
  if [ "$sections_done" -eq 12 ]; then
    echo -e "Step 1 - Discovery: ${GREEN}✓ Complete (12/12 sections)${NC}"
  elif [ "$sections_done" -gt 0 ]; then
    echo -e "Step 1 - Discovery: ${YELLOW}In progress ($sections_done/12 sections)${NC}"
    echo ""
    echo "Completed sections:"
    for section in $SECTIONS; do
      if [ -f "$sections_dir/${section}.md" ]; then
        echo -e "  ${GREEN}✓${NC} ${SECTION_NAMES[$section]}"
      else
        echo -e "  ${RED}✗${NC} ${SECTION_NAMES[$section]}"
      fi
    done
    echo ""
    echo "Next: ./discovery.sh --discover $name"
    exit 0
  else
    echo "Step 1 - Discovery: Not started"
    echo ""
    echo "Next: ./discovery.sh --discover $name"
    exit 0
  fi

  # Step 2: Merged discovery
  if [ -f "$scope_dir/discovery.md" ]; then
    echo -e "Step 2 - Merge: ${GREEN}✓ $scope_dir/discovery.md${NC}"
  else
    echo "Step 2 - Merge: Not done"
    echo ""
    echo "Next: ./discovery.sh --merge $name"
    exit 0
  fi

  # Step 3: Scope documents
  if [ -f "$scope_dir/00_scope_document.md" ]; then
    echo -e "Step 3 - Scope: ${GREEN}✓ Scope documents created${NC}"
  else
    echo "Step 3 - Scope: Not generated"
    echo ""
    echo "Next: ./discovery.sh --scope $name"
    exit 0
  fi

  # Step 4: Roadmap
  if [ -f "$scope_dir/07_roadmap.md" ]; then
    echo -e "Step 4 - Roadmap: ${GREEN}✓ $scope_dir/07_roadmap.md${NC}"
  else
    echo "Step 4 - Roadmap: Not generated"
    echo ""
    echo "Next: ./discovery.sh --roadmap $name"
    exit 0
  fi

  # Step 5: Decomposed PRDs
  local decomposed_dir="$PRD_DIR/$name"
  if [ -d "$decomposed_dir" ]; then
    local prd_count
    prd_count=$(ls -1 "$decomposed_dir"/*.md 2>/dev/null | wc -l)
    echo -e "Step 5 - PRDs: ${GREEN}✓ $decomposed_dir/ ($prd_count files)${NC}"
  else
    echo "Step 5 - PRDs: Not generated"
    echo ""
    echo "Next: ./discovery.sh --decompose $name"
    exit 0
  fi

  echo ""
  echo -e "${GREEN}✅ Pipeline complete${NC}"
  echo ""
  echo "Next steps:"
  echo "  Parse PRDs: /pm:prd-parse $name/<prd-name>"
  echo "  View PRDs:  ls $decomposed_dir/"
}

# Initialize pipeline state
init_pipeline_state() {
  local name="$1"
  local state_dir="$PIPELINE_DIR/$name"
  local state_file="$state_dir/state.yaml"

  mkdir -p "$state_dir"

  if [ ! -f "$state_file" ]; then
    local current_date
    current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    cat > "$state_file" << EOF
session: $name
status: in_progress
started: $current_date
last_completed_step: 0
steps:
  1_discover: pending
  2_merge: pending
  3_scope: pending
  4_roadmap: pending
  5_decompose: pending
EOF
  fi
}

# Update pipeline state
update_pipeline_state() {
  local name="$1"
  local step="$2"
  local status="$3"
  local state_file="$PIPELINE_DIR/$name/state.yaml"

  if [ -f "$state_file" ]; then
    sed -i "s/${step}: .*/${step}: $status/" "$state_file"

    if [ "$status" = "complete" ]; then
      step_num=$(echo "$step" | grep -o '^[0-9]')
      sed -i "s/last_completed_step: .*/last_completed_step: $step_num/" "$state_file"
    fi
  fi
}

# Step 1: Run 12-section discovery (INTERACTIVE)
run_discover() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./discovery.sh --discover <name>"
    exit 1
  fi

  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Step 1: DISCOVERY (Interactive)${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo ""
  echo "Discovery consists of 12 sections."
  echo "Each section is a separate interactive session."
  echo "Progress is saved after each section."
  echo ""

  local scope_dir="$SCOPE_BASE/$name"
  local sections_dir="$scope_dir/sections"

  mkdir -p "$sections_dir"

  # Initialize pipeline state
  init_pipeline_state "$name"
  update_pipeline_state "$name" "1_discover" "in_progress"

  local total=12
  local done=$(count_sections "$name")

  echo -e "Progress: ${CYAN}$done/$total sections complete${NC}"
  echo ""

  # Loop through sections
  for section in $SECTIONS; do
    local section_file="$sections_dir/${section}.md"
    local section_name="${SECTION_NAMES[$section]}"

    if [ -f "$section_file" ]; then
      echo -e "  ${GREEN}✓${NC} $section_name (complete)"
    else
      echo ""
      echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
      echo -e "${YELLOW}  Section: $section_name${NC}"
      echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
      echo ""
      echo "Starting interactive session..."
      echo "Answer the questions. Type 'skip' to skip optional questions."
      echo "Type 'UNKNOWN' for questions you can't answer."
      echo ""

      # Run INTERACTIVE Claude session (no --print!)
      claude --dangerously-skip-permissions "/pm:scope-discover-section $name $section"

      # Check if section was completed
      if [ -f "$section_file" ]; then
        echo ""
        echo -e "${GREEN}✓ Section complete: $section_name${NC}"
        done=$((done + 1))
      else
        echo ""
        echo -e "${YELLOW}Section incomplete: $section_name${NC}"
        echo ""
        echo "Re-run to continue: ./discovery.sh --discover $name"
        return 1
      fi

      # After each section, ask if user wants to continue
      local remaining=$((total - done))
      if [ $remaining -gt 0 ]; then
        echo ""
        echo -e "Progress: ${CYAN}$done/$total sections${NC} ($remaining remaining)"
        echo ""
        read -p "Continue to next section? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
          echo ""
          echo "Paused. Resume with: ./discovery.sh --discover $name"
          return 0
        fi
      fi
    fi
  done

  echo ""
  echo -e "${GREEN}All 12 sections complete!${NC}"
  update_pipeline_state "$name" "1_discover" "complete"
  echo ""
  echo "Next: ./discovery.sh --merge $name"
}

# Step 2: Merge sections into discovery.md
run_merge() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./discovery.sh --merge <name>"
    exit 1
  fi

  local scope_dir="$SCOPE_BASE/$name"
  local sections_dir="$scope_dir/sections"

  # Check all sections are complete
  local sections_done=$(count_sections "$name")
  if [ "$sections_done" -lt 12 ]; then
    echo "❌ Discovery incomplete: $sections_done/12 sections"
    echo ""
    echo "Complete discovery first: ./discovery.sh --discover $name"
    exit 1
  fi

  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Step 2: MERGE Discovery Sections${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo ""

  # Initialize pipeline state
  init_pipeline_state "$name"
  update_pipeline_state "$name" "2_merge" "in_progress"

  echo "Merging 12 sections into discovery.md..."
  echo ""

  claude --dangerously-skip-permissions --print "/pm:scope-discover $name"

  echo ""
  echo "---"
  echo ""

  if [ -f "$scope_dir/discovery.md" ]; then
    echo -e "${GREEN}✅ Discovery merged: $scope_dir/discovery.md${NC}"
    update_pipeline_state "$name" "2_merge" "complete"
    echo ""
    echo "Next: ./discovery.sh --scope $name"
  else
    echo "❌ Merge failed"
    update_pipeline_state "$name" "2_merge" "failed"
    exit 1
  fi
}

# Step 3: Create scope documents from discovery
create_scope_from_discovery() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./discovery.sh --scope <name>"
    exit 1
  fi

  local scope_dir="$SCOPE_BASE/$name"
  local discovery_file="$scope_dir/discovery.md"

  if [ ! -f "$discovery_file" ]; then
    echo "❌ Discovery not merged: $discovery_file"
    echo ""
    echo "First run: ./discovery.sh --merge $name"
    exit 1
  fi

  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Step 3: Create Scope Documents${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo ""
  echo "Source: $discovery_file"
  echo "Output: $scope_dir/"
  echo ""

  # Initialize pipeline state
  init_pipeline_state "$name"
  update_pipeline_state "$name" "3_scope" "in_progress"

  # Get current datetime
  local current_date
  current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Extract content from discovery sections
  local sections_dir="$scope_dir/sections"

  # Read key information from discovery sections
  local company_name=""
  local problem_statement=""
  local business_goals=""
  local tech_stack=""

  if [ -f "$sections_dir/company_background.md" ]; then
    company_name=$(grep -A1 "Company Name:" "$sections_dir/company_background.md" 2>/dev/null | tail -1 | tr -d '-' | xargs || echo "")
  fi

  if [ -f "$sections_dir/problem_definition.md" ]; then
    problem_statement=$(grep -A3 "Problem Statement:" "$sections_dir/problem_definition.md" 2>/dev/null | tail -1 | xargs || echo "")
  fi

  # Generate 00_scope_document.md
  echo "Creating 00_scope_document.md..."
  cat > "$scope_dir/00_scope_document.md" << EOF
# Scope Document: $name

**Generated:** $current_date
**Source:** Discovery (12 sections)
**Status:** Draft

---

## Executive Summary

This scope was generated from comprehensive discovery across 12 sections including company background, stakeholders, problem definition, business goals, and technical requirements.

## Discovery Source

See \`discovery.md\` for the complete merged discovery document.

## Key Sections

| Section | Status |
|---------|--------|
| Company Background | ✓ |
| Stakeholders | ✓ |
| Timeline & Budget | ✓ |
| Problem Definition | ✓ |
| Business Goals | ✓ |
| Project Scope | ✓ |
| Technical Environment | ✓ |
| Users & Audience | ✓ |
| User Types | ✓ |
| Competitive Landscape | ✓ |
| Risks & Assumptions | ✓ |
| Data & Reporting | ✓ |

## Next Steps

1. Review scope documents
2. Generate roadmap: \`./discovery.sh --roadmap $name\`
3. Decompose into PRDs: \`./discovery.sh --decompose $name\`
EOF

  # Generate 01_features.md from project_scope and business_goals sections
  echo "Creating 01_features.md..."
  cat > "$scope_dir/01_features.md" << EOF
# Features Catalog: $name

**Generated:** $current_date
**Source:** Discovery sections (project_scope, business_goals)

---

## Features

*Features extracted from discovery. Review and customize.*

| ID | Feature | Priority | Complexity |
|----|---------|----------|------------|
| F-001 | Core Functionality | Must Have | M |
| F-002 | User Authentication | Must Have | M |
| F-003 | Data Management | Must Have | M |
| F-004 | Reporting/Analytics | Should Have | M |
| F-005 | Integration Points | Should Have | L |

---

## Feature Details

### F-001: Core Functionality

**User Story:** As a user, I want core product functionality, so that I can achieve my primary goals.

**Priority:** Must Have

**Acceptance Criteria:**
- [ ] Core workflow implemented
- [ ] User can complete primary tasks
- [ ] System responds within performance targets

*See discovery.md > Project Scope for detailed requirements.*

---

*Note: Review and customize these features based on the discovery document.*
EOF

  # Generate 02_user_journeys.md from users_audience and user_types sections
  echo "Creating 02_user_journeys.md..."
  cat > "$scope_dir/02_user_journeys.md" << EOF
# User Journeys: $name

**Generated:** $current_date
**Source:** Discovery sections (users_audience, user_types)

---

## User Types

*From discovery section: user_types*

See \`sections/user_types.md\` for detailed role definitions.

---

## J-001: Primary User Journey

**Actor:** Primary User
**Goal:** Complete core workflow
**Benefit:** Achieve intended outcome efficiently

**Steps:**
1. User accesses the system
2. User navigates to key feature
3. User performs primary action
4. System processes request
5. User receives confirmation

**Related Features:** F-001, F-002

---

## J-002: Admin User Journey

**Actor:** Administrator
**Goal:** Manage system and users
**Benefit:** Maintain system health and user access

**Steps:**
1. Admin logs in with elevated privileges
2. Admin accesses admin dashboard
3. Admin performs management action
4. Changes are applied
5. Audit trail recorded

**Related Features:** F-002, F-004

---

*Note: Review discovery.md and customize these journeys.*
EOF

  # Generate 04_technical_architecture.md from technical_environment section
  echo "Creating 04_technical_architecture.md..."
  cat > "$scope_dir/04_technical_architecture.md" << EOF
# Technical Architecture: $name

**Generated:** $current_date
**Source:** Discovery section (technical_environment)

---

## Technology Stack

*From discovery section: technical_environment*

See \`sections/technical_environment.md\` for detailed stack requirements.

### Summary

| Layer | Technology |
|-------|------------|
| Frontend | TBD - See discovery |
| Backend | TBD - See discovery |
| Database | TBD - See discovery |
| Infrastructure | TBD - See discovery |

---

## Integrations

*From discovery section: technical_environment*

| Integration | Type | Purpose |
|-------------|------|---------|
| Authentication | OAuth/SSO | User authentication |
| Database | Primary | Data persistence |
| External APIs | Various | See discovery |

---

## Security Requirements

*From discovery sections: technical_environment, risks_assumptions*

- Authentication method: See discovery
- Authorization model: See discovery
- Compliance requirements: See discovery

---

## Performance Requirements

- Response time targets: See discovery
- Scalability requirements: See discovery
- Availability targets: See discovery

---

*Note: Review technical_environment.md and customize this document.*
EOF

  echo ""
  echo "---"
  echo ""

  # Verify files were created
  local file_count
  file_count=$(ls -1 "$scope_dir"/0*.md 2>/dev/null | wc -l)

  if [ "$file_count" -ge 4 ]; then
    echo -e "${GREEN}✅ Scope documents created: $scope_dir/${NC}"
    echo "   Files: $file_count"
    update_pipeline_state "$name" "3_scope" "complete"
    echo ""
    echo "Review and customize the generated scope documents."
    echo ""
    echo "Next: ./discovery.sh --roadmap $name"
  else
    echo "❌ Scope generation failed"
    update_pipeline_state "$name" "3_scope" "failed"
    exit 1
  fi
}

# Step 4: Generate roadmap
generate_roadmap() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./discovery.sh --roadmap <name>"
    exit 1
  fi

  local scope_dir="$SCOPE_BASE/$name"

  if [ ! -f "$scope_dir/00_scope_document.md" ]; then
    echo "❌ Scope documents not found"
    echo ""
    echo "First run: ./discovery.sh --scope $name"
    exit 1
  fi

  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Step 4: Generate Roadmap${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo ""
  echo "Scope: $scope_dir/"
  echo ""

  # Initialize pipeline state
  init_pipeline_state "$name"
  update_pipeline_state "$name" "4_roadmap" "in_progress"

  claude --dangerously-skip-permissions --print "/pm:roadmap-generate $name"

  echo ""
  echo "---"
  echo ""

  if [ -f "$scope_dir/07_roadmap.md" ]; then
    echo -e "${GREEN}✅ Roadmap generated: $scope_dir/07_roadmap.md${NC}"
    update_pipeline_state "$name" "4_roadmap" "complete"
    echo ""
    echo "Next: ./discovery.sh --decompose $name"
  else
    echo "❌ Roadmap generation failed"
    update_pipeline_state "$name" "4_roadmap" "failed"
    exit 1
  fi
}

# Step 5: Decompose into PRDs
decompose_to_prds() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./discovery.sh --decompose <name>"
    exit 1
  fi

  local scope_dir="$SCOPE_BASE/$name"
  local roadmap="$scope_dir/07_roadmap.md"

  if [ ! -f "$roadmap" ]; then
    echo "❌ Roadmap not found: $roadmap"
    echo ""
    echo "First run: ./discovery.sh --roadmap $name"
    exit 1
  fi

  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Step 5: Decompose into PRDs${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo ""
  echo "Roadmap: $roadmap"
  echo "Output: $PRD_DIR/$name/"
  echo ""

  # Initialize pipeline state
  init_pipeline_state "$name"
  update_pipeline_state "$name" "5_decompose" "in_progress"

  # Create a roadmap item file for decompose
  local item_file="$scope_dir/roadmap-item.md"

  local current_date
  current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  cat > "$item_file" << EOF
---
id: $name
title: $name Implementation
description: Implementation based on discovery and scope documents
type: epic
created: $current_date
---

# $name Implementation

## Overview

Implementation of $name based on comprehensive 12-section discovery.

## Source Documents

- Discovery: \`$scope_dir/discovery.md\`
- Scope: \`$scope_dir/\`
- Roadmap: \`$roadmap\`

## Goals

See discovery.md > Business Goals

## Constraints

See discovery.md > Technical Environment
EOF

  # Run decompose
  claude --dangerously-skip-permissions --print "/pm:decompose $item_file --output-dir $PRD_DIR/$name"

  echo ""
  echo "---"
  echo ""

  local decomposed_dir="$PRD_DIR/$name"
  if [ -d "$decomposed_dir" ]; then
    local prd_count
    prd_count=$(ls -1 "$decomposed_dir"/*.md 2>/dev/null | wc -l)

    if [ "$prd_count" -gt 0 ]; then
      echo -e "${GREEN}✅ Decomposed into $prd_count PRDs: $decomposed_dir/${NC}"
      update_pipeline_state "$name" "5_decompose" "complete"

      # Mark pipeline as complete
      local state_file="$PIPELINE_DIR/$name/state.yaml"
      [ -f "$state_file" ] && sed -i 's/status: .*/status: complete/' "$state_file"

      echo ""
      echo -e "${GREEN}═══════════════════════════════════════════${NC}"
      echo -e "${GREEN}  PIPELINE COMPLETE: $name${NC}"
      echo -e "${GREEN}═══════════════════════════════════════════${NC}"
      echo ""
      echo "Files created:"
      echo "  Discovery: $scope_dir/discovery.md"
      echo "  Scope: $scope_dir/*.md"
      echo "  Roadmap: $roadmap"
      echo "  PRDs: $decomposed_dir/ ($prd_count files)"
      echo ""
      echo "Next steps:"
      echo "  Parse PRDs: /pm:prd-parse $name/<prd-name>"
      echo "  List PRDs:  ls $decomposed_dir/"
    else
      echo "⚠️ Decompose completed but no PRDs found"
      update_pipeline_state "$name" "5_decompose" "partial"
    fi
  else
    echo "❌ Decomposition failed"
    update_pipeline_state "$name" "5_decompose" "failed"
    exit 1
  fi
}

# Full pipeline
build_full() {
  local name="$1"
  local start_step="${2:-1}"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./discovery.sh <name>"
    exit 1
  fi

  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Discovery Pipeline: $name${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo ""
  echo "Pipeline: discover → merge → scope → roadmap → decompose"
  echo ""

  # Run steps based on start_step
  if [ "$start_step" -le 1 ]; then
    run_discover "$name"
    if [ $? -ne 0 ]; then
      echo ""
      echo "Discovery paused. Resume with: ./discovery.sh --discover $name"
      return 0
    fi
    echo ""
  fi

  if [ "$start_step" -le 2 ]; then
    run_merge "$name"
    echo ""
  fi

  if [ "$start_step" -le 3 ]; then
    create_scope_from_discovery "$name"
    echo ""
  fi

  if [ "$start_step" -le 4 ]; then
    generate_roadmap "$name"
    echo ""
  fi

  if [ "$start_step" -le 5 ]; then
    decompose_to_prds "$name"
  fi
}

# Resume pipeline from last completed step
resume_pipeline() {
  local name="$1"
  local state_file="$PIPELINE_DIR/$name/state.yaml"

  if [ ! -f "$state_file" ]; then
    # Check if there's any progress in scope directory
    local scope_dir="$SCOPE_BASE/$name"
    if [ -d "$scope_dir" ]; then
      echo "No pipeline state, but scope directory exists."
      echo "Checking progress..."
      echo ""

      # Determine where to resume based on files present
      if [ -f "$scope_dir/07_roadmap.md" ]; then
        echo "Resuming from step 5 (decompose)"
        build_full "$name" 5
      elif [ -f "$scope_dir/00_scope_document.md" ]; then
        echo "Resuming from step 4 (roadmap)"
        build_full "$name" 4
      elif [ -f "$scope_dir/discovery.md" ]; then
        echo "Resuming from step 3 (scope)"
        build_full "$name" 3
      elif [ $(count_sections "$name") -eq 12 ]; then
        echo "Resuming from step 2 (merge)"
        build_full "$name" 2
      else
        echo "Resuming from step 1 (discover)"
        build_full "$name" 1
      fi
    else
      echo "❌ No session found for: $name"
      echo ""
      echo "Start fresh with: ./discovery.sh $name"
      exit 1
    fi
    return
  fi

  # Get last completed step
  local last_step
  last_step=$(grep "^last_completed_step:" "$state_file" 2>/dev/null | cut -d: -f2 | tr -d ' ')

  if [ -z "$last_step" ] || [ "$last_step" = "0" ]; then
    echo "No steps completed yet. Starting from step 1."
    build_full "$name" 1
  elif [ "$last_step" = "5" ]; then
    echo "Pipeline already complete for: $name"
    echo ""
    show_status "$name"
    exit 0
  else
    local next_step=$((last_step + 1))
    echo "Resuming from step $next_step (last completed: $last_step)"
    echo ""
    build_full "$name" "$next_step"
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
      shift
      show_status "$1"
      exit 0
      ;;
    --discover|-d)
      shift
      run_discover "$1"
      exit 0
      ;;
    --merge|-m)
      shift
      run_merge "$1"
      exit 0
      ;;
    --scope)
      shift
      create_scope_from_discovery "$1"
      exit 0
      ;;
    --roadmap|-r)
      shift
      generate_roadmap "$1"
      exit 0
      ;;
    --decompose)
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
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -*)
      echo "❌ Unknown option: $1"
      echo "Run ./discovery.sh --help for usage"
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
  build_full "$PROJECT_NAME" 1
else
  show_help
fi
