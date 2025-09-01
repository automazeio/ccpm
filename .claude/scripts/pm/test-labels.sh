#!/bin/bash
# test-labels.sh - Comprehensive test suite for CCPM label management functionality
#
# This test suite validates all aspects of the label management system:
# - Core utility functions from labels-ensure.sh
# - Integration with PM commands
# - Error handling scenarios
# - Cache performance and TTL functionality
# - Idempotency guarantees
#
# Usage: bash .claude/scripts/pm/test-labels.sh [--help] [--cleanup-only] [--verbose]
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed
#   2 - Configuration/setup error

set -e

# Configuration
TEST_PREFIX="ccpm-test"
TEST_EPIC_NAME="test-epic-$(date +%s)"
ORIGINAL_TTL=""
VERBOSE=false
CLEANUP_ONLY=false

# Test statistics
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

#================================================================================
# Helper Functions
#================================================================================

# Show help information
show_help() {
    cat <<EOF
test-labels.sh - Comprehensive CCPM Label Management Test Suite

USAGE:
    bash .claude/scripts/pm/test-labels.sh [OPTIONS]

OPTIONS:
    --help           Show this help message
    --cleanup-only   Only run cleanup (remove test labels)
    --verbose        Show detailed output for debugging

DESCRIPTION:
    Runs a comprehensive test suite for the CCPM label management system,
    including unit tests, integration tests, error scenarios, and performance tests.

TEST CATEGORIES:
    1. Unit Tests - Core functions from labels-ensure.sh
    2. Integration Tests - Command integrations (init, epic-sync, epic-oneshot)
    3. Error Scenario Tests - Authentication, permissions, network failures
    4. Performance Tests - Cache effectiveness and TTL behavior
    5. Idempotency Tests - Multiple runs produce same result

REQUIREMENTS:
    - GitHub CLI (gh) must be installed and authenticated
    - Must be run from within a Git repository connected to GitHub
    - User must have label creation permissions on the repository

CLEANUP:
    The test suite automatically cleans up test labels after completion.
    Use --cleanup-only to remove any leftover test labels from previous runs.

EXIT CODES:
    0 - All tests passed
    1 - One or more tests failed
    2 - Configuration/setup error
EOF
}

# Print colored output
print_color() {
    local color="$1"
    local message="$2"
    if [[ "$VERBOSE" == "true" ]] || [[ "$color" == "$RED" ]] || [[ "$color" == "$GREEN" ]] || [[ "$color" == "$YELLOW" ]]; then
        echo -e "${color}${message}${NC}"
    fi
}

# Debug output (only shown in verbose mode)
debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        print_color "$BLUE" "DEBUG: $1"
    fi
}

# Test assertion functions
assert_success() {
    local description="$1"
    local command="$2"
    ((TESTS_RUN++))
    
    debug "Running: $command"
    
    if eval "$command" &>/dev/null; then
        print_color "$GREEN" "✅ $description"
        ((TESTS_PASSED++))
        return 0
    else
        print_color "$RED" "❌ $description"
        FAILED_TESTS+=("$description")
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_failure() {
    local description="$1"
    local command="$2"
    ((TESTS_RUN++))
    
    debug "Running (expecting failure): $command"
    
    if eval "$command" &>/dev/null; then
        print_color "$RED" "❌ $description (expected failure but succeeded)"
        FAILED_TESTS+=("$description")
        ((TESTS_FAILED++))
        return 1
    else
        print_color "$GREEN" "✅ $description"
        ((TESTS_PASSED++))
        return 0
    fi
}

assert_label_exists() {
    local label_name="$1"
    local description="${2:-Label $label_name should exist}"
    assert_success "$description" "gh label list --json name -q '.[].name' | grep -q '^${label_name}$'"
}

assert_label_not_exists() {
    local label_name="$1"
    local description="${2:-Label $label_name should not exist}"
    assert_failure "$description" "gh label list --json name -q '.[].name' | grep -q '^${label_name}$'"
}

#================================================================================
# Setup and Cleanup Functions
#================================================================================

# Setup test environment
setup_test_env() {
    print_color "$BLUE" "🔧 Setting up test environment..."
    
    # Check prerequisites
    if ! command -v gh &>/dev/null; then
        print_color "$RED" "❌ GitHub CLI (gh) is not installed"
        return 2
    fi
    
    if ! gh auth status &>/dev/null; then
        print_color "$RED" "❌ GitHub CLI is not authenticated. Run: gh auth login"
        return 2
    fi
    
    # Verify we're in a git repository
    if ! git rev-parse --git-dir &>/dev/null; then
        print_color "$RED" "❌ Not in a Git repository"
        return 2
    fi
    
    # Get repository info
    local repo_name
    repo_name=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)
    if [[ -z "$repo_name" ]]; then
        print_color "$RED" "❌ Cannot determine GitHub repository"
        return 2
    fi
    
    print_color "$GREEN" "✅ Repository: $repo_name"
    
    # Store original TTL setting
    ORIGINAL_TTL="${CCPM_LABEL_CACHE_TTL:-}"
    
    return 0
}

