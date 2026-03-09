#!/bin/bash
# deploy-skeleton.sh - Deploy skeleton app to Kubernetes
#
# Usage:
#   ./deploy-skeleton.sh <session-name>
#
# Invokes /pm:deploy-skeleton which:
#   1. Reads templates from .claude/templates/$SESSION/
#   2. Deploys K8s manifests to cluster
#   3. Verifies pods are running
#
# Prerequisites:
#   - Templates generated via generate-app-template.sh
#   - kubectl configured with cluster access

set -e

SESSION="${1:-}"

if [ -z "$SESSION" ]; then
  echo "Usage: $0 <session-name>"
  echo ""
  echo "Example: $0 my-project"
  exit 1
fi

# Verify prerequisites
TEMPLATE_DIR=".claude/templates/$SESSION"

if [ ! -d "$TEMPLATE_DIR/k8s" ]; then
  echo "Error: K8s templates not found: $TEMPLATE_DIR/k8s/"
  echo "Run generate-app-template.sh first."
  exit 1
fi

echo "Deploying skeleton for session: $SESSION"
echo "Using templates from: $TEMPLATE_DIR/k8s/"
echo ""

# Invoke Claude with the deploy-skeleton command
claude --dangerously-skip-permissions --print "/pm:deploy-skeleton $SESSION"

# Verify deployment
echo ""
echo "Checking pod status..."

if kubectl get pods -n "$SESSION" --no-headers 2>/dev/null | grep -q "Running"; then
  echo ""
  echo "Skeleton deployment successful!"
  echo ""
  kubectl get pods -n "$SESSION"
else
  echo ""
  echo "Warning: No running pods found in namespace: $SESSION"
  echo ""
  kubectl get pods -n "$SESSION" 2>/dev/null || echo "Namespace may not exist yet"
  exit 1
fi
