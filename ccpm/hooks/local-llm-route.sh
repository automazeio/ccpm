#!/bin/bash
# Pre-tool-use hook for Task tool routing
# Routes tasks between Claude (planning/review) and Ollama (code generation)
# Based on task content analysis and routing rules

set -e
set -o pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SETTINGS_FILE="$PROJECT_ROOT/.claude/settings.json"
ROUTING_RULES="$PROJECT_ROOT/ccpm/rules/local-llm-decision-tree.md"
OLLAMA_LIB="$PROJECT_ROOT/ccpm/lib/ollama-client.sh"

DEBUG_MODE="${CLAUDE_HOOK_DEBUG:-false}"
LOG_FILE="${CLAUDE_HOOK_LOG:-/tmp/local-llm-route.log}"

debug_log() {
    case "${DEBUG_MODE:-}" in
        true|TRUE|1|yes|YES)
            printf '[%s] DEBUG [local-llm-route]: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
            ;;
    esac
}

info_log() {
    printf '[%s] INFO [local-llm-route]: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}

error_log() {
    printf '[%s] ERROR [local-llm-route]: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}

log_to_file() {
    if [ -n "$LOG_FILE" ]; then
        printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
    fi
}

check_enabled() {
    if [ ! -f "$SETTINGS_FILE" ]; then
        debug_log "Settings file not found: $SETTINGS_FILE"
        return 1
    fi

    local enabled
    if ! enabled=$(jq -r '.local_llm.enabled // false' "$SETTINGS_FILE" 2>/dev/null); then
        debug_log "Failed to parse settings file"
        return 1
    fi

    debug_log "local_llm.enabled = $enabled"

    if [ "$enabled" != "true" ]; then
        debug_log "Local LLM routing is disabled"
        return 1
    fi

    return 0
}

check_ollama_available() {
    if [ ! -f "$OLLAMA_LIB" ]; then
        error_log "Ollama client library not found: $OLLAMA_LIB"
        return 1
    fi

    # Source the Ollama client library
    # shellcheck source=/dev/null
    source "$OLLAMA_LIB"

    local endpoint
    endpoint=$(jq -r '.local_llm.endpoint // "http://localhost:11434"' "$SETTINGS_FILE" 2>/dev/null)

    if ! ollama_health_check "$endpoint" >/dev/null 2>&1; then
        error_log "Ollama health check failed - routing to Claude"
        return 1
    fi

    debug_log "Ollama is available at $endpoint"
    return 0
}

classify_task() {
    local task_description="$1"
    local task_prompt="$2"
    local combined_text="${task_description} ${task_prompt}"

    debug_log "Classifying task: ${task_description:0:100}..."

    # Normalize text to lowercase for matching
    local text_lower
    text_lower=$(echo "$combined_text" | tr '[:upper:]' '[:lower:]')

    # Check for override conditions (always route to Claude)
    if check_critical_code_path "$text_lower"; then
        echo "claude"
        return 0
    fi

    # Check for planning/review keywords (route to Claude)
    if check_planning_keywords "$text_lower"; then
        echo "claude"
        return 0
    fi

    # Check for code generation keywords (route to Ollama)
    if check_code_generation_keywords "$text_lower"; then
        echo "ollama"
        return 0
    fi

    # Check file operations
    if check_code_file_operations "$text_lower"; then
        echo "ollama"
        return 0
    fi

    if check_doc_file_operations "$text_lower"; then
        echo "claude"
        return 0
    fi

    # Default to Claude when uncertain
    debug_log "Classification uncertain - defaulting to Claude"
    echo "claude"
}

check_critical_code_path() {
    local text="$1"

    # Security-critical keywords
    if echo "$text" | grep -qE '\b(auth|authentication|authorization|security|encrypt|decrypt|password|token|jwt|oauth|permission|acl)\b'; then
        debug_log "Detected security-critical content"
        return 0
    fi

    # Payment-related keywords
    if echo "$text" | grep -qE '\b(payment|billing|invoice|charge|transaction|stripe|paypal|credit|card|pci)\b'; then
        debug_log "Detected payment-related content"
        return 0
    fi

    # Complex algorithms
    if echo "$text" | grep -qE '\b(algorithm|optimization|performance|critical|distributed|concurrency|race condition)\b'; then
        debug_log "Detected high-complexity content"
        return 0
    fi

    return 1
}

check_planning_keywords() {
    local text="$1"

    # Primary planning indicators
    if echo "$text" | grep -qE '\b(plan|design|architecture|review|analyze|evaluate|decide|assess|recommend|strategy|approach)\b'; then
        debug_log "Detected planning keywords"
        return 0
    fi

    # Document creation indicators
    if echo "$text" | grep -qE '\b(prd|epic|specification|document|diagram|flowchart)\b'; then
        debug_log "Detected documentation keywords"
        return 0
    fi

    # Quality assurance indicators
    if echo "$text" | grep -qE '\b(code review|security review|audit|quality|compliance)\b'; then
        debug_log "Detected quality assurance keywords"
        return 0
    fi

    return 1
}

check_code_generation_keywords() {
    local text="$1"

    # Primary code generation indicators
    if echo "$text" | grep -qE '\b(implement|create function|create class|write code|generate|refactor|add method|build component|add endpoint)\b'; then
        debug_log "Detected code generation keywords"
        return 0
    fi

    # Test writing indicators
    if echo "$text" | grep -qE '\b(write test|add test|create test|test case|unit test|integration test)\b'; then
        debug_log "Detected test writing keywords"
        return 0
    fi

    # Utility and boilerplate indicators
    if echo "$text" | grep -qE '\b(utility|helper|boilerplate|crud|add validation|add logging|error handling)\b'; then
        debug_log "Detected utility/boilerplate keywords"
        return 0
    fi

    return 1
}

check_code_file_operations() {
    local text="$1"

    # Code file extensions
    if echo "$text" | grep -qE '\.(js|ts|jsx|tsx|py|sh|bash|go|java|rb|php|rs|cpp|c|h)(\s|$|")'; then
        debug_log "Detected code file operations"
        return 0
    fi

    # Test file patterns
    if echo "$text" | grep -qE '\.(test|spec)\.(js|ts|py)|test_.*\.py|.*_test\.(go|rs)'; then
        debug_log "Detected test file operations"
        return 0
    fi

    return 1
}

check_doc_file_operations() {
    local text="$1"

    # Documentation file patterns
    if echo "$text" | grep -qE '\.(md|markdown|rst|txt)(\s|$|")'; then
        # Check if it's in PRD or epic directories (planning docs)
        if echo "$text" | grep -qE '(prd|epic|\.claude/).*\.md'; then
            debug_log "Detected planning documentation operations"
            return 0
        fi
    fi

    return 1
}

get_routing_strategy() {
    local strategy
    strategy=$(jq -r '.local_llm.routing_strategy // "balanced"' "$SETTINGS_FILE" 2>/dev/null)
    echo "$strategy"
}

should_force_claude() {
    local text="$1"
    local force_keywords

    if ! force_keywords=$(jq -r '.local_llm.override_keywords[]? // empty' "$SETTINGS_FILE" 2>/dev/null); then
        return 1
    fi

    while IFS= read -r keyword; do
        if [ -n "$keyword" ] && echo "$text" | grep -qi "$keyword"; then
            debug_log "Matched override keyword: $keyword"
            return 0
        fi
    done <<< "$force_keywords"

    return 1
}

should_force_ollama() {
    local text="$1"
    local force_keywords

    if ! force_keywords=$(jq -r '.local_llm.force_ollama_keywords[]? // empty' "$SETTINGS_FILE" 2>/dev/null); then
        return 1
    fi

    while IFS= read -r keyword; do
        if [ -n "$keyword" ] && echo "$text" | grep -qi "$keyword"; then
            debug_log "Matched force Ollama keyword: $keyword"
            return 0
        fi
    done <<< "$force_keywords"

    return 1
}

route_task() {
    local task_description="$1"
    local task_prompt="$2"
    local combined_text="${task_description} ${task_prompt}"

    # Check for keyword overrides first
    if should_force_claude "$combined_text"; then
        info_log "Routing: CLAUDE (keyword override)"
        log_to_file "ROUTE: CLAUDE (override) | Description: ${task_description:0:80}"
        echo "claude"
        return 0
    fi

    if should_force_ollama "$combined_text"; then
        info_log "Routing: OLLAMA (keyword override)"
        log_to_file "ROUTE: OLLAMA (override) | Description: ${task_description:0:80}"
        echo "ollama"
        return 0
    fi

    # Classify the task
    local classification
    classification=$(classify_task "$task_description" "$task_prompt")

    # Get routing strategy
    local strategy
    strategy=$(get_routing_strategy)

    debug_log "Classification: $classification, Strategy: $strategy"

    # Apply routing strategy
    case "$strategy" in
        aggressive)
            # Route maximum to Ollama
            if [ "$classification" = "claude" ]; then
                # Only route to Claude if absolutely necessary
                if check_critical_code_path "$combined_text"; then
                    info_log "Routing: CLAUDE (aggressive strategy - critical path)"
                    log_to_file "ROUTE: CLAUDE (critical) | Description: ${task_description:0:80}"
                    echo "claude"
                else
                    info_log "Routing: OLLAMA (aggressive strategy override)"
                    log_to_file "ROUTE: OLLAMA (aggressive) | Description: ${task_description:0:80}"
                    echo "ollama"
                fi
            else
                info_log "Routing: OLLAMA (aggressive strategy)"
                log_to_file "ROUTE: OLLAMA (aggressive) | Description: ${task_description:0:80}"
                echo "ollama"
            fi
            ;;
        conservative)
            # Route maximum to Claude
            if [ "$classification" = "ollama" ]; then
                # Only route to Ollama if clearly suitable
                if check_code_generation_keywords "$combined_text" && ! check_critical_code_path "$combined_text"; then
                    info_log "Routing: OLLAMA (conservative strategy - clear code gen)"
                    log_to_file "ROUTE: OLLAMA (conservative) | Description: ${task_description:0:80}"
                    echo "ollama"
                else
                    info_log "Routing: CLAUDE (conservative strategy override)"
                    log_to_file "ROUTE: CLAUDE (conservative) | Description: ${task_description:0:80}"
                    echo "claude"
                fi
            else
                info_log "Routing: CLAUDE (conservative strategy)"
                log_to_file "ROUTE: CLAUDE (conservative) | Description: ${task_description:0:80}"
                echo "claude"
            fi
            ;;
        balanced|*)
            # Use classification as-is
            local route_upper
            route_upper=$(echo "$classification" | tr '[:lower:]' '[:upper:]')
            info_log "Routing: ${route_upper} (balanced strategy)"
            log_to_file "ROUTE: ${route_upper} (balanced) | Description: ${task_description:0:80}"
            echo "$classification"
            ;;
    esac
}

