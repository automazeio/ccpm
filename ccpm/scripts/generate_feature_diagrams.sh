#!/bin/bash
# generate_feature_diagrams.sh - Generate comprehensive feature diagram suite
# Creates: System Flow, User Journey, Sequence Diagram, State Diagram
#
# Usage: ./generate_feature_diagrams.sh <session_dir> <feature_name>
# Output: Multiple mermaid diagrams + combined HTML

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

SESSION_DIR="${1:-}"
FEATURE_NAME="${2:-feature}"

if [ -z "$SESSION_DIR" ]; then
  echo "Usage: $0 <session_dir> <feature_name>" >&2
  exit 1
fi

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
  echo -e "  ${GREEN}▸${NC} $1" >&2
}

log_warn() {
  echo -e "  ${YELLOW}⚠${NC} $1" >&2
}

# Ensure architecture index is up-to-date before generating diagrams
ensure_architecture_index() {
  local index_builder="$SCRIPT_DIR/build_architecture_index.sh"

  if [ -x "$index_builder" ]; then
    log "Ensuring architecture index is current..."
    "$index_builder" "$PROJECT_ROOT" 2>&1 | grep -v "^Building\|^$" | head -3 >&2 || true
  else
    log_warn "Architecture index builder not found at $index_builder"
  fi
}

# Load architecture index for deterministic element names
load_architecture_index() {
  local index_file="$PROJECT_ROOT/.claude/cache/architecture/index.yaml"

  if [ -f "$index_file" ]; then
    echo "<architecture_index>"
    echo "This index contains all known components in the codebase."
    echo "Use these exact names for diagram consistency."
    echo ""
    echo "Structure:"
    echo "- frontend.components: Pages and UI components with their API dependencies"
    echo "- backend.endpoints: API routes with their database table dependencies"
    echo "- database.tables: Tables with column names"
    echo "- relationships: Cross-layer dependency mappings"
    echo ""
    echo "For new elements not in this index, prefix with [NEW] and apply newNode class."
    echo ""
    cat "$index_file"
    echo "</architecture_index>"
  fi
}

