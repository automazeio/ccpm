#!/bin/bash
# sync-env-to-k8s.sh - Sync .env file to Kubernetes secret
#
# Usage:
#   ./sync-env-to-k8s.sh <app-name> [namespace] [env-file]
#
# Creates or updates a Kubernetes secret from local .env file

set -e

APP_NAME="$1"
NAMESPACE="${2:-default}"
ENV_FILE="${3:-.env}"

# Show help
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
  cat << 'EOF'
Sync .env to Kubernetes Secret

Usage:
  ./sync-env-to-k8s.sh <app-name> [namespace] [env-file]

Arguments:
  app-name    Name for the secret (will be suffixed with -secrets)
  namespace   Kubernetes namespace (default: default)
  env-file    Path to .env file (default: .env)

Behavior:
  - If secret exists, it will be deleted and recreated
  - Requires kubectl with cluster access

Examples:
  ./sync-env-to-k8s.sh myapp
  ./sync-env-to-k8s.sh myapp production
  ./sync-env-to-k8s.sh myapp staging .env.staging

Note: This creates/updates a secret in the LIVE cluster.
EOF
  exit 0
fi

# Validate arguments
if [[ -z "$APP_NAME" ]]; then
  echo "❌ Error: App name required"
  echo ""
  echo "Usage: ./sync-env-to-k8s.sh <app-name> [namespace] [env-file]"
  exit 1
fi

# Check if .env file exists
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Error: .env file not found: $ENV_FILE"
  echo ""
  echo "Either:"
  echo "  1. Create .env file manually"
  echo "  2. Run: ./interrogate.sh --credentials <session>"
  exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
  echo "❌ Error: kubectl not found"
  echo ""
  echo "Install kubectl: https://kubernetes.io/docs/tasks/tools/"
  exit 1
fi

SECRET_NAME="${APP_NAME}-secrets"

echo "=== Syncing to Kubernetes ==="
echo ""
echo "Secret: $SECRET_NAME"
echo "Namespace: $NAMESPACE"
echo "Source: $ENV_FILE"
echo ""

# Check if secret already exists
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &> /dev/null; then
  echo "Secret exists. Deleting old version..."
  kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE"
  echo ""
fi

# Create new secret
echo "Creating secret..."
kubectl create secret generic "$SECRET_NAME" \
  --from-env-file="$ENV_FILE" \
  --namespace="$NAMESPACE"

echo ""
echo "✅ Synced to K8s: $SECRET_NAME"
echo "   Namespace: $NAMESPACE"
echo ""
echo "To verify:"
echo "  kubectl get secret $SECRET_NAME -n $NAMESPACE -o yaml"
echo ""
echo "To use in pod:"
echo "  envFrom:"
echo "  - secretRef:"
echo "      name: $SECRET_NAME"
