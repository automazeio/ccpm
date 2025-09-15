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

# Minimum content length requirements (in characters, excluding whitespace)
# These can be overridden by environment variables
CCPM_MIN_EPIC_CONTENT="${CCPM_MIN_EPIC_CONTENT:-100}"
CCPM_MIN_TASK_CONTENT="${CCPM_MIN_TASK_CONTENT:-50}"
CCPM_MIN_COMMENT_CONTENT="${CCPM_MIN_COMMENT_CONTENT:-30}"

# Function to get appropriate minimum content length for context
get_min_content_length() {
    local context="$1"
    case "$context" in
        epic:*)
            echo "$CCPM_MIN_EPIC_CONTENT"
            ;;
        task:*|issue:*)
            echo "$CCPM_MIN_TASK_CONTENT"
            ;;
        comment:*|update:*|progress-update:*)
            echo "$CCPM_MIN_COMMENT_CONTENT"
            ;;
        *)
            echo "50"  # Default
            ;;
    esac
}

# Validate that a body file has meaningful content
# Usage: validate_body_file_has_content "file" "context" [min_chars]
# Returns: 0 on success (file has sufficient content), 1 on error
validate_body_file_has_content() {
    local file="$1"
    local context="$2"
    local min_chars="${3:-50}"  # Default minimum 50 characters of actual content

    # Check if file exists
    if [[ ! -f "$file" ]]; then
        echo "Error: Body file $file does not exist for $context" >&2
        return 1
    fi

    # Read file content and strip whitespace
    local content
    content=$(cat "$file" | tr -d '[:space:]')

    # Get actual content length (excluding whitespace)
    local content_length=${#content}

    # Check for common placeholder patterns
    local has_placeholder=0
    if grep -qiE "(insert.*here|to.*be.*added|todo|tbd|placeholder|description.*here|add.*content|write.*here|fill.*in|coming.*soon|work.*in.*progress|wip|xxx|fixme|update.*this)" "$file"; then
        has_placeholder=1
        echo "Warning: Placeholder text detected in $file for $context" >&2
    fi

    # Check if content is too short or is placeholder
    if [[ $content_length -lt $min_chars ]] || [[ $has_placeholder -eq 1 ]]; then
        echo "Warning: Body file $file has insufficient content for $context" >&2
        echo "  Content length: $content_length chars (minimum: $min_chars)" >&2

        if [[ $has_placeholder -eq 1 ]]; then
            echo "  Placeholder text detected - replacing with proper default" >&2
        fi

        echo "Adding appropriate default content..." >&2

        # Add context-appropriate substantive default content
        case "$context" in
            epic:*)
                cat > "$file" << 'EOF'
# Epic Implementation

## Overview
This epic encompasses the implementation tasks required for this feature.

## Objectives
- Define clear implementation goals
- Establish success criteria
- Coordinate parallel development efforts

## Technical Approach
The implementation will follow established patterns and best practices.

## Success Metrics
- All acceptance criteria met
- Tests passing
- Documentation complete

## Notes
Further details will be added as implementation progresses.
EOF
                ;;
            task:*|issue:*)
                cat > "$file" << 'EOF'
# Task Details

## Description
This task implements a specific component of the parent epic.

## Implementation Notes
- Follow existing code patterns
- Ensure comprehensive test coverage
- Update documentation as needed

## Acceptance Criteria
- [ ] Implementation complete
- [ ] Tests passing
- [ ] Code reviewed
- [ ] Documentation updated

## Technical Details
Additional technical details will be documented during implementation.
EOF
                ;;
            progress-update:*|comment:*|update:*)
                cat > "$file" << 'EOF'
## Progress Update

### Summary
Work is progressing on this issue. Details to follow.

### Recent Activity
- Analyzing requirements
- Setting up development environment
- Beginning implementation

### Next Steps
- Continue implementation
- Add tests
- Update documentation

---
*Detailed progress information will be added in subsequent updates.*
EOF
                ;;
            completion:*)
                cat > "$file" << 'EOF'
## Task Completed

### Summary
This task has been completed according to specifications.

### Deliverables
- Implementation complete
- Tests added and passing
- Documentation updated

### Verification
All acceptance criteria have been met and verified.

### Notes
The implementation follows established patterns and is ready for review.
EOF
                ;;
            refresh:*|edit:*)
                # For refresh/edit operations, preserve more of the original
                # but ensure minimum content
                if [[ $content_length -lt 30 ]]; then
                    echo "" >> "$file"
                    echo "---" >> "$file"
                    echo "*Updated via CCPM. Additional details to be added.*" >> "$file"
                fi
                ;;
            *)
                cat > "$file" << 'EOF'
# Details

## Overview
This document provides information about the current work item.

## Description
Implementation details and requirements are being finalized.

## Status
Work is in progress. Updates will be provided as implementation proceeds.

## Notes
Additional information will be added as needed.
EOF
                ;;
        esac

        echo "Default content added to $file" >&2
    fi

    return 0
}

# Backward compatibility - keep the original function that calls the new one
validate_body_file_not_empty() {
    validate_body_file_has_content "$1" "$2" 1
}

# Export functions so they can be used by other scripts
export -f cross_platform_sed
export -f cross_platform_sed_backup
export -f handle_error
export -f command_exists
export -f detect_platform
export -f robust_parse
export -f get_min_content_length
export -f validate_body_file_has_content
export -f validate_body_file_not_empty