#!/bin/bash
# interrogate.sh - Orchestrate structured discovery conversations
#
# This script delegates discovery steps to discovery.sh and adds additional
# infrastructure, deployment, and testing steps.
#
# Individual Steps:
#   ./interrogate.sh --services [name]        # Step 1: Setup PostgreSQL, MinIO, CloudBeaver
#   ./interrogate.sh --schema [name]          # Step 2: Create database schema
#   ./interrogate.sh --repo [name]            # Step 3: Ensure GitHub repo exists
#   ./interrogate.sh --discover <name>        # Step 4: Run 12-section discovery (via discovery.sh)
#   ./interrogate.sh --scope <name>           # Step 5: Create scope documents (via discovery.sh)
#   ./interrogate.sh --credentials [name]     # Step 6: Gather credentials (auto-detects scope)
#   ./interrogate.sh --roadmap <name>         # Step 7: Generate MVP roadmap (via discovery.sh)
#   ./interrogate.sh --generate-template <name> # Step 8: Generate K8s + code scaffolds
#   ./interrogate.sh --deploy-skeleton <name>  # Step 9: Deploy skeleton application
#   ./interrogate.sh --decompose <name>       # Step 10: Decompose into PRDs (via discovery.sh)
#   ./interrogate.sh --batch <name>           # Step 11: Batch process PRDs
#   ./interrogate.sh --deploy <name>          # Step 12: Deploy full application
#   ./interrogate.sh --synthetic <name>       # Step 13: Synthetic testing
#   ./interrogate.sh --remediation <name>     # Step 14: Generate remediation PRDs
#
# Pipeline Commands:
#   ./interrogate.sh [session-name]           # Run full pipeline
#   ./interrogate.sh --build <name>           # Run full pipeline (explicit)
#   ./interrogate.sh --resume <name>          # Resume from last step
#   ./interrogate.sh --resume-from <N> <name> # Resume from specific step
#
# Session Management:
#   ./interrogate.sh --list                   # List all sessions
#   ./interrogate.sh --status [name]          # Show session status
#   ./interrogate.sh --pipeline-status <name> # Show pipeline progress
#
# Pipeline Flow:
#   services → schema → repo → discover → scope → credentials → roadmap → template → skeleton → decompose → batch → deploy → synthetic → remediation

set -e

# Get script directory for sourcing library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to discovery.sh
DISCOVERY_SH="$SCRIPT_DIR/pm/discovery.sh"

SESSION_NAME="${1:-$(date +%Y%m%d-%H%M%S)}"
SESSION_DIR=".claude/interrogations/$SESSION_NAME"
CONV_FILE="$SESSION_DIR/conversation.md"
SCOPE_DIR=".claude/scopes/$SESSION_NAME"

