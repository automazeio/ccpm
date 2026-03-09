#!/bin/bash
# test-e2e.sh - End-to-end test harness for Robert PM system
#
# Validates the complete pipeline:
# interrogation → extract → credentials → roadmap → PRDs → batch-process
#
# Usage:
#   ./test-e2e.sh <scenario.yaml>           # Run single scenario
#   ./test-e2e.sh --all                     # Run all scenarios
#   ./test-e2e.sh --verbose <scenario.yaml> # Verbose output
#   ./test-e2e.sh --keep <scenario.yaml>    # Preserve temp directory
#   ./test-e2e.sh --dry-run <scenario.yaml> # Show what would run

set -euo pipefail

# Script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
SCENARIOS_DIR="$SCRIPT_DIR/scenarios"

# Load library modules
source "$LIB_DIR/scenario-loader.sh"
source "$LIB_DIR/assertions.sh"
source "$LIB_DIR/report.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
VERBOSE=false
KEEP_TEMP=false
DRY_RUN=false
PARALLEL=false
RUN_ALL=false
TIMEOUT=1800  # 30 minutes default timeout

# Temp directory for test run
TEST_DIR=""
LOG_FILE=""
RESPONSE_FILE=""

# Cleanup handler
cleanup() {
    local exit_code=$?

    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        if [[ "$KEEP_TEMP" == "true" || $exit_code -ne 0 ]]; then
            echo -e "\n${YELLOW}Test directory preserved:${NC} $TEST_DIR"
        else
            rm -rf "$TEST_DIR"
        fi
    fi

    exit $exit_code
}

trap cleanup EXIT INT TERM

# Print usage
usage() {
    cat << EOF
E2E Test Harness for Robert PM System

Usage:
  $(basename "$0") [options] <scenario.yaml>
  $(basename "$0") --all [options]

Options:
  --all             Run all scenarios in scenarios directory
  --verbose, -v     Enable verbose output
  --keep, -k        Keep temp directory after test (always kept on failure)
  --dry-run         Show what would be executed without running
  --timeout <sec>   Set timeout in seconds (default: 1800)
  --help, -h        Show this help message

Examples:
  $(basename "$0") scenarios/inventory.yaml
  $(basename "$0") --verbose --keep scenarios/simple-crud.yaml
  $(basename "$0") --all
  $(basename "$0") --dry-run scenarios/saas-auth.yaml

Scenario File Format:
  See scenarios/example.yaml for full schema documentation.
EOF
}

# Global variable for scenario file (set by parse_args)
SCENARIO_ARG=""

# Parse command line arguments
# Sets global variables: VERBOSE, KEEP_TEMP, DRY_RUN, RUN_ALL, TIMEOUT, SCENARIO_ARG
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all)
                RUN_ALL=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --keep|-k)
                KEEP_TEMP=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                usage
                exit 1
                ;;
            *)
                SCENARIO_ARG="$1"
                shift
                ;;
        esac
    done

    if [[ "$RUN_ALL" == "false" && -z "$SCENARIO_ARG" ]]; then
        echo -e "${RED}Error: No scenario file specified${NC}" >&2
        usage
        exit 1
    fi
}

# Setup isolated test environment
setup_environment() {
    local scenario_name="$1"

    report_stage_start "Setting up environment"

    # Create temp directory
    TEST_DIR=$(mktemp -d "/tmp/robert-e2e-${scenario_name}-XXXXXX")
    LOG_FILE="$TEST_DIR/test.log"
    RESPONSE_FILE="$TEST_DIR/responses.txt"

    mkdir -p "$TEST_DIR/.claude/scopes/${scenario_name}"
    mkdir -p "$TEST_DIR/.claude/prds"
    mkdir -p "$TEST_DIR/.claude/logs"
    mkdir -p "$TEST_DIR/.claude/commands/pm"

    # Initialize git repo
    cd "$TEST_DIR"
    git init -q
    git config user.email "test@e2e.local"
    git config user.name "E2E Test"

    # Copy essential files from project
    cp -r "$PROJECT_ROOT/.claude/commands" "$TEST_DIR/.claude/" 2>/dev/null || true
    cp -r "$PROJECT_ROOT/.claude/scripts" "$TEST_DIR/.claude/" 2>/dev/null || true
    cp -r "$PROJECT_ROOT/.claude/rules" "$TEST_DIR/.claude/" 2>/dev/null || true
    cp -r "$PROJECT_ROOT/.claude/agents" "$TEST_DIR/.claude/" 2>/dev/null || true

    # Create initial commit
    echo "# E2E Test: $scenario_name" > README.md
    git add .
    git commit -q -m "Initial commit for E2E test"

    # Generate mock .env from scenario
    if [[ -f "$SCENARIO_FILE" ]]; then
        generate_mock_env "$SCENARIO_FILE" "$TEST_DIR/.env"
    fi

    report_stage_end "pass" "Environment ready"

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "  ${CYAN}Test directory:${NC} $TEST_DIR"
    fi
}

