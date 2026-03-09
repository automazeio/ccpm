#!/bin/bash
# generate_repo_diagrams.sh - Generate comprehensive repository diagram suite
# Creates: Architecture, ERD, User Flows, and API Sequence diagrams
#
# Usage: ./generate_repo_diagrams.sh [output_dir]
# Output: Multiple mermaid diagrams in markdown format + combined HTML

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

CACHE_DIR="$PROJECT_ROOT/.claude/cache"
DEFAULT_OUTPUT_DIR="$CACHE_DIR"
HASH_FILE="$CACHE_DIR/repo-diagrams.hash"

OUTPUT_DIR="${1:-$DEFAULT_OUTPUT_DIR}"

# Colors for output
RED='\033[0;31m'
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

# Calculate hash of repo structure for cache invalidation
calculate_repo_hash() {
  local hash=""
  if git rev-parse HEAD &>/dev/null; then
    hash=$(git rev-parse HEAD)
  else
    hash=$(find . -type f \( -name "*.py" -o -name "*.ts" -o -name "*.tsx" \) \
      ! -path "*/node_modules/*" ! -path "*/.venv/*" \
      2>/dev/null | head -100 | xargs ls -la 2>/dev/null | md5sum | cut -d' ' -f1)
  fi
  echo "$hash"
}

# Check if cached diagrams are still valid
check_cache() {
  mkdir -p "$CACHE_DIR"
  mkdir -p "$OUTPUT_DIR"

  local current_hash
  current_hash=$(calculate_repo_hash)

  if [ -f "$HASH_FILE" ] && [ -f "$CACHE_DIR/repo-diagrams.md" ]; then
    local cached_hash
    cached_hash=$(cat "$HASH_FILE")
    if [ "$current_hash" = "$cached_hash" ]; then
      return 0  # Cache is valid
    fi
  fi

  echo "$current_hash" > "$HASH_FILE"
  return 1  # Cache invalid
}

# Extract database models for ERD (concise - class names and key relationships only)
extract_models() {
  local models=""

  # Python SQLAlchemy models - just class names and FKs
  if [ -d "backend/app/models" ]; then
    models+="### Models:\n"
    for model_file in backend/app/models/*.py; do
      if [ -f "$model_file" ] && [ "$(basename "$model_file")" != "__init__.py" ]; then
        local classname=$(grep -E "^class [A-Z]" "$model_file" 2>/dev/null | head -1 | sed 's/class \([A-Za-z]*\).*/\1/')
        local fks=$(grep -oE "ForeignKey\(['\"]([^'\"]+)" "$model_file" 2>/dev/null | sed "s/ForeignKey(['\"]//g" | tr '\n' ', ' | sed 's/,$//')
        if [ -n "$classname" ]; then
          models+="- $classname"
          [ -n "$fks" ] && models+=" -> $fks"
          models+="\n"
        fi
      fi
    done
  fi

  echo -e "$models"
}

