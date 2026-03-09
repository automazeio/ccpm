#!/bin/bash
# setup-base-services.sh - Deploy base infrastructure and create schema
#
# Usage:
#   ./setup-base-services.sh [project-name]
#
# Deploys:
#   - PostgreSQL (via Helm)
#   - MinIO (object storage)
#   - CloudBeaver (database UI, auto-deployed with PostgreSQL)
#   - Interview schema (10 tables)

set -e

PROJECT="${1:-$(basename "$(pwd)")}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Setting up base services for: $PROJECT ==="

# Step 1: Deploy services to K8s
echo ""
echo ">>> Deploying PostgreSQL, MinIO, and CloudBeaver..."
"$SCRIPT_DIR/setup-service.sh" all "$PROJECT" --project="$PROJECT"

# Step 2: Pull credentials into .env
echo ""
echo ">>> Syncing credentials to .env..."
NAMESPACE="$PROJECT" "$SCRIPT_DIR/setup-env-from-k8s.sh"

# Step 3: Create database schema
echo ""
echo ">>> Creating database schema..."
NAMESPACE="$PROJECT" "$SCRIPT_DIR/create-interview-schema.sh"

echo ""
echo "✅ Base services ready"
echo "   Namespace: $PROJECT"
echo "   PostgreSQL: Running"
echo "   MinIO: Running"
echo "   CloudBeaver: Running"
echo "   Schema: 10 tables created"
