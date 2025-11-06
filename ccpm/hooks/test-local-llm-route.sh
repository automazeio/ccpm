#!/bin/bash
# Test script for local-llm-route.sh hook
# Validates routing logic with various task descriptions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/local-llm-route.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "========================================"
echo "  Local LLM Routing Hook - Test Suite"
echo "========================================"
echo ""

test_count=0
pass_count=0
fail_count=0

run_test() {
    local test_name="$1"
    local task_description="$2"
    local expected_route="$3"

    ((test_count++))

    echo -e "${BLUE}Test $test_count: $test_name${NC}"
    echo "Task: $task_description"

    # Run the hook with debug mode enabled
    local output
    output=$(echo "$task_description" | CLAUDE_HOOK_DEBUG=false "$HOOK_SCRIPT" 2>&1)

    # Check if output contains expected route indicator
    local actual_route="unknown"
    if echo "$output" | grep -q "ROUTE TO OLLAMA"; then
        actual_route="ollama"
    elif echo "$output" | grep -q -v "ROUTE TO OLLAMA"; then
        # If no OLLAMA marker, it passed through to Claude
        actual_route="claude"
    fi

    if [ "$actual_route" = "$expected_route" ]; then
        echo -e "${GREEN}✓ PASS${NC} - Routed to $actual_route as expected"
        ((pass_count++))
    else
        echo -e "${RED}✗ FAIL${NC} - Expected $expected_route but got $actual_route"
        ((fail_count++))
    fi

    echo ""
}

echo "Testing with local_llm.enabled=false (should always pass through to Claude)"
echo "------------------------------------------------------------------------"

run_test \
    "Disabled - Code generation task" \
    "Implement user registration endpoint with email validation" \
    "claude"

run_test \
    "Disabled - Planning task" \
    "Design the architecture for the notification system" \
    "claude"

echo ""
echo "Enabling local_llm in settings..."

# Temporarily enable local_llm for testing
SETTINGS_FILE="$SCRIPT_DIR/../../.claude/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    # Backup original settings
    cp "$SETTINGS_FILE" "${SETTINGS_FILE}.backup"

    # Enable local_llm
    jq '.local_llm.enabled = true' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"
    mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"

    echo -e "${GREEN}✓ local_llm.enabled set to true${NC}"
else
    echo -e "${YELLOW}⚠ Settings file not found, some tests may be skipped${NC}"
fi

echo ""
echo "Testing Code Generation Tasks (should route to Ollama)"
echo "------------------------------------------------------"

run_test \
    "Code Gen - Implement function" \
    "Implement a function to validate email addresses using regex" \
    "ollama"

run_test \
    "Code Gen - Create class" \
    "Create a UserService class with methods for CRUD operations" \
    "ollama"

run_test \
    "Code Gen - Write tests" \
    "Write unit tests for the authentication middleware" \
    "ollama"

run_test \
    "Code Gen - Refactor code" \
    "Refactor the legacy callback-based code to use async/await" \
    "ollama"

run_test \
    "Code Gen - Add endpoint" \
    "Add a REST API endpoint for product search functionality" \
    "ollama"

run_test \
    "Code Gen - File extension indicator" \
    "Create a new file utils/date-formatter.js with helper functions" \
    "ollama"

echo ""
echo "Testing Planning/Review Tasks (should route to Claude)"
echo "------------------------------------------------------"

run_test \
    "Planning - Design architecture" \
    "Design the database schema for the blog platform" \
    "claude"

run_test \
    "Planning - Create PRD" \
    "Create a PRD for the notification system with user stories" \
    "claude"

run_test \
    "Planning - Review code" \
    "Review the authentication implementation for security issues" \
    "claude"

run_test \
    "Planning - Analyze performance" \
    "Analyze the performance bottleneck in the data processing pipeline" \
    "claude"

run_test \
    "Planning - Epic breakdown" \
    "Decompose the user management epic into actionable tasks" \
    "claude"

run_test \
    "Planning - PRD file" \
    "Update the .claude/prds/notification-system.md document" \
    "claude"

echo ""
echo "Testing Critical Code Paths (should always route to Claude)"
echo "-----------------------------------------------------------"

run_test \
    "Critical - Authentication" \
    "Implement JWT token generation and validation for user authentication" \
    "claude"

run_test \
    "Critical - Payment processing" \
    "Create a payment processing service using Stripe API" \
    "claude"

run_test \
    "Critical - Security review" \
    "Review the OAuth implementation for security vulnerabilities" \
    "claude"

run_test \
    "Critical - Encryption" \
    "Implement AES encryption for sensitive user data storage" \
    "claude"

echo ""
echo "Testing Mixed/Ambiguous Tasks (default to Claude when uncertain)"
echo "---------------------------------------------------------------"

run_test \
    "Ambiguous - Vague request" \
    "Help me improve the application performance" \
    "claude"

run_test \
    "Ambiguous - No clear indicators" \
    "Update the database connection handling" \
    "claude"

echo ""
echo "========================================"
echo "           Test Results"
echo "========================================"
echo ""
echo "Total Tests:  $test_count"
echo -e "${GREEN}Passed:       $pass_count${NC}"
if [ $fail_count -gt 0 ]; then
    echo -e "${RED}Failed:       $fail_count${NC}"
else
    echo -e "Failed:       $fail_count"
fi
echo ""

# Restore original settings
if [ -f "${SETTINGS_FILE}.backup" ]; then
    mv "${SETTINGS_FILE}.backup" "$SETTINGS_FILE"
    echo "Settings restored to original state"
fi

if [ $fail_count -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
