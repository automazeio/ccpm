#!/bin/bash
# extract_domain_context.sh - Extract domain topic, entities, and relationships from requirements
# This structured context improves diagram generation accuracy
#
# Usage: ./extract_domain_context.sh "<requirements_text>" [output_file]
# Output: YAML structure with domain context

set -euo pipefail

REQUIREMENTS="${1:-}"
OUTPUT_FILE="${2:-/dev/stdout}"

if [ -z "$REQUIREMENTS" ]; then
  echo "Usage: $0 '<requirements_text>' [output_file]" >&2
  exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log() {
  echo -e "  ${GREEN}▸${NC} $1" >&2
}

extract_context() {
  local requirements="$1"

  local prompt
  prompt=$(cat << 'EOF'
<role>
You are a domain analyst. Extract structured context from feature requirements for diagram generation.
</role>

<requirements>
REQUIREMENTS_PLACEHOLDER
</requirements>

<output_format>
Return this YAML structure only (no explanations, no code fences):

domain:
  topic: "<2-4 word domain description, e.g., 'B2B Inventory Management'>"
  industry: "<industry category, e.g., 'Supply Chain', 'E-commerce', 'Healthcare'>"

entities:
  - name: "<Entity1 - use singular noun>"
    type: "<actor|system|data|external>"
    description: "<one sentence>"
  - name: "<Entity2>"
    type: "<actor|system|data|external>"
    description: "<one sentence>"
  # List 5-8 key entities

relationships:
  - from: "<Entity1>"
    to: "<Entity2>"
    action: "<verb phrase, e.g., 'places order with', 'sends data to'>"
  - from: "<Entity2>"
    to: "<Entity3>"
    action: "<verb phrase>"
  # List 4-6 key relationships

decision_points:
  - question: "<Yes/No question, e.g., 'Is inventory available?'>"
    yes_path: "<what happens on yes>"
    no_path: "<what happens on no>"
  - question: "<another decision>"
    yes_path: "<outcome>"
    no_path: "<outcome>"
  # List 2-3 key decisions maximum

user_journeys:
  - name: "<journey name, e.g., 'Place Order'>"
    steps:
      - "<step 1>"
      - "<step 2>"
      - "<step 3>"
    # 4-6 steps per journey
  # List 1-2 primary journeys

complexity_assessment:
  estimated_nodes: <number between 8-25>
  recommended_levels: <1, 2, or 3>
  primary_diagram_type: "<flowchart|sequence|architecture>"
  split_recommendation: "<if >15 nodes, describe how to split, otherwise 'none'>"
</output_format>
EOF
)

  prompt="${prompt//REQUIREMENTS_PLACEHOLDER/$requirements}"

  if command -v claude &>/dev/null; then
    claude --dangerously-skip-permissions --print "$prompt" 2>&1
  else
    echo "Error: Claude CLI not found" >&2
    exit 1
  fi
}

# Validate YAML structure (basic check)
validate_yaml() {
  local yaml="$1"

  # Check for required fields
  if ! echo "$yaml" | grep -q "domain:"; then
    return 1
  fi
  if ! echo "$yaml" | grep -q "entities:"; then
    return 1
  fi
  if ! echo "$yaml" | grep -q "relationships:"; then
    return 1
  fi

  return 0
}

# Main execution
main() {
  log "Extracting domain context..."

  local result
  result=$(extract_context "$REQUIREMENTS")

  # Basic validation
  if validate_yaml "$result"; then
    log "Domain context extracted successfully"
  else
    log "Warning: Domain context may be incomplete" >&2
  fi

  # Output
  if [ "$OUTPUT_FILE" = "/dev/stdout" ]; then
    echo "$result"
  else
    echo "$result" > "$OUTPUT_FILE"
    log "Saved to $OUTPUT_FILE"
  fi
}

main
