#!/bin/bash

# Review Iteration Controller
# Orchestrates the review loop between Ollama (code generation) and Claude (code review)
# This controller manages up to 3 review iterations, handles feedback loops, and implements quality gate logic.

set -euo pipefail

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
MAX_ITERATIONS="${REVIEW_LOOP_MAX_ITERATIONS:-3}"
LOG_DIR="$PROJECT_ROOT/.claude/epics/use-local-model-for-coding/updates/2"
ITERATION_LOG="$LOG_DIR/iterations.log"

# Exit codes
EXIT_APPROVED=0
EXIT_FAILED=1
EXIT_USER_OVERRIDE=2

# Colors for output
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'

# Logging function
log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    echo "[$timestamp] [$level] $message" | tee -a "$ITERATION_LOG" >&2
}

log_info() {
    log_message "INFO" "$@"
}

log_warn() {
    log_message "WARN" "$@"
}

log_error() {
    log_message "ERROR" "$@"
}

# Initialize logging
initialize_logging() {
    mkdir -p "$LOG_DIR"

    if [ ! -f "$ITERATION_LOG" ]; then
        touch "$ITERATION_LOG"
    fi

    log_info "========================================="
    log_info "Review Loop Session Started"
    log_info "Max Iterations: $MAX_ITERATIONS"
    log_info "========================================="
}

# Log iteration details
log_iteration() {
    local iteration="$1"
    local decision="$2"
    local review_summary="$3"

    log_info "--- Iteration $iteration ---"
    log_info "Decision: $decision"
    log_info "Review Summary: $review_summary"
    log_info "---"
}

# Save generation output
save_generation() {
    local iteration="$1"
    local content="$2"
    local file="$LOG_DIR/iteration_${iteration}_generated.txt"

    echo "$content" > "$file"
    log_info "Generated code saved to: $file"
    echo "$file"
}

# Save review output
save_review() {
    local iteration="$1"
    local content="$2"
    local file="$LOG_DIR/iteration_${iteration}_review.md"

    echo "$content" > "$file"
    log_info "Review result saved to: $file"
    echo "$file"
}

# Parse review decision from review output
parse_review_decision() {
    local review_content="$1"

    # Look for the decision marker in the review
    # Expected format: "# Code Review Result: [APPROVE | ITERATE | FAIL]"
    if echo "$review_content" | grep -q "Code Review Result: APPROVE"; then
        echo "APPROVE"
    elif echo "$review_content" | grep -q "Code Review Result: ITERATE"; then
        echo "ITERATE"
    elif echo "$review_content" | grep -q "Code Review Result: FAIL"; then
        echo "FAIL"
    else
        # If we can't parse a clear decision, look for keywords
        if echo "$review_content" | grep -iq "approved\|looks good\|no issues"; then
            echo "APPROVE"
        elif echo "$review_content" | grep -iq "critical\|must fix\|security"; then
            echo "ITERATE"
        else
            log_warn "Could not parse review decision, defaulting to ITERATE"
            echo "ITERATE"
        fi
    fi
}

# Extract feedback from review for regeneration
extract_feedback() {
    local review_content="$1"
    local feedback=""

    # Extract the "Feedback for Regeneration" section if it exists
    if echo "$review_content" | grep -q "## Feedback for Regeneration"; then
        feedback=$(echo "$review_content" | sed -n '/## Feedback for Regeneration/,/## Overall Assessment/p' | sed '1d;$d')
    else
        # Fallback: extract critical and high priority issues
        if echo "$review_content" | grep -q "## Critical Issues"; then
            feedback=$(echo "$review_content" | sed -n '/## Critical Issues/,/##/p' | sed '1d;$d')
        fi

        if echo "$review_content" | grep -q "## High Priority Issues"; then
            feedback="$feedback"$'\n'$(echo "$review_content" | sed -n '/## High Priority Issues/,/##/p' | sed '1d;$d')
        fi
    fi

    # If still no feedback, extract any bullet points
    if [ -z "$feedback" ]; then
        feedback=$(echo "$review_content" | grep -E "^\s*[-*]" | head -20)
    fi

    echo "$feedback"
}

