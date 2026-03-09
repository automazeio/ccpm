#!/bin/bash
# create-interview-schema.sh - Create PostgreSQL schema for interrogation data
#
# Usage:
#   ./create-interview-schema.sh              # Uses default credentials
#   POSTGRES_PASSWORD=xxx ./create-interview-schema.sh   # With explicit password
#
# Prerequisites:
#   - PostgreSQL database must be running
#   - Credentials in .env or K8s secrets
#   - .claude/schemas/interview_schema.sql must exist

set -e

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
NAMESPACE="${NAMESPACE:-$(basename "$PROJECT_ROOT")}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Creating Interview Database Schema ==="
echo ""

# Load credentials from .env if it exists
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo "Loading credentials from .env..."
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# Try to get credentials from K8s if not in .env
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "Attempting to get credentials from Kubernetes..."
    POSTGRES_PASSWORD=$(kubectl get secret postgres-credentials -n "$NAMESPACE" \
        -o jsonpath='{.data.POSTGRES_PASSWORD}' 2>/dev/null | base64 -d || echo "")
fi

# Set defaults
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_DB="${POSTGRES_DB:-$NAMESPACE}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"

if [ -z "$POSTGRES_PASSWORD" ]; then
    echo -e "${YELLOW}Warning: No POSTGRES_PASSWORD found${NC}"
    echo "Will attempt connection without password (may fail)"
fi

echo "Database: $POSTGRES_DB@$POSTGRES_HOST:$POSTGRES_PORT"
echo ""

# Check if schema file exists
SCHEMA_FILE="$PROJECT_ROOT/.claude/schemas/interview_schema.sql"
if [ ! -f "$SCHEMA_FILE" ]; then
    echo -e "${RED}Error: Schema file not found: $SCHEMA_FILE${NC}"
    exit 1
fi

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL..."
MAX_RETRIES=30
RETRY_COUNT=0
while ! PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1" > /dev/null 2>&1; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo -e "${RED}Error: PostgreSQL not ready after $MAX_RETRIES attempts${NC}"
        exit 1
    fi
    echo "  Waiting... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
done
echo -e "${GREEN}PostgreSQL is ready${NC}"
echo ""

# Check if schema already exists (check for v3 schema's 'journey_steps_detailed' table)
EXISTING_V3=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'journey_steps_detailed'" 2>/dev/null | tr -d ' ')

# Check for old 16-table schema
OLD_SCHEMA=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'interrogation_sessions'" 2>/dev/null | tr -d ' ')

# Check for v2 7-table schema (has journey_step but not journey_steps_detailed)
V2_SCHEMA=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'journey_step'" 2>/dev/null | tr -d ' ')

if [ "$OLD_SCHEMA" -gt 0 ] 2>/dev/null; then
    echo -e "${YELLOW}Old 16-table schema detected. Migrating to v3.1 (10-table design)...${NC}"
    echo "  (Old tables will be dropped)"
    echo ""
fi

if [ "$V2_SCHEMA" -gt 0 ] 2>/dev/null && [ "$EXISTING_V3" -eq 0 ] 2>/dev/null; then
    echo -e "${YELLOW}v2.0 (7-table) schema detected. Migrating to v3.1 (10-table design)...${NC}"
    echo "  (Old tables will be dropped)"
    echo ""
fi

# Check for integration_credentials (v3.1 indicator)
V31_INDICATOR=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'integration_credentials'" 2>/dev/null | tr -d ' ')

if [ "$EXISTING_V3" -gt 0 ] 2>/dev/null && [ "$V31_INDICATOR" -gt 0 ] 2>/dev/null; then
    echo -e "${YELLOW}Schema v3.1 already exists${NC}"
    echo -e "${GREEN}Schema is current${NC}"
elif [ "$EXISTING_V3" -gt 0 ] 2>/dev/null && [ "$V31_INDICATOR" -eq 0 ] 2>/dev/null; then
    echo -e "${YELLOW}Upgrading from v3.0 to v3.1 (adding integration_credentials)...${NC}"
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
        -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$SCHEMA_FILE"
    echo -e "${GREEN}Schema upgraded successfully${NC}"
else
    echo "Creating schema v3.1 (10-table hybrid design)..."
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
        -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$SCHEMA_FILE"
    echo -e "${GREEN}Schema created successfully${NC}"
fi

# Verify tables exist
echo ""
echo "Verifying schema..."
TABLES=(
    "feature"
    "page"
    "journey"
    "journey_steps_detailed"
    "conversation"
    "conversation_feature"
    "database_entities"
    "technical_components"
    "step_component_mapping"
    "integration_credentials"
)

MISSING=0
for TABLE in "${TABLES[@]}"; do
    EXISTS=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
        -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = '$TABLE'" 2>/dev/null | tr -d ' ')
    if [ "$EXISTS" -eq 0 ] 2>/dev/null; then
        echo -e "  ${RED}x $TABLE${NC}"
        MISSING=$((MISSING + 1))
    else
        echo -e "  ${GREEN}v $TABLE${NC}"
    fi
done

echo ""
if [ $MISSING -eq 0 ]; then
    echo -e "${GREEN}Interview schema verified: ${#TABLES[@]} tables${NC}"

    # Show views
    echo ""
    echo "Views created:"
    VIEWS=(
        "journey_full_view"
        "feature_discovery_view"
        "step_components_view"
        "entity_usage_view"
    )
    for VIEW in "${VIEWS[@]}"; do
        EXISTS=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
            -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c \
            "SELECT COUNT(*) FROM information_schema.views WHERE table_name = '$VIEW'" 2>/dev/null | tr -d ' ')
        if [ "$EXISTS" -gt 0 ] 2>/dev/null; then
            echo -e "  ${GREEN}v $VIEW${NC}"
        fi
    done

    echo ""
    echo -e "${GREEN}Interview schema ready${NC}"
else
    echo -e "${RED}Missing $MISSING tables${NC}"
    exit 1
fi