# Show help
show_help() {
  cat << 'EOF'
Interrogate - Structured Discovery Conversations

Usage:
  ./interrogate.sh [session-name]             Full pipeline (default): services → PRDs → batch-process
  ./interrogate.sh --help                     Show this help

Individual Steps (run independently):
   1. ./interrogate.sh --services [name]       Setup PostgreSQL, MinIO, CloudBeaver
   2. ./interrogate.sh --schema [name]         Create interview database schema
   3. ./interrogate.sh --repo [name]           Ensure GitHub repo exists
   4. ./interrogate.sh --discover <name>       Run 12-section discovery (INTERACTIVE)
   5. ./interrogate.sh --scope <name>          Create scope documents from discovery
 5.5. ./interrogate.sh --sync <name>          Sync markdown to database (auto-runs after scope)
   6. ./interrogate.sh --credentials [name]    Gather integration credentials (auto-detects)
   7. ./interrogate.sh --roadmap <name>        Generate MVP roadmap
   8. ./interrogate.sh --generate-template <name> Generate K8s + code scaffolds
   9. ./interrogate.sh --deploy-skeleton <name>  Deploy skeleton application
  10. ./interrogate.sh --decompose <name>      Decompose into PRDs (alias: --prds)
  11. ./interrogate.sh --batch <name>          Batch process PRDs
  12. ./interrogate.sh --deploy <name>         Deploy full application
  13. ./interrogate.sh --synthetic <name>      Synthetic persona testing (alias: --test)
  14. ./interrogate.sh --remediation <name>    Generate remediation PRDs (alias: --fix)
  15. ./interrogate.sh --feedback <name>       Run feedback pipeline (test→research→fix)

Legacy Support:
  ./interrogate.sh --interrogate-only <name>  Alias for --discover
  ./interrogate.sh --extract <name>           Alias for --scope

Pipeline Commands:
  ./interrogate.sh --build <name>             Run full pipeline from step 1
  ./interrogate.sh --resume <name>            Resume from last completed step
  ./interrogate.sh --resume-from <N> <name>   Resume from specific step (1-14)
  ./interrogate.sh --pipeline-status <name>   Show pipeline progress

Session Management:
  ./interrogate.sh --list                     List all sessions
  ./interrogate.sh --status [name]            Show session status

Example - Run steps independently:
  ./interrogate.sh --services myapp           # Step 1: Setup infrastructure
  ./interrogate.sh --repo myapp               # Step 3: Setup GitHub repo
  ./interrogate.sh --discover myapp           # Step 4: Run 12-section discovery
  ./interrogate.sh --scope myapp              # Step 5: Generate scope documents
  ./interrogate.sh --roadmap myapp            # Step 7: Create roadmap
  ./interrogate.sh --generate-template myapp  # Step 8: Generate K8s templates
  ./interrogate.sh --deploy-skeleton myapp    # Step 9: Deploy skeleton app
  ./interrogate.sh --decompose myapp          # Step 10: Create PRDs
  ./interrogate.sh --batch myapp              # Step 11: Process PRDs
  ./interrogate.sh --deploy myapp             # Step 12: Deploy full app

Self-Healing:
  When a step fails in pipeline mode, it automatically invokes /pm:fix_problem
  to diagnose and fix the issue. Up to 3 fix attempts are made before
  escalating to manual intervention.

Output Files:
  .claude/scopes/<name>/sections/             12 discovery section files
  .claude/scopes/<name>/discovery.md          Merged discovery document
  .claude/scopes/<name>/00_scope_document.md  Comprehensive scope doc
  .claude/scopes/<name>/01_features.md        Feature catalog
  .claude/scopes/<name>/02_user_journeys.md   User journey maps
  .claude/scopes/<name>/04_technical_architecture.md   Tech stack, integrations
  .claude/scopes/<name>/07_roadmap.md         MVP roadmap with phases
  .claude/scopes/<name>/credentials.yaml      Credential collection metadata
  .claude/prds/<name>/*.md                    Generated PRDs
  .claude/testing/personas/<name>-personas.json   Synthetic test personas
  .claude/testing/playwright/                 E2E test suite
  .claude/testing/feedback/<name>-feedback.json   Synthetic user feedback
  .claude/testing/feedback/<name>-analysis.md     Feedback analysis report
  .env                                        Environment credentials (gitignored)
  .env.template                               Template for sharing

Pipeline State:
  .claude/pipeline/<name>/state.yaml          Pipeline progress tracking
  .claude/pipeline/<name>/feedback-state.yaml Feedback pipeline progress
  .claude/pipeline/<name>/fix-issue-*.md      Fix attempt logs per issue
EOF
}

# List all sessions
list_sessions() {
  echo "=== Discovery Sessions ==="
  echo ""

  # Delegate to discovery.sh --list
  if [ -f "$DISCOVERY_SH" ]; then
    "$DISCOVERY_SH" --list
  else
    echo "discovery.sh not found at: $DISCOVERY_SH"
    echo ""
    # Fallback to local listing
    if [ -d ".claude/scopes" ] && [ "$(ls -A .claude/scopes 2>/dev/null)" ]; then
      for dir in .claude/scopes/*/; do
        if [ -d "$dir" ]; then
          name=$(basename "$dir")
          echo "  $name"
        fi
      done
    else
      echo "No sessions found."
    fi
  fi
}