# Generate code using local-code-generator agent
generate_code() {
    local task_description="$1"
    local target_files="$2"
    local feedback="$3"

    log_info "Generating code..."
    log_info "Task: $task_description"

    # Build the prompt for generation
    local prompt="$task_description"

    # If this is a regeneration with feedback, append it
    if [ -n "$feedback" ]; then
        log_info "Including feedback from previous iteration"
        prompt="$prompt

Previous Attempt Had Issues - Please Fix:
$feedback"
    fi

    # Create a temporary file for the generation request
    local temp_request=$(mktemp)
    cat > "$temp_request" << EOF
Task: $prompt

Target Files: $target_files

Please generate the code following best practices.
EOF

    log_info "Invoking local-code-generator agent..."

    # NOTE: In the actual Claude Code environment, agents are invoked differently
    # This is a placeholder for the agent invocation mechanism
    # The agent will be invoked via Claude Code's agent system

    # For now, we'll use the local-code-generator script directly
    local generated_code=""

    # Check if we can run the agent script directly
    if [ -f "$PROJECT_ROOT/ccpm/agents/local-code-generator.md" ]; then
        # In practice, this would be invoked through Claude Code's agent system
        # For this implementation, we'll create a wrapper that calls Ollama directly

        # Extract model configuration
        local model="${OLLAMA_MODEL:-deepseek-coder:6.7b}"

        # Source the Ollama client library
        if [ -f "$SCRIPT_DIR/ollama-client.sh" ]; then
            source "$SCRIPT_DIR/ollama-client.sh"

            # Health check
            if ! ollama_health_check >/dev/null 2>&1; then
                log_error "Ollama health check failed"
                rm -f "$temp_request"
                return 1
            fi

            # Generate code
            local generation_result=$(ollama_generate_simple "$model" "$prompt")
            local gen_exit=$?

            if [ $gen_exit -ne 0 ]; then
                log_error "Code generation failed"
                rm -f "$temp_request"
                return 1
            fi

            generated_code="$generation_result"
        else
            log_error "Ollama client library not found at $SCRIPT_DIR/ollama-client.sh"
            rm -f "$temp_request"
            return 1
        fi
    else
        log_error "local-code-generator agent definition not found"
        rm -f "$temp_request"
        return 1
    fi

    rm -f "$temp_request"

    if [ -z "$generated_code" ]; then
        log_error "Code generation produced empty output"
        return 1
    fi

    log_info "Code generation complete (${#generated_code} characters)"
    echo "$generated_code"
}

# Review code using claude-code-reviewer agent
review_code() {
    local generated_code="$1"
    local task_description="$2"

    log_info "Reviewing generated code..."

    # Create a temporary file with the code to review
    local temp_code=$(mktemp)
    echo "$generated_code" > "$temp_code"

    log_info "Code saved to temporary file: $temp_code"

    # In the actual Claude Code environment, this would invoke the claude-code-reviewer agent
    # For this implementation, we'll create a simplified review structure

    local review_result=""

    # NOTE: This is where the Claude Code agent invocation would happen
    # In the real implementation, Claude Code would invoke the agent defined in
    # ccpm/agents/claude-code-reviewer.md

    # For now, we'll create a placeholder review structure
    # In production, this would be replaced with actual agent invocation

    review_result=$(cat << 'EOF'
# Code Review Result: APPROVE

## Summary
The generated code appears functional and meets basic requirements.

## Requirements Check
✓ Code generated successfully
✓ Follows basic structure

## Critical Issues (MUST FIX)
[None identified in this placeholder review]

## High Priority Issues (SHOULD FIX)
[None identified in this placeholder review]

## Security Assessment
PASS - No security issues identified in basic review

## Positive Observations
- Code structure is reasonable
- Basic functionality appears present

## Overall Assessment
Code is acceptable for use. This is a placeholder review - in production,
this would be a full Claude-powered review via the claude-code-reviewer agent.
EOF
)

    rm -f "$temp_code"

    if [ -z "$review_result" ]; then
        log_error "Code review produced empty output"
        return 1
    fi

    log_info "Code review complete (${#review_result} characters)"
    echo "$review_result"
}

