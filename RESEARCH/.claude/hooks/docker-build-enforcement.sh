#!/bin/sh
# Pre-tool-use hook: Block direct Docker CLI build/push commands
# Forces image builds through /pm:build-deployment skill (which uses nerdctl)
#
# BLOCKED: docker build, docker push
# ALLOWED: nerdctl build, nerdctl push (used by official skill)

DEBUG_MODE="${CLAUDE_HOOK_DEBUG:-false}"

debug_log() {
    case "${DEBUG_MODE:-}" in
        true|TRUE|1|yes|YES)
            printf '%s\n' "DEBUG [docker-enforcement]: $*" >&2
            ;;
    esac
}

# Check if command contains direct Docker CLI build/push (NOT nerdctl)
is_blocked_command() {
    cmd="$1"

    # Only block 'docker' commands, allow 'nerdctl'
    case "$cmd" in
        *"docker build"*|*"docker push"*)
            return 0  # Is blocked
            ;;
        *)
            return 1  # Not blocked
            ;;
    esac
}

main() {
    original_command="$*"
    debug_log "Checking command: ${original_command}"

    if is_blocked_command "${original_command}"; then
        # Output error message to stderr
        printf '%s\n' "Direct 'docker' CLI commands are blocked" >&2
        printf '%s\n' "" >&2
        printf '%s\n' "Use the official deployment skills instead:" >&2
        printf '%s\n' "  /pm:build-deployment <scope>  - Build and push images" >&2
        printf '%s\n' "  /pm:deploy <scope>            - Build, push, and deploy" >&2
        printf '%s\n' "" >&2
        printf '%s\n' "These skills use nerdctl internally with proper registry config." >&2
        printf '%s\n' "See: .claude/rules/docker-operations.md" >&2

        # Return a command that will fail gracefully
        printf '%s\n' "exit 1"
        exit 0
    fi

    # Pass through unchanged
    debug_log "Command allowed, passing through"
    printf '%s\n' "${original_command}"
}

main "$@"
