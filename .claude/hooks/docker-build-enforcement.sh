#!/bin/sh
# Pre-tool-use hook: Remind about /pm:build-deployment for Docker builds
# No longer blocks Docker — just logs a debug reminder.

DEBUG_MODE="${CLAUDE_HOOK_DEBUG:-false}"

debug_log() {
    case "${DEBUG_MODE:-}" in
        true|TRUE|1|yes|YES)
            printf '%s\n' "DEBUG [docker-enforcement]: $*" >&2
            ;;
    esac
}

main() {
    original_command="$*"
    debug_log "Checking command: ${original_command}"

    # Pass through all commands unchanged
    printf '%s\n' "${original_command}"
}

main "$@"