# Load context from session files
load_context() {
  local context=""

  # Architecture index (for deterministic element naming)
  local arch_context
  arch_context=$(load_architecture_index)
  if [ -n "$arch_context" ]; then
    context+="$arch_context\n\n"
  fi

  # Requirements
  if [ -f "$SESSION_DIR/refined-requirements.md" ]; then
    context+="## Requirements\n$(cat "$SESSION_DIR/refined-requirements.md")\n\n"
  fi

  # Previous feedback (address all points)
  if [ -f "$SESSION_DIR/flow-feedback.md" ]; then
    context+="## Previous Feedback (address all points)\n$(cat "$SESSION_DIR/flow-feedback.md")\n\n"
  fi

  # Existing diagrams for targeted refinement based on feedback
  local has_existing_diagrams=false

  if [ -f "$SESSION_DIR/diagram-system-flow.md" ]; then
    has_existing_diagrams=true
    context+="## Existing System Flow Diagram (modify only what feedback requires)\n"
    context+="$(cat "$SESSION_DIR/diagram-system-flow.md")\n\n"
  fi

  if [ -f "$SESSION_DIR/diagram-user-journey.md" ]; then
    has_existing_diagrams=true
    context+="## Existing User Journey Diagram (modify only what feedback requires)\n"
    context+="$(cat "$SESSION_DIR/diagram-user-journey.md")\n\n"
  fi

  if [ -f "$SESSION_DIR/diagram-sequence.md" ]; then
    has_existing_diagrams=true
    context+="## Existing Sequence Diagram (modify only what feedback requires)\n"
    context+="$(cat "$SESSION_DIR/diagram-sequence.md")\n\n"
  fi

  if [ -f "$SESSION_DIR/diagram-state.md" ]; then
    has_existing_diagrams=true
    context+="## Existing State Diagram (modify only what feedback requires)\n"
    context+="$(cat "$SESSION_DIR/diagram-state.md")\n\n"
  fi

  if [ "$has_existing_diagrams" = true ] && [ -f "$SESSION_DIR/flow-feedback.md" ]; then
    context+="## Targeted Modification Required\n"
    context+="Existing diagrams are provided above with feedback.\n"
    context+="- Apply only the changes requested in the feedback section\n"
    context+="- Preserve node names, structure, and styling for unchanged elements\n\n"
  fi

  # Repo context
  if [ -f "$PROJECT_ROOT/CLAUDE.md" ]; then
    context+="## Repository Context\n$(head -150 "$PROJECT_ROOT/CLAUDE.md")\n\n"
  fi

  # Extract actual table names from migrations (for consistency)
  if [ -d "$PROJECT_ROOT/backend/migrations" ]; then
    context+="## DATABASE TABLES (use exact names)\n"
    context+="$(grep -h "CREATE TABLE" "$PROJECT_ROOT/backend/migrations"/*.sql 2>/dev/null | sed 's/CREATE TABLE IF NOT EXISTS /- /g' | sed 's/ (.*//g' | sort -u)\n\n"
  fi

  # Extract API route names (for consistency)
  if [ -d "$PROJECT_ROOT/backend/app/api/v1" ]; then
    context+="## API ROUTES (use exact paths)\n"
    context+="$(grep -rh '@router\.' "$PROJECT_ROOT/backend/app/api/v1"/*.py 2>/dev/null | grep -oE '"/[^"]*"' | sort -u | head -20)\n\n"
  fi

  # Domain models
  if [ -d "$PROJECT_ROOT/backend/app/models" ]; then
    context+="## Database Models\n"
    for model_file in "$PROJECT_ROOT/backend/app/models"/*.py; do
      if [ -f "$model_file" ] && [ "$(basename "$model_file")" != "__init__.py" ]; then
        local filename=$(basename "$model_file" .py)
        context+="### $filename\n"
        context+="$(grep -E "^class [A-Z]|__tablename__|status.*=|state.*=" "$model_file" 2>/dev/null | head -15)\n"
      fi
    done
    context+="\n"
  fi

  # Research output if available
  if [ -f "$SESSION_DIR/research-output.md" ]; then
    context+="## Research Findings\n$(head -80 "$SESSION_DIR/research-output.md")\n\n"
  fi

  echo -e "$context"
}

# Generate all diagrams with a single Claude call
generate_diagrams() {
  local context
  context=$(load_context)

  local prompt
  prompt=$(cat << 'PROMPT_HEADER'
<role>
You are a senior software architect specializing in technical documentation and system visualization. You create precise, accurate Mermaid diagrams that reflect actual system architecture and data flow patterns.
</role>

<task>
Generate a comprehensive diagram suite (4 diagrams) for the feature described below.
</task>

PROMPT_HEADER
)

  prompt+="
<feature_name>$FEATURE_NAME</feature_name>

<context>
$context
</context>

"

  prompt+=$(cat << 'PROMPT_INSTRUCTIONS'
<instructions>

<flow_direction>
Request pipelines follow execution order. Auth and middleware run BEFORE route handlers process requests. This reflects how web frameworks actually work: a request passes through middleware layers before reaching the handler.

Correct order: Client → Gateway/Middleware → Auth → Validation → Route Handler → Database → Response
</flow_direction>

<naming_conventions>
Use exact names from the context above when available:
- Database tables: lowercase with underscores (e.g., marketplace_orders)
- Services: PascalCase (e.g., MarketplaceService)
- External systems: brackets (e.g., [Stripe])
</naming_conventions>

<architecture_constraint>
When an architecture_index is provided in the context, use it as your vocabulary source:
- Use exact component names, endpoint paths, and table names from the index
- The index ensures diagrams remain consistent with the actual codebase

For elements not in the index (new features, external systems):
- Apply the "newNode" class: A[New Component]:::newNode
- Include this class definition: classDef newNode fill:#e3f2fd,stroke:#1976d2,stroke-dasharray:5
- New nodes appear with blue dashed borders, clearly indicating proposed additions
</architecture_constraint>

<data_layer_rules>
When deciding whether to use existing tables or create new tables in diagrams:

USE AN EXISTING TABLE when:
- The architecture_index shows a table storing the same entity type
- The API endpoint already has a documented relationship to that table
- The data is an attribute of an existing entity

CREATE A NEW TABLE (mark with [NEW] and newNode class) when ANY of these are true:
- Data has its own unique identifier/lifecycle (it's a new entity)
- Data has one-to-many or many-to-many relationship with existing tables
- Data would be NULL for more than 50% of parent records
- Data represents a distinct business concept (e.g., "agreements" vs "listings")

API-TO-TABLE MAPPING:
- Each distinct resource noun in the API path typically maps to its own table
- /marketplace/listings → marketplace_listings table
- /marketplace/listings/{id}/offers → marketplace_offers table (FK to listings)
- Nested sub-resources with their own IDs → separate tables with foreign keys

CONSISTENCY CHECK:
- If an endpoint like /api/v1/X/Y exists, look for tables named X or Y in the index
- Prefer domain-specific tables (marketplace_* for marketplace features)
- Avoid connecting unrelated domains unless explicitly bridging
</data_layer_rules>

<backend_to_data_connections>
Label every arrow from Backend to Data Layer:

LABEL SCHEMA:
- "CRUD: {table}" - Primary table this endpoint manages (one per endpoint)
- "FK: {field}" - Foreign key lookup/validation
- "JOIN: {table}" - Related data fetched together with primary
- "writes" / "reads" - Operation type

For each endpoint, identify:
1. PRIMARY TABLE: The resource noun in the URL path
2. SECONDARY TABLES: Foreign key references needed

Rules:
- Each endpoint has exactly ONE primary table (labeled "CRUD: {table}")
- Label secondary connections with purpose (FK, JOIN)
- Use existing relationships from architecture_index exactly when present
</backend_to_data_connections>

<error_handling>
Include error paths to show what happens when things fail:
- Use dotted arrow syntax: A -.-> B for error flows
- Style error nodes: classDef errorNode fill:#ffebee,stroke:#c62828
- Common errors: auth failure (401), validation error (400), not found (404)
</error_handling>

<diagrams>

<diagram type="system-flow" section="1">
Shows how the feature integrates with existing system components.

```mermaid
flowchart TD
    subgraph frontend[Frontend]
        %% UI components involved
    end
    subgraph backend[Backend Services]
        %% API endpoints, services
    end
    subgraph data[Data Layer]
        %% Database, external APIs
    end
    %% Show data flow between components
```

Guidelines:
- Maximum 10 nodes
- Use actual component names from the codebase
- Show request/response flow in execution order (auth before handlers)
- Include error paths with dotted lines
- Label ALL Backend→Data arrows with relationship type (CRUD, FK, JOIN)
- Each endpoint connects to exactly one PRIMARY table
</diagram>

<diagram type="user-journey" section="2">
Shows the end-user's perspective and experience flow.

```mermaid
flowchart LR
    subgraph discover[Discovery]
        %% How user finds/accesses feature
    end
    subgraph action[Main Actions]
        %% Primary user interactions
    end
    subgraph outcome[Outcomes]
        %% Results, confirmations, next steps
    end
```

Guidelines:
- Maximum 12 nodes
- Focus on USER actions and decisions (not system internals)
- Include what the user SEES at each step
- Show both success and error experiences
- Use friendly labels (e.g., "Sees confirmation" not "API returns 200")
</diagram>

<diagram type="sequence" section="3">
Shows interaction between actors and system components over time.

```mermaid
sequenceDiagram
    participant U as User
    participant F as Frontend
    participant Auth as Auth Middleware
    participant A as API Handler
    participant D as Database
    %% Show the main interaction flow with auth FIRST
```

Guidelines:
- Maximum 5 participants
- Maximum 15 messages
- Show the PRIMARY workflow (not all edge cases)
- Auth/middleware is called BEFORE API handler processes the request
- Include auth failure response (alt block with 401)
</diagram>

<diagram type="state" section="4">
Shows lifecycle states of the primary entity involved in this feature.

```mermaid
stateDiagram-v2
    [*] --> InitialState
    InitialState --> ProcessingState: trigger_event
    ProcessingState --> SuccessState: completion
    ProcessingState --> ErrorState: failure
    SuccessState --> [*]
    ErrorState --> InitialState: retry
```

Guidelines:
- Maximum 8 states
- Show transitions with event/action labels
- Include initial [*] and final [*] states
- For simple CRUD features, show data lifecycle (created -> updated -> archived)
- Avoid multiline note blocks (they cause rendering errors)
</diagram>

</diagrams>

<layout_optimization>
Mermaid uses automatic layout (dagre). To minimize line crossings:

1. **Order nodes by connection flow** - Within each subgraph, define nodes left-to-right matching their primary connections to the next layer. If A connects to X and B connects to Y, define them as A, B in source and X, Y in target.

2. **No orphan nodes** - Every defined node must have at least one connection. Remove unused nodes.

3. **Consistent link direction** - Define links in consistent left-to-right order within each layer transition.

4. **Group related connections** - Define all links from node A before moving to links from node B.

Example of good ordering:
```
subgraph frontend
    A  %% connects to X
    B  %% connects to Y
end
subgraph backend
    X  %% aligned under A
    Y  %% aligned under B
end
A --> X
B --> Y
```
This produces zero crossings because node order matches connection order.
</layout_optimization>

<syntax_rules>
These prevent common Mermaid rendering errors:
1. Use "done", "finish", or "complete" as node IDs ("end" is a reserved word)
2. In state diagrams: omit multiline note blocks (they cause rendering errors)
3. Wrap labels with special characters in quotes: A["Label (with parens)"]
4. Keep node/state names as simple alphanumeric identifiers
</syntax_rules>

<refinement_mode>
If EXISTING DIAGRAM sections are present in the context above:
- This is a REFINEMENT request, not fresh generation
- Copy the existing diagram structure exactly
- Make ONLY the changes requested in the PREVIOUS FEEDBACK section
- Keep unchanged diagrams IDENTICAL to existing versions
</refinement_mode>

</instructions>

<example>
This shows correct flow direction with auth before handler, plus error styling:

```mermaid
flowchart TD
    A[Client Request] --> B[Auth Middleware]
    B --> C{Authenticated?}
    C -.->|No| D[401 Unauthorized]:::errorNode
    C -->|Yes| E[Route Handler]
    E --> F[(Database)]
    F --> G[Response]
    classDef errorNode fill:#ffebee,stroke:#c62828
```
</example>

<output_format>
Return all 4 diagrams with their section headers (## 1. System Flow Diagram, etc.). No explanations outside the code blocks.
</output_format>

PROMPT_INSTRUCTIONS
)

  if command -v claude &>/dev/null; then
    claude --dangerously-skip-permissions --print "$prompt" 2>&1
  else
    echo "Error: Claude CLI not found" >&2
    exit 1
  fi
}

# Extract individual diagrams from combined output
extract_diagram() {
  local content="$1"
  local section="$2"

  # Extract section between headers
  echo "$content" | sed -n "/## $section/,/## [0-9]/p" | sed '$ d' | sed -n '/```mermaid/,/```/p' | sed '1d;$d'
}

# Generate combined HTML with tabs
generate_html() {
  local output_file="$1"

  local system_flow user_journey sequence_diagram state_diagram

  # Read individual diagram files
  system_flow=$(cat "$SESSION_DIR/diagram-system-flow.md" 2>/dev/null | sed -n '/```mermaid/,/```/p' | sed '1d;$d' || echo "flowchart TD\n    A[Not generated]")
  user_journey=$(cat "$SESSION_DIR/diagram-user-journey.md" 2>/dev/null | sed -n '/```mermaid/,/```/p' | sed '1d;$d' || echo "flowchart LR\n    A[Not generated]")
  sequence_diagram=$(cat "$SESSION_DIR/diagram-sequence.md" 2>/dev/null | sed -n '/```mermaid/,/```/p' | sed '1d;$d' || echo "sequenceDiagram\n    Note over A: Not generated")
  state_diagram=$(cat "$SESSION_DIR/diagram-state.md" 2>/dev/null | sed -n '/```mermaid/,/```/p' | sed '1d;$d' || echo "stateDiagram-v2\n    [*] --> NotGenerated")

  cat > "$output_file" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Feature Diagrams: ${FEATURE_TITLE:-$FEATURE_NAME}</title>
  <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #1a1a2e;
      color: #eee;
      min-height: 100vh;
    }
    .header {
      background: linear-gradient(135deg, #16213e 0%, #1a1a2e 100%);
      padding: 20px 30px;
      border-bottom: 2px solid #B89C4C;
    }
    .header h1 {
      color: #B89C4C;
      font-size: 1.5rem;
      font-weight: 600;
    }
    .header .subtitle {
      color: #888;
      font-size: 0.9rem;
      margin-top: 5px;
    }
    .tabs {
      display: flex;
      flex-wrap: wrap;
      background: #16213e;
      border-bottom: 1px solid #333;
      padding: 0 20px;
    }
    .tab {
      padding: 15px 20px;
      cursor: pointer;
      color: #888;
      border-bottom: 3px solid transparent;
      transition: all 0.2s;
      font-weight: 500;
      font-size: 0.9rem;
    }
    .tab:hover {
      color: #B89C4C;
      background: rgba(184, 156, 76, 0.1);
    }
    .tab.active {
      color: #B89C4C;
      border-bottom-color: #B89C4C;
    }
    .tab-icon {
      margin-right: 8px;
    }
    .content {
      padding: 30px;
    }
    .diagram-container {
      display: none;
      background: #fff;
      border-radius: 12px;
      padding: 30px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.3);
    }
    .diagram-container.active {
      display: block;
    }
    .diagram-container h2 {
      color: #1a1a2e;
      margin-bottom: 10px;
      font-size: 1.2rem;
    }
    .diagram-container .description {
      color: #666;
      font-size: 0.9rem;
      margin-bottom: 20px;
      padding-bottom: 15px;
      border-bottom: 1px solid #eee;
    }
    .mermaid {
      display: flex;
      justify-content: center;
    }
    .mermaid svg {
      max-width: 100%;
      height: auto;
    }
    .timestamp {
      text-align: center;
      color: #666;
      font-size: 0.8rem;
      margin-top: 30px;
      padding-top: 20px;
      border-top: 1px solid #eee;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>Feature Diagram Suite</h1>
    <div class="subtitle">${FEATURE_TITLE:-$FEATURE_NAME} | Generated $(date '+%Y-%m-%d %H:%M:%S')</div>
  </div>

  <div class="tabs">
    <div class="tab active" onclick="showTab('system')"><span class="tab-icon">⚙️</span>System Flow</div>
    <div class="tab" onclick="showTab('journey')"><span class="tab-icon">👤</span>User Journey</div>
    <div class="tab" onclick="showTab('sequence')"><span class="tab-icon">↔️</span>Sequence</div>
    <div class="tab" onclick="showTab('state')"><span class="tab-icon">🔄</span>State</div>
  </div>

  <div class="content">
    <div id="system" class="diagram-container active">
      <h2>System Flow Diagram</h2>
      <div class="description">Shows how the feature integrates with existing system components (backend perspective)</div>
      <div class="mermaid">
$system_flow
      </div>
      <div class="timestamp">Verify: Components, data flow, error handling</div>
    </div>

    <div id="journey" class="diagram-container">
      <h2>User Journey Diagram</h2>
      <div class="description">Shows the end-user's perspective and experience flow (what the user sees and does)</div>
      <div class="mermaid">
$user_journey
      </div>
      <div class="timestamp">Verify: User touchpoints, screens, feedback messages</div>
    </div>

    <div id="sequence" class="diagram-container">
      <h2>Sequence Diagram</h2>
      <div class="description">Shows interactions between actors and components over time</div>
      <div class="mermaid">
$sequence_diagram
      </div>
      <div class="timestamp">Verify: API calls, response handling, timing</div>
    </div>

    <div id="state" class="diagram-container">
      <h2>State Diagram</h2>
      <div class="description">Shows the lifecycle states of the primary entity/resource</div>
      <div class="mermaid">
$state_diagram
      </div>
      <div class="timestamp">Verify: Valid states, transitions, edge cases</div>
    </div>
  </div>

  <script>
    mermaid.initialize({
      startOnLoad: true,
      theme: 'default',
      flowchart: { useMaxWidth: true, htmlLabels: true, curve: 'basis' },
      sequence: { useMaxWidth: true, showSequenceNumbers: true },
      stateDiagram: { useMaxWidth: true }
    });

    function showTab(tabId) {
      document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
      event.target.closest('.tab').classList.add('active');
      document.querySelectorAll('.diagram-container').forEach(d => d.classList.remove('active'));
      document.getElementById(tabId).classList.add('active');
    }
  </script>
</body>
</html>
HTMLEOF

  log "HTML diagram suite generated: $output_file"
}

# Parse and save individual diagrams
parse_and_save_diagrams() {
  local combined_output="$1"

  # Save the combined output
  echo "$combined_output" > "$SESSION_DIR/feature-diagrams-combined.md"

  # Extract and save individual diagrams
  local current_section=""
  local current_content=""
  local in_code_block=false

  while IFS= read -r line; do
    # Detect section headers
    if [[ "$line" =~ ^##\ 1\.\ System ]]; then
      current_section="system-flow"
      current_content=""
    elif [[ "$line" =~ ^##\ 2\.\ User ]]; then
      # Save previous section
      if [ -n "$current_section" ] && [ -n "$current_content" ]; then
        echo "$current_content" > "$SESSION_DIR/diagram-$current_section.md"
      fi
      current_section="user-journey"
      current_content=""
    elif [[ "$line" =~ ^##\ 3\.\ Sequence ]]; then
      if [ -n "$current_section" ] && [ -n "$current_content" ]; then
        echo "$current_content" > "$SESSION_DIR/diagram-$current_section.md"
      fi
      current_section="sequence"
      current_content=""
    elif [[ "$line" =~ ^##\ 4\.\ State ]]; then
      if [ -n "$current_section" ] && [ -n "$current_content" ]; then
        echo "$current_content" > "$SESSION_DIR/diagram-$current_section.md"
      fi
      current_section="state"
      current_content=""
    fi

    # Accumulate content
    if [ -n "$current_section" ]; then
      current_content+="$line"$'\n'
    fi
  done <<< "$combined_output"

  # Save last section
  if [ -n "$current_section" ] && [ -n "$current_content" ]; then
    echo "$current_content" > "$SESSION_DIR/diagram-$current_section.md"
  fi

  log "Individual diagrams saved to $SESSION_DIR/"
}

# Main execution
main() {
  mkdir -p "$SESSION_DIR"

  # Step 1: Ensure architecture index is up-to-date (auto-rebuilds if source changed)
  ensure_architecture_index

  # Extract meaningful feature title from requirements (not timestamp-based)
  if [ -f "$SESSION_DIR/refined-requirements.md" ]; then
    FEATURE_TITLE=$(head -5 "$SESSION_DIR/refined-requirements.md" | grep -oE '^#.*' | head -1 | sed 's/^# //')
    [ -z "$FEATURE_TITLE" ] && FEATURE_TITLE="$FEATURE_NAME"
  else
    FEATURE_TITLE="$FEATURE_NAME"
  fi
  export FEATURE_TITLE

  log "Generating feature diagram suite for: $FEATURE_TITLE"
  log "  (System Flow, User Journey, Sequence, State)"

  local result
  result=$(generate_diagrams)

  # Parse and save individual diagrams
  parse_and_save_diagrams "$result"

  # Optimize diagrams (remove orphans, reorder for minimal crossings)
  OPTIMIZER="$SCRIPT_DIR/optimize_mermaid_diagram.sh"
  if [ -x "$OPTIMIZER" ]; then
    log "Optimizing diagrams..."
    for diagram in "$SESSION_DIR"/diagram-*.md; do
      if [ -f "$diagram" ]; then
        "$OPTIMIZER" "$diagram" 2>&1 | grep -v "^Optimized:" || true
      fi
    done
  fi

  # Generate combined HTML
  generate_html "$SESSION_DIR/feature-diagrams.html"

  # Step 4: Validate diagrams against architecture index
  VALIDATOR="$SCRIPT_DIR/validate_diagram.sh"
  if [ -x "$VALIDATOR" ]; then
    log "Validating diagrams against architecture index..."
    local validation_report="$SESSION_DIR/validation-report.txt"

    {
      echo "# Diagram Validation Report"
      echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
      echo ""

      for diagram in "$SESSION_DIR"/diagram-*.md; do
        if [ -f "$diagram" ]; then
          "$VALIDATOR" "$diagram" 2>&1 || true
          echo ""
        fi
      done
    } > "$validation_report"

    # Show summary
    local new_count
    new_count=$(grep -c "★ New elements:" "$validation_report" 2>/dev/null || echo "0")
    if [ "$new_count" -gt 0 ]; then
      log_warn "Validation found new elements - see: $validation_report"
    else
      log "All elements validated against architecture index"
    fi
  fi

  log "Diagram suite complete"
  log "  Combined: $SESSION_DIR/feature-diagrams.html"

  # Output the combined result to stdout as well
  echo "$result"
}

main "$@"
