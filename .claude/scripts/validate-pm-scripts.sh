#!/bin/bash
set -euo pipefail

# Comprehensive PM script validation tool
# This script performs checks similar to ShellCheck for PM shell scripts

echo "[SEARCH] CCPM Shell Script Validator"
echo "================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
total_scripts=0
passed_scripts=0
warnings=0
errors=0

# Function to print colored output
print_status() {
    local status="$1"
    local message="$2"
    local color="$3"
    
    echo -e "${color}[${status}]${NC} ${message}"
}

print_ok() {
    print_status "[DONE] OK" "$1" "$GREEN"
}

print_warning() {
    print_status "[WARNING]  WARN" "$1" "$YELLOW"
    ((warnings++))
}

print_error() {
    print_status "[ERROR] ERROR" "$1" "$RED" 
    ((errors++))
}

print_info() {
    print_status "[INFO]  INFO" "$1" "$BLUE"
}

# Function to validate individual script
validate_script() {
    local script_path="$1"
    local script_name
    script_name=$(basename "$script_path")
    
    echo ""
    print_info "Validating $script_name"
    echo "----------------------------------------"
    
    local script_errors=0
    local script_warnings=0
    
    # Check 1: File exists and is readable
    if [[ ! -f "$script_path" ]]; then
        print_error "Script file not found: $script_path"
        return 1
    fi
    
    if [[ ! -r "$script_path" ]]; then
        print_error "Script file not readable: $script_path"
        return 1
    fi
    
    # Check 2: Valid shebang line
    local first_line
    first_line=$(head -1 "$script_path")
    if [[ "$first_line" != "#!/bin/bash" ]]; then
        print_error "Invalid or missing shebang line: '$first_line'"
        ((script_errors++))
    else
        print_ok "Proper shebang line"
    fi
    
    # Check 3: Error handling (set -euo pipefail)
    if grep -q "set -euo pipefail" "$script_path"; then
        print_ok "Error handling enabled (set -euo pipefail)"
    else
        print_error "Missing error handling: set -euo pipefail"
        ((script_errors++))
    fi
    
    # Check 4: Syntax validation with bash -n
    if bash -n "$script_path" 2>/dev/null; then
        print_ok "Syntax validation passed"
    else
        print_error "Syntax errors found in script"
        ((script_errors++))
        # Show the actual syntax error
        echo "Syntax error details:"
        bash -n "$script_path" 2>&1 | sed 's/^/  /'
    fi
    
    # Check 5: Unquoted command substitution (SC2046 equivalent)
    if grep -n '\$(' "$script_path" | grep -v '".*\$(' | grep -v "'\.*\$(" | grep '\$([^)]*\$(' >/dev/null; then
        print_warning "Potential unquoted nested command substitution found"
        echo "  Lines with potential issues:"
        grep -n '\$([^)]*\$(' "$script_path" | sed 's/^/    /' || true
        ((script_warnings++))
    fi
    
    # Check 6: Dangerous for loops with command substitution
    if grep -n 'for.*in.*\$(.*' "$script_path" >/dev/null; then
        print_warning "Potentially unsafe 'for' loop with command substitution"
        echo "  Consider using 'while read -r' instead:"
        grep -n 'for.*in.*\$(.*' "$script_path" | sed 's/^/    /' || true
        ((script_warnings++))
    fi
    
    # Check 7: Unquoted variable expansions
    if grep -n 'for.*in.*\$[a-zA-Z_][a-zA-Z0-9_]*[^"]' "$script_path" >/dev/null; then
        print_warning "Unquoted variables in for loops (potential word splitting)"
        grep -n 'for.*in.*\$[a-zA-Z_][a-zA-Z0-9_]*[^"]' "$script_path" | sed 's/^/    /' || true
        ((script_warnings++))
    fi
    
    # Check 8: Missing quotes around variables in critical contexts
    local dangerous_patterns=(
        '\[ \$[a-zA-Z_][a-zA-Z0-9_]* '
        'echo \$[a-zA-Z_][a-zA-Z0-9_]*[^"]'
        'cd \$[a-zA-Z_][a-zA-Z0-9_]*[^"]'
    )
    
    for pattern in "${dangerous_patterns[@]}"; do
        if grep -n "$pattern" "$script_path" >/dev/null 2>&1; then
            print_warning "Unquoted variable expansion: $pattern"
            grep -n "$pattern" "$script_path" | head -3 | sed 's/^/    /' || true
            ((script_warnings++))
        fi
    done
    
    # Check 9: Use of deprecated or dangerous commands
    local dangerous_commands=('eval' 'exec' 'rm -rf \$' 'rm -rf /')
    for cmd in "${dangerous_commands[@]}"; do
        if grep -n "$cmd" "$script_path" >/dev/null 2>&1; then
            print_warning "Potentially dangerous command: $cmd"
            grep -n "$cmd" "$script_path" | head -2 | sed 's/^/    /' || true
            ((script_warnings++))
        fi
    done
    
    # Check 10: File existence checks before operations
    if grep -n 'cat \|grep.*<' "$script_path" >/dev/null 2>&1; then
        if ! grep -q '\[ -f.*\]' "$script_path"; then
            print_warning "File operations without existence checks"
            ((script_warnings++))
        fi
    fi
    
    # Check 11: Executable permissions
    if [[ -x "$script_path" ]]; then
        print_ok "Script is executable"
    else
        print_warning "Script is not executable (consider: chmod +x $script_name)"
        ((script_warnings++))
    fi
    
    # Check 12: UTF-8 encoding validation
    if file "$script_path" | grep -q "UTF-8"; then
        print_ok "UTF-8 encoding detected"
    elif file "$script_path" | grep -q "ASCII"; then
        print_ok "ASCII encoding (safe)"
    else
        print_warning "Unknown file encoding - may cause issues"
        ((script_warnings++))
    fi
    
    # Summary for this script
    echo ""
    if [[ $script_errors -eq 0 ]]; then
        print_ok "Script validation passed"
        ((passed_scripts++))
        if [[ $script_warnings -gt 0 ]]; then
            print_warning "Script has $script_warnings warnings"
        fi
    else
        print_error "Script validation failed with $script_errors errors"
    fi
    
    return $script_errors
}