extract_task_info() {
    local input="$1"

    # This is a placeholder for parsing Task tool parameters
    # In a real implementation, this would parse JSON or structured input
    # For now, we'll treat the entire input as task description

    local task_description="$input"
    local task_prompt="$input"

    echo "$task_description|$task_prompt"
}

inject_ollama_agent() {
    local original_input="$1"

    # Inject instructions to use local-code-generator agent
    # This is a conceptual demonstration - actual implementation depends on
    # how the Task tool and agent system work

    cat <<EOF
[ROUTE TO OLLAMA]
Task will be processed by local-code-generator agent using Ollama.

Original task:
$original_input

Note: Generated code will be reviewed by Claude for quality assurance.
EOF
}

main() {
    local input
    input=$(cat)

    debug_log "Received input (first 200 chars): ${input:0:200}"

    # Check if routing is enabled
    if ! check_enabled; then
        debug_log "Routing disabled - passing through unchanged"
        echo "$input"
        exit 0
    fi

    # Check if Ollama is available
    if ! check_ollama_available; then
        debug_log "Ollama unavailable - passing through to Claude"
        echo "$input"
        exit 0
    fi

    # Extract task information
    local task_info
    task_info=$(extract_task_info "$input")

    local task_description
    task_description=$(echo "$task_info" | cut -d'|' -f1)

    local task_prompt
    task_prompt=$(echo "$task_info" | cut -d'|' -f2)

    # Route the task
    local target
    target=$(route_task "$task_description" "$task_prompt")

    # Modify output based on routing decision
    if [ "$target" = "ollama" ]; then
        info_log "Task routed to Ollama - injecting agent instructions"
        inject_ollama_agent "$input"
    else
        info_log "Task routed to Claude - passing through unchanged"
        echo "$input"
    fi

    debug_log "Routing complete"
}

# Only run main if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
