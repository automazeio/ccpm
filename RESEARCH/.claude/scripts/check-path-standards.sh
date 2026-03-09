#!/bin/bash

# Path Standards Validation Script
# Validates that project documentation follows path format standards

set -Eeuo pipefail

echo "🔍 Path Standards Validation Starting..."

# Color output functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check counters
total_checks=0
passed_checks=0
failed_checks=0

# Check functions
check_absolute_paths() {
    echo -e "\n📋 Check 1: Scanning for absolute path violations..."
    total_checks=$((total_checks + 1))
    
    # Check for absolute paths in .claude directory, excluding rules and backups
    if rg -q "/Users/|/home/|C:\\\\\\\\" .claude/ -g '!rules/**' -g '!**/*.backup' 2>/dev/null; then
        print_error "Found absolute path violations:"
        rg -n "/Users/|/home/|C:\\\\\\\\" .claude/ -g '!rules/**' -g '!**/*.backup' | head -10
        failed_checks=$((failed_checks + 1))
        return 1
    else
        print_success "No absolute path violations found"
        passed_checks=$((passed_checks + 1))
        return 0
    fi
}

check_user_specific_paths() {
    echo -e "\n📋 Check 2: Scanning for user-specific paths..."
    total_checks=$((total_checks + 1))
    
    # Check for paths containing usernames, excluding documentation examples
    if rg -q "/[Uu]sers/[^/]*/|/home/[^/]*/" .claude/ -g '!rules/**' -g '!**/*.backup' 2>/dev/null; then
        print_error "Found user-specific paths:"
        rg -n "/[Uu]sers/[^/]*/|/home/[^/]*/" .claude/ -g '!rules/**' -g '!**/*.backup' | head -10
        failed_checks=$((failed_checks + 1))
        return 1
    else
        print_success "No user-specific paths found"
        passed_checks=$((passed_checks + 1))
        return 0
    fi
}

check_path_format_consistency() {
    echo -e "\n📋 Check 3: Checking path format consistency..."
    total_checks=$((total_checks + 1))
    
    # Check for consistent relative path formats, excluding documentation
    inconsistent_found=false
    
    # Check for mixed usage of ./ and direct paths
    if rg -q "\\.\/" .claude/ -g '!rules/**' -g '!**/*.backup' 2>/dev/null && \
       rg -q "src/|lib/|internal/|cmd/|configs/" .claude/ -g '!rules/**' -g '!**/*.backup' 2>/dev/null; then
        print_warning "Found inconsistent path formats (mixed ./ and direct paths)"
        inconsistent_found=true
    fi
    
    if [ "$inconsistent_found" = false ]; then
        print_success "Path formats are consistent"
        passed_checks=$((passed_checks + 1))
    else
        print_warning "Consider standardizing path formats"
        passed_checks=$((passed_checks + 1))  # Warning, not failure
    fi
}

check_sync_content() {
    echo -e "\n📋 Check 4: Validating sync content path formats..."
    total_checks=$((total_checks + 1))
    
    # Check update files for proper path formats
    update_files=$(find .claude/epics/*/updates/ -name "*.md" 2>/dev/null | head -10)
    
    if [ -z "$update_files" ]; then
        print_warning "No update files found, skipping this check"
        passed_checks=$((passed_checks + 1))
        return 0
    fi
    
    violations_found=false
    for file in $update_files; do
        if rg -q "/Users/|/home/|C:\\\\\\\\" "$file" 2>/dev/null; then
            print_error "File $file contains absolute paths"
            violations_found=true
        fi
    done
    
    if [ "$violations_found" = false ]; then
        print_success "Update file path formats are correct"
        passed_checks=$((passed_checks + 1))
    else
        failed_checks=$((failed_checks + 1))
        return 1
    fi
}

check_standards_file() {
    echo -e "\n📋 Check 5: Verifying standards file exists..."
    total_checks=$((total_checks + 1))
    
    if [ -f ".claude/rules/path-standards.md" ]; then
        print_success "Path standards documentation exists"
        passed_checks=$((passed_checks + 1))
    else
        print_error "Missing path standards documentation file"
        failed_checks=$((failed_checks + 1))
        return 1
    fi
}

# Run all checks
check_absolute_paths
check_user_specific_paths  
check_path_format_consistency
check_sync_content
check_standards_file

# Output summary
echo -e "\n📊 Validation Results Summary:"
echo "Total checks: $total_checks"
echo "Passed: $passed_checks"
echo "Failed: $failed_checks"

if [ $failed_checks -eq 0 ]; then
    print_success "All checks passed! Path standards compliant 🎉"
    exit 0
else
    print_error "Found $failed_checks issues that need fixing"
    echo -e "\n💡 Remediation suggestions:"
    echo "1. Run path cleanup script to fix absolute paths"
    echo "2. Review and update relevant documentation formats"  
    echo "3. Follow guidelines in .claude/rules/path-standards.md"
    exit 1
fi