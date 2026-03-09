#!/bin/bash
# assertions.sh - Verification functions for E2E testing
#
# Provides assertion functions to verify:
# - File existence and counts
# - Content patterns
# - YAML/frontmatter validity
# - Pipeline output correctness

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test result tracking
ASSERTIONS_PASSED=0
ASSERTIONS_FAILED=0
ASSERTIONS_TOTAL=0
declare -a ASSERTION_FAILURES

# Reset assertion counters
reset_assertions() {
    ASSERTIONS_PASSED=0
    ASSERTIONS_FAILED=0
    ASSERTIONS_TOTAL=0
    ASSERTION_FAILURES=()
}

# Record assertion result
# Usage: record_assertion <pass|fail> <message>
record_assertion() {
    local result="$1"
    local message="$2"

    ((ASSERTIONS_TOTAL++))

    if [[ "$result" == "pass" ]]; then
        ((ASSERTIONS_PASSED++))
        echo -e "  ${GREEN}✓${NC} $message"
    else
        ((ASSERTIONS_FAILED++))
        ASSERTION_FAILURES+=("$message")
        echo -e "  ${RED}✗${NC} $message"
    fi
}

# Get assertion summary
get_assertion_summary() {
    echo "Passed: $ASSERTIONS_PASSED / $ASSERTIONS_TOTAL"
    if [[ $ASSERTIONS_FAILED -gt 0 ]]; then
        echo ""
        echo "Failures:"
        for failure in "${ASSERTION_FAILURES[@]}"; do
            echo "  - $failure"
        done
    fi
}

# Check if all assertions passed
assertions_passed() {
    [[ $ASSERTIONS_FAILED -eq 0 ]]
}

#------------------------------------------------------------------------------
# File Assertions
#------------------------------------------------------------------------------

# Assert a file exists
# Usage: assert_file_exists <path> [description]
assert_file_exists() {
    local path="$1"
    local desc="${2:-$path}"

    if [[ -f "$path" ]]; then
        record_assertion "pass" "File exists: $desc"
        return 0
    else
        record_assertion "fail" "File missing: $desc"
        return 1
    fi
}

# Assert a directory exists
# Usage: assert_dir_exists <path> [description]
assert_dir_exists() {
    local path="$1"
    local desc="${2:-$path}"

    if [[ -d "$path" ]]; then
        record_assertion "pass" "Directory exists: $desc"
        return 0
    else
        record_assertion "fail" "Directory missing: $desc"
        return 1
    fi
}

# Assert file count matches expected range
# Usage: assert_file_count <pattern> <min> <max> [description]
assert_file_count() {
    local pattern="$1"
    local min="$2"
    local max="$3"
    local desc="${4:-files matching $pattern}"

    local count
    count=$(find . -path "$pattern" -type f 2>/dev/null | wc -l | tr -d ' ')

    if [[ $count -ge $min && $count -le $max ]]; then
        record_assertion "pass" "$desc: $count (expected $min-$max)"
        return 0
    else
        record_assertion "fail" "$desc: $count (expected $min-$max)"
        return 1
    fi
}