# Main validation function
main() {
    local pm_scripts_dir=".claude/scripts/pm"
    
    print_info "Starting PM script validation"
    print_info "Checking scripts in: $pm_scripts_dir"
    echo ""
    
    # Check if directory exists
    if [[ ! -d "$pm_scripts_dir" ]]; then
        print_error "PM scripts directory not found: $pm_scripts_dir"
        exit 1
    fi
    
    # Count total scripts
    total_scripts=$(find "$pm_scripts_dir" -name "*.sh" -type f | wc -l | tr -d ' ')
    
    if [[ $total_scripts -eq 0 ]]; then
        print_error "No shell scripts found in $pm_scripts_dir"
        exit 1
    fi
    
    print_info "Found $total_scripts shell scripts to validate"
    
    # Validate each script
    local validation_failed=false
    for script_file in "$pm_scripts_dir"/*.sh; do
        if [[ -f "$script_file" ]]; then
            if ! validate_script "$script_file"; then
                validation_failed=true
            fi
        fi
    done
    
    # Final summary
    echo ""
    echo "[FINISH] VALIDATION SUMMARY"
    echo "========================"
    echo "Total scripts checked: $total_scripts"
    echo "Scripts passed: $passed_scripts"
    echo "Scripts failed: $((total_scripts - passed_scripts))"
    echo "Total warnings: $warnings"
    echo "Total errors: $errors"
    echo ""
    
    if [[ $errors -eq 0 ]]; then
        if [[ $warnings -eq 0 ]]; then
            print_ok "All scripts are perfect! [SPARKLE]"
        else
            print_warning "All scripts passed with $warnings warnings"
            echo ""
            echo "[IDEA] Consider addressing warnings for best practices"
        fi
        echo ""
        echo "[SUCCESS] PM scripts are ready for production use!"
        return 0
    else
        print_error "Validation failed with $errors critical errors"
        echo ""
        echo "[TOOL] Please fix the errors before using these scripts"
        
        if [[ "$validation_failed" == "true" ]]; then
            return 1
        fi
        return 0
    fi
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Validates all PM shell scripts for common issues and best practices."
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --verbose  Show verbose output"
    echo ""
    echo "Examples:"
    echo "  $0              # Validate all PM scripts"
    echo "  $0 --verbose    # Validate with detailed output"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--verbose)
            set -x  # Enable verbose mode
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Run main function
main