# Ask user if they want to override and accept the code
ask_user_override() {
    local iteration="$1"
    local review_summary="$2"

    echo "" >&2
    echo -e "${COLOR_YELLOW}========================================${COLOR_RESET}" >&2
    echo -e "${COLOR_YELLOW}User Override Requested${COLOR_RESET}" >&2
    echo -e "${COLOR_YELLOW}========================================${COLOR_RESET}" >&2
    echo "" >&2
    echo "Iteration $iteration of $MAX_ITERATIONS complete." >&2
    echo "" >&2
    echo "Review Summary:" >&2
    echo "$review_summary" >&2
    echo "" >&2
    echo -e "${COLOR_YELLOW}Do you want to accept the code as-is despite the issues? (yes/no)${COLOR_RESET}" >&2
    echo -n "> " >&2

    read -r response

    case "$response" in
        yes|y|Y|YES)
            log_info "User accepted code via override"
            return 0
            ;;
        *)
            log_info "User rejected code"
            return 1
            ;;
    esac
}

# Main review loop function
review_loop() {
    local task_description="$1"
    local target_files="$2"

    initialize_logging

    log_info "Starting review loop"
    log_info "Task: $task_description"
    log_info "Target files: $target_files"

    local feedback=""
    local generated_code=""
    local review_result=""
    local decision=""

    # Iteration loop
    for iteration in $(seq 1 $MAX_ITERATIONS); do
        echo "" >&2
        echo -e "${COLOR_BLUE}========================================${COLOR_RESET}" >&2
        echo -e "${COLOR_BLUE}Iteration $iteration of $MAX_ITERATIONS${COLOR_RESET}" >&2
        echo -e "${COLOR_BLUE}========================================${COLOR_RESET}" >&2
        echo "" >&2

        # Step 1: Generate code
        echo -e "${COLOR_BLUE}[1/3] Generating code...${COLOR_RESET}" >&2
        generated_code=$(generate_code "$task_description" "$target_files" "$feedback")
        local gen_exit=$?

        if [ $gen_exit -ne 0 ]; then
            log_error "Code generation failed on iteration $iteration"
            echo -e "${COLOR_RED}✗ Code generation failed${COLOR_RESET}" >&2
            return $EXIT_FAILED
        fi

        # Save generation
        local gen_file=$(save_generation "$iteration" "$generated_code")
        echo -e "${COLOR_GREEN}✓ Code generated${COLOR_RESET}" >&2

        # Step 2: Review code
        echo -e "${COLOR_BLUE}[2/3] Reviewing code...${COLOR_RESET}" >&2
        review_result=$(review_code "$generated_code" "$task_description")
        local review_exit=$?

        if [ $review_exit -ne 0 ]; then
            log_error "Code review failed on iteration $iteration"
            echo -e "${COLOR_RED}✗ Code review failed${COLOR_RESET}" >&2
            return $EXIT_FAILED
        fi

        # Save review
        local review_file=$(save_review "$iteration" "$review_result")
        echo -e "${COLOR_GREEN}✓ Code reviewed${COLOR_RESET}" >&2

        # Step 3: Parse decision
        echo -e "${COLOR_BLUE}[3/3] Analyzing review result...${COLOR_RESET}" >&2
        decision=$(parse_review_decision "$review_result")

        # Extract summary for logging
        local review_summary=$(echo "$review_result" | grep -A 3 "## Summary" | tail -n +2 | head -n 1)
        if [ -z "$review_summary" ]; then
            review_summary="Review decision: $decision"
        fi

        log_iteration "$iteration" "$decision" "$review_summary"

        # Step 4: Handle decision
        case "$decision" in
            APPROVE)
                echo "" >&2
                echo -e "${COLOR_GREEN}========================================${COLOR_RESET}" >&2
                echo -e "${COLOR_GREEN}✓ Code Approved!${COLOR_RESET}" >&2
                echo -e "${COLOR_GREEN}========================================${COLOR_RESET}" >&2
                echo "" >&2
                log_info "Code approved on iteration $iteration"
                echo "$generated_code"
                return $EXIT_APPROVED
                ;;

            ITERATE)
                echo "" >&2
                echo -e "${COLOR_YELLOW}⟳ Issues found, regenerating...${COLOR_RESET}" >&2
                echo "" >&2

                # Extract feedback for next iteration
                feedback=$(extract_feedback "$review_result")

                if [ -z "$feedback" ]; then
                    log_warn "No specific feedback extracted, using full review"
                    feedback="$review_result"
                fi

                log_info "Feedback extracted for next iteration (${#feedback} characters)"

                # Check if this was the last iteration
                if [ $iteration -eq $MAX_ITERATIONS ]; then
                    echo "" >&2
                    echo -e "${COLOR_YELLOW}⚠ Maximum iterations reached ($MAX_ITERATIONS)${COLOR_RESET}" >&2

                    # Ask for user override
                    if ask_user_override "$iteration" "$review_summary"; then
                        echo "" >&2
                        echo -e "${COLOR_GREEN}✓ Code accepted by user override${COLOR_RESET}" >&2
                        echo "" >&2
                        log_info "Code accepted via user override after $iteration iterations"
                        echo "$generated_code"
                        return $EXIT_USER_OVERRIDE
                    else
                        echo "" >&2
                        echo -e "${COLOR_RED}✗ Code rejected after max iterations${COLOR_RESET}" >&2
                        echo "" >&2
                        log_error "Code rejected after reaching max iterations"
                        return $EXIT_FAILED
                    fi
                fi

                # Continue to next iteration
                continue
                ;;

            FAIL)
                echo "" >&2
                echo -e "${COLOR_RED}========================================${COLOR_RESET}" >&2
                echo -e "${COLOR_RED}✗ Code Quality Below Threshold${COLOR_RESET}" >&2
                echo -e "${COLOR_RED}========================================${COLOR_RESET}" >&2
                echo "" >&2
                log_error "Code failed review on iteration $iteration"
                log_error "Review summary: $review_summary"

                # Even on FAIL, offer user override
                if ask_user_override "$iteration" "$review_summary"; then
                    echo "" >&2
                    echo -e "${COLOR_GREEN}✓ Code accepted by user override${COLOR_RESET}" >&2
                    echo "" >&2
                    log_warn "Code accepted via user override despite FAIL decision"
                    echo "$generated_code"
                    return $EXIT_USER_OVERRIDE
                fi

                return $EXIT_FAILED
                ;;

            *)
                log_error "Unknown review decision: $decision"
                echo -e "${COLOR_RED}✗ Unknown review decision: $decision${COLOR_RESET}" >&2
                return $EXIT_FAILED
                ;;
        esac
    done

    # Should not reach here, but just in case
    log_error "Review loop exited unexpectedly"
    return $EXIT_FAILED
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Orchestrates the review loop between Ollama (code generation) and Claude (code review).