# Extract frontend pages with navigation targets and API calls (enhanced)
extract_frontend() {
  local frontend=""

  # React pages with navigation targets
  if [ -d "frontend/src/pages" ]; then
    frontend+="### Pages & Navigation:\n"

    for page in frontend/src/pages/*.tsx; do
      [ -f "$page" ] || continue
      local name=$(basename "$page" .tsx)

      # Get navigation targets
      local nav_targets=$(grep -oE "navigate\(['\"][^'\"]*" "$page" 2>/dev/null | \
        sed "s/navigate(['\"]//g" | sort -u | head -3 | tr '\n' ',' | sed 's/,$//')

      # Get API calls
      local api_calls=$(grep -oE "[a-zA-Z]+Api\.[a-zA-Z]+" "$page" 2>/dev/null | \
        sort -u | head -3 | tr '\n' ',' | sed 's/,$//')

      frontend+="- $name"
      [ -n "$nav_targets" ] && frontend+=" -> [$nav_targets]"
      [ -n "$api_calls" ] && frontend+=" (API: $api_calls)"
      frontend+="\n"
    done
    frontend+="\n"
  fi

  # Route definitions
  if [ -f "frontend/src/App.tsx" ]; then
    frontend+="### Routes:\n"
    grep -oE 'path="[^"]*"' frontend/src/App.tsx 2>/dev/null | \
      sed 's/path="//g; s/"//g' | sort -u | while read route; do
        frontend+="- $route\n"
      done
    frontend+="\n"
  fi

  echo -e "$frontend"
}

# Extract user journeys from navigation patterns, API workflows, and kanban stages
extract_user_journeys() {
  local output=""

  output+="### USER JOURNEYS\n\n"

  # 1. Authentication Journey
  output+="**Authentication Journey:**\n"
  if [ -f "frontend/src/pages/LoginPage.tsx" ]; then
    local has_keycloak=$(grep -c "Keycloak\|keycloak" frontend/src/pages/LoginPage.tsx 2>/dev/null || echo 0)
    local has_native=$(grep -c "authApi.login\|login(" frontend/src/pages/LoginPage.tsx 2>/dev/null || echo 0)

    output+="- Entry: /login\n"
    [ "$has_native" -gt 0 ] && output+="  - Native Auth (email/password)\n"
    [ "$has_keycloak" -gt 0 ] && output+="  - Keycloak SSO (PKCE)\n"
    output+="- Success: /dashboard\n"
    [ -f "frontend/src/pages/RegisterPage.tsx" ] && output+="- Register: /register -> /login\n"
    output+="\n"
  fi

  # 2. Navigation Flow Graph
  output+="**Page Navigation Graph:**\n"
  if [ -d "frontend/src/pages" ]; then
    for page in frontend/src/pages/*.tsx; do
      [ -f "$page" ] || continue
      local name=$(basename "$page" .tsx | sed 's/Page$//')

      local targets=$(grep -oE "navigate\(['\"/][^'\"]*" "$page" 2>/dev/null | \
        sed "s/navigate(['\"]//g; s/navigate(\`//g" | \
        grep -v "^\$" | sort -u | head -5 | tr '\n' ', ' | sed 's/,$//')

      if [ -n "$targets" ]; then
        output+="- $name -> $targets\n"
      fi
    done
    output+="\n"
  fi

  # 3. Kanban/Workflow Stages (if exists)
  if grep -q "Kanban System\|kanban" CLAUDE.md 2>/dev/null; then
    output+="**Procurement Workflow Stages:**\n"
    output+="1. Ordered (initial purchase)\n"
    output+="2. In Transit (shipment)\n"
    output+="3. Receiving (inspection)\n"
    output+="4. Processing (internal)\n"
    output+="5. Ready to Bill (invoicing)\n"
    output+="6. Completed (finalized)\n\n"
  elif [ -f "backend/app/api/v1/kanban.py" ]; then
    output+="**Kanban Workflow:** (check backend for stages)\n\n"
  fi

  # 4. API-Driven User Actions
  output+="**API Namespaces (User Actions):**\n"
  if [ -f "frontend/src/api.ts" ]; then
    grep -E "^export const [a-zA-Z]+Api" frontend/src/api.ts 2>/dev/null | \
      sed 's/export const //g; s/ =.*//g' | while read api; do
        output+="- $api\n"
      done
    output+="\n"
  fi

  # 5. Protected vs Public Routes
  output+="**Route Protection:**\n"
  if [ -f "frontend/src/App.tsx" ]; then
    output+="Public: /login, /register, /auth/callback\n"
    output+="Protected: "
    grep -oE 'path="[^"]*"' frontend/src/App.tsx 2>/dev/null | \
      sed 's/path="//g; s/"//g' | \
      grep -v "login\|register\|callback\|\*" | \
      tr '\n' ', ' | sed 's/,$/\n/'
    output+="\n"
  fi

  echo -e "$output"
}

