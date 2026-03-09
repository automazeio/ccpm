#!/bin/bash

# Path Standards Fix Script
# Automatically converts absolute paths to relative paths in documentation

set -Eeuo pipefail

echo "🔧 Path Standards Fix Starting..."

# Color output functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Path normalization function
normalize_paths() {
    local file="$1"
    local backup_file="${file}.backup"
    
    print_info "Processing file: $file"
    
    # Create backup
    cp "$file" "$backup_file"
    
    # Apply path transformation rules - fixed patterns for proper Windows path handling
    sed -i.tmp \
        -e 's|/Users/[^/]*/[^/]*/|../|g' \
        -e 's|/home/[^/]*/[^/]*/|../|g' \
        -e 's|C:\\\\Users\\\\[^\\\\]*\\\\[^\\\\]*\\\\|..\\\\|g' \
        -e 's|\\./\\([^./]\\)|\\1|g' \
        "$file"
    
    # Clean up temporary files
    rm -f "${file}.tmp"
    
    # Check for changes
    if ! diff -q "$file" "$backup_file" >/dev/null 2>&1; then
        print_success "File fixed: $(basename "$file")"
        return 0
    else
        print_info "File needs no changes: $(basename "$file")"
        rm "$backup_file"  # Remove unnecessary backup
        return 1
    fi
}

# Fix statistics
files_processed=0
files_modified=0

# Process all markdown files in .claude directory
echo -e "\n🔍 Scanning for files needing fixes..."

while IFS= read -r -d '' file; do
    # Skip backup files and rule documentation (which contains examples)
    [[ "$file" == *.backup ]] && continue
    [[ "$file" == *"/rules/"* ]] && continue
    
    # Check if file contains paths that need fixing - use extended regex
    if grep -Eq "/Users/|/home/|C:\\\\\\\\" "$file" 2>/dev/null; then
        files_processed=$((files_processed + 1))
        
        if normalize_paths "$file"; then
            files_modified=$((files_modified + 1))
        fi
    fi
done < <(find .claude/ -name "*.md" -type f -print0 2>/dev/null)

# Output statistics
echo -e "\n📊 Fix Results Summary:"
echo "Files processed: $files_processed"
echo "Files modified: $files_modified"

if [ $files_modified -gt 0 ]; then
    print_success "Successfully fixed $files_modified files"
    
    echo -e "\n💾 Backup Information:"
    echo "Original files backed up with .backup suffix"
    echo "To restore if needed: mv file.backup file"
    
    print_warning "Recommended: Run validation script to verify fixes:"
    echo "./.claude/scripts/check-path-standards.sh"
    
elif [ $files_processed -eq 0 ]; then
    print_success "No files found requiring fixes 🎉"
else
    print_info "All files were already compliant"
fi

# Provide cleanup option for backup files
if [ $files_modified -gt 0 ]; then
    echo -e "\n🧹 Cleanup Backup Files (optional):"
    echo "If fixes are confirmed correct, run:"
    echo "find .claude/ -name '*.backup' -delete"
fi

echo -e "\n✨ Path standards fix completed!"