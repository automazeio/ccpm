#!/bin/bash
# Setup environment from Kubernetes secrets
# This script pulls secrets from the project namespace and populates .env file

set -e

# Default namespace to current directory name (project name)
NAMESPACE="${NAMESPACE:-$(basename "$(pwd)")}"
ENV_FILE="${ENV_FILE:-.env}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Use current working directory as project directory (not script's parent)
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"

echo "🔧 Setting up .env from Kubernetes secrets..."
echo "   Namespace: $NAMESPACE"
echo "   Target: $PROJECT_DIR/$ENV_FILE"

# Backup .env before making changes
backup_env() {
    if [ -f "$PROJECT_DIR/$ENV_FILE" ]; then
        local backup_file="$PROJECT_DIR/$ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$PROJECT_DIR/$ENV_FILE" "$backup_file"
        echo "   💾 Backup created: $(basename $backup_file)"

        # Clean old backups (keep last 5)
        ls -t "$PROJECT_DIR/$ENV_FILE.backup."* 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
    fi
}

# Create .env from example if it doesn't exist
if [ ! -f "$PROJECT_DIR/$ENV_FILE" ]; then
    echo "   Creating $ENV_FILE from .env.example..."
    if [ -f "$PROJECT_DIR/.env.example" ]; then
        cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/$ENV_FILE"
    else
        # Create minimal .env if no example exists
        touch "$PROJECT_DIR/$ENV_FILE"
    fi
else
    # Backup existing .env
    backup_env
fi

# Function to get secret value from k8s
get_secret() {
    local secret_name=$1
    local key=$2
    kubectl get secret "$secret_name" -n "$NAMESPACE" -o jsonpath="{.data.$key}" 2>/dev/null | base64 -d || echo ""
}

# Function to update or add env var in .env file
update_env_var() {
    local key=$1
    local value=$2

    if [ -z "$value" ]; then
        echo "   ⚠️  Skipping $key (secret not found)"
        return
    fi

    # Escape special characters for sed (but not forward slashes in URLs)
    local escaped_value=$(echo "$value" | sed 's/[&\\]/\\&/g')

    if grep -q "^${key}=" "$PROJECT_DIR/$ENV_FILE"; then
        # Update existing - use different delimiter to avoid issues with URLs
        sed -i "s|^${key}=.*|${key}=${escaped_value}|" "$PROJECT_DIR/$ENV_FILE"
        echo "   ✅ Updated $key"
    else
        # Add new - direct write to avoid escaping issues
        echo "${key}=${value}" >> "$PROJECT_DIR/$ENV_FILE"
        echo "   ✅ Added $key"
    fi
}

# Pull Tavily API key from project namespace (if it exists)
echo ""
echo "📡 Fetching API keys from secrets..."
TAVILY_KEY=$(kubectl get secret "tavily-api-key" -n "$NAMESPACE" -o jsonpath="{.data.TAVILY_API_KEY}" 2>/dev/null | base64 -d || echo "")
if [ -n "$TAVILY_KEY" ]; then
    update_env_var "TAVILY_API_KEY" "$TAVILY_KEY"
fi

# Pull PostgreSQL credentials from standardized secret (includes NodePort info)
echo ""
echo "🗄️  Fetching PostgreSQL credentials..."
POSTGRES_HOST=$(get_secret "postgres-credentials" "POSTGRES_HOST")
POSTGRES_PORT=$(get_secret "postgres-credentials" "POSTGRES_PORT")
POSTGRES_DB=$(get_secret "postgres-credentials" "POSTGRES_DB")
POSTGRES_USER=$(get_secret "postgres-credentials" "POSTGRES_USER")
POSTGRES_PASSWORD=$(get_secret "postgres-credentials" "POSTGRES_PASSWORD")

if [ -n "$POSTGRES_HOST" ]; then
    update_env_var "POSTGRES_HOST" "$POSTGRES_HOST"
    update_env_var "POSTGRES_PORT" "${POSTGRES_PORT:-5432}"
    update_env_var "POSTGRES_DB" "${POSTGRES_DB:-$NAMESPACE}"
    update_env_var "POSTGRES_USER" "${POSTGRES_USER:-postgres}"
    update_env_var "POSTGRES_PASSWORD" "$POSTGRES_PASSWORD"
else
    # Fallback to Helm secret if standardized secret doesn't exist
    HELM_SECRET="${NAMESPACE}-postgresql"
    POSTGRES_HOST=$(get_secret "$HELM_SECRET" "host")
    POSTGRES_PASSWORD=$(get_secret "$HELM_SECRET" "password")

    if [ -n "$POSTGRES_HOST" ]; then
        update_env_var "POSTGRES_HOST" "$POSTGRES_HOST"
    fi
    if [ -n "$POSTGRES_PASSWORD" ]; then
        update_env_var "POSTGRES_PASSWORD" "$POSTGRES_PASSWORD"
    fi
    # Set default values if not from secret
    update_env_var "POSTGRES_PORT" "5432"
    update_env_var "POSTGRES_DB" "$NAMESPACE"
    update_env_var "POSTGRES_USER" "postgres"
