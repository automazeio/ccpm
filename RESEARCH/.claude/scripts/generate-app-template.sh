#!/bin/bash
# generate-app-template.sh - Generate K8s manifests and code scaffolds from scope
#
# Usage:
#   ./generate-app-template.sh <session-name>
#
# Invokes /pm:generate-template which:
#   1. Parses tech stack from 04_technical_architecture.md
#   2. Uses deep research to determine K8s deployment patterns
#   3. Generates K8s manifests and code scaffolds
#
# Outputs to: .claude/templates/$SESSION/

set -e

SESSION="${1:-}"

if [ -z "$SESSION" ]; then
  echo "Usage: $0 <session-name>"
  echo ""
  echo "Example: $0 my-project"
  exit 1
fi

# Verify prerequisites
ARCH_FILE=".claude/scopes/$SESSION/04_technical_architecture.md"

if [ ! -f "$ARCH_FILE" ]; then
  echo "Error: Technical architecture not found: $ARCH_FILE"
  echo "Run scope extraction first."
  exit 1
fi

echo "Generating app template for session: $SESSION"
echo "Reading technical architecture from: $ARCH_FILE"
echo ""

# Invoke Claude with the generate-template command
claude --dangerously-skip-permissions --print "/pm:generate-template $SESSION"

# Verify outputs
TEMPLATE_DIR=".claude/templates/$SESSION"

if [ -d "$TEMPLATE_DIR/k8s" ] && [ -d "$TEMPLATE_DIR/scaffold" ]; then
  echo ""
  echo "Template generation complete!"
  echo ""
  echo "Generated files:"
  find "$TEMPLATE_DIR" -type f | sort | sed 's/^/  /'
else
  echo ""
  echo "Warning: Template directory structure incomplete"
  echo "Expected: $TEMPLATE_DIR/k8s/ and $TEMPLATE_DIR/scaffold/"
  exit 1
fi
