#!/bin/bash
# env-to-k8s-secret.sh - Generate Kubernetes secret manifest from .env file
#
# Usage:
#   ./env-to-k8s-secret.sh <app-name> [namespace] [env-file]
#
# Outputs:
#   k8s-secret.yaml - Kubernetes Secret manifest (gitignored)

set -e

APP_NAME="$1"
NAMESPACE="${2:-default}"
ENV_FILE="${3:-.env}"

# Show help
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
  cat << 'EOF'
Generate Kubernetes Secret Manifest from .env

Usage:
  ./env-to-k8s-secret.sh <app-name> [namespace] [env-file]

Arguments:
  app-name    Name for the secret (will be suffixed with -secrets)
  namespace   Kubernetes namespace (default: default)
  env-file    Path to .env file (default: .env)

Output:
  k8s-secret.yaml - Kubernetes Secret manifest (gitignored)

Examples:
  ./env-to-k8s-secret.sh myapp
  ./env-to-k8s-secret.sh myapp production
  ./env-to-k8s-secret.sh myapp staging .env.staging

To apply:
  kubectl apply -f k8s-secret.yaml
EOF
  exit 0
fi

# Validate arguments
if [[ -z "$APP_NAME" ]]; then
  echo "❌ Error: App name required"
  echo ""
  echo "Usage: ./env-to-k8s-secret.sh <app-name> [namespace] [env-file]"
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

echo "=== Generating K8s Secret ==="
echo ""
echo "App: $APP_NAME"
echo "Namespace: $NAMESPACE"
echo "Source: $ENV_FILE"
echo ""

# Generate secret manifest using kubectl
# --dry-run=client outputs YAML without applying
kubectl create secret generic "${APP_NAME}-secrets" \
  --from-env-file="$ENV_FILE" \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml > k8s-secret.yaml

echo "✅ Generated: k8s-secret.yaml"
echo ""
echo "Secret name: ${APP_NAME}-secrets"
echo "Namespace: $NAMESPACE"
echo ""
echo "To apply:"
echo "  kubectl apply -f k8s-secret.yaml"
echo ""
echo "To use in Deployment:"
echo "  spec:"
echo "    containers:"
echo "    - name: app"
echo "      envFrom:"
echo "      - secretRef:"
echo "          name: ${APP_NAME}-secrets"