# Assert file count using glob pattern
# Usage: assert_glob_count <pattern> <min> <max> [description]
assert_glob_count() {
    local pattern="$1"
    local min="$2"
    local max="$3"
    local desc="${4:-files matching $pattern}"

    shopt -s nullglob
    local files=($pattern)
    local count=${#files[@]}
    shopt -u nullglob

    if [[ $count -ge $min && $count -le $max ]]; then
        record_assertion "pass" "$desc: $count (expected $min-$max)"
        return 0
    else
        record_assertion "fail" "$desc: $count (expected $min-$max)"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Content Assertions
#------------------------------------------------------------------------------

# Assert file contains pattern
# Usage: assert_contains <file> <pattern> [description]
assert_contains() {
    local file="$1"
    local pattern="$2"
    local desc="${3:-$file contains '$pattern'}"

    if [[ ! -f "$file" ]]; then
        record_assertion "fail" "$desc (file not found)"
        return 1
    fi

    if grep -q "$pattern" "$file" 2>/dev/null; then
        record_assertion "pass" "$desc"
        return 0
    else
        record_assertion "fail" "$desc"
        return 1
    fi
}

# Assert file does not contain pattern
# Usage: assert_not_contains <file> <pattern> [description]
assert_not_contains() {
    local file="$1"
    local pattern="$2"
    local desc="${3:-$file does not contain '$pattern'}"

    if [[ ! -f "$file" ]]; then
        record_assertion "pass" "$desc (file not found)"
        return 0
    fi

    if grep -q "$pattern" "$file" 2>/dev/null; then
        record_assertion "fail" "$desc"
        return 1
    else
        record_assertion "pass" "$desc"
        return 0
    fi
}

# Assert file is not empty
# Usage: assert_not_empty <file> [description]
assert_not_empty() {
    local file="$1"
    local desc="${2:-$file is not empty}"

    if [[ ! -f "$file" ]]; then
        record_assertion "fail" "$desc (file not found)"
        return 1
    fi

    if [[ -s "$file" ]]; then
        record_assertion "pass" "$desc"
        return 0
    else
        record_assertion "fail" "$desc (file is empty)"
        return 1
    fi
}

#------------------------------------------------------------------------------
# YAML/Frontmatter Assertions
#------------------------------------------------------------------------------

# Assert file has valid YAML frontmatter
# Usage: assert_has_frontmatter <file> [description]
assert_has_frontmatter() {
    local file="$1"
    local desc="${2:-$file has valid frontmatter}"

    if [[ ! -f "$file" ]]; then
        record_assertion "fail" "$desc (file not found)"
        return 1
    fi

    # Check for opening ---
    local first_line
    first_line=$(head -n 1 "$file")
    if [[ "$first_line" != "---" ]]; then
        record_assertion "fail" "$desc (no opening ---)"
        return 1
    fi

    # Check for closing ---
    local has_closing
    has_closing=$(sed -n '2,${/^---$/p}' "$file" | head -n 1)
    if [[ -z "$has_closing" ]]; then
        record_assertion "fail" "$desc (no closing ---)"
        return 1
    fi

    record_assertion "pass" "$desc"
    return 0
}

# Assert YAML file is valid
# Usage: assert_yaml_valid <file> [description]
assert_yaml_valid() {
    local file="$1"
    local desc="${2:-$file is valid YAML}"

    if [[ ! -f "$file" ]]; then
        record_assertion "fail" "$desc (file not found)"
        return 1
    fi

    # Try to parse with Python
    if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
        record_assertion "pass" "$desc"
        return 0
    else
        record_assertion "fail" "$desc (parse error)"
        return 1
    fi
}

# Assert frontmatter contains required field
# Usage: assert_frontmatter_field <file> <field> [description]
assert_frontmatter_field() {
    local file="$1"
    local field="$2"
    local desc="${3:-$file has frontmatter field '$field'}"

    if [[ ! -f "$file" ]]; then
        record_assertion "fail" "$desc (file not found)"
        return 1
    fi

    # Extract frontmatter and check for field
    local frontmatter
    frontmatter=$(sed -n '1,/^---$/p' "$file" | tail -n +2 | head -n -1)

    if echo "$frontmatter" | grep -q "^${field}:"; then
        record_assertion "pass" "$desc"
        return 0
    else
        record_assertion "fail" "$desc"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Pipeline-Specific Assertions
#------------------------------------------------------------------------------

# Assert scope directory has required files
# Usage: assert_scope_complete <scope_dir> <expected_files_array_name>
assert_scope_complete() {
    local scope_dir="$1"
    local -n expected_files=$2
    local all_found=true

    echo -e "  ${BLUE}Checking scope directory: $scope_dir${NC}"

    for file in "${expected_files[@]}"; do
        if [[ -f "$scope_dir/$file" ]]; then
            record_assertion "pass" "Scope file: $file"
        else
            record_assertion "fail" "Scope file missing: $file"
            all_found=false
        fi
    done

    $all_found
}

# Assert PRDs were generated
# Usage: assert_prds_generated <prds_dir> <min> <max>
assert_prds_generated() {
    local prds_dir="$1"
    local min="$2"
    local max="$3"

    if [[ ! -d "$prds_dir" ]]; then
        record_assertion "fail" "PRDs directory not found: $prds_dir"
        return 1
    fi

    local count
    count=$(find "$prds_dir" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')

    if [[ $count -ge $min && $count -le $max ]]; then
        record_assertion "pass" "PRDs generated: $count (expected $min-$max)"
        return 0
    else
        record_assertion "fail" "PRDs generated: $count (expected $min-$max)"
        return 1
    fi
}

# Assert features were extracted
# Usage: assert_features_extracted <features_file> <min_count> [must_include_array_name]
assert_features_extracted() {
    local features_file="$1"
    local min_count="$2"
    local must_include_ref="${3:-}"

    if [[ ! -f "$features_file" ]]; then
        record_assertion "fail" "Features file not found: $features_file"
        return 1
    fi

    # Count features (look for feature markers)
    local count
    count=$(grep -c "^## \|^### \|^- \*\*" "$features_file" 2>/dev/null || echo "0")

    if [[ $count -ge $min_count ]]; then
        record_assertion "pass" "Features extracted: $count (min: $min_count)"
    else
        record_assertion "fail" "Features extracted: $count (min: $min_count)"
        return 1
    fi

    # Check must-include features if provided
    if [[ -n "$must_include_ref" ]]; then
        local -n must_include=$must_include_ref
        for feature in "${must_include[@]}"; do
            if grep -qi "$feature" "$features_file" 2>/dev/null; then
                record_assertion "pass" "Feature included: $feature"
            else
                record_assertion "fail" "Feature missing: $feature"
            fi
        done
    fi

    return 0
}

# Assert journeys were extracted
# Usage: assert_journeys_extracted <journeys_file> <min_count> [must_include_array_name]
assert_journeys_extracted() {
    local journeys_file="$1"
    local min_count="$2"
    local must_include_ref="${3:-}"

    if [[ ! -f "$journeys_file" ]]; then
        record_assertion "fail" "Journeys file not found: $journeys_file"
        return 1
    fi

    # Count journeys (look for journey markers like ## or ### headings)
    local count
    count=$(grep -c "^## \|^### " "$journeys_file" 2>/dev/null || echo "0")

    if [[ $count -ge $min_count ]]; then
        record_assertion "pass" "Journeys extracted: $count (min: $min_count)"
    else
        record_assertion "fail" "Journeys extracted: $count (min: $min_count)"
        return 1
    fi

    # Check must-include journeys if provided
    if [[ -n "$must_include_ref" ]]; then
        local -n must_include=$must_include_ref
        for journey in "${must_include[@]}"; do
            if grep -qi "$journey" "$journeys_file" 2>/dev/null; then
                record_assertion "pass" "Journey included: $journey"
            else
                record_assertion "fail" "Journey missing: $journey"
            fi
        done
    fi

    return 0
}

# Assert roadmap was generated
# Usage: assert_roadmap_generated <roadmap_file>
assert_roadmap_generated() {
    local roadmap_file="$1"

    if [[ ! -f "$roadmap_file" ]]; then
        record_assertion "fail" "Roadmap not generated: $roadmap_file"
        return 1
    fi

    # Check for common roadmap sections
    local has_phases=false
    local has_milestones=false

    if grep -qi "phase\|sprint\|milestone\|week" "$roadmap_file" 2>/dev/null; then
        has_phases=true
    fi

    if [[ "$has_phases" == "true" ]]; then
        record_assertion "pass" "Roadmap generated with phases/milestones"
        return 0
    else
        record_assertion "fail" "Roadmap missing phases/milestones"
        return 1
    fi
}

# Assert no error patterns in log file
# Usage: assert_no_errors <log_file>
assert_no_errors() {
    local log_file="$1"

    if [[ ! -f "$log_file" ]]; then
        record_assertion "pass" "No log file to check for errors"
        return 0
    fi

    # Check for critical error patterns
    local error_patterns=(
        "FATAL"
        "Error:"
        "Exception:"
        "Traceback"
        "panic:"
        "FAILED"
    )

    local found_errors=false
    for pattern in "${error_patterns[@]}"; do
        if grep -q "$pattern" "$log_file" 2>/dev/null; then
            record_assertion "fail" "Error pattern found in log: $pattern"
            found_errors=true
        fi
    done

    if [[ "$found_errors" == "false" ]]; then
        record_assertion "pass" "No critical errors in log"
        return 0
    fi

    return 1
}

#------------------------------------------------------------------------------
# Comparison Assertions
#------------------------------------------------------------------------------

# Assert two values are equal
# Usage: assert_equals <expected> <actual> [description]
assert_equals() {
    local expected="$1"
    local actual="$2"
    local desc="${3:-Expected '$expected', got '$actual'}"

    if [[ "$expected" == "$actual" ]]; then
        record_assertion "pass" "$desc"
        return 0
    else
        record_assertion "fail" "$desc"
        return 1
    fi
}

# Assert value is greater than or equal to
# Usage: assert_gte <value> <min> [description]
assert_gte() {
    local value="$1"
    local min="$2"
    local desc="${3:-Value $value >= $min}"

    if [[ $value -ge $min ]]; then
        record_assertion "pass" "$desc"
        return 0
    else
        record_assertion "fail" "$desc"
        return 1
    fi
}

# Assert value is less than or equal to
# Usage: assert_lte <value> <max> [description]
assert_lte() {
    local value="$1"
    local max="$2"
    local desc="${3:-Value $value <= $max}"

    if [[ $value -le $max ]]; then
        record_assertion "pass" "$desc"
        return 0
    else
        record_assertion "fail" "$desc"
        return 1
    fi
}

# Export functions
export -f reset_assertions
export -f record_assertion
export -f get_assertion_summary
export -f assertions_passed
export -f assert_file_exists
export -f assert_dir_exists
export -f assert_file_count
export -f assert_glob_count
export -f assert_contains
export -f assert_not_contains
export -f assert_not_empty
export -f assert_has_frontmatter
export -f assert_yaml_valid
export -f assert_frontmatter_field
export -f assert_scope_complete
export -f assert_prds_generated
export -f assert_features_extracted
export -f assert_journeys_extracted
export -f assert_roadmap_generated
export -f assert_no_errors
export -f assert_equals
export -f assert_gte
export -f assert_lte