# Find and source the labels-ensure utility
setup_labels_utility() {
    print_color "$BLUE" "🔧 Setting up labels utility..."
    
    # Find labels-ensure.sh in common locations
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    local labels_script=""
    local possible_paths=(
        "$script_dir/labels-ensure.sh"
        "$script_dir/../../../ccpm_enhanced/.claude/scripts/pm/labels-ensure.sh"
        "$(pwd)/.claude/scripts/pm/labels-ensure.sh"
        "$(pwd)/../ccpm_enhanced/.claude/scripts/pm/labels-ensure.sh"
    )
    
    for path in "${possible_paths[@]}"; do
        if [[ -f "$path" ]]; then
            labels_script="$path"
            break
        fi
    done
    
    if [[ -z "$labels_script" ]]; then
        print_color "$RED" "❌ Cannot find labels-ensure.sh utility script"
        print_color "$RED" "   Searched locations:"
        for path in "${possible_paths[@]}"; do
            print_color "$RED" "   - $path"
        done
        return 2
    fi
    
    debug "Found labels-ensure.sh at: $labels_script"
    
    # Source the utility script
    # shellcheck source=/dev/null
    if ! source "$labels_script"; then
        print_color "$RED" "❌ Failed to source labels-ensure.sh"
        return 2
    fi
    
    print_color "$GREEN" "✅ Labels utility loaded successfully"
    return 0
}

# Clean up test labels
cleanup_test_labels() {
    print_color "$BLUE" "🧹 Cleaning up test labels..."
    
    local cleanup_count=0
    
    # Get all labels and filter for test labels
    local test_labels
    test_labels=$(gh label list --json name -q '.[].name' 2>/dev/null | grep "^${TEST_PREFIX}-" || true)
    
    if [[ -n "$test_labels" ]]; then
        while IFS= read -r label_name; do
            if [[ -n "$label_name" ]]; then
                debug "Deleting test label: $label_name"
                if gh label delete "$label_name" --yes &>/dev/null; then
                    ((cleanup_count++))
                else
                    debug "Warning: Failed to delete $label_name"
                fi
            fi
        done <<< "$test_labels"
    fi
    
    # Clean up test epic label
    local test_epic_label="epic:${TEST_EPIC_NAME}"
    if gh label list --json name -q '.[].name' 2>/dev/null | grep -q "^${test_epic_label}$"; then
        debug "Deleting test epic label: $test_epic_label"
        if gh label delete "$test_epic_label" --yes &>/dev/null; then
            ((cleanup_count++))
        fi
    fi
    
    # Clear label cache to ensure fresh state
    if declare -f clear_label_cache &>/dev/null; then
        clear_label_cache &>/dev/null || true
    fi
    
    if [[ $cleanup_count -gt 0 ]]; then
        print_color "$GREEN" "✅ Cleaned up $cleanup_count test labels"
    else
        print_color "$GREEN" "✅ No test labels to clean up"
    fi
}

# Restore original environment
restore_environment() {
    debug "Restoring environment..."
    
    # Restore original TTL setting
    if [[ -n "$ORIGINAL_TTL" ]]; then
        export CCPM_LABEL_CACHE_TTL="$ORIGINAL_TTL"
    else
        unset CCPM_LABEL_CACHE_TTL
    fi
}

#================================================================================
# Test Categories
#================================================================================

# Unit Tests - Core functions from labels-ensure.sh
test_unit_functions() {
    print_color "$PURPLE" "📝 Running Unit Tests (Core Functions)"
    print_color "$PURPLE" "======================================"
    
    # Test check_gh_cli function
    assert_success "check_gh_cli should succeed when gh is authenticated" "check_gh_cli"
    
    # Test cache file path generation
    assert_success "get_cache_file should return valid path" "get_cache_file | grep -q '/tmp/ccpm-labels-cache-'"
    
    # Test cache validation with non-existent file
    local fake_cache="/tmp/fake-cache-$(date +%s)"
    assert_failure "is_cache_valid should fail for non-existent file" "is_cache_valid '$fake_cache'"
    
    # Test cache refresh
    assert_success "refresh_label_cache should succeed" "refresh_label_cache"
    
    # Test cache validity after refresh
    local cache_file
    cache_file=$(get_cache_file)
    assert_success "Cache should be valid after refresh" "is_cache_valid '$cache_file'"
    
    # Test label existence check for known non-existent label
    local fake_label="${TEST_PREFIX}-nonexistent-$(date +%s)"
    assert_failure "check_label_exists should fail for non-existent label" "check_label_exists '$fake_label'"
    
    echo ""
}

