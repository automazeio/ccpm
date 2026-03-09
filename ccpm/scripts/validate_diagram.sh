#!/bin/bash
# validate_diagram.sh - Validate generated diagrams against architecture index
#
# 1. Extracts elements from mermaid diagrams
# 2. Compares against architecture index to identify new/existing
# 3. Uses AI to verify diagram correctness
#
# Usage: ./validate_diagram.sh <diagram_file> [--fix]
# Output: Validation report with new elements highlighted

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
INDEX_FILE="$PROJECT_ROOT/.claude/cache/architecture/index.yaml"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

DIAGRAM_FILE="${1:-}"
SKIP_AI="${2:-}"

if [ -z "$DIAGRAM_FILE" ]; then
  echo "Usage: $0 <diagram_file> [--skip-ai]" >&2
  exit 1
fi

if [ ! -f "$DIAGRAM_FILE" ]; then
  echo "Error: Diagram file not found: $DIAGRAM_FILE" >&2
  exit 1
fi

# Extract mermaid content from markdown
extract_mermaid() {
  sed -n '/```mermaid/,/```/p' "$1" | sed '1d;$d'
}

# Extract node identifiers from mermaid diagram
# Focuses on meaningful identifiers, ignoring structural elements
extract_nodes() {
  local content="$1"

  # Extract node IDs (before [Label]) - skip subgraph definitions and single letters
  echo "$content" | grep -v '^\s*subgraph' | grep -oE '\b[A-Za-z_][A-Za-z0-9_]{2,}\[' | sed 's/\[$//' | sort -u || true

  # Extract participant names from sequence diagrams
  echo "$content" | grep -oE 'participant [A-Za-z_][A-Za-z0-9_]+' | sed 's/participant //' | sort -u || true
}

# Extract labels/text from nodes - focus on component-like names
extract_labels() {
  local content="$1"

  # Extract text inside brackets that look like component names (PascalCase, snake_case, or paths)
  # Filter out generic words like "Frontend", "Backend", "Data Layer", etc.
  echo "$content" | grep -o '\[[^]]*\]' | sed 's/^\[//;s/\]$//' | tr -d '"()' | \
    grep -E '^[A-Z][a-z]+[A-Z]|^[a-z]+_[a-z]+|^/api/' | sort -u || true
}

# Load known elements from architecture index
load_index_elements() {
  if [ ! -f "$INDEX_FILE" ]; then
    echo ""
    return
  fi

  # Extract component IDs
  grep -E "^    - id:" "$INDEX_FILE" 2>/dev/null | sed 's/.*id: //' || true

  # Extract endpoint paths (simplified)
  grep -E "^    - path:" "$INDEX_FILE" 2>/dev/null | sed 's/.*path: //' | sed 's|/api/v1/||' | cut -d'/' -f1 | sort -u || true

  # Extract table names
  grep -E "^    - name:" "$INDEX_FILE" 2>/dev/null | sed 's/.*name: //' || true

  # Extract model names
  grep -E "^      model:" "$INDEX_FILE" 2>/dev/null | sed 's/.*model: //' || true
}

