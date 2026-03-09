#!/bin/bash
# sync-k8s-to-env.sh - Pull Kubernetes secret to .env file
#
# Usage:
#   ./sync-k8s-to-env.sh <app-name> [namespace] [env-file]
#
# Extracts secrets from K8s and writes to local .env file

set -e

APP_NAME="$1"
NAMESPACE="${2:-default}"
ENV_FILE="${3:-.env}"

# Show help
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
  cat << 'EOF'
Pull Kubernetes Secret to .env

Usage:
  ./sync-k8s-to-env.sh <app-name> [namespace] [env-file]

Arguments:
  app-name    Name of the secret (without -secrets suffix)
  namespace   Kubernetes namespace (default: default)
  env-file    Output path for .env file (default: .env)

Behavior:
  - Backs up existing .env to .env.backup
  - Extracts and decodes all secret values
  - Writes to specified .env file

Examples:
  ./sync-k8s-to-env.sh myapp
  ./sync-k8s-to-env.sh myapp production
  ./sync-k8s-to-env.sh myapp staging .env.staging

Note: This reads secrets from the LIVE cluster.
EOF
  exit 0
fi

# Validate arguments
if [[ -z "$APP_NAME" ]]; then
  echo "❌ Error: App name required"
  echo ""
  echo "Usage: ./sync-k8s-to-env.sh <app-name> [namespace] [env-file]"
  exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
  echo "❌ Error: kubectl not found"
  echo ""
  echo "Install kubectl: https://kubernetes.io/docs/tasks/tools/"
  exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo "❌ Error: jq not found"
  echo ""
  echo "Install jq: https://jqlang.github.io/jq/download/"
  exit 1
fi

SECRET_NAME="${APP_NAME}-secrets"

echo "=== Pulling from Kubernetes ==="
echo ""
echo "Secret: $SECRET_NAME"
echo "Namespace: $NAMESPACE"
echo "Output: $ENV_FILE"
echo ""

# Check if secret exists
if ! kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &> /dev/null; then
  echo "❌ Error: Secret not found: $SECRET_NAME"
  echo "   Namespace: $NAMESPACE"
  echo ""
  echo "Available secrets:"
  kubectl get secrets -n "$NAMESPACE" --no-headers | awk '{print "  - " $1}'
  exit 1
fi

# Backup existing .env
if [[ -f "$ENV_FILE" ]]; then
  BACKUP_FILE="${ENV_FILE}.backup"
  cp "$ENV_FILE" "$BACKUP_FILE"
  echo "✓ Backed up existing $ENV_FILE to $BACKUP_FILE"
  echo ""
fi

# Extract secret data and decode
# jq extracts each key-value pair, base64 decodes values
echo "Extracting secrets..."

kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o json | \
  jq -r '.data | to_entries[] | "\(.key)=\(.value | @base64d)"' > "$ENV_FILE"

# Count extracted credentials
count=$(wc -l < "$ENV_FILE" | tr -d ' ')

echo ""
echo "✅ Pulled K8s secret to $ENV_FILE"
echo "   Credentials: $count"
echo "   Namespace: $NAMESPACE"
echo "   Secret: $SECRET_NAME"
echo ""

if [[ -f "${ENV_FILE}.backup" ]]; then
  echo "Previous .env backed up to: ${ENV_FILE}.backup"
fi