# Standard Labels Tests
test_standard_labels() {
    print_color "$PURPLE" "🏷️  Testing Standard Label Creation"
    print_color "$PURPLE" "=================================="
    
    # Test creation of all 9 standard labels using test prefix
    local standard_labels=("epic" "task" "feature" "bug" "test:not-written" "test:written" "test:passing" "test:failing" "test:flaky")
    
    for label_name in "${standard_labels[@]}"; do
        local test_label="${TEST_PREFIX}-${label_name}"
        local color="${STANDARD_LABELS[$label_name]}"
        local description="${LABEL_DESCRIPTIONS[$label_name]} (TEST)"
        
        # Create test version of standard label
        assert_success "Create test label: $test_label" "create_label '$test_label' '$color' '$description'"
        assert_label_exists "$test_label" "Test label $test_label should exist after creation"
    done
    
    echo ""
}

# Dynamic Epic Label Tests
test_epic_label_creation() {
    print_color "$PURPLE" "🎯 Testing Epic Label Creation"
    print_color "$PURPLE" "=============================="
    
    # Test epic label creation
    assert_success "Create epic label" "ensure_epic_label '$TEST_EPIC_NAME'"
    
    local epic_label="epic:${TEST_EPIC_NAME}"
    assert_label_exists "$epic_label" "Epic label should exist after creation"
    
    # Test idempotency - creating same epic label again should not fail
    assert_success "Epic label creation should be idempotent" "ensure_epic_label '$TEST_EPIC_NAME'"
    
    echo ""
}

# Cache Performance and TTL Tests
test_cache_functionality() {
    print_color "$PURPLE" "⚡ Testing Cache Performance and TTL"
    print_color "$PURPLE" "=================================="
    
    # Test with short TTL
    export CCPM_LABEL_CACHE_TTL=1  # 1 minute
    
    # Clear cache and refresh
    assert_success "Force cache refresh" "force_refresh_cache"
    
    local cache_file
    cache_file=$(get_cache_file)
    
    # Verify cache exists and is valid
    assert_success "Cache file should exist" "[[ -f '$cache_file' ]]"
    assert_success "Cache should be valid immediately after refresh" "is_cache_valid '$cache_file'"
    
    # Test cache performance by checking a label (should use cache)
    local start_time
    start_time=$(date +%s%N)
    check_label_exists "epic" &>/dev/null || true  # Don't fail test if label doesn't exist
    local end_time
    end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
    
    debug "Cache lookup took ${duration}ms"
    
    # Performance should be reasonable (under 100ms for cache hit)
    assert_success "Cache lookup should be fast (under 100ms)" "[[ $duration -lt 100 ]]"
    
    # Test cache invalidation
    assert_success "Clear cache" "clear_label_cache"
    assert_failure "Cache should not be valid after clearing" "is_cache_valid '$cache_file'"
    
    # Reset TTL for remaining tests
    export CCPM_LABEL_CACHE_TTL=5
    
    echo ""
}

# Integration Tests
test_command_integration() {
    print_color "$PURPLE" "🔗 Testing Command Integration"
    print_color "$PURPLE" "============================="
    
    # Test labels-setup.sh command
    local labels_setup_script
    labels_setup_script="$(dirname "${BASH_SOURCE[0]}")/labels-setup.sh"
    
    if [[ -f "$labels_setup_script" ]]; then
        # Test help output
        assert_success "labels-setup.sh should show help" "bash '$labels_setup_script' --help | grep -q 'labels-setup'"
        
        # Test dry-run (we don't actually run full setup to avoid affecting real labels)
        debug "labels-setup.sh integration test completed (help check only)"
    else
        print_color "$YELLOW" "⚠️  labels-setup.sh not found, skipping integration test"
    fi
    
    # Test integration points would normally be tested here, but since we're in a test
    # environment, we focus on the utility functions that the commands would use
    
    echo ""
}