fi

# Pull MinIO credentials from standardized secret (includes NodePort info)
echo ""
echo "🪣 Fetching MinIO credentials..."
MINIO_ENDPOINT=$(get_secret "minio-credentials" "MINIO_ENDPOINT")
MINIO_CONSOLE_URL=$(get_secret "minio-credentials" "MINIO_CONSOLE_URL")
MINIO_BUCKET=$(get_secret "minio-credentials" "MINIO_BUCKET")
MINIO_ACCESS_KEY=$(get_secret "minio-credentials" "MINIO_ACCESS_KEY")
MINIO_SECRET_KEY=$(get_secret "minio-credentials" "MINIO_SECRET_KEY")

if [ -n "$MINIO_ENDPOINT" ]; then
    update_env_var "MINIO_ENDPOINT" "$MINIO_ENDPOINT"
    if [ -n "$MINIO_CONSOLE_URL" ]; then
        update_env_var "MINIO_CONSOLE_URL" "$MINIO_CONSOLE_URL"
    fi
    update_env_var "MINIO_BUCKET" "${MINIO_BUCKET:-$NAMESPACE}"
    if [ -n "$MINIO_ACCESS_KEY" ]; then
        update_env_var "MINIO_ACCESS_KEY" "$MINIO_ACCESS_KEY"
    fi
    if [ -n "$MINIO_SECRET_KEY" ]; then
        update_env_var "MINIO_SECRET_KEY" "$MINIO_SECRET_KEY"
    fi
else
    # Fallback to legacy keys if standardized secret doesn't exist
    MINIO_ENDPOINT=$(get_secret "minio-credentials" "endpoint")
    MINIO_ACCESS_KEY=$(get_secret "minio-credentials" "accesskey")
    MINIO_SECRET_KEY=$(get_secret "minio-credentials" "secretkey")

    if [ -n "$MINIO_ENDPOINT" ]; then
        update_env_var "MINIO_ENDPOINT" "$MINIO_ENDPOINT"
    fi
    if [ -n "$MINIO_ACCESS_KEY" ]; then
        update_env_var "MINIO_ACCESS_KEY" "$MINIO_ACCESS_KEY"
    fi
    if [ -n "$MINIO_SECRET_KEY" ]; then
        update_env_var "MINIO_SECRET_KEY" "$MINIO_SECRET_KEY"
    fi
    update_env_var "MINIO_BUCKET" "development"
fi

# Set project metadata
echo ""
echo "📦 Setting project metadata..."
update_env_var "PROJECT_NAME" "$NAMESPACE"
update_env_var "NAMESPACE" "$NAMESPACE"

# Pull CloudBeaver credentials (if deployed)
echo ""
echo "🗄️  Fetching CloudBeaver credentials (if available)..."
CLOUDBEAVER_URL=$(get_secret "cloudbeaver-credentials" "CLOUDBEAVER_URL")
CLOUDBEAVER_USER=$(get_secret "cloudbeaver-credentials" "CLOUDBEAVER_USER")
CLOUDBEAVER_PASSWORD=$(get_secret "cloudbeaver-credentials" "CLOUDBEAVER_PASSWORD")

if [ -n "$CLOUDBEAVER_URL" ]; then
    update_env_var "CLOUDBEAVER_URL" "$CLOUDBEAVER_URL"
    if [ -n "$CLOUDBEAVER_USER" ]; then
        update_env_var "CLOUDBEAVER_USER" "$CLOUDBEAVER_USER"
    fi
    if [ -n "$CLOUDBEAVER_PASSWORD" ]; then
        update_env_var "CLOUDBEAVER_PASSWORD" "$CLOUDBEAVER_PASSWORD"
    fi
fi

# Validate required variables are present
validate_env() {
    local required_vars=("PROJECT_NAME" "NAMESPACE")
    local missing=()

    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=.\\+" "$PROJECT_DIR/$ENV_FILE" 2>/dev/null; then
            missing+=("$var")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "   ❌ Missing required variables: ${missing[*]}"
        return 1
    fi

    echo "   ✅ All required variables present"
    return 0
}

echo ""
echo "✨ Environment setup complete!"
echo "   File: $PROJECT_DIR/$ENV_FILE"
echo ""
echo "🔐 Secrets loaded from Kubernetes:"
echo "   - postgres-credentials or ${NAMESPACE}-postgresql (POSTGRES_*)"
echo "   - minio-credentials (MINIO_ENDPOINT, MINIO_ACCESS_KEY, MINIO_SECRET_KEY)"
echo "   - cloudbeaver-credentials (CLOUDBEAVER_URL, CLOUDBEAVER_USER, CLOUDBEAVER_PASSWORD)"
echo ""

# Validate .env file
validate_env

echo ""
echo "💡 To reload secrets, run: $0"
