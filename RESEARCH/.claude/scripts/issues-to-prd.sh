#!/usr/bin/env bash
# issues-to-prd.sh - Export triaged database issues to JSON and generate PRDs
#
# Usage:
#   ./issues-to-prd.sh <session-name> [--run <test-run-id>] [--dry-run] [--max N]
#
# Examples:
#   ./issues-to-prd.sh finance-personal
#   ./issues-to-prd.sh finance-personal --run run-20260121-143000 --max 5
#   ./issues-to-prd.sh finance-personal --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

SESSION="${1:-}"
TEST_RUN_ID=""
DRY_RUN=false
MAX_PRDS=10
INVOKE_GENERATE=true

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log() { echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $*"; }
log_success() { echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[$(date +%H:%M:%S)]${NC} $*"; }
log_error() { echo -e "${RED}[$(date +%H:%M:%S)]${NC} $*"; }

usage() {
    cat <<EOF
Usage: $0 <session-name> [OPTIONS]

Export triaged issues from database to JSON and generate PRDs using /pm:generate-remediation.

Options:
  --run <id>       Specific test run ID (default: latest with triaged issues)
  --max N          Maximum PRDs to generate (default: 10)
  --dry-run        Export JSON only, don't generate PRDs
  --no-generate    Export JSON only (same as --dry-run)
  --status-filter  Issue status to export (default: triaged)
  -h, --help       Show this help

Examples:
  $0 finance-personal                    # Export triaged issues, generate PRDs
  $0 finance-personal --max 5            # Limit to 5 highest RICE score issues
  $0 finance-personal --dry-run          # Export JSON only for review
  $0 finance-personal --status-filter escalated  # Export escalated issues
EOF
    exit 1
}

[[ -z "${SESSION}" || "${SESSION}" == "-h" || "${SESSION}" == "--help" ]] && usage

# Parse arguments
STATUS_FILTER="triaged"
shift
while [[ $# -gt 0 ]]; do
    case "$1" in
        --run) TEST_RUN_ID="$2"; shift 2 ;;
        --max) MAX_PRDS="$2"; shift 2 ;;
        --dry-run|--no-generate) INVOKE_GENERATE=false; shift ;;
        --status-filter) STATUS_FILTER="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

# Database connection - check multiple sources
get_db_conn() {
    # Try project .env first
    if [[ -f "${PROJECT_ROOT}/.env" ]]; then
        set -a
        source "${PROJECT_ROOT}/.env"
        set +a
    fi

    # For k8s port-forwarded databases, check if we need to use kubectl
    local host="${POSTGRES_HOST:-localhost}"
    local port="${POSTGRES_PORT:-5432}"
    local user="${POSTGRES_USER:-postgres}"
    local pass="${POSTGRES_PASSWORD:-}"
    local db="${POSTGRES_DB:-${SESSION}}"

    # Handle hyphenated database names
    db="${db//_/-}"

    echo "postgresql://${user}:${pass}@${host}:${port}/${db}"
}

db_query() {
    local -r query="$1"
    local conn
    conn=$(get_db_conn)
    psql "${conn}" -t -A -c "${query}" 2>/dev/null || echo ""
}

db_query_json() {
    local -r query="$1"
    local conn
    conn=$(get_db_conn)
    psql "${conn}" -t -A -c "${query}" 2>/dev/null
}

# Verify database connection
verify_db() {
    log "Verifying database connection..."
    local result
    result=$(db_query "SELECT 1" 2>&1)
    if [[ "${result}" != "1" ]]; then
        log_error "Cannot connect to database"
        echo "Connection string: $(get_db_conn | sed 's/:.*@/:***@/')"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Check .env file has correct POSTGRES_* variables"
        echo "  2. For k8s: kubectl port-forward -n ${SESSION} svc/${SESSION}-postgresql 5432:5432"
        echo "  3. Verify database '${SESSION}' exists"
        exit 1
    fi
}

# Check if issues table exists
check_issues_table() {
    local exists
    exists=$(db_query "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'issues')")
    if [[ "${exists}" != "t" ]]; then
        log_error "Issues table does not exist"
        echo "Run: .claude/scripts/create-feedback-schema.sh ${SESSION}"
        exit 1
    fi
}