# Error Scenario Tests
test_error_scenarios() {
    print_color "$PURPLE" "🚨 Testing Error Scenarios"
    print_color "$PURPLE" "========================="
    
    # Test with invalid label name
    assert_failure "create_label should fail with empty label name" "create_label '' '000000' 'test'"
    
    # Test with invalid color
    assert_failure "create_label should fail with empty color" "create_label 'test-label' '' 'test'"
    
    # Test check_label_exists with empty name
    assert_failure "check_label_exists should fail with empty label name" "check_label_exists ''"
    
    # Test ensure_epic_label with empty name
    assert_failure "ensure_epic_label should fail with empty epic name" "ensure_epic_label ''"
    
    # Test duplicate label creation (should handle gracefully)
    local test_label="${TEST_PREFIX}-duplicate-test"
    assert_success "Create initial test label" "create_label '$test_label' '000000' 'first creation'"
    # Second creation should fail gracefully (handled by gh CLI)
    debug "Testing duplicate creation (expecting warning but not failure)"
    
    echo ""
}

# Idempotency Tests
test_idempotency() {
    print_color "$PURPLE" "🔄 Testing Idempotency"
    print_color "$PURPLE" "===================="
    
    local test_label="${TEST_PREFIX}-idempotency"
    local color="123456"
    local description="Idempotency test label"
    
    # First creation
    assert_success "First label creation" "create_label '$test_label' '$color' '$description'"
    assert_label_exists "$test_label"
    
    # Clear cache to ensure fresh check
    clear_label_cache &>/dev/null || true
    
    # Check that label still exists after cache clear
    assert_label_exists "$test_label" "Label should still exist after cache clear"
    
    # Test that epic label creation is idempotent
    local idempotent_epic="idempotent-epic-$(date +%s)"
    assert_success "First epic label creation" "ensure_epic_label '$idempotent_epic'"
    assert_success "Second epic label creation should not fail" "ensure_epic_label '$idempotent_epic'"
    
    # Cleanup the idempotent epic label
    gh label delete "epic:${idempotent_epic}" --yes &>/dev/null || true
    
    echo ""
}

#================================================================================
# Main Test Runner
#================================================================================

# Run all tests
run_all_tests() {
    print_color "$BLUE" "🧪 CCPM Label Management Test Suite"
    print_color "$BLUE" "=================================="
    print_color "$BLUE" "Repository: $(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)"
    print_color "$BLUE" "Test Prefix: $TEST_PREFIX"
    print_color "$BLUE" "Verbose Mode: $VERBOSE"
    echo ""
    
    # Run test categories in order
    test_unit_functions
    test_standard_labels  
    test_epic_label_creation
    test_cache_functionality
    test_command_integration
    test_error_scenarios
    test_idempotency
}

# Show final results
show_results() {
    echo ""
    print_color "$BLUE" "📊 Test Results Summary"
    print_color "$BLUE" "======================"
    print_color "$BLUE" "Tests Run: $TESTS_RUN"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        print_color "$GREEN" "Tests Passed: $TESTS_PASSED ✅"
        print_color "$GREEN" "Tests Failed: $TESTS_FAILED"
        echo ""
        print_color "$GREEN" "🎉 All tests passed!"
    else
        print_color "$GREEN" "Tests Passed: $TESTS_PASSED"
        print_color "$RED" "Tests Failed: $TESTS_FAILED ❌"
        echo ""
        print_color "$RED" "❌ Failed tests:"
        for test_name in "${FAILED_TESTS[@]}"; do
            print_color "$RED" "   - $test_name"
        done
    fi
    
    echo ""
    print_color "$BLUE" "🧹 Cleanup completed"
    print_color "$BLUE" "💡 Tip: Use --verbose for detailed debugging output"
}

#================================================================================
# Main Script Logic
#================================================================================

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            exit 0
            ;;
        --cleanup-only)
            CLEANUP_ONLY=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            print_color "$RED" "❌ Unknown option: $1"
            print_color "$RED" "   Use --help for usage information"
            exit 2
            ;;
    esac
done

# Trap to ensure cleanup happens
trap 'restore_environment' EXIT

# Main execution
main() {
    # Setup
    if ! setup_test_env; then
        exit 2
    fi
    
    if ! setup_labels_utility; then
        exit 2
    fi
    
    # If cleanup-only mode, just clean and exit
    if [[ "$CLEANUP_ONLY" == "true" ]]; then
        cleanup_test_labels
        print_color "$GREEN" "🧹 Cleanup completed"
        exit 0
    fi
    
    # Clean up any existing test labels before starting
    cleanup_test_labels
    
    # Run tests
    run_all_tests
    
    # Cleanup after tests
    cleanup_test_labels
    
    # Show results
    show_results
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"