# Generate response script for Claude
generate_responses() {
    local scenario_file="$1"

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "  ${CYAN}Generating response script...${NC}"
    fi

    generate_response_script "$scenario_file" "$RESPONSE_FILE"

    # Add a final "done" response
    echo "done" >> "$RESPONSE_FILE"
    echo "yes" >> "$RESPONSE_FILE"
}

# Run a PM command with automated responses
# Usage: run_pm_command <command> [args...]
run_pm_command() {
    local command="$1"
    shift
    local args=("$@")

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "  ${CYAN}Running:${NC} /pm:$command ${args[*]}"
    fi

    # Build the prompt based on the command
    local prompt
    case "$command" in
        interrogate)
            prompt="Run /pm:interrogate with the following app description and answer the questions:"
            ;;
        extract-findings)
            prompt="Run /pm:extract-findings"
            ;;
        gather-credentials)
            prompt="Run /pm:gather-credentials"
            ;;
        roadmap-generate)
            prompt="Run /pm:roadmap-generate"
            ;;
        scope-generate)
            prompt="Run /pm:scope-generate ${args[*]}"
            ;;
        batch-process)
            prompt="Run /pm:batch-process ${args[*]}"
            ;;
        *)
            prompt="Run /pm:$command ${args[*]}"
            ;;
    esac

    # Run with timeout
    local exit_code=0
    timeout "$TIMEOUT" claude --print "$prompt" >> "$LOG_FILE" 2>&1 || exit_code=$?

    if [[ $exit_code -eq 124 ]]; then
        report_error "Command timed out after ${TIMEOUT}s: /pm:$command"
        return 1
    elif [[ $exit_code -ne 0 ]]; then
        report_error "Command failed with exit code $exit_code: /pm:$command"
        return 1
    fi

    return 0
}

# Run the interrogation phase
run_interrogation() {
    local app_description
    app_description=$(get_app_description "$SCENARIO_FILE")

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would run interrogation with description:"
        echo "$app_description" | head -5
        return 0
    fi

    # For interrogation, we use a more controlled approach
    # Write the app description to a temp file
    local desc_file="$TEST_DIR/app_description.txt"
    echo "$app_description" > "$desc_file"

    # Run Claude with the description
    local prompt="Start the interrogation process for a new application. Here is the description:

$app_description

Please proceed with /pm:interrogate and generate all required scope documents."

    timeout "$TIMEOUT" claude --print "$prompt" >> "$LOG_FILE" 2>&1 || {
        report_error "Interrogation phase failed or timed out"
        return 1
    }

    return 0
}

# Run the extraction phase
run_extraction() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would run /pm:extract-findings"
        return 0
    fi

    local prompt="Extract findings from the interrogation. Run /pm:extract-findings"

    timeout "$TIMEOUT" claude --print "$prompt" >> "$LOG_FILE" 2>&1 || {
        report_error "Extraction phase failed or timed out"
        return 1
    }

    return 0
}

# Run roadmap generation
run_roadmap() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would run /pm:roadmap-generate"
        return 0
    fi

    local prompt="Generate the product roadmap. Run /pm:roadmap-generate"

    timeout "$TIMEOUT" claude --print "$prompt" >> "$LOG_FILE" 2>&1 || {
        report_error "Roadmap generation failed or timed out"
        return 1
    }

    return 0
}

# Run PRD generation (batch process)
run_prd_generation() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would run /pm:batch-process"
        return 0
    fi

    local prompt="Generate all PRDs from the roadmap. Run /pm:batch-process"

    timeout "$TIMEOUT" claude --print "$prompt" >> "$LOG_FILE" 2>&1 || {
        report_error "PRD generation failed or timed out"
        return 1
    }

    return 0
}

