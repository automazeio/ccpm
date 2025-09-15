#!/bin/bash
# comprehensive-audit.sh - Complete CCPM system audit
set -euo pipefail

echo "======================================"
echo "   CCPM COMPREHENSIVE AUDIT"
echo "======================================"
echo ""

# Track overall status
total_errors=0
total_warnings=0

# 1. Structure Validation
validate_structure() {
    echo "[1/6] Validating Directory Structure..."
    local errors=0

    # Check required directories
    for dir in .claude .claude/prds .claude/epics .claude/scripts .claude/scripts/pm .claude/commands .claude/commands/pm; do
        if [ ! -d "$dir" ]; then
            echo "  ❌ Missing directory: $dir"
            ((errors++))
        else
            echo "  ✓ Found: $dir"
        fi
    done

    return $errors
}

# 2. Script Validation
validate_scripts() {
    echo ""
    echo "[2/6] Validating Scripts..."
    local errors=0
    local warnings=0

    # Count scripts
    script_count=$(find .claude/scripts/pm -name "*.sh" -type f 2>/dev/null | wc -l)
    echo "  Found $script_count PM scripts"

    # Check all scripts have proper shebang and error handling
    for script in .claude/scripts/pm/*.sh; do
        if [ -f "$script" ]; then
            script_name=$(basename "$script")

            # Check shebang
            if ! head -1 "$script" | grep -q "^#!/bin/bash"; then
                echo "  ❌ Missing shebang: $script_name"
                ((errors++))
            fi

            # Check error handling
            if ! grep -q "^set -e" "$script"; then
                echo "  ⚠️  Missing 'set -e': $script_name"
                ((warnings++))
            fi

            # Check script is executable
            if [ ! -x "$script" ]; then
                echo "  ⚠️  Not executable: $script_name"
                ((warnings++))
            fi

            # Syntax check
            if ! bash -n "$script" 2>/dev/null; then
                echo "  ❌ Syntax error: $script_name"
                ((errors++))
            fi
        fi
    done

    if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
        echo "  ✓ All scripts valid"
    fi

    total_warnings=$((total_warnings + warnings))
    return $errors
}

# 3. Command-Script Mapping
validate_command_script_mapping() {
    echo ""
    echo "[3/6] Validating Command-Script References..."
    local errors=0

    for cmd in .claude/commands/pm/*.md; do
        if [ -f "$cmd" ]; then
            cmd_name=$(basename "$cmd")

            # Extract script references (handle both quoted and unquoted paths)
            scripts=$(grep -oE 'bash [^"]*\.claude/scripts/pm/[^"]*\.sh' "$cmd" 2>/dev/null | sed 's/^bash //' || true)

            for script_ref in $scripts; do
                script_path="${script_ref#bash }"
                if [ ! -f "$script_path" ]; then
                    echo "  ❌ Command $cmd_name references missing: $script_path"
                    ((errors++))
                fi
            done
        fi
    done

    if [ $errors -eq 0 ]; then
        echo "  ✓ All command references valid"
    fi

    return $errors
}

# 4. GitHub Integration Check
validate_github_integration() {
    echo ""
    echo "[4/6] Validating GitHub Integration..."
    local warnings=0

    # Check for file validation function in utils.sh (check both locations)
    utils_found=false
    for utils_path in ".claude/scripts/utils.sh" "ccpm/claude_template/scripts/utils.sh"; do
        if [ -f "$utils_path" ]; then
            utils_found=true
            if grep -q "validate_body_file_has_content" "$utils_path"; then
                echo "  ✓ File validation function present in $utils_path"
            else
                echo "  ⚠️  Missing file validation function in $utils_path"
                ((warnings++))
            fi
            break
        fi
    done

    if [ "$utils_found" = "false" ]; then
        echo "  ⚠️  utils.sh not found"
        ((warnings++))
    fi

    # Check critical commands use validation
    for cmd in epic-sync issue-sync issue-close; do
        cmd_file=".claude/commands/pm/${cmd}.md"
        if [ -f "$cmd_file" ]; then
            if grep -q "validate_body_file" "$cmd_file" 2>/dev/null; then
                echo "  ✓ ${cmd} uses validation"
            else
                echo "  ⚠️  ${cmd} missing validation"
                ((warnings++))
            fi
        fi
    done

    return $warnings
}

# 5. Performance Checks
validate_performance() {
    echo ""
    echo "[5/6] Validating Performance Safeguards..."
    local info_count=0

    # Check for output limiting
    scripts_with_limits=$(grep -l "MAX_OUTPUT_LINES\|output_limit" .claude/scripts/pm/*.sh 2>/dev/null | wc -l)
    total_scripts=$(ls .claude/scripts/pm/*.sh 2>/dev/null | wc -l)

    echo "  Scripts with output limits: $scripts_with_limits/$total_scripts"
    if [ $scripts_with_limits -lt $((total_scripts / 2)) ]; then
        echo "  ℹ️  Less than 50% of scripts have output limits"
        ((info_count++))
    fi

    # Check for timeout usage
    scripts_with_timeout=$(grep -l "timeout\|TIMEOUT" .claude/scripts/pm/*.sh 2>/dev/null | wc -l)
    echo "  Scripts with timeouts: $scripts_with_timeout/$total_scripts"

    # Check for cleanup traps
    scripts_with_cleanup=$(grep -l "trap.*cleanup\|trap.*EXIT" .claude/scripts/pm/*.sh 2>/dev/null | wc -l)
    echo "  Scripts with cleanup: $scripts_with_cleanup/$total_scripts"

    # Check for dangerous patterns
    scripts_with_eval=$(grep -l "^[^#]*eval " .claude/scripts/pm/*.sh 2>/dev/null | wc -l)
    if [ $scripts_with_eval -gt 0 ]; then
        echo "  ⚠️  Scripts using eval: $scripts_with_eval (security risk)"
        total_warnings=$((total_warnings + scripts_with_eval))
    else
        echo "  ✓ No eval usage detected"
    fi

    return 0
}

# 6. Test Coverage
validate_test_coverage() {
    echo ""
    echo "[6/6] Validating Test Coverage..."

    # List of PM scripts
    all_scripts=(
        "blocked.sh" "epic-list.sh" "epic-show.sh" "epic-status.sh"
        "help.sh" "in-progress.sh" "init.sh" "next.sh"
        "prd-list.sh" "prd-status.sh" "search.sh" "standup.sh"
        "status.sh" "validate.sh"
    )

    # Check which scripts have test coverage
    test_file="tests/integration/test_pm_shell_scripts.py"
    if [ -f "$test_file" ]; then
        tested_count=0
        untested=""

        for script in "${all_scripts[@]}"; do
            script_base="${script%.sh}"
            # Check if script is mentioned in tests
            if grep -qi "test.*${script_base}\|${script_base}.*test" "$test_file"; then
                ((tested_count++))
            else
                untested="$untested $script"
            fi
        done

        echo "  Test coverage: $tested_count/${#all_scripts[@]} scripts"

        if [ -n "$untested" ]; then
            echo "  ⚠️  Untested scripts:$untested"
        else
            echo "  ✓ All scripts have test coverage"
        fi
    else
        echo "  ❌ Test file not found: $test_file"
        ((total_errors++))
    fi

    return 0
}

# Run all validations
echo "Starting comprehensive audit..."
echo ""

validate_structure; total_errors=$((total_errors + $?))
validate_scripts; total_errors=$((total_errors + $?))
validate_command_script_mapping; total_errors=$((total_errors + $?))
validate_github_integration; total_warnings=$((total_warnings + $?))
validate_performance
validate_test_coverage

# Summary
echo ""
echo "======================================"
echo "         AUDIT SUMMARY"
echo "======================================"
echo ""
echo "Errors:   $total_errors"
echo "Warnings: $total_warnings"
echo ""

if [ $total_errors -eq 0 ]; then
    if [ $total_warnings -eq 0 ]; then
        echo "✅ System validation PASSED - No issues found!"
        exit 0
    else
        echo "⚠️  System validation PASSED with $total_warnings warnings"
        exit 0
    fi
else
    echo "❌ System validation FAILED with $total_errors errors"
    exit 1
fi