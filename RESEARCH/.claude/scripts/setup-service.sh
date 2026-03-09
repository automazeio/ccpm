#!/bin/bash
#
# setup-service.sh - Unified service setup orchestrator
#
# Deploys, exposes, and configures infrastructure services (PostgreSQL, MinIO)
# with a pluggable exposure strategy (NodePort vs port-forward).
#
# Usage: ./setup-service.sh <service> <namespace> [options]
#
# Services:
#   postgres  - PostgreSQL database via Helm
#   minio     - MinIO object storage
#
# Options:
#   --expose=MODE    Exposure mode: nodeport (default) or portforward
#   --project=NAME   Project name (defaults to namespace)
#
# Output:
#   Prints key=value pairs to stdout for .env file
#
# Example:
#   ./setup-service.sh postgres myproject --expose=nodeport
#   ./setup-service.sh minio myproject --expose=portforward --project=myapp
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "$SCRIPT_DIR/lib/common.sh"

# Default values
EXPOSE_MODE="nodeport"
PROJECT=""

# Parse arguments
SERVICE=""
NAMESPACE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --expose=*)
      EXPOSE_MODE="${1#*=}"
      shift
      ;;
    --project=*)
      PROJECT="${1#*=}"
      shift
      ;;
    -*)
      log_error "Unknown option: $1"
      exit 1
      ;;
    *)
      if [[ -z "$SERVICE" ]]; then
        SERVICE="$1"
      elif [[ -z "$NAMESPACE" ]]; then
        NAMESPACE="$1"
      else
        log_error "Too many arguments"
        exit 1
      fi
      shift
      ;;
  esac
done

# Validate arguments
if [[ -z "$SERVICE" ]] || [[ -z "$NAMESPACE" ]]; then
  echo "Usage: $0 <service> <namespace> [--expose=nodeport|portforward] [--project=name]"
  echo ""
  echo "Services: postgres, minio"
  echo ""
  echo "Options:"
  echo "  --expose=MODE    Exposure mode (default: nodeport)"
  echo "  --project=NAME   Project name (default: namespace)"
  exit 1
fi

# Default project to namespace if not specified
PROJECT="${PROJECT:-$NAMESPACE}"

# Validate expose mode
if [[ "$EXPOSE_MODE" != "nodeport" ]] && [[ "$EXPOSE_MODE" != "portforward" ]]; then
  log_error "Invalid expose mode: $EXPOSE_MODE (must be nodeport or portforward)"
  exit 1
fi

# Ensure namespace exists
ensure_namespace "$NAMESPACE"

# Source service-specific functions
case "$SERVICE" in
  postgres)
    source "$SCRIPT_DIR/lib/services/postgres.sh"
    setup_postgres "$NAMESPACE" "$PROJECT" "$EXPOSE_MODE"
    ;;
  minio)
    source "$SCRIPT_DIR/lib/services/minio.sh"
    setup_minio "$NAMESPACE" "$PROJECT" "$EXPOSE_MODE"
    ;;
  cloudbeaver)
    # CloudBeaver requires PostgreSQL to be already deployed
    source "$SCRIPT_DIR/lib/services/postgres.sh"
    source "$SCRIPT_DIR/lib/services/cloudbeaver.sh"

    # Check if PostgreSQL exists
    RELEASE="${PROJECT}-postgresql"
    if ! kubectl get statefulset "$RELEASE" -n "$NAMESPACE" &>/dev/null; then
      log_error "PostgreSQL must be deployed first. Run: $0 postgres $NAMESPACE"
      exit 1
    fi

    # Get PostgreSQL credentials from existing secret
    PG_PASSWORD=$(kubectl get secret "$RELEASE" -n "$NAMESPACE" \
      -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)

    if [[ -z "$PG_PASSWORD" ]]; then
      PG_PASSWORD=$(kubectl get secret "$RELEASE" -n "$NAMESPACE" \
        -o jsonpath="{.data.postgres-password}" 2>/dev/null | base64 -d)
    fi

    if [[ -z "$PG_PASSWORD" ]]; then
      log_error "Could not retrieve PostgreSQL credentials"
      exit 1
    fi

    # Get internal K8s service name
    POSTGRES_INTERNAL_SERVICE="${RELEASE}.${NAMESPACE}.svc.cluster.local"

    # Setup CloudBeaver
    setup_cloudbeaver "$NAMESPACE" "$PROJECT" "$EXPOSE_MODE" \
      "$POSTGRES_INTERNAL_SERVICE" "$PROJECT" "$PROJECT" "$PG_PASSWORD"
    ;;
  all)
    # Setup both services
    source "$SCRIPT_DIR/lib/services/postgres.sh"
    source "$SCRIPT_DIR/lib/services/minio.sh"

    log_info "Setting up all services for namespace: $NAMESPACE"

    # Setup PostgreSQL (will auto-deploy CloudBeaver unless DEPLOY_CLOUDBEAVER=false)
    setup_postgres "$NAMESPACE" "$PROJECT" "$EXPOSE_MODE"

    # Setup MinIO
    setup_minio "$NAMESPACE" "$PROJECT" "$EXPOSE_MODE"

    log_info "All services ready"
    ;;
  *)
    log_error "Unknown service: $SERVICE"
    echo "Available services: postgres (includes cloudbeaver), minio, cloudbeaver, all"
    exit 1
    ;;
esac