# Run the complete pipeline
run_pipeline() {
    report_stage_start "Running pipeline"

    cd "$TEST_DIR"

    # Phase 1: Interrogation
    echo -e "  ${BLUE}Phase 1:${NC} Interrogation"
    run_interrogation || {
        report_stage_end "fail" "Interrogation failed"
        return 1
    }

    # Phase 2: Extract findings
    echo -e "  ${BLUE}Phase 2:${NC} Extract findings"
    run_extraction || {
        report_stage_end "fail" "Extraction failed"
        return 1
    }

    # Phase 3: Roadmap generation
    echo -e "  ${BLUE}Phase 3:${NC} Roadmap generation"
    run_roadmap || {
        report_stage_end "fail" "Roadmap generation failed"
        return 1
    }

    # Phase 4: PRD generation
    echo -e "  ${BLUE}Phase 4:${NC} PRD generation"
    run_prd_generation || {
        report_stage_end "fail" "PRD generation failed"
        return 1
    }

    report_stage_end "pass" "Pipeline complete"
    return 0
}

# Verify outputs against expected results
verify_outputs() {
    report_stage_start "Verifying outputs"

    reset_assertions
    cd "$TEST_DIR"

    local scope_dir=".claude/scopes/${SCENARIO_NAME}"
    local prds_dir=".claude/prds"

    # Check scope files exist
    if [[ ${#EXPECTED_SCOPE_FILES[@]} -gt 0 ]]; then
        echo -e "  ${BLUE}Checking scope files...${NC}"
        assert_scope_complete "$scope_dir" EXPECTED_SCOPE_FILES
    fi

    # Check features extraction
    if [[ $EXPECTED_FEATURES_MIN -gt 0 ]]; then
        echo -e "  ${BLUE}Checking features...${NC}"
        local features_file="$scope_dir/01_features.md"
        if [[ -f "$features_file" ]]; then
            assert_features_extracted "$features_file" "$EXPECTED_FEATURES_MIN" EXPECTED_FEATURES_MUST_INCLUDE
        else
            record_assertion "fail" "Features file not found: $features_file"
        fi
    fi

    # Check PRDs generated
    if [[ $EXPECTED_PRDS_MIN -gt 0 ]]; then
        echo -e "  ${BLUE}Checking PRDs...${NC}"
        assert_prds_generated "$prds_dir" "$EXPECTED_PRDS_MIN" "$EXPECTED_PRDS_MAX"
    fi

    # Check journeys extraction
    if [[ $EXPECTED_JOURNEYS_MIN -gt 0 ]]; then
        echo -e "  ${BLUE}Checking journeys...${NC}"
        local journeys_file="$scope_dir/02_user_journeys.md"
        if [[ -f "$journeys_file" ]]; then
            assert_journeys_extracted "$journeys_file" "$EXPECTED_JOURNEYS_MIN" EXPECTED_JOURNEYS_MUST_INCLUDE
        else
            record_assertion "fail" "Journeys file not found: $journeys_file"
        fi
    fi

    # Check for errors in log
    echo -e "  ${BLUE}Checking for errors...${NC}"
    assert_no_errors "$LOG_FILE"

    # Record metrics
    local prd_count
    prd_count=$(find "$prds_dir" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    report_metric "prds_generated" "$prd_count"

    if [[ -d "$scope_dir" ]]; then
        local scope_files
        scope_files=$(find "$scope_dir" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
        report_metric "scope_files" "$scope_files"
    fi

    # Determine stage result
    if assertions_passed; then
        report_stage_end "pass" "All assertions passed ($ASSERTIONS_PASSED/$ASSERTIONS_TOTAL)"
        return 0
    else
        report_stage_end "fail" "$ASSERTIONS_FAILED assertions failed"
        return 1
    fi
}

# Generate final report
generate_report() {
    local status="$1"

    report_stage_start "Generating report"

    # Finalize report data
    report_finalize "$status"

    # End the stage first (so file reports have correct duration)
    report_stage_end "pass" "Reports saved to $TEST_DIR"

    # Save reports (now all stages have correct durations)
    report_json "$TEST_DIR/report.json"
    report_markdown "$TEST_DIR/report.md"

    # Print console summary
    report_console
}

# Run a single scenario
run_scenario() {
    local scenario_file="$1"

    # Resolve relative path
    if [[ ! -f "$scenario_file" ]]; then
        scenario_file="$SCENARIOS_DIR/$scenario_file"
    fi

    if [[ ! -f "$scenario_file" ]]; then
        echo -e "${RED}Error: Scenario file not found: $scenario_file${NC}" >&2
        return 1
    fi

    # Convert to absolute path early
    scenario_file="$(cd "$(dirname "$scenario_file")" && pwd)/$(basename "$scenario_file")"

    # Load scenario
    load_scenario "$scenario_file" || {
        echo -e "${RED}Error: Failed to load scenario${NC}" >&2
        return 1
    }

    # Initialize report
    report_init "$SCENARIO_NAME" "$scenario_file" ""

    echo -e "\n${BOLD}=== E2E Test: $SCENARIO_NAME ===${NC}\n"

    if [[ "$VERBOSE" == "true" ]]; then
        print_scenario_summary
        echo ""
    fi

    # Setup environment first (creates RESPONSE_FILE path)
    setup_environment "$SCENARIO_NAME"

    # Generate responses (now RESPONSE_FILE is set)
    generate_responses "$scenario_file"

    # Update report with test dir
    REPORT_TEST_DIR="$TEST_DIR"

    # Run pipeline (or dry-run)
    local pipeline_status=0
    if [[ "$DRY_RUN" == "true" ]]; then
        report_stage_start "Running pipeline (DRY-RUN)"
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would execute full pipeline"
        run_interrogation
        run_extraction
        run_roadmap
        run_prd_generation
        report_stage_end "pass" "Dry run complete"
    else
        run_pipeline || pipeline_status=1
    fi

    # Verify outputs (skip for dry-run)
    local verify_status=0
    if [[ "$DRY_RUN" == "true" ]]; then
        report_stage_start "Verifying outputs (DRY-RUN)"
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would verify:"
        echo "    - Scope files: ${#EXPECTED_SCOPE_FILES[@]} expected"
        echo "    - Features: min $EXPECTED_FEATURES_MIN"
        echo "    - PRDs: $EXPECTED_PRDS_MIN - $EXPECTED_PRDS_MAX"
        echo "    - Journeys: min $EXPECTED_JOURNEYS_MIN"
        report_stage_end "pass" "Verification plan ready"
    else
        verify_outputs || verify_status=1
    fi

    # Determine final status
    local final_status="pass"
    if [[ $pipeline_status -ne 0 || $verify_status -ne 0 ]]; then
        final_status="fail"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        final_status="dry-run"
    fi

    # Generate report
    generate_report "$final_status"

    # Return status
    [[ "$final_status" == "pass" || "$final_status" == "dry-run" ]]
}

# Run all scenarios
run_all_scenarios() {
    local scenarios=()
    local passed=0
    local failed=0

    # Find all scenario files
    shopt -s nullglob
    for scenario in "$SCENARIOS_DIR"/*.yaml "$SCENARIOS_DIR"/*.yml; do
        scenarios+=("$scenario")
    done
    shopt -u nullglob

    if [[ ${#scenarios[@]} -eq 0 ]]; then
        echo -e "${RED}No scenarios found in $SCENARIOS_DIR${NC}" >&2
        return 1
    fi

    echo -e "${BOLD}Running ${#scenarios[@]} scenarios${NC}\n"

    for scenario in "${scenarios[@]}"; do
        local scenario_name
        scenario_name=$(basename "$scenario" .yaml)
        scenario_name=$(basename "$scenario_name" .yml)

        echo -e "${CYAN}[$((passed + failed + 1))/${#scenarios[@]}]${NC} $scenario_name"

        if run_scenario "$scenario"; then
            passed=$((passed + 1))
        else
            failed=$((failed + 1))
        fi

        # Reset for next scenario
        TEST_DIR=""
    done

    # Summary
    echo -e "\n${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}Summary: $passed passed, $failed failed (${#scenarios[@]} total)${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"

    [[ $failed -eq 0 ]]
}

# Main entry point
main() {
    # Parse args directly (not in subshell) so globals are set
    parse_args "$@"

    if [[ "$RUN_ALL" == "true" ]]; then
        run_all_scenarios
    else
        run_scenario "$SCENARIO_ARG"
    fi
}

# Run main
main "$@"
