# Implementation Plan: Enhanced Mermaid Diagram Generation

## Overview

This plan addresses seven key improvements to the `feature_interrogate.sh` diagram generation:

1. Generate repo relationship diagram first
2. Create script for missing elements (domain topic extraction)
3. Implement auditor/validator loop
4. Incorporate research output
5. Provide diagram type guidance
6. Prompt for hierarchical decomposition

---

## 1. Generate Repo Relationship Diagram First

### Why It Helps
A baseline architecture diagram provides context for feature-specific diagrams. The LLM can reference existing components rather than inventing them.

### Implementation: `generate_repo_diagram.sh`

```bash
#!/bin/bash
# Generate baseline repository architecture diagram
# Caches result and only regenerates when repo changes

CACHE_DIR=".claude/cache"
DIAGRAM_FILE="$CACHE_DIR/repo-architecture.md"
HASH_FILE="$CACHE_DIR/repo-architecture.hash"

# Check if regeneration needed
current_hash=$(git rev-parse HEAD 2>/dev/null || find . -name "*.py" -o -name "*.ts" -o -name "*.tsx" | head -50 | xargs md5sum | md5sum | cut -d' ' -f1)

if [ -f "$HASH_FILE" ] && [ -f "$DIAGRAM_FILE" ]; then
  cached_hash=$(cat "$HASH_FILE")
  if [ "$current_hash" = "$cached_hash" ]; then
    echo "Using cached repo diagram"
    cat "$DIAGRAM_FILE"
    exit 0
  fi
fi

mkdir -p "$CACHE_DIR"

# Extract key files for context
KEY_FILES=$(find . -type f \( -name "*.py" -o -name "*.ts" -o -name "*.tsx" \) \
  ! -path "*/node_modules/*" ! -path "*/.venv/*" ! -path "*/dist/*" \
  | head -30 | xargs ls -la 2>/dev/null)

# Extract directory structure
DIR_STRUCTURE=$(find . -type d ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/.venv/*" | head -30)

# Generate prompt
PROMPT=$(cat << 'PROMPT_EOF'
Analyze this codebase structure and generate a HIGH-LEVEL architecture diagram.

CONSTRAINTS:
- Maximum 15 nodes
- Maximum 3 subgraphs (e.g., Frontend, Backend, Data)
- Show only major components, not individual files
- Use flowchart TD

FORMAT:
- Return ONLY the mermaid code block
- No explanations

DIRECTORY STRUCTURE:
DIR_PLACEHOLDER

KEY FILES:
FILES_PLACEHOLDER

Generate a clean architecture overview diagram:
PROMPT_EOF
)

PROMPT="${PROMPT//DIR_PLACEHOLDER/$DIR_STRUCTURE}"
PROMPT="${PROMPT//FILES_PLACEHOLDER/$KEY_FILES}"

# Generate diagram
RESULT=$(claude --dangerously-skip-permissions --print "$PROMPT" 2>&1)

# Save
echo "$RESULT" > "$DIAGRAM_FILE"
echo "$current_hash" > "$HASH_FILE"

echo "$RESULT"
```

### Integration Point
Call this at the start of `familiarize_repo()` and store output in `$SESSION_DIR/repo-architecture.md`.

---

## 2. Script for Missing Elements (Domain Topic Extraction)

### Why It Helps
Domain context improves semantic accuracy. DiagrammerGPT research shows topic specification significantly improves results.

### Implementation: `extract_domain_context.sh`

```bash
#!/bin/bash
# Extract domain topic, entities, and relationships from requirements

REQUIREMENTS="$1"
OUTPUT_FILE="$2"

PROMPT=$(cat << 'EOF'
Analyze this feature request and extract structured context for diagram generation.

REQUIREMENTS:
REQUIREMENTS_PLACEHOLDER

Extract and return ONLY this YAML structure (no other text):

```yaml
domain:
  topic: "<2-3 word domain, e.g., 'B2B Inventory Management'>"
  industry: "<industry category>"

entities:
  - name: "<Entity1>"
    type: "<actor|system|data|external>"
  - name: "<Entity2>"
    type: "<actor|system|data|external>"
  # (list 5-8 key entities)

relationships:
  - from: "<Entity1>"
    to: "<Entity2>"
    action: "<verb phrase, e.g., 'places order with'>"
  # (list 4-6 key relationships)

decision_points:
  - "<key decision 1, e.g., 'Is inventory available?'>"
  - "<key decision 2>"
  # (list 2-3 max)

complexity:
  estimated_nodes: <number 8-20>
  recommended_levels: <1-3>
  split_suggestion: "<if >15 nodes, suggest how to split>"
```
EOF
)

PROMPT="${PROMPT//REQUIREMENTS_PLACEHOLDER/$REQUIREMENTS}"

claude --dangerously-skip-permissions --print "$PROMPT" > "$OUTPUT_FILE"
```