# Show session status
show_status() {
  local name="${1:-$SESSION_NAME}"

  # Delegate to discovery.sh --status
  if [ -f "$DISCOVERY_SH" ]; then
    "$DISCOVERY_SH" --status "$name"
  else
    echo "discovery.sh not found at: $DISCOVERY_SH"
    exit 1
  fi

  # Also show interrogate-specific status
  local pipeline_state=".claude/pipeline/$name/state.yaml"
  if [ -f "$pipeline_state" ]; then
    echo ""
    echo "=== Pipeline Status ==="
    local pipe_status
    pipe_status=$(grep "^status:" "$pipeline_state" 2>/dev/null | head -1 | cut -d: -f2 | tr -d ' ')
    local last_step
    last_step=$(grep "^last_completed_step:" "$pipeline_state" 2>/dev/null | cut -d: -f2 | tr -d ' ')
    echo "  Status: $pipe_status"
    echo "  Progress: Step $last_step/14"
  fi
}

# Run discovery (Step 4) - delegates to discovery.sh
run_discover() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./interrogate.sh --discover <session-name>"
    exit 1
  fi

  echo "=== Step 4: Discovery (12 sections) ==="
  echo ""

  # Delegate to discovery.sh
  if [ -f "$DISCOVERY_SH" ]; then
    "$DISCOVERY_SH" --discover "$name"
  else
    echo "❌ discovery.sh not found at: $DISCOVERY_SH"
    exit 1
  fi
}

# Create scope documents (Step 5) - delegates to discovery.sh
create_scope() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./interrogate.sh --scope <session-name>"
    exit 1
  fi

  echo "=== Step 5: Create Scope Documents ==="
  echo ""

  # First merge if not done
  if [ ! -f ".claude/scopes/$name/discovery.md" ]; then
    if [ -f "$DISCOVERY_SH" ]; then
      "$DISCOVERY_SH" --merge "$name"
    fi
  fi

  # Then create scope
  if [ -f "$DISCOVERY_SH" ]; then
    "$DISCOVERY_SH" --scope "$name"
  else
    echo "❌ discovery.sh not found at: $DISCOVERY_SH"
    exit 1
  fi

  # Auto-sync to database
  echo ""
  echo "Syncing to database..."
  if [ -f "./.claude/scripts/sync-interview-to-db.sh" ]; then
    ./.claude/scripts/sync-interview-to-db.sh "$name" || echo "⚠️ DB sync had issues (non-fatal)"
  fi
}

# Sync interview data to database (Step 5.5)
sync_to_database() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./interrogate.sh --sync <session-name>"
    exit 1
  fi

  local scope_dir=".claude/scopes/$name"

  if [ ! -d "$scope_dir" ]; then
    echo "❌ No scope found for session: $name"
    echo ""
    echo "First run: ./interrogate.sh --scope $name"
    exit 1
  fi

  echo "=== Sync to Database: $name ==="
  echo ""

  if [ -f "./.claude/scripts/sync-interview-to-db.sh" ]; then
    ./.claude/scripts/sync-interview-to-db.sh "$name"
  else
    echo "❌ sync-interview-to-db.sh not found"
    exit 1
  fi
}

