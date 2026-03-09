#!/bin/bash
# prd-scope.sh - Orchestrate scope decomposition into PRDs
#
# Usage:
#   ./prd-scope.sh <scope-name>              # Full flow (resume from current phase)
#   ./prd-scope.sh <scope-name> --discover   # Run discovery phase (interactive)
#   ./prd-scope.sh <scope-name> --research   # Research UNKNOWN gaps from discovery
#   ./prd-scope.sh <scope-name> --decompose  # Run decomposition phase
#   ./prd-scope.sh <scope-name> --generate   # Generate all PRDs
#   ./prd-scope.sh <scope-name> --verify     # Run verification phase
#   ./prd-scope.sh <scope-name> --status     # Show status
#   ./prd-scope.sh --list                    # List all scopes
#   ./prd-scope.sh --help                    # Show help
#
# Each phase spawns a fresh Claude instance to avoid context pollution.
# Session state is persisted to .claude/scopes/{scope-name}/
#
# Discovery is INTERACTIVE (user answers questions).
# All other phases use --print mode (non-interactive).

set -uo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# The 12 discovery sections (from discovery.py)
SECTIONS="company_background stakeholders timeline_budget problem_definition business_goals project_scope technical_environment users_audience user_types competitive_landscape risks_assumptions data_reporting"

# Section display names for prettier output
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
  echo "prd-scope.sh - Orchestrate scope decomposition into PRDs"
  echo ""
  echo "Usage:"
  echo "  $0 <scope-name>              # Full flow (resume from current phase)"
  echo "  $0 <scope-name> --discover   # Run discovery phase (INTERACTIVE)"
  echo "  $0 <scope-name> --research   # Research UNKNOWN gaps (optional)"
  echo "  $0 <scope-name> --decompose  # Run decomposition phase"
  echo "  $0 <scope-name> --generate   # Generate all PRDs"
  echo "  $0 <scope-name> --verify     # Run verification and finalize"
  echo "  $0 <scope-name> --status     # Show status"
  echo "  $0 --list                    # List all scopes"
  echo "  $0 --help                    # Show this help"
  echo ""
  echo "Flow:"
  echo "  DISCOVER (12 sections) -> [RESEARCH] -> DECOMPOSE -> GENERATE -> VERIFY"
  echo ""
  echo "Discovery Phase (INTERACTIVE):"
  echo "  - 12 sections, each run as a separate Claude session"
  echo "  - You answer questions interactively"
  echo "  - Progress saved after each section"
  echo "  - Say 'UNKNOWN' for questions you can't answer"
  echo ""
  echo "Research Phase (OPTIONAL):"
  echo "  - Scans discovery for UNKNOWN items"
  echo "  - Does targeted web searches to fill gaps"
  echo "  - Produces research.md with recommendations"
  echo ""
  echo "Other Phases (--print mode):"
  echo "  - Non-interactive, Claude reads files and produces output"
  echo "  - Human checkpoints between phases"
  echo ""
  echo "Resumability:"
  echo "  - Session dies? Just re-run the same command"
  echo "  - Discovery resumes from last incomplete section"
  echo "  - Generation skips already-created PRDs"
  echo "  - All progress saved to .claude/scopes/{scope-name}/"
}

# Handle --help and --list before requiring scope name
case "${1:-}" in
  --help|-h)
    show_help
    exit 0
    ;;
  --list)
    echo "=== Active Scopes ==="
    echo ""
    if [ -d ".claude/scopes" ] && [ "$(ls -A .claude/scopes 2>/dev/null)" ]; then
      for dir in .claude/scopes/*/; do
        if [ -d "$dir" ]; then
          name=$(basename "$dir")
          session="$dir/session.yaml"
          if [ -f "$session" ]; then
            phase=$(grep "^phase:" "$session" 2>/dev/null | cut -d: -f2 | tr -d ' ')
            updated=$(grep "^updated:" "$session" 2>/dev/null | cut -d: -f2- | tr -d ' ')

            # Count completed sections
            sections_done=0
            for section in $SECTIONS; do
              [ -f "$dir/sections/${section}.md" ] && sections_done=$((sections_done + 1))
            done

            echo -e "${BLUE}$name${NC}"
            echo "  Phase: $phase"
            echo "  Discovery: $sections_done/12 sections"
            echo "  Updated: $updated"
            echo ""
          fi
        fi
      done
    else
      echo "No scopes found."
      echo ""
      echo "Create one with:"
      echo "  $0 <scope-name>"
    fi
    exit 0
    ;;
  "")
    echo "Error: scope-name required"
    echo ""
    show_help
    exit 1
    ;;
esac

SCOPE_NAME="$1"
SESSION_DIR=".claude/scopes/$SCOPE_NAME"
SESSION_FILE="$SESSION_DIR/session.yaml"
SECTIONS_DIR="$SESSION_DIR/sections"

# Initialize session if needed
init_session() {
  mkdir -p "$SECTIONS_DIR"
  mkdir -p "$SESSION_DIR/prds"
  if [ ! -f "$SESSION_FILE" ]; then
    echo -e "${GREEN}Creating new scope session: $SCOPE_NAME${NC}"
    cat > "$SESSION_FILE" << EOF
name: $SCOPE_NAME
phase: discovery
created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
discovery:
  complete: false
  sections_done: 0
decomposition:
  complete: false
  approved: false
generation:
  total: 0
  completed: 0
decisions: []
open_questions: []
EOF
  else
    echo -e "${BLUE}Resuming scope session: $SCOPE_NAME${NC}"
  fi
}

# Get current phase from session
get_phase() {
  grep "^phase:" "$SESSION_FILE" 2>/dev/null | cut -d: -f2 | tr -d ' '
}

# Update phase in session
set_phase() {
  sed -i "s/^phase:.*/phase: $1/" "$SESSION_FILE"
  sed -i "s/^updated:.*/updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")/" "$SESSION_FILE"
  echo -e "${GREEN}Phase updated to: $1${NC}"
}