# Compare diagram elements against index
compare_elements() {
  local diagram_elements="$1"
  local index_elements="$2"

  local new_elements=""
  local existing_elements=""

  while IFS= read -r element; do
    [ -z "$element" ] && continue

    local found=false

    # Check if element exists in index (case-insensitive, partial match)
    if echo "$index_elements" | grep -qi "$element"; then
      found=true
    fi

    # For API paths, also check the base path (e.g., /api/v1/inventory -> inventory)
    if [ "$found" = false ] && [[ "$element" == /api/* ]]; then
      local base_path
      base_path=$(echo "$element" | sed 's|/api/v1/||' | cut -d'/' -f1)
      if echo "$index_elements" | grep -qi "^$base_path$"; then
        found=true
      fi
    fi

    # Check common variations (PascalCase, snake_case)
    if [ "$found" = false ]; then
      local lower_element snake_element
      lower_element=$(echo "$element" | tr '[:upper:]' '[:lower:]')
      snake_element=$(echo "$element" | sed 's/\([A-Z]\)/_\L\1/g' | sed 's/^_//')

      if echo "$index_elements" | grep -qi "$lower_element\|$snake_element"; then
        found=true
      fi
    fi

    if [ "$found" = true ]; then
      existing_elements+="$element"$'\n'
    else
      new_elements+="$element"$'\n'
    fi
  done <<< "$diagram_elements"

  # Output with markers on their own lines for easier parsing
  echo "EXISTING:"
  echo -n "$existing_elements"
  echo "NEW:"
  echo -n "$new_elements"
}

# AI verification of diagram correctness
verify_with_ai() {
  local diagram_content="$1"
  local requirements_file="$2"

  if ! command -v claude &>/dev/null; then
    echo "Claude CLI not available - skipping AI verification"
    return 0
  fi

  local requirements=""
  if [ -f "$requirements_file" ]; then
    requirements=$(cat "$requirements_file")
  fi

  local index_summary=""
  if [ -f "$INDEX_FILE" ]; then
    index_summary=$(head -100 "$INDEX_FILE")
  fi

  local prompt="<role>
You are a diagram validator. Analyze mermaid diagrams for correctness against architecture constraints.
</role>

<diagram>
$diagram_content
</diagram>

<architecture_index_summary>
$index_summary
</architecture_index_summary>

<requirements>
$requirements
</requirements>

<output_format>
Respond in this exact format:

SCORE: [1-10]
ISSUES:
- [issue 1 if any]
SUGGESTIONS:
- [suggestion 1 if any]
NEW_ELEMENTS:
- [element]: [why it's needed or whether an existing element should be used instead]
</output_format>

Check:
1. Node names match the architecture index
2. Flow is logically consistent
3. No orphan nodes or missing connections
4. Diagram matches requirements"

  claude --dangerously-skip-permissions --print "$prompt" 2>/dev/null || echo "AI verification unavailable"
}

# Generate validation report
generate_report() {
  local diagram_file="$1"
  local mermaid_content
  mermaid_content=$(extract_mermaid "$diagram_file")

  local nodes labels index_elements
  nodes=$(extract_nodes "$mermaid_content")
  labels=$(extract_labels "$mermaid_content")
  index_elements=$(load_index_elements)

  # Combine nodes and labels for comparison
  local all_elements
  all_elements=$(echo -e "$nodes\n$labels" | sort -u | grep -v '^$')

  local comparison
  comparison=$(compare_elements "$all_elements" "$index_elements")

  local existing new
  # Extract elements between EXISTING: and NEW: markers
  # Note: Need || true because grep returns 1 when there are no matches (empty input with pipefail)
  existing=$(echo "$comparison" | sed -n '/^EXISTING:/,/^NEW:/p' | grep -v '^EXISTING:\|^NEW:' | grep -v '^$' | wc -l || true)
  new=$(echo "$comparison" | sed -n '/^NEW:/,$p' | grep -v '^NEW:' | grep -v '^$' | wc -l || true)

  echo ""
  echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  DIAGRAM VALIDATION REPORT${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "  File: ${BLUE}$diagram_file${NC}"
  echo ""
  echo -e "  ${GREEN}✓ Existing elements:${NC} $existing"
  echo -e "  ${YELLOW}★ New elements:${NC} $new"
  echo ""

  if [ "$new" -gt 0 ]; then
    echo -e "  ${YELLOW}New elements detected:${NC}"
    echo "$comparison" | sed -n '/^NEW:/,$p' | grep -v '^NEW:' | grep -v '^$' | while read -r elem; do
      echo -e "    ${YELLOW}→${NC} $elem"
    done
    echo ""
  fi

  # Find requirements file in same directory
  local session_dir
  session_dir=$(dirname "$diagram_file")
  local requirements_file="$session_dir/refined-requirements.md"

  if [ "$SKIP_AI" != "--skip-ai" ]; then
    echo -e "  ${CYAN}Running AI verification...${NC}"
    echo ""

    local ai_result
    ai_result=$(timeout 60 bash -c "$(declare -f verify_with_ai); verify_with_ai '$mermaid_content' '$requirements_file'" 2>/dev/null || echo "AI verification timed out or unavailable")

    echo "$ai_result" | while IFS= read -r line; do
      if [[ "$line" =~ ^SCORE: ]]; then
        local score=$(echo "$line" | grep -oE '[0-9]+') || true
        if [ -n "$score" ] && [ "$score" -ge 8 ]; then
          echo -e "  ${GREEN}$line${NC}"
        elif [ -n "$score" ] && [ "$score" -ge 5 ]; then
          echo -e "  ${YELLOW}$line${NC}"
        else
          echo -e "  ${RED}$line${NC}"
        fi
      elif [[ "$line" =~ ^ISSUES:|^SUGGESTIONS:|^NEW_ELEMENTS: ]]; then
        echo -e "  ${CYAN}$line${NC}"
      elif [[ "$line" =~ ^- ]]; then
        echo -e "    $line"
      else
        echo "  $line"
      fi
    done
  else
    echo -e "  ${YELLOW}AI verification skipped${NC}"
  fi

  echo ""
  echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"

  # Return exit code based on new elements
  if [ "$new" -gt 0 ]; then
    return 1
  fi
  return 0
}

# Main
main() {
  # Ensure index exists
  local index_builder="$SCRIPT_DIR/build_architecture_index.sh"
  if [ -x "$index_builder" ] && [ ! -f "$INDEX_FILE" ]; then
    "$index_builder" "$PROJECT_ROOT" >/dev/null 2>&1
  fi

  generate_report "$DIAGRAM_FILE"
}

main "$@"