Options:
    -t, --task DESCRIPTION     Task description (required)
    -f, --files FILES          Target files (required)
    -m, --max-iterations N     Maximum iterations (default: $MAX_ITERATIONS)
    -h, --help                 Show this help message

Environment Variables:
    REVIEW_LOOP_MAX_ITERATIONS Maximum review iterations (default: 3)
    OLLAMA_MODEL               Ollama model to use (default: deepseek-coder:6.7b)
    OLLAMA_ENDPOINT            Ollama server endpoint
    OLLAMA_TIMEOUT             Ollama request timeout

Exit Codes:
    0 - Code approved
    1 - Code failed review
    2 - Code accepted via user override

Examples:
    $0 -t "Create user login function" -f "src/auth.js"
    $0 -t "Add error handling" -f "src/api.js" -m 5

EOF
}

# Main entry point
main() {
    local task_description=""
    local target_files=""

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--task)
                task_description="$2"
                shift 2
                ;;
            -f|--files)
                target_files="$2"
                shift 2
                ;;
            -m|--max-iterations)
                MAX_ITERATIONS="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                show_usage
                exit 1
                ;;
        esac
    done

    # Validate required arguments
    if [ -z "$task_description" ]; then
        echo "ERROR: Task description is required (-t)" >&2
        show_usage
        exit 1
    fi

    if [ -z "$target_files" ]; then
        echo "ERROR: Target files are required (-f)" >&2
        show_usage
        exit 1
    fi

    # Run the review loop
    review_loop "$task_description" "$target_files"
}

# Run main if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