### Usage in flow_diagram_loop()
```bash
# Before generating diagram
extract_domain_context.sh "$flow_context" "$SESSION_DIR/domain-context.yaml"
DOMAIN_CONTEXT=$(cat "$SESSION_DIR/domain-context.yaml")
```

---

## 3. Auditor/Validator Loop

### Why It Helps
Microsoft GenAIScript research shows LLMs fix syntax errors well when given explicit feedback. Iterative repair catches issues before user sees them.

### Implementation: `validate_and_repair_mermaid.sh`

```bash
#!/bin/bash
# Validate mermaid diagram and repair if needed
# Requires: npm install -g mermaid-validate

INPUT_FILE="$1"
MAX_RETRIES="${2:-3}"

# Extract mermaid code block
extract_mermaid() {
  sed -n '/```mermaid/,/```/p' "$1" | sed '1d;$d'
}

validate_mermaid() {
  local diagram="$1"
  # Use npx for validation
  echo "$diagram" | npx mermaid-validate validate --string - 2>&1
}

repair_mermaid() {
  local diagram="$1"
  local error="$2"

  REPAIR_PROMPT=$(cat << EOF
This Mermaid diagram has a syntax error. Fix it.

DIAGRAM:
\`\`\`mermaid
$diagram
\`\`\`

ERROR:
$error

RULES:
- Fix ONLY the syntax error
- Preserve the diagram's intent and structure
- Never use "end" as a node ID (use "finish" or "done")
- Ensure all arrows use --> not ->
- Balance all brackets and quotes

Return ONLY the corrected mermaid code block.
EOF
)

  claude --dangerously-skip-permissions --print "$REPAIR_PROMPT"
}

# Main loop
MERMAID_CODE=$(extract_mermaid "$INPUT_FILE")
RETRY=0

while [ $RETRY -lt $MAX_RETRIES ]; do
  VALIDATION=$(validate_mermaid "$MERMAID_CODE")

  if echo "$VALIDATION" | grep -q "isValid.*true"; then
    echo "✓ Diagram is valid"
    echo "$MERMAID_CODE"
    exit 0
  fi

  echo "⚠ Validation failed (attempt $((RETRY+1))/$MAX_RETRIES)"
  echo "Error: $VALIDATION"

  # Attempt repair
  REPAIRED=$(repair_mermaid "$MERMAID_CODE" "$VALIDATION")
  MERMAID_CODE=$(echo "$REPAIRED" | sed -n '/```mermaid/,/```/p' | sed '1d;$d')

  RETRY=$((RETRY+1))
done

echo "✗ Could not repair diagram after $MAX_RETRIES attempts"
exit 1
```

### Integration
Call after each diagram generation:
```bash
validate_and_repair_mermaid.sh "$SESSION_DIR/flow-diagram-iter-$iteration.md" 3
```

---

## 4. Incorporate Research Output

### Current Gap
`research-output.md` contains valuable architecture patterns but isn't used in diagram generation.

### Implementation
Modify the flow diagram prompt to include research findings:

```bash
# In flow_diagram_loop()
RESEARCH_CONTEXT=""
if [ -f "$SESSION_DIR/research-output.md" ]; then
  # Extract key architecture recommendations
  RESEARCH_CONTEXT=$(cat << EOF

## Architecture Context (from research)
$(grep -A 20 "ARCHITECTURE PATTERNS\|Implementation Roadmap\|Key Findings" "$SESSION_DIR/research-output.md" | head -40)

Use these patterns in your diagram where applicable.
EOF
)
fi
```

Then include `$RESEARCH_CONTEXT` in the prompt.

---

## 5. Diagram Type Guidance

### Recommended Types by Use Case

| Scenario | Diagram Type | Direction | Max Nodes |
|----------|--------------|-----------|-----------|
| User journey / workflow | `flowchart TD` | Top-down | 10-15 |
| System architecture | `flowchart TD` with subgraphs | Top-down | 15-25 |
| API sequence | `sequenceDiagram` | Left-right | 8-12 participants |
| Data model | `erDiagram` | N/A | 6-10 entities |
| State machine | `stateDiagram-v2` | Top-down | 8-12 states |

### Implementation: Add to Prompt

```bash
DIAGRAM_GUIDANCE=$(cat << 'EOF'
## Diagram Type Selection

Based on the requirements, choose the MOST APPROPRIATE type:

1. **User Flow / Process** → `flowchart TD`
   - For: Order workflows, user journeys, approval processes
   - Max: 12 nodes, 2-3 decisions

2. **System Architecture** → `flowchart TD` with subgraphs
   - For: Component relationships, service interactions
   - Max: 3 subgraphs, 5-7 nodes each

3. **API Interactions** → `sequenceDiagram`
   - For: Request/response flows, service calls
   - Max: 5 participants, 10 messages

4. **Data Relationships** → `erDiagram`
   - For: Database schema, entity relationships
   - Max: 8 entities

Choose ONE type. Do not mix types in a single diagram.
EOF
)
```

---

## 6. Hierarchical Decomposition Prompt

### The Problem
Single monolithic diagrams become unreadable at 20+ nodes.