# Gather credentials for integrations (Step 6)
gather_credentials() {
  local name="$1"

  # Auto-detect scope if not provided
  if [ -z "$name" ]; then
    local scope_count
    scope_count=$(ls -1d .claude/scopes/*/ 2>/dev/null | wc -l)

    if [ "$scope_count" -eq 0 ]; then
      echo "❌ No scopes found in .claude/scopes/"
      echo ""
      echo "First run: ./interrogate.sh --scope <session-name>"
      exit 1
    elif [ "$scope_count" -eq 1 ]; then
      name=$(ls -1d .claude/scopes/*/ 2>/dev/null | head -1 | xargs basename)
      echo "Using scope: $name"
    else
      name=$(ls -1td .claude/scopes/*/ 2>/dev/null | head -1 | xargs basename)
      echo "Multiple scopes found, using most recent: $name"
    fi
    echo ""
  fi

  local scope=".claude/scopes/$name/04_technical_architecture.md"

  if [ ! -f "$scope" ]; then
    echo "❌ Scope not found: $name"
    echo ""
    echo "First run: ./interrogate.sh --scope $name"
    exit 1
  fi

  echo "=== Step 6: Gathering Credentials ==="
  echo ""
  echo "Scope: $name"
  echo "This will collect credentials for integrations in your scope document..."
  echo ""

  claude --dangerously-skip-permissions "/pm:gather-credentials $name"

  echo ""
  echo "---"
  echo ""

  if [ -f ".env" ]; then
    echo "✅ Credentials gathered"
    echo ""
    echo "Files created:"
    echo "  .env (actual values - gitignored)"
    echo "  .env.template (template for sharing)"
    echo ""
    echo "Next: ./interrogate.sh --roadmap $name"
  else
    echo "⚠️  Credential gathering incomplete"
    echo ""
    echo "Resume with: ./interrogate.sh --credentials"
  fi
}

# Ensure GitHub repository exists (Step 3)
ensure_repo() {
  local repo_name="${1:-$(basename "$(pwd)" | tr '_' '-')}"

  echo "=== Step 3: Ensure GitHub Repository ==="
  echo ""

  if [ -f "./.claude/scripts/ensure-github-repo.sh" ]; then
    ./.claude/scripts/ensure-github-repo.sh "$repo_name"
  else
    echo "⚠️ ensure-github-repo.sh not found"
    echo "Skipping repo setup"
  fi
}

# Create database schema (Step 2)
create_schema() {
  local name="${1:-$(basename "$(pwd)" | tr '_' '-')}"

  echo "=== Step 2: Create Database Schema ==="
  echo ""

  if [ -f "./.claude/scripts/create-interview-schema.sh" ]; then
    ./.claude/scripts/create-interview-schema.sh
    echo ""
    echo "✅ Schema created"
  else
    echo "⚠️ Schema script not found: .claude/scripts/create-interview-schema.sh"
    echo "Skipping schema creation"
  fi
}

# Generate MVP roadmap (Step 7) - delegates to discovery.sh
generate_roadmap() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./interrogate.sh --roadmap <session-name>"
    exit 1
  fi

  echo "=== Step 7: Generate MVP Roadmap ==="
  echo ""

  # Delegate to discovery.sh
  if [ -f "$DISCOVERY_SH" ]; then
    "$DISCOVERY_SH" --roadmap "$name"
  else
    # Fallback to direct call
    local scope=".claude/scopes/$name/00_scope_document.md"
    if [ ! -f "$scope" ]; then
      echo "❌ Scope document not found: $scope"
      echo ""
      echo "First run: ./interrogate.sh --scope $name"
      exit 1
    fi

    claude --dangerously-skip-permissions --print "/pm:roadmap-generate $name"
  fi
}

# Generate K8s templates and code scaffolds (Step 8)
generate_template() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./interrogate.sh --generate-template <session-name>"
    exit 1
  fi

  local tech_arch=".claude/scopes/$name/04_technical_architecture.md"
  if [ ! -f "$tech_arch" ]; then
    echo "❌ Technical architecture not found: $tech_arch"
    echo ""
    echo "First run: ./interrogate.sh --scope $name"
    exit 1
  fi

  echo "=== Step 8: Generate Templates ==="
  echo ""

  claude --dangerously-skip-permissions --print "/pm:generate-template $name"

  echo ""
  echo "---"

  local k8s_dir=".claude/templates/$name/k8s"
  if [ -d "$k8s_dir" ]; then
    echo "✅ Templates generated: $k8s_dir"
    echo ""
    echo "Next: ./interrogate.sh --deploy-skeleton $name"
  else
    echo "❌ Template generation failed"
  fi
}

# Deploy skeleton application (Step 9)
deploy_skeleton() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./interrogate.sh --deploy-skeleton <session-name>"
    exit 1
  fi

  local k8s_dir=".claude/templates/$name/k8s"
  if [ ! -d "$k8s_dir" ]; then
    echo "❌ K8s templates not found: $k8s_dir"
    echo ""
    echo "First run: ./interrogate.sh --generate-template $name"
    exit 1
  fi

  echo "=== Step 9: Deploy Skeleton ==="
  echo ""

  claude --dangerously-skip-permissions --print "/pm:deploy-skeleton $name"

  echo ""
  echo "---"

  local running
  running=$(kubectl get pods -n "$name" --no-headers 2>/dev/null | grep -c "Running" || echo "0")
  if [ "$running" -gt 0 ]; then
    echo "✅ Skeleton deployed: $running pod(s) running"
    echo ""
    echo "Check status: kubectl get pods -n $name"
    echo ""
    echo "Next: ./interrogate.sh --decompose $name"
  else
    echo "⚠️ Deployment may still be starting"
    echo "Check with: kubectl get pods -n $name"
  fi
}

# Decompose into PRDs (Step 10) - delegates to discovery.sh
decompose_prds() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./interrogate.sh --decompose <session-name>"
    exit 1
  fi

  echo "=== Step 10: Decompose into PRDs ==="
  echo ""

  # Delegate to discovery.sh
  if [ -f "$DISCOVERY_SH" ]; then
    "$DISCOVERY_SH" --decompose "$name"
  else
    # Fallback to direct call
    local roadmap=".claude/scopes/$name/07_roadmap.md"
    if [ ! -f "$roadmap" ]; then
      echo "❌ Roadmap not found: $roadmap"
      echo ""
      echo "First run: ./interrogate.sh --roadmap $name"
      exit 1
    fi

    claude --dangerously-skip-permissions --print "/pm:scope-decompose $name --generate"
  fi
}

# Batch process PRDs (Step 11)
batch_process() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./interrogate.sh --batch <session-name>"
    exit 1
  fi

  local prd_dir=".claude/prds/$name"
  local prd_count
  prd_count=$(ls -1 "$prd_dir"/*.md 2>/dev/null | wc -l)

  if [ "$prd_count" -eq 0 ]; then
    # Check root prds directory
    prd_count=$(ls -1 .claude/prds/*.md 2>/dev/null | wc -l)
    if [ "$prd_count" -eq 0 ]; then
      echo "❌ No PRDs found"
      echo ""
      echo "First run: ./interrogate.sh --decompose $name"
      exit 1
    fi
  fi

  echo "=== Step 11: Batch Process PRDs ==="
  echo "PRDs to process: $prd_count"
  echo ""

  claude --dangerously-skip-permissions "/pm:batch-process"

  echo ""
  echo "---"

  local complete_count
  complete_count=$(grep -l "^status: complete" .claude/prds/*.md .claude/prds/"$name"/*.md 2>/dev/null | wc -l)
  echo "✅ Batch processing complete"
  echo "   Completed PRDs: $complete_count / $prd_count"
  echo ""
  echo "Next: ./interrogate.sh --deploy $name"
}

# Deploy to Kubernetes (Step 12)
deploy_app() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./interrogate.sh --deploy <session-name>"
    exit 1
  fi

  local complete_count
  complete_count=$(grep -l "^status: complete" .claude/prds/*.md .claude/prds/"$name"/*.md 2>/dev/null | wc -l)
  if [ "$complete_count" -eq 0 ]; then
    echo "❌ No completed PRDs found"
    echo ""
    echo "First run: ./interrogate.sh --batch $name"
    exit 1
  fi

  local project_name
  project_name=$(basename "$(pwd)" | tr '_' '-')

  echo "=== Step 12: Deploy to Kubernetes ==="
  echo "Namespace: $project_name"
  echo ""

  claude --dangerously-skip-permissions "/pm:deploy $name"

  echo ""
  echo "---"

  echo "✅ Deployment complete"
  echo ""
  echo "Check status: kubectl get pods -n $project_name"
  echo ""
  echo "Next: ./interrogate.sh --synthetic $name"
}

# Synthetic persona testing (Step 13)
synthetic_testing() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./interrogate.sh --synthetic <session-name>"
    exit 1
  fi

  local journeys=".claude/scopes/$name/02_user_journeys.md"
  if [ ! -f "$journeys" ]; then
    echo "❌ User journeys not found: $journeys"
    echo ""
    echo "First run: ./interrogate.sh --scope $name"
    exit 1
  fi

  echo "=== Step 13: Synthetic Persona Testing ==="
  echo ""

  echo "Step 1: Generating personas..."
  claude --dangerously-skip-permissions --print "/pm:generate-personas $name --count 10"

  local personas=".claude/testing/personas/$name-personas.json"
  if [ ! -f "$personas" ]; then
    echo "⚠️ Persona generation may have failed"
  else
    echo "✅ Personas generated"
  fi
  echo ""

  echo "Step 2: Generating E2E tests..."
  claude --dangerously-skip-permissions --print "/pm:generate-tests $name"
  echo ""

  echo "Step 3: Generating synthetic feedback..."
  claude --dangerously-skip-permissions --print "/pm:generate-feedback $name"

  local feedback=".claude/testing/feedback/$name-feedback.json"
  if [ ! -f "$feedback" ]; then
    echo "⚠️ Feedback generation may have failed"
  else
    echo "✅ Feedback generated"
  fi
  echo ""

  echo "Step 4: Analyzing feedback..."
  claude --dangerously-skip-permissions --print "/pm:analyze-feedback $name"

  local analysis=".claude/testing/feedback/$name-analysis.md"
  if [ -f "$analysis" ]; then
    echo "✅ Analysis complete: $analysis"
  fi

  echo ""
  echo "---"
  echo ""
  echo "Outputs:"
  echo "  Personas: .claude/testing/personas/$name-personas.json"
  echo "  Feedback: .claude/testing/feedback/$name-feedback.json"
  echo "  Analysis: .claude/testing/feedback/$name-analysis.md"
  echo ""
  echo "Next: ./interrogate.sh --remediation $name"
}

# Generate remediation PRDs (Step 14)
generate_remediation() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./interrogate.sh --remediation <session-name>"
    exit 1
  fi

  local feedback=".claude/testing/feedback/$name-feedback.json"
  if [ ! -f "$feedback" ]; then
    echo "❌ Feedback file not found: $feedback"
    echo ""
    echo "First run: ./interrogate.sh --synthetic $name"
    exit 1
  fi

  echo "=== Step 14: Generate Remediation PRDs ==="
  echo ""

  claude --dangerously-skip-permissions --print "/pm:generate-remediation $name --max 10"

  echo ""
  echo "---"

  local remediation_count
  remediation_count=$(ls -1 .claude/prds/*-fix-*.md .claude/prds/*-improve-*.md .claude/prds/*-add-*.md 2>/dev/null | wc -l)
  if [ "$remediation_count" -gt 0 ]; then
    echo "✅ Generated $remediation_count remediation PRDs"
    echo ""
    echo "Process them with: ./interrogate.sh --batch $name"
  else
    echo "No remediation PRDs needed (or generation failed)"
  fi
}

# Run feedback pipeline (Step 15)
run_feedback_pipeline() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./interrogate.sh --feedback <session-name>"
    exit 1
  fi

  local journeys=".claude/scopes/$name/02_user_journeys.md"
  if [ ! -f "$journeys" ]; then
    echo "❌ User journeys not found: $journeys"
    echo ""
    echo "First run: ./interrogate.sh --scope $name"
    exit 1
  fi

  echo "=== Feedback Pipeline: $name ==="
  echo ""
  echo "Pipeline: test-journey → generate-feedback → analyze → research → fix"
  echo ""

  if [ -f "./.claude/scripts/feedback-pipeline.sh" ]; then
    ./.claude/scripts/feedback-pipeline.sh "$name"
  else
    echo "❌ feedback-pipeline.sh not found"
    exit 1
  fi
}

# Setup infrastructure services (Step 1)
setup_services() {
  local project_name="${1:-$(basename "$(pwd)" | tr '_' '-')}"

  echo "=== Step 1: Setup Infrastructure Services ==="
  echo ""
  echo "Project: $project_name"
  echo "Namespace: $project_name"
  echo ""
  echo "Initializing services..."
  echo "  - PostgreSQL (database)"
  echo "  - MinIO (object storage)"
  echo "  - CloudBeaver (database UI)"
  echo ""
  echo "This may take a few minutes while containers are pulled and started."
  echo ""

  if [ -f "./.claude/scripts/setup-service.sh" ]; then
    ./.claude/scripts/setup-service.sh all "$project_name" --project="$project_name"
  else
    echo "⚠️ setup-service.sh not found"
    echo "Skipping service setup"
    return 0
  fi

  echo ""
  echo "---"
  echo ""

  # Pull credentials into .env
  echo "Pulling credentials into .env..."
  if [ -f "./.claude/scripts/setup-env-from-k8s.sh" ]; then
    NAMESPACE="$project_name" ./.claude/scripts/setup-env-from-k8s.sh
  fi

  echo ""
  echo "✅ Services ready"
  echo "   PostgreSQL: $project_name namespace"
  echo "   MinIO: $project_name namespace"
  echo "   CloudBeaver: $project_name namespace"
}

# Full pipeline using pipeline-lib.sh
build_full() {
  local name="$1"
  local start_step="${2:-1}"

  echo "=== Full Pipeline: $name ==="
  echo ""
  echo "Pipeline: services → schema → repo → discover → scope → credentials → roadmap → template → skeleton → decompose → batch → deploy → synthetic → remediation"
  echo ""

  # Source the pipeline library if available
  if [ -f "$SCRIPT_DIR/pipeline-lib.sh" ]; then
    source "$SCRIPT_DIR/pipeline-lib.sh"
    init_pipeline_state "$name"
    run_pipeline_from "$start_step"
  else
    # Manual pipeline execution
    [ "$start_step" -le 1 ] && setup_services "$name"
    [ "$start_step" -le 2 ] && create_schema "$name"
    [ "$start_step" -le 3 ] && ensure_repo "$name"
    [ "$start_step" -le 4 ] && run_discover "$name"
    [ "$start_step" -le 5 ] && create_scope "$name"
    [ "$start_step" -le 6 ] && gather_credentials "$name"
    [ "$start_step" -le 7 ] && generate_roadmap "$name"
    [ "$start_step" -le 8 ] && generate_template "$name"
    [ "$start_step" -le 9 ] && deploy_skeleton "$name"
    [ "$start_step" -le 10 ] && decompose_prds "$name"
    [ "$start_step" -le 11 ] && batch_process "$name"
    [ "$start_step" -le 12 ] && deploy_app "$name"
    [ "$start_step" -le 13 ] && synthetic_testing "$name"
    [ "$start_step" -le 14 ] && generate_remediation "$name"
  fi

  # Show final summary
  echo ""
  echo "=== Pipeline Summary ==="
  echo ""
  echo "  - Scope: .claude/scopes/$name/"
  [ -f ".claude/scopes/$name/07_roadmap.md" ] && echo "  - Roadmap: .claude/scopes/$name/07_roadmap.md"
  echo "  - PRDs: .claude/prds/$name/"
  [ -f ".claude/testing/personas/$name-personas.json" ] && echo "  - Personas: .claude/testing/personas/$name-personas.json"
  [ -f ".claude/testing/feedback/$name-analysis.md" ] && echo "  - Feedback Analysis: .claude/testing/feedback/$name-analysis.md"
  echo ""
  echo "Monitor progress:"
  echo "  /pm:status"
  echo "  /pm:epic-status <epic-name>"
}

# Resume pipeline from last completed step
resume_pipeline() {
  local name="$1"
  local pipeline_state=".claude/pipeline/$name/state.yaml"

  if [ ! -f "$pipeline_state" ]; then
    # Try to resume via discovery.sh
    if [ -f "$DISCOVERY_SH" ]; then
      "$DISCOVERY_SH" --resume "$name"
      return $?
    fi

    echo "❌ No pipeline state found for: $name"
    echo ""
    echo "Start fresh with: ./interrogate.sh --build $name"
    exit 1
  fi

  local last_step
  last_step=$(grep "^last_completed_step:" "$pipeline_state" 2>/dev/null | cut -d: -f2 | tr -d ' ')

  if [ -z "$last_step" ] || [ "$last_step" = "0" ]; then
    echo "No steps completed yet. Starting from step 1."
    build_full "$name" 1
  elif [ "$last_step" = "14" ]; then
    echo "Pipeline already complete for: $name"
    echo ""
    echo "To restart: ./interrogate.sh --resume-from 1 $name"
    exit 0
  else
    local next_step=$((last_step + 1))
    echo "Resuming from step $next_step (last completed: $last_step)"
    echo ""
    build_full "$name" "$next_step"
  fi
}

# Resume from specific step
resume_from_step() {
  local step="$1"
  local name="$2"

  if [ -z "$step" ] || [ -z "$name" ]; then
    echo "❌ Usage: ./interrogate.sh --resume-from <step> <session-name>"
    echo "   Example: ./interrogate.sh --resume-from 5 my-app"
    exit 1
  fi

  if [ "$step" -lt 1 ] || [ "$step" -gt 14 ]; then
    echo "❌ Invalid step number: $step (must be 1-14)"
    exit 1
  fi

  echo "Starting from step $step for session: $name"
  echo ""
  build_full "$name" "$step"
}

# Show pipeline status
show_pipeline_status() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Session name required"
    echo "Usage: ./interrogate.sh --pipeline-status <session-name>"
    exit 1
  fi

  # Source the pipeline library if available
  if [ -f "$SCRIPT_DIR/pipeline-lib.sh" ]; then
    source "$SCRIPT_DIR/pipeline-lib.sh"
    init_pipeline_state "$name"
    show_pipeline_status
  else
    # Basic status
    show_status "$name"
  fi
}

# Handle arguments
case "$1" in
  --help|-h)
    show_help
    exit 0
    ;;
  --list|-l)
    list_sessions
    exit 0
    ;;
  --status|-s)
    show_status "$2"
    exit 0
    ;;
  --discover|--interrogate-only|-i)
    if [ -z "$2" ]; then
      echo "❌ Error: Session name required"
      echo "Usage: ./interrogate.sh --discover <session-name>"
      exit 1
    fi
    run_discover "$2"
    exit 0
    ;;
  --scope|--extract|-e)
    if [ -z "$2" ]; then
      echo "❌ Error: Session name required"
      echo "Usage: ./interrogate.sh --scope <session-name>"
      exit 1
    fi
    create_scope "$2"
    exit 0
    ;;
  --sync)
    sync_to_database "$2"
    exit 0
    ;;
  --credentials|-c)
    gather_credentials "$2"
    exit 0
    ;;
  --repo|-r)
    ensure_repo "$2"
    exit 0
    ;;
  --services)
    setup_services "$2"
    exit 0
    ;;
  --schema)
    create_schema "$2"
    exit 0
    ;;
  --roadmap)
    generate_roadmap "$2"
    exit 0
    ;;
  --generate-template)
    generate_template "$2"
    exit 0
    ;;
  --deploy-skeleton)
    deploy_skeleton "$2"
    exit 0
    ;;
  --decompose|--prds)
    decompose_prds "$2"
    exit 0
    ;;
  --batch)
    batch_process "$2"
    exit 0
    ;;
  --deploy)
    deploy_app "$2"
    exit 0
    ;;
  --synthetic|--test)
    synthetic_testing "$2"
    exit 0
    ;;
  --remediation|--fix)
    generate_remediation "$2"
    exit 0
    ;;
  --feedback)
    run_feedback_pipeline "$2"
    exit 0
    ;;
  --build|-b)
    if [ -z "$2" ]; then
      echo "❌ Error: Session name required"
      echo "Usage: ./interrogate.sh --build <session-name>"
      exit 1
    fi
    build_full "$2"
    exit 0
    ;;
  --resume)
    if [ -z "$2" ]; then
      echo "❌ Error: Session name required"
      echo "Usage: ./interrogate.sh --resume <session-name>"
      exit 1
    fi
    resume_pipeline "$2"
    exit 0
    ;;
  --resume-from)
    resume_from_step "$2" "$3"
    exit 0
    ;;
  --pipeline-status)
    show_pipeline_status "$2"
    exit 0
    ;;
esac

# Default: Run full build pipeline
build_full "$SESSION_NAME"