# Count completed sections
count_sections() {
  local count=0
  for section in $SECTIONS; do
    [ -f "$SECTIONS_DIR/${section}.md" ] && count=$((count + 1))
  done
  echo $count
}

# Check for UNKNOWN items in a file
count_unknowns() {
  local file="${1:-$SESSION_DIR/discovery.md}"
  local count=0
  if [ -f "$file" ]; then
    count=$(grep -ci "UNKNOWN\|TBD\|need to research\|not sure" "$file" 2>/dev/null || echo 0)
  fi
  echo $count
}


# Run research phase
run_research() {
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Phase: RESEARCH (Optional)${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo ""

  if [ ! -f "$SESSION_DIR/discovery.md" ]; then
    echo -e "${RED}Error: No discovery.md found. Run discovery first.${NC}"
    echo "$0 $SCOPE_NAME --discover"
    return 1
  fi

  local unknowns=$(count_unknowns)

  if [ "$unknowns" -eq 0 ]; then
    echo -e "${GREEN}No UNKNOWN items found in discovery.${NC}"
    echo "Research phase not needed."
    echo ""
    echo "Continue with: $0 $SCOPE_NAME --decompose"
    return 0
  fi

  echo "Found $unknowns UNKNOWN/TBD items in discovery."
  echo ""
  echo "Researching gaps with targeted web searches..."
  echo ""

  claude --dangerously-skip-permissions --print "/pm:scope-research $SCOPE_NAME"

  # Check if research file was created
  if [ -f "$SESSION_DIR/research.md" ]; then
    echo ""
    echo -e "${GREEN}Research complete!${NC}"
    echo "Review: $SESSION_DIR/research.md"
    echo ""

    # Count resolved vs unresolved
    local resolved=$(grep -c "✓ Recommended\|**Recommendation:**" "$SESSION_DIR/research.md" 2>/dev/null || echo 0)
    local unresolved=$(grep -c "Unresolved\|couldn't be resolved" "$SESSION_DIR/research.md" 2>/dev/null || echo 0)

    echo "Resolved: $resolved gaps"
    [ "$unresolved" -gt 0 ] && echo -e "${YELLOW}Unresolved: $unresolved gaps (may need manual decision)${NC}"
    echo ""
    echo "Continue with: $0 $SCOPE_NAME --decompose"
  else
    echo ""
    echo -e "${YELLOW}Research file not created.${NC}"
    echo "You can skip research and continue: $0 $SCOPE_NAME --decompose"
  fi
}

# Run discovery phase (INTERACTIVE - section by section)
run_discover() {
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Phase 1: DISCOVERY (Interactive)${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo ""
  echo "Discovery consists of 12 sections."
  echo "Each section is a separate interactive session."
  echo "Progress is saved after each section."
  echo ""

  local total=12
  local done=$(count_sections)

  echo -e "Progress: ${CYAN}$done/$total sections complete${NC}"
  echo ""

  # Loop through sections
  for section in $SECTIONS; do
    section_file="$SECTIONS_DIR/${section}.md"
    section_name="${SECTION_NAMES[$section]}"

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
      echo ""

      # Run INTERACTIVE Claude session (no --print!)
      claude --dangerously-skip-permissions "/pm:scope-discover-section $SCOPE_NAME $section"

      # Check if section was completed
      if [ -f "$section_file" ]; then
        echo ""
        echo -e "${GREEN}✓ Section complete: $section_name${NC}"
        done=$((done + 1))

        # Update session file
        sed -i "s/sections_done:.*/sections_done: $done/" "$SESSION_FILE"
        sed -i "s/^updated:.*/updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")/" "$SESSION_FILE"

        # Note: Research happens during the interactive session itself
        # If user said "I don't know", Claude researched and presented options
      else
        echo ""
        echo -e "${YELLOW}Section incomplete: $section_name${NC}"
        echo ""
        echo "Re-run to continue: $0 $SCOPE_NAME --discover"
        return 1
      fi

      # After each section, ask if user wants to continue
      remaining=$((total - done))
      if [ $remaining -gt 0 ]; then
        echo ""
        echo -e "Progress: ${CYAN}$done/$total sections${NC} ($remaining remaining)"
        echo ""
        read -p "Continue to next section? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
          echo ""
          echo "Paused. Resume with: $0 $SCOPE_NAME --discover"
          return 0
        fi
      fi
    fi
  done

  # All sections complete - merge into discovery.md
  echo ""
  echo -e "${GREEN}All 12 sections complete!${NC}"
  echo ""
  echo "Merging sections into discovery.md..."

  claude --dangerously-skip-permissions --print "/pm:scope-discover $SCOPE_NAME"

  # Check if merge succeeded
  if [ -f "$SESSION_DIR/discovery.md" ] && grep -q "discovery_complete: true" "$SESSION_DIR/discovery.md" 2>/dev/null; then
    set_phase "decomposition"
    echo ""
    echo -e "${GREEN}Discovery complete!${NC}"
    echo "Review: $SESSION_DIR/discovery.md"
  else
    echo ""
    echo -e "${YELLOW}Discovery merge may have issues.${NC}"
    echo "Check: $SESSION_DIR/discovery.md"
  fi
}

# Run decomposition phase
run_decompose() {
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Phase 2: DECOMPOSITION${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo ""

  if [ ! -f "$SESSION_DIR/discovery.md" ]; then
    echo -e "${RED}Error: No discovery.md found. Run discovery first.${NC}"
    echo "$0 $SCOPE_NAME --discover"
    return 1
  fi

  echo "Reading discovery and proposing PRD breakdown..."
  echo ""

  claude --dangerously-skip-permissions --print "/pm:scope-decompose $SCOPE_NAME"

  echo ""
  echo -e "${GREEN}Decomposition complete!${NC}"
  echo "Review: $SESSION_DIR/decomposition.md"
  echo ""

  read -p "Approve this breakdown and continue to generation? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    set_phase "generation"
    echo ""
    echo "Continue with: $0 $SCOPE_NAME --generate"
  else
    echo ""
    echo "Edit $SESSION_DIR/decomposition.md as needed."
    echo "Then re-run: $0 $SCOPE_NAME --decompose"
  fi
}

# Run generation phase
run_generate() {
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Phase 3: GENERATE PRDs${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo ""

  if [ ! -f "$SESSION_DIR/decomposition.md" ]; then
    echo -e "${RED}Error: No decomposition.md found. Run decomposition first.${NC}"
    echo "$0 $SCOPE_NAME --decompose"
    return 1
  fi

  # Extract PRD names from decomposition.md
  # Look for lines like "## PRD: 85-user-auth" or "### PRD: 85-user-auth"
  PRD_NAMES=$(grep -E "^#+ PRD: " "$SESSION_DIR/decomposition.md" | sed 's/^#* PRD: //' | tr -d '\r')

  if [ -z "$PRD_NAMES" ]; then
    echo -e "${YELLOW}No PRDs found in decomposition.md${NC}"
    echo "Expected format: '## PRD: 85-feature-name'"
    return 1
  fi

  TOTAL=$(echo "$PRD_NAMES" | wc -l)
  CURRENT=0

  echo "Generating $TOTAL PRDs..."
  echo ""

  GENERATED=0
  SKIPPED=0

  while IFS= read -r prd; do
    # Skip empty lines
    [ -z "$prd" ] && continue

    CURRENT=$((CURRENT + 1))
    PRD_FILE="$SESSION_DIR/prds/$prd.md"

    # Skip if already generated
    if [ -f "$PRD_FILE" ]; then
      echo -e "${GREEN}[$CURRENT/$TOTAL] ✓ $prd (already exists)${NC}"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi

    echo -e "${BLUE}[$CURRENT/$TOTAL] Generating: $prd${NC}"
    echo ""

    claude --dangerously-skip-permissions --print "/pm:scope-generate $SCOPE_NAME $prd"

    echo ""
    if [ -f "$PRD_FILE" ]; then
      echo -e "${GREEN}Created: $PRD_FILE${NC}"
      GENERATED=$((GENERATED + 1))
    else
      echo -e "${YELLOW}Warning: PRD file not created${NC}"
    fi
    echo ""
  done <<< "$PRD_NAMES"

  echo ""
  echo "Generated: $GENERATED, Skipped: $SKIPPED (already existed)"

  set_phase "verification"
  echo ""
  echo -e "${GREEN}All PRDs generated!${NC}"
  echo "Continue with: $0 $SCOPE_NAME --verify"
}

# Run verification phase
run_verify() {
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Phase 4: VERIFICATION${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo ""

  # Check PRDs exist
  PRD_COUNT=$(ls "$SESSION_DIR/prds/"*.md 2>/dev/null | wc -l)
  if [ "$PRD_COUNT" -eq 0 ]; then
    echo -e "${RED}Error: No PRDs found in $SESSION_DIR/prds/${NC}"
    echo "Run generation first: $0 $SCOPE_NAME --generate"
    return 1
  fi

  echo "Verifying $PRD_COUNT PRDs against discovery..."
  echo ""

  claude --dangerously-skip-permissions --print "/pm:scope-verify $SCOPE_NAME"

  echo ""
  echo -e "${GREEN}Verification complete!${NC}"
  echo "Review: $SESSION_DIR/verification.md"
  echo ""

  # Check if gaps found
  if [ -f "$SESSION_DIR/verification.md" ] && \
     grep -q "## Gaps Found" "$SESSION_DIR/verification.md" && \
     ! grep -q "No gaps found" "$SESSION_DIR/verification.md"; then
    echo -e "${YELLOW}Gaps detected in coverage.${NC}"
    echo ""
    read -p "Address gaps before finalizing? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo ""
      echo "Options:"
      echo "  1. Edit decomposition.md and re-run: $0 $SCOPE_NAME --decompose"
      echo "  2. Manually add PRDs to $SESSION_DIR/prds/"
      echo "  3. Re-run verify when ready: $0 $SCOPE_NAME --verify"
      return
    fi
  fi

  # Finalize - move PRDs to main directory
  echo ""
  echo "Moving PRDs to .claude/prds/..."
  mv "$SESSION_DIR/prds/"*.md .claude/prds/ 2>/dev/null || true

  set_phase "complete"
  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════${NC}"
  echo -e "${GREEN}  SCOPE COMPLETE: $SCOPE_NAME${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════${NC}"
  echo ""
  echo "PRDs created in .claude/prds/"
  echo ""
  echo "Next: Process PRDs with batch-prd-complete.sh"
}

# Show status
run_status() {
  claude --dangerously-skip-permissions --print "/pm:scope-status $SCOPE_NAME"
}

# Main flow
case "${2:-}" in
  --discover)
    init_session
    run_discover
    ;;
  --research)
    if [ ! -f "$SESSION_FILE" ]; then
      echo -e "${RED}Error: No session found for $SCOPE_NAME${NC}"
      echo "Start with: $0 $SCOPE_NAME"
      exit 1
    fi
    run_research
    ;;
  --decompose)
    if [ ! -f "$SESSION_FILE" ]; then
      echo -e "${RED}Error: No session found for $SCOPE_NAME${NC}"
      echo "Start with: $0 $SCOPE_NAME"
      exit 1
    fi
    run_decompose
    ;;
  --generate)
    if [ ! -f "$SESSION_FILE" ]; then
      echo -e "${RED}Error: No session found for $SCOPE_NAME${NC}"
      exit 1
    fi
    run_generate
    ;;
  --verify)
    if [ ! -f "$SESSION_FILE" ]; then
      echo -e "${RED}Error: No session found for $SCOPE_NAME${NC}"
      exit 1
    fi
    run_verify
    ;;
  --status)
    if [ ! -f "$SESSION_FILE" ]; then
      echo -e "${RED}Error: No session found for $SCOPE_NAME${NC}"
      exit 1
    fi
    run_status
    ;;
  "")
    # Full flow with checkpoints - resume from current phase
    init_session

    phase=$(get_phase)
    echo "Current phase: $phase"
    echo ""

    case "$phase" in
      discovery)
        run_discover
        if [ "$(get_phase)" = "decomposition" ]; then
          echo ""
          read -p "Continue to decomposition? (y/n) " -n 1 -r
          echo
          [[ $REPLY =~ ^[Yy]$ ]] && run_decompose
        fi
        ;;
      decomposition)
        run_decompose
        ;;
      generation)
        run_generate
        ;;
      verification)
        run_verify
        ;;
      complete)
        echo -e "${GREEN}Scope '$SCOPE_NAME' already complete.${NC}"
        echo ""
        echo "PRDs in .claude/prds/"
        echo ""
        echo "To process them:"
        echo "  .claude/scripts/batch-prd-complete.sh <prd-numbers>"
        ;;
      *)
        echo -e "${RED}Unknown phase: $phase${NC}"
        echo "Check $SESSION_FILE"
        exit 1
        ;;
    esac
    ;;
  *)
    echo -e "${RED}Unknown option: $2${NC}"
    echo ""
    show_help
    exit 1
    ;;
esac