### Solution: Multi-Level Generation

```bash
HIERARCHICAL_PROMPT=$(cat << 'EOF'
Generate a HIERARCHICAL diagram set (not one giant diagram).

## LEVEL 1: System Overview
Create a HIGH-LEVEL diagram showing major components only.
- Maximum 5-7 nodes
- Show: User → Frontend → Backend → Database (conceptual)
- NO implementation details
- Use: `flowchart LR`

## LEVEL 2: Component Details (generate separately)
For each major component from Level 1, create a focused diagram:
- Maximum 8-10 nodes each
- Show internal structure of that component
- Include decision points within that scope
- Use: `flowchart TD`

## LEVEL 3: Critical Flows (generate separately)
For the most important user journey:
- Maximum 10 nodes
- Step-by-step process
- Include error handling path
- Use: `flowchart TD`

---

START WITH LEVEL 1 ONLY.
After user confirms Level 1, generate Level 2 diagrams one at a time.

Generate Level 1 now:
EOF
)
```

### Implementation: Phased Generation

```bash
generate_hierarchical_diagrams() {
  # Level 1: Overview
  echo "Generating Level 1: System Overview..."
  generate_diagram_level 1 "overview" 7

  # Ask user if they want Level 2
  read -p "Generate detailed component diagrams? (y/n): " response
  if [ "$response" = "y" ]; then
    # Extract components from Level 1
    COMPONENTS=$(extract_components "$SESSION_DIR/level-1-overview.md")

    for component in $COMPONENTS; do
      echo "Generating Level 2: $component..."
      generate_diagram_level 2 "$component" 10
    done
  fi

  # Ask about Level 3
  read -p "Generate critical flow detail? (y/n): " response
  if [ "$response" = "y" ]; then
    generate_diagram_level 3 "critical-flow" 10
  fi
}
```

---

## 7. Complete Improved Prompt Template

```bash
IMPROVED_PROMPT=$(cat << 'EOF'
You are generating a Mermaid diagram for a software feature.

## Domain Context
$DOMAIN_CONTEXT

## Repository Architecture (existing system)
$REPO_ARCHITECTURE

## Feature Requirements
$REQUIREMENTS

## Research Findings (use these patterns)
$RESEARCH_CONTEXT

## Diagram Constraints
- **Type**: flowchart TD (or as specified in guidance)
- **Maximum nodes**: 12
- **Maximum decision points**: 3
- **Maximum subgraphs**: 3 (if needed)
- **Node labels**: 2-4 words maximum
- **Edge labels**: 1-3 words maximum

## Node Naming Convention
- Use short IDs with descriptive labels: `A[User Action]`
- Never use "end" as ID (use "finish" or "done")
- Never start IDs with "o" or "x"

## Structure Requirements
1. Start with entry point (user action or trigger)
2. Show main happy path first
3. Add 1-2 error/alternative paths
4. End with clear outcome states

## Output Format
Return ONLY the mermaid code block. No explanations, no prose.

```mermaid
flowchart TD
    [your diagram here]
```

Generate the diagram now:
EOF
)
```

---

## File Structure

```
.claude/
├── scripts/
│   ├── generate_repo_diagram.sh      # Baseline architecture
│   ├── extract_domain_context.sh     # Domain/entity extraction
│   └── validate_and_repair_mermaid.sh # Validator loop
├── cache/
│   ├── repo-architecture.md          # Cached repo diagram
│   └── repo-architecture.hash        # Cache invalidation hash
└── RESEARCH/
    └── {session}/
        ├── domain-context.yaml       # Extracted domain info
        ├── level-1-overview.md       # Hierarchical Level 1
        ├── level-2-{component}.md    # Hierarchical Level 2
        └── flow-diagram.md           # Final confirmed diagram
```

---

## Integration Summary

1. **familiarize_repo()** → calls `generate_repo_diagram.sh`, caches result
2. **refine_requirements()** → calls `extract_domain_context.sh` after refinement
3. **flow_diagram_loop()** →
   - Includes repo architecture, domain context, research output in prompt
   - Uses hierarchical decomposition (Level 1 first, then Level 2)
   - Calls `validate_and_repair_mermaid.sh` after each generation
   - Shows validation status to user

---

## Sources

- [Swark - Architecture diagrams from code](https://github.com/swark-io/swark)
- [Zencoder - Repo Grokking for diagrams](https://docs.zencoder.ai/user-guides/tutorials/generate-codebase-diagrams)
- [mermaid-validate CLI](https://github.com/cloud-on-prem/mermaid-validator)
- [mermaid-fixer - AI repair](https://github.com/sopaco/mermaid-fixer)
- [GenAIScript Mermaid Repairer](https://microsoft.github.io/genaiscript/blog/mermaids/)
- [DiagrammerGPT - Structured diagram plans](https://arxiv.org/html/2310.12128v2)
- [MermaidSeqBench - Evaluation dimensions](https://arxiv.org/html/2511.14967v1)
