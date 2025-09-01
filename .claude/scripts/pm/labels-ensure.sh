#!/bin/bash
# labels-ensure.sh - Core label management utility for CCPM
# 
# This script provides functions to check for existing GitHub labels and create missing ones.
# It implements enhanced file-based caching with configurable TTL to improve performance.
#
# Features:
# - Repository-specific cache files with full owner/name format
# - Configurable TTL via CCPM_LABEL_CACHE_TTL environment variable (default: 5 minutes)
# - Automatic cache refresh when expired
# - Force cache refresh functionality
# - Cache invalidation after label creation
# - Multi-repository support
#
# Usage: Source this script in other scripts to access label management functions
# Example: source .claude/scripts/pm/labels-ensure.sh
# Example with custom TTL: CCPM_LABEL_CACHE_TTL=10 source .claude/scripts/pm/labels-ensure.sh

# Color codes for standard CCPM labels
declare -A STANDARD_LABELS
STANDARD_LABELS=(
    ["epic"]="7057ff"
    ["task"]="0969da" 
    ["feature"]="0e8a16"
    ["bug"]="d73a4a"
    ["test:not-written"]="6e7781"
    ["test:written"]="fbca04"
    ["test:passing"]="0e8a16"
    ["test:failing"]="d73a4a"
    ["test:flaky"]="fb8500"
)

# Descriptions for standard CCPM labels
declare -A LABEL_DESCRIPTIONS
LABEL_DESCRIPTIONS=(
    ["epic"]="Epic issue containing multiple tasks"
    ["task"]="Individual task within an epic"
    ["feature"]="New feature or enhancement"
    ["bug"]="Something isn't working"
    ["test:not-written"]="Test specification exists but no code"
    ["test:written"]="Test code exists but not verified"
    ["test:passing"]="Test executes successfully"
    ["test:failing"]="Test currently failing"
    ["test:flaky"]="Test intermittently fails"
)

# Get cache file path based on current repository
get_cache_file() {
    local repo_name
    repo_name=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null | tr '/' '-' || echo "unknown")
    echo "/tmp/ccpm-labels-cache-${repo_name}.txt"
}

# Check if cache is valid (configurable TTL, defaults to 5 minutes)
is_cache_valid() {
    local cache_file="$1"
    local ttl="${CCPM_LABEL_CACHE_TTL:-5}"  # TTL in minutes, default 5
    
    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi
    
    # Use find -mmin for TTL check as specified in requirements
    [[ $(find "$cache_file" -mmin -"$ttl" 2>/dev/null) ]]
}

# Refresh the label cache by fetching current labels from GitHub
refresh_label_cache() {
    local cache_file
    cache_file=$(get_cache_file)
    
    echo "Refreshing label cache..."
    
    # Fetch labels and store in cache file
    if gh label list --json name -q '.[].name' > "$cache_file" 2>/dev/null; then
        echo "Label cache refreshed at $cache_file"
    else
        echo "Warning: Failed to refresh label cache" >&2
        # Remove invalid cache file
        rm -f "$cache_file"
        return 1
    fi
}

# Force refresh the label cache, ignoring TTL
force_refresh_cache() {
    local cache_file
    cache_file=$(get_cache_file)
    
    echo "Force refreshing label cache..."
    
    # Remove existing cache file to force refresh
    rm -f "$cache_file"
    
    # Refresh the cache
    refresh_label_cache
}

# Clear the label cache (used after label creation)
clear_label_cache() {
    local cache_file
    cache_file=$(get_cache_file)
    
    if [[ -f "$cache_file" ]]; then
        rm -f "$cache_file"
        echo "Label cache cleared"
    fi
}

# Check if a label exists (uses cache for performance)
check_label_exists() {
    local label_name="$1"
    local cache_file
    
    if [[ -z "$label_name" ]]; then
        echo "Error: Label name is required" >&2
        return 1
    fi
    
    cache_file=$(get_cache_file)
    
    # Refresh cache if invalid or missing
    if ! is_cache_valid "$cache_file"; then
        if ! refresh_label_cache; then
            # Fallback to direct API call if cache refresh fails
            echo "Warning: Cache unavailable, checking label directly..." >&2
            gh label list --json name -q '.[].name' | grep -q "^${label_name}$" 2>/dev/null
            return $?
        fi
    fi
    
    # Check cache for label existence
    grep -q "^${label_name}$" "$cache_file" 2>/dev/null
}

# Create a single label with color and description
create_label() {
    local label_name="$1"
    local color="$2"
    local description="$3"
    
    if [[ -z "$label_name" || -z "$color" ]]; then
        echo "Error: Label name and color are required" >&2
        return 1
    fi
    
    # Remove # from color if present
    color="${color#\#}"
    
    echo "Creating label: $label_name (color: #$color)"
    
    local create_args=("--name" "$label_name" "--color" "$color")
    
    if [[ -n "$description" ]]; then
        create_args+=("--description" "$description")
    fi
    
    if gh label create "${create_args[@]}" 2>/dev/null; then
        echo "✓ Successfully created label: $label_name"
        return 0
    else
        echo "Warning: Failed to create label '$label_name' (may already exist)" >&2
        return 1
    fi
}

# Create all standard CCPM labels
ensure_standard_labels() {
    echo "Ensuring all standard CCPM labels exist..."
    local created_count=0
    local total_count=${#STANDARD_LABELS[@]}
    
    for label_name in "${!STANDARD_LABELS[@]}"; do
        if ! check_label_exists "$label_name"; then
            local color="${STANDARD_LABELS[$label_name]}"
            local description="${LABEL_DESCRIPTIONS[$label_name]}"
            
            if create_label "$label_name" "$color" "$description"; then
                ((created_count++))
            fi
        else
            echo "✓ Label already exists: $label_name"
        fi
    done
    
    # Clear cache once if any labels were created to ensure consistency
    if [[ $created_count -gt 0 ]]; then
        clear_label_cache
    fi
    
    echo "Standard labels status: $created_count created, $((total_count - created_count)) already existed"
}

# Create epic-specific label (e.g., "epic:user-management")
ensure_epic_label() {
    local epic_name="$1"
    
    if [[ -z "$epic_name" ]]; then
        echo "Error: Epic name is required" >&2
        return 1
    fi
    
    # Format epic label name
    local epic_label="epic:${epic_name}"
    local color="7057ff"  # Same as standard epic color
    local description="Epic: ${epic_name}"
    
    echo "Ensuring epic label exists: $epic_label"
    
    if ! check_label_exists "$epic_label"; then
        if create_label "$epic_label" "$color" "$description"; then
            # Clear cache after successful epic label creation
            clear_label_cache
        fi
    else
        echo "✓ Epic label already exists: $epic_label"
    fi
}

# Utility function to list all cached labels (for debugging)
list_cached_labels() {
    local cache_file
    cache_file=$(get_cache_file)
    
    if is_cache_valid "$cache_file"; then
        echo "Cached labels (from $cache_file):"
        cat "$cache_file"
    else
        echo "No valid cache available"
        return 1
    fi
}

# Check if GitHub CLI is available and authenticated
check_gh_cli() {
    if ! command -v gh >/dev/null 2>&1; then
        echo "Error: GitHub CLI (gh) is not installed" >&2
        return 1
    fi
    
    if ! gh auth status >/dev/null 2>&1; then
        echo "Error: GitHub CLI is not authenticated. Run 'gh auth login'" >&2
        return 1
    fi
    
    return 0
}

# Main initialization when script is sourced
if ! check_gh_cli; then
    echo "Warning: GitHub CLI is not properly configured" >&2
fi

# Functions are automatically available when this script is sourced