# Main execution
main() {
    echo "=== Issues to PRD Export ==="
    echo ""

    verify_db
    check_issues_table

    # test_run_id is now optional - if not provided, process all matching issues for session
    local run_filter=""
    if [[ -n "${TEST_RUN_ID}" ]]; then
        run_filter="AND test_run_id='${TEST_RUN_ID}'"
        log "Session: ${SESSION}"
        log "Test Run: ${TEST_RUN_ID}"
    else
        log "Session: ${SESSION}"
        log "Test Run: (all runs)"
    fi
    log "Status Filter: ${STATUS_FILTER}"
    echo ""

    # Count issues
    local issue_count
    issue_count=$(db_query "SELECT COUNT(*) FROM issues
                            WHERE session_name='${SESSION}'
                            ${run_filter}
                            AND status='${STATUS_FILTER}'")

    log "Found ${issue_count} ${STATUS_FILTER} issues"

    if [[ "${issue_count}" -eq 0 ]]; then
        log_warn "No issues to process"
        exit 0
    fi

    # Create output directory
    local output_dir="${PROJECT_ROOT}/.claude/testing/feedback"
    mkdir -p "${output_dir}"
    local output_file="${output_dir}/${SESSION}-issues.json"

    log "Exporting to: ${output_file}"

    # Generate JSON using SQL JSON functions
    # Escape session name for SQL
    local escaped_session="${SESSION//\'/\'\'}"
    local escaped_run="${TEST_RUN_ID:-all}"

    db_query_json "SELECT json_build_object(
        'session', '${escaped_session}',
        'testRun', '${escaped_run}',
        'analyzedAt', to_char(NOW() AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'),
        'metrics', json_build_object(
            'issuesFound', (SELECT COUNT(*) FROM issues WHERE session_name='${escaped_session}' ${run_filter}),
            'issuesTriaged', (SELECT COUNT(*) FROM issues WHERE session_name='${escaped_session}' ${run_filter} AND status='triaged'),
            'issuesResolved', (SELECT COUNT(*) FROM issues WHERE session_name='${escaped_session}' ${run_filter} AND status='resolved')
        ),
        'prioritizedIssues', COALESCE((
            SELECT json_agg(issue_obj ORDER BY rice_score DESC NULLS LAST)
            FROM (
                SELECT json_build_object(
                    'id', issue_id,
                    'type', category,
                    'title', title,
                    'description', COALESCE(description, ''),
                    'severity', COALESCE(severity, 'medium'),
                    'riceScore', COALESCE(rice_score, 0),
                    'reach', COALESCE(mentions, 1),
                    'impact', CASE
                        WHEN severity = 'critical' THEN 10
                        WHEN severity = 'high' THEN 7
                        WHEN severity = 'medium' THEN 5
                        ELSE 3
                    END,
                    'confidence', 8,
                    'effort', CASE
                        WHEN category = 'bug' THEN 3
                        WHEN category = 'ux' THEN 5
                        WHEN category = 'performance' THEN 4
                        ELSE 6
                    END,
                    'reportedBy', COALESCE(persona_refs, '[]'::jsonb),
                    'journeysAffected', COALESCE(journey_refs, '[]'::jsonb),
                    'suggestedFix', COALESCE(research_context, ''),
                    'fixAttempts', COALESCE(fix_attempts, 0)
                ) as issue_obj, rice_score
                FROM issues
                WHERE session_name='${escaped_session}'
                  ${run_filter}
                  AND status='${STATUS_FILTER}'
                ORDER BY rice_score DESC NULLS LAST
                LIMIT ${MAX_PRDS}
            ) sub
        ), '[]'::json),
        'featureRequests', '[]'::json,
        'strengths', '[]'::json
    )" > "${output_file}"

    # Validate JSON
    if ! jq empty "${output_file}" 2>/dev/null; then
        log_error "Generated JSON is invalid"
        cat "${output_file}"
        exit 1
    fi

    log_success "Exported ${issue_count} issues to JSON"

    # Show preview
    echo ""
    echo "Issues to convert (by RICE score):"
    jq -r '.prioritizedIssues[] | "  \(.id): \(.title) [\(.severity), RICE: \(.riceScore)]"' "${output_file}" | head -10

    local actual_count
    actual_count=$(jq '.prioritizedIssues | length' "${output_file}")

    if [[ "${actual_count}" -lt "${issue_count}" ]]; then
        echo "  ... and $((issue_count - actual_count)) more (limited to ${MAX_PRDS})"
    fi

    # Optionally invoke generate-remediation
    if [[ "${INVOKE_GENERATE}" == "true" ]]; then
        echo ""
        log "Invoking /pm:generate-remediation..."
        echo ""

        if command -v claude &>/dev/null; then
            if claude --dangerously-skip-permissions --print "/pm:generate-remediation ${SESSION} --max ${MAX_PRDS}"; then
                # Update issue status to prd_created
                echo ""
                log "Updating issue status to 'prd_created'..."

                local updated
                updated=$(db_query "UPDATE issues
                          SET status = 'prd_created',
                              updated_at = NOW()
                          WHERE session_name='${escaped_session}'
                            ${run_filter}
                            AND status='${STATUS_FILTER}'
                          RETURNING issue_id")

                local updated_count
                updated_count=$(echo "${updated}" | grep -c . || echo 0)
                log_success "Updated ${updated_count} issues to prd_created"
            else
                log_error "generate-remediation failed"
                exit 1
            fi
        else
            log_error "Claude CLI not found"
            echo "Install: npm install -g @anthropic-ai/claude-code"
            echo ""
            echo "Or manually run: /pm:generate-remediation ${SESSION}"
            exit 1
        fi
    else
        echo ""
        log_warn "Dry run - PRDs not generated"
        echo ""
        echo "JSON exported to: ${output_file}"
        echo ""
        echo "To generate PRDs manually:"
        echo "  /pm:generate-remediation ${SESSION}"
        echo ""
        echo "Or run without --dry-run:"
        echo "  $0 ${SESSION}"
    fi

    echo ""
    echo "=== Complete ==="
    echo "JSON: ${output_file}"
    echo "PRDs: .claude/prds/"
    echo ""
    echo "Next steps:"
    echo "  1. Review generated PRDs in .claude/prds/"
    echo "  2. Run /pm:prd-parse <name> to create epics"
    echo "  3. Run /pm:epic-decompose <name> to create tasks"
}

main "$@"
