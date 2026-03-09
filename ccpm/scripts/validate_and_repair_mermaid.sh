#!/bin/bash
# validate_and_repair_mermaid.sh - Validate mermaid diagram and repair if needed
# Uses mermaid-validate CLI and LLM for iterative repair
#
# Usage: ./validate_and_repair_mermaid.sh <input_file> [max_retries]
# Output: Validated/repaired mermaid code to stdout, status to stderr

set -euo pipefail

INPUT_FILE="${1:-}"
MAX_RETRIES="${2:-3}"

if [ -z "$INPUT_FILE" ] || [ ! -f "$INPUT_FILE" ]; then
  echo "Usage: $0 <input_file> [max_retries]" >&2
  echo "  input_file: Markdown file containing mermaid code block" >&2
  exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
  echo -e "  ${GREEN}▸${NC} $1" >&2
}

log_warn() {
  echo -e "  ${YELLOW}⚠${NC} $1" >&2
}

log_error() {
  echo -e "  ${RED}✗${NC} $1" >&2
}

log_success() {
  echo -e "  ${GREEN}✓${NC} $1" >&2
}

# Extract mermaid code block from markdown
extract_mermaid() {
  local file="$1"
  # Extract content between ```mermaid and ```
  sed -n '/```mermaid/,/```/p' "$file" | sed '1d;$d'
}

# Validate mermaid using basic syntax checks (fast, no npm required)
validate_mermaid() {
  local diagram="$1"
  local errors=""

  # Check for common syntax issues
  if echo "$diagram" | grep -qE '^\s*end\s*(\[|-->)'; then
    errors+="Error: 'end' used as node ID (reserved word). "
  fi

  if echo "$diagram" | grep -qE '^\s*[ox][A-Za-z]*\s*\['; then
    errors+="Error: Node ID starts with 'o' or 'x' (conflicts with edge syntax). "
  fi

  if echo "$diagram" | grep -qE '\s->\s' | grep -v '-->'; then
    errors+="Error: Use '-->' for arrows, not '->'. "
  fi

  # Count brackets
  local open_brackets
  local close_brackets
  open_brackets=$(echo "$diagram" | grep -o '\[' | wc -l)
  close_brackets=$(echo "$diagram" | grep -o '\]' | wc -l)
  if [ "$open_brackets" != "$close_brackets" ]; then
    errors+="Error: Unbalanced brackets ([ = $open_brackets, ] = $close_brackets). "
  fi

  # Check subgraph/end balance
  local subgraph_count
  local end_count
  subgraph_count=$(echo "$diagram" | grep -c '^\s*subgraph' || true)
  end_count=$(echo "$diagram" | grep -c '^\s*end\s*$' || true)
  if [ "$subgraph_count" != "$end_count" ]; then
    errors+="Error: Unbalanced subgraph/end (subgraph = $subgraph_count, end = $end_count). "
  fi

  if [ -n "$errors" ]; then
    echo "$errors"
    return 1
  fi

  echo "valid"
  return 0
}

# Repair mermaid using LLM
repair_mermaid() {
  local diagram="$1"
  local error="$2"

  local repair_prompt
  repair_prompt=$(cat << EOF
This Mermaid diagram has syntax errors. Fix them while preserving the diagram's intent.

CURRENT DIAGRAM:
\`\`\`mermaid
$diagram
\`\`\`

ERROR MESSAGE:
$error

SYNTAX RULES:
1. Use "finish", "done", or "complete" as node IDs ("end" is a reserved word)
2. Start node IDs with letters other than "o" or "x" (those conflict with edge markers)
3. Use "-->" for arrows (not "->")
4. Balance all brackets [] {} ()
5. Match each "subgraph" with a closing "end"
6. Wrap labels with special characters in quotes: A["Label (with parens)"]
7. Use short alphanumeric IDs: A, B, C or auth, db, api

RESPONSE FORMAT:
Return ONLY the corrected mermaid code block. No explanations.

\`\`\`mermaid
[corrected diagram here]
\`\`\`
EOF
)

  if command -v claude &>/dev/null; then
    claude --dangerously-skip-permissions --print "$repair_prompt" 2>&1
  else
    echo "Error: Claude CLI not found" >&2
    return 1
  fi
}

# Extract mermaid from repair response
extract_repaired_mermaid() {
  local response="$1"
  echo "$response" | sed -n '/```mermaid/,/```/p' | sed '1d;$d'
}

# Main validation and repair loop
main() {
  log "Validating mermaid diagram from $INPUT_FILE"

  # Extract initial mermaid code
  local mermaid_code
  mermaid_code=$(extract_mermaid "$INPUT_FILE")

  if [ -z "$mermaid_code" ]; then
    log_error "No mermaid code block found in $INPUT_FILE"
    exit 1
  fi

  local retry=0
  local validation_result

  while [ $retry -lt "$MAX_RETRIES" ]; do
    log "Validation attempt $((retry + 1))/$MAX_RETRIES"

    validation_result=$(validate_mermaid "$mermaid_code" || true)

    if [ "$validation_result" = "valid" ]; then
      log_success "Diagram is valid"
      echo "$mermaid_code"
      exit 0
    fi

    log_warn "Validation failed: $validation_result"

    if [ $((retry + 1)) -lt "$MAX_RETRIES" ]; then
      log "Attempting repair..."

      local repaired_response
      repaired_response=$(repair_mermaid "$mermaid_code" "$validation_result")

      local repaired_code
      repaired_code=$(extract_repaired_mermaid "$repaired_response")

      if [ -n "$repaired_code" ]; then
        mermaid_code="$repaired_code"
        log "Repair generated, re-validating..."
      else
        log_warn "Repair did not produce valid mermaid code"
      fi
    fi

    retry=$((retry + 1))
  done

  log_error "Could not validate/repair diagram after $MAX_RETRIES attempts"
  log_warn "Returning last version (may have errors)"

  # Return the last version anyway
  echo "$mermaid_code"
  exit 1
}

main