# Extract API routes for sequence diagrams (concise)
extract_api_routes() {
  local routes=""

  # FastAPI routes - just module names
  if [ -d "backend/app/api" ]; then
    routes+="### API modules: "
    routes+=$(find backend/app/api -name "*.py" ! -name "__init__.py" 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/.py//' | tr '\n' ', ' | sed 's/,$//')
    routes+="\n"
  fi

  echo -e "$routes"
}

# Extract project documentation (concise - just overview and architecture)
extract_documentation() {
  local docs=""

  if [ -f "CLAUDE.md" ]; then
    docs+="### Project Overview:\n"
    # Extract just the key sections
    sed -n '1,/^## Architecture/p' CLAUDE.md | head -50
    docs+="\n"
  elif [ -f "README.md" ]; then
    docs+="### From README:\n"
    head -40 README.md
    docs+="\n"
  fi

  echo -e "$docs"
}

# Generate all diagrams with a single Claude call
generate_diagrams() {
  local documentation
  documentation=$(extract_documentation)

  local models
  models=$(extract_models)

  local frontend
  frontend=$(extract_frontend)

  local api_routes
  api_routes=$(extract_api_routes)

  local user_journeys
  user_journeys=$(extract_user_journeys)

  local prompt
  prompt=$(cat << 'PROMPT_HEADER'
Generate a comprehensive diagram suite for this repository. Create 5 separate mermaid diagrams.

PROMPT_HEADER
)

  prompt+="
## PROJECT DOCUMENTATION
$documentation

## DATABASE MODELS
$models

## FRONTEND PAGES & ROUTES
$frontend

## API ENDPOINTS
$api_routes

## USER JOURNEYS
$user_journeys

"

  prompt+=$(cat << 'PROMPT_INSTRUCTIONS'
---

Generate exactly 5 diagrams in the following format. Use domain-specific terminology, not generic tech labels.

## 1. Architecture Overview

Create a high-level system architecture diagram showing major components and their relationships.

```mermaid
flowchart TD
    subgraph ui[User Interface]
        %% Main user-facing features
    end
    subgraph core[Core Business Logic]
        %% Domain services and operations
    end
    subgraph data[Data & Integrations]
        %% Database, external APIs, storage
    end
    %% Show connections between components
```

Constraints:
- Maximum 12 nodes
- Use domain terms (e.g., "Inventory Mgmt" not "CRUD Operations")
- Show data flow direction with arrows
- Maximum 4 subgraphs

---

## 2. Entity Relationship Diagram

Create an ERD showing database tables and their relationships based on the models provided.

```mermaid
erDiagram
    %% Define entities with their key attributes
    %% Show relationships: ||--o{ (one-to-many), ||--|| (one-to-one), }o--o{ (many-to-many)
```

Constraints:
- Include primary entities only (max 10 entities)
- Show foreign key relationships
- Include 2-4 key attributes per entity
- Use proper ERD relationship notation

---

## 3. User Flow Diagram

Create a user journey diagram showing the main workflows users perform.

```mermaid
flowchart LR
    subgraph auth[Authentication]
    end
    subgraph main[Main Workflows]
    end
    subgraph actions[Key Actions]
    end
```

Constraints:
- Maximum 15 nodes
- Show 2-3 primary user journeys
- Include decision points for key branches
- Left-to-right flow (LR)

---

## 4. API Sequence Diagram

Create a sequence diagram showing a typical API request flow (choose the most important workflow).

```mermaid
sequenceDiagram
    participant U as User
    participant F as Frontend
    participant A as API
    participant D as Database
    %% Show the request/response flow
```

Constraints:
- Maximum 5 participants
- Show 8-12 messages
- Include one key workflow (e.g., create order, authentication)
- Show error handling if relevant

---

## 5. User Journey Diagram

Create a Mermaid User Journey diagram showing the primary user workflows with satisfaction scores.
Use the USER JOURNEYS data provided to create accurate journeys based on actual navigation patterns.

```mermaid
journey
    title Primary User Journeys
    section Authentication
      Visit Login Page: 5: User
      Enter Credentials: 3: User
      Navigate to Dashboard: 5: User
    section Main Workflow
      View Dashboard: 5: User
      Select Feature: 4: User
      Perform Action: 3: User
      View Results: 5: User
```

Constraints:
- Include 3-4 major sections (journeys) based on the actual workflows
- 3-5 tasks per section
- Satisfaction scores 1-5 (1=frustrating, 5=delightful)
- Include relevant actors (User, System, Admin)
- Use actual page names and workflows from the USER JOURNEYS data

---

OUTPUT FORMAT:
Return all 5 diagrams in markdown format with headers. Omit explanations outside the code blocks.
PROMPT_INSTRUCTIONS
)

  if command -v claude &>/dev/null; then
    claude --dangerously-skip-permissions --print "$prompt" 2>&1
  else
    echo "Error: Claude CLI not found" >&2
    exit 1
  fi
}

# Generate combined HTML with tabs for each diagram
generate_html() {
  local markdown_file="$1"
  local html_file="$2"
  local title="${3:-Repository Diagrams}"

  # Extract each diagram section
  local arch_diagram=$(sed -n '/## 1\. Architecture/,/## 2\./p' "$markdown_file" | sed '$ d')
  local erd_diagram=$(sed -n '/## 2\. Entity Relationship/,/## 3\./p' "$markdown_file" | sed '$ d')
  local flow_diagram=$(sed -n '/## 3\. User Flow/,/## 4\./p' "$markdown_file" | sed '$ d')
  local seq_diagram=$(sed -n '/## 4\. API Sequence/,/## 5\./p' "$markdown_file" | sed '$ d')
  local journey_diagram=$(sed -n '/## 5\. User Journey/,$ p' "$markdown_file")

  # Extract just the mermaid code blocks
  extract_mermaid() {
    echo "$1" | sed -n '/```mermaid/,/```/p' | sed '1d;$d'
  }

  local arch_mermaid=$(extract_mermaid "$arch_diagram")
  local erd_mermaid=$(extract_mermaid "$erd_diagram")
  local flow_mermaid=$(extract_mermaid "$flow_diagram")
  local seq_mermaid=$(extract_mermaid "$seq_diagram")
  local journey_mermaid=$(extract_mermaid "$journey_diagram")

  cat > "$html_file" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title</title>
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
      background: #16213e;
      border-bottom: 1px solid #333;
      padding: 0 20px;
    }
    .tab {
      padding: 15px 25px;
      cursor: pointer;
      color: #888;
      border-bottom: 3px solid transparent;
      transition: all 0.2s;
      font-weight: 500;
    }
    .tab:hover {
      color: #B89C4C;
      background: rgba(184, 156, 76, 0.1);
    }
    .tab.active {
      color: #B89C4C;
      border-bottom-color: #B89C4C;
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
      margin-bottom: 20px;
      font-size: 1.2rem;
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
    <h1>$title</h1>
    <div class="subtitle">Generated $(date '+%Y-%m-%d %H:%M:%S')</div>
  </div>

  <div class="tabs">
    <div class="tab active" onclick="showTab('arch')">Architecture</div>
    <div class="tab" onclick="showTab('erd')">Entity Relationships</div>
    <div class="tab" onclick="showTab('flow')">User Flows</div>
    <div class="tab" onclick="showTab('seq')">API Sequence</div>
    <div class="tab" onclick="showTab('journey')">User Journeys</div>
  </div>

  <div class="content">
    <div id="arch" class="diagram-container active">
      <h2>System Architecture Overview</h2>
      <div class="mermaid">
$arch_mermaid
      </div>
      <div class="timestamp">Shows high-level system components and their relationships</div>
    </div>

    <div id="erd" class="diagram-container">
      <h2>Entity Relationship Diagram</h2>
      <div class="mermaid">
$erd_mermaid
      </div>
      <div class="timestamp">Database tables and their relationships</div>
    </div>

    <div id="flow" class="diagram-container">
      <h2>User Flow Diagram</h2>
      <div class="mermaid">
$flow_mermaid
      </div>
      <div class="timestamp">Primary user journeys through the application</div>
    </div>

    <div id="seq" class="diagram-container">
      <h2>API Sequence Diagram</h2>
      <div class="mermaid">
$seq_mermaid
      </div>
      <div class="timestamp">Request/response flow for key operations</div>
    </div>

    <div id="journey" class="diagram-container">
      <h2>User Journey Diagram</h2>
      <div class="mermaid">
$journey_mermaid
      </div>
      <div class="timestamp">Primary user workflows with satisfaction scores (1-5)</div>
    </div>
  </div>

  <script>
    mermaid.initialize({
      startOnLoad: true,
      theme: 'default',
      flowchart: { useMaxWidth: true, htmlLabels: true, curve: 'basis' },
      sequence: { useMaxWidth: true, showSequenceNumbers: true },
      er: { useMaxWidth: true },
      journey: { useMaxWidth: true }
    });

    function showTab(tabId) {
      // Update tabs
      document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
      event.target.classList.add('active');

      // Update content
      document.querySelectorAll('.diagram-container').forEach(d => d.classList.remove('active'));
      document.getElementById(tabId).classList.add('active');
    }
  </script>
</body>
</html>
HTMLEOF

  log "HTML diagram suite generated: $html_file"
}

# Main execution
main() {
  cd "$PROJECT_ROOT"

  # Check cache first
  if check_cache && [ -f "$CACHE_DIR/repo-diagrams.md" ]; then
    log "Using cached diagram suite"

    # Copy to output if different
    if [ "$OUTPUT_DIR" != "$CACHE_DIR" ]; then
      cp "$CACHE_DIR/repo-diagrams.md" "$OUTPUT_DIR/repo-diagrams.md"
      if [ -f "$CACHE_DIR/repo-diagrams.html" ]; then
        cp "$CACHE_DIR/repo-diagrams.html" "$OUTPUT_DIR/repo-diagrams.html"
      fi
    fi

    cat "$CACHE_DIR/repo-diagrams.md"
    exit 0
  fi

  log "Generating comprehensive diagram suite..."
  log "This includes: Architecture, ERD, User Flows, API Sequence"

  local result
  result=$(generate_diagrams)

  # Save markdown
  echo "$result" > "$CACHE_DIR/repo-diagrams.md"

  # Copy to output dir if different
  if [ "$OUTPUT_DIR" != "$CACHE_DIR" ]; then
    echo "$result" > "$OUTPUT_DIR/repo-diagrams.md"
  fi

  # Generate HTML
  generate_html "$CACHE_DIR/repo-diagrams.md" "$CACHE_DIR/repo-diagrams.html" "Repository Diagram Suite"

  if [ "$OUTPUT_DIR" != "$CACHE_DIR" ]; then
    cp "$CACHE_DIR/repo-diagrams.html" "$OUTPUT_DIR/repo-diagrams.html"
  fi

  log "Diagram suite saved to $OUTPUT_DIR/repo-diagrams.md"
  log "HTML version: $OUTPUT_DIR/repo-diagrams.html"

  echo "$result"
}

main "$@"
