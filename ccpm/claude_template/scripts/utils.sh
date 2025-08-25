#!/bin/bash

# Cross-platform utility functions for CCPM shell scripts
# This file provides portable implementations of commonly used commands

# Cross-platform sed in-place replacement
# Usage: cross_platform_sed 's/old/new/g' file
cross_platform_sed() {
    local sed_expression="$1"
    local file="$2"
    
    if [[ -z "$sed_expression" || -z "$file" ]]; then
        echo "Usage: cross_platform_sed 'expression' file" >&2
        return 1
    fi
    
    # Check if file exists
    if [[ ! -f "$file" ]]; then
        echo "Error: File '$file' does not exist" >&2
        return 1
    fi
    
    # Create a temporary file
    local temp_file
    temp_file=$(mktemp)
    
    # Perform the sed operation using a temporary file approach
    if sed "$sed_expression" "$file" > "$temp_file"; then
        # Only replace if sed was successful
        mv "$temp_file" "$file"
    else
        # Clean up temp file on failure
        rm -f "$temp_file"
        echo "Error: sed operation failed" >&2
        return 1
    fi
}

# Cross-platform in-place replacement with backup
# Usage: cross_platform_sed_backup 's/old/new/g' file
cross_platform_sed_backup() {
    local sed_expression="$1"
    local file="$2"
    
    if [[ -z "$sed_expression" || -z "$file" ]]; then
        echo "Usage: cross_platform_sed_backup 'expression' file" >&2
        return 1
    fi
    
    # Check if file exists
    if [[ ! -f "$file" ]]; then
        echo "Error: File '$file' does not exist" >&2
        return 1
    fi
    
    # Create backup
    cp "$file" "$file.bak"
    
    # Use our cross-platform sed function
    if ! cross_platform_sed "$sed_expression" "$file"; then
        # Restore backup on failure
        mv "$file.bak" "$file"
        echo "Error: sed operation failed, backup restored" >&2
        return 1
    fi
    
    return 0
}

# Enhanced error handling function
handle_error() {
    local exit_code=$?
    local line_number=${1:-"unknown"}
    local command=${2:-"unknown command"}
    
    if [[ $exit_code -ne 0 ]]; then
        echo "❌ Error on line $line_number: '$command' failed with exit code $exit_code" >&2
        exit $exit_code
    fi
}

# Cross-platform command existence check
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Platform detection
detect_platform() {
    case "$(uname -s)" in
        Linux*)     echo "Linux";;
        Darwin*)    echo "macOS";;
        CYGWIN*)    echo "Windows";;
        MINGW*)     echo "Windows";;
        MSYS*)      echo "Windows";;
        *)          echo "Unknown";;
    esac
}

# Robust awk-based parsing function for better cross-platform parsing
# Usage: robust_parse "pattern" file
robust_parse() {
    local pattern="$1"
    local file="$2"
    
    if [[ -z "$pattern" || -z "$file" ]]; then
        echo "Usage: robust_parse 'pattern' file" >&2
        return 1
    fi
    
    if [[ ! -f "$file" ]]; then
        echo "Error: File '$file' does not exist" >&2
        return 1
    fi
    
    # Use awk for more reliable parsing
    awk "$pattern" "$file"
}

# Export functions so they can be used by other scripts
export -f cross_platform_sed
export -f cross_platform_sed_backup
export -f handle_error
export -f command_exists
export -f detect_platform
export -f robust_parse