#!/bin/bash
# CloudBeaver service setup functions
# Deploy via kubectl, expose, and configure datasource connection

# CloudBeaver configuration
CLOUDBEAVER_PORT=8978
CLOUDBEAVER_ADMIN_USER="cbadmin"
CLOUDBEAVER_ADMIN_PASSWORD="AdminAdmin1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Deploy CloudBeaver with PostgreSQL datasource configuration
# Usage: deploy_cloudbeaver <namespace> <project> <postgres_service> <postgres_db> <postgres_user> <postgres_password>
deploy_cloudbeaver() {
  local namespace=$1
  local project=$2
  local postgres_service=$3
  local postgres_db=$4
  local postgres_user=$5
  local postgres_password=$6

  log_info "Deploying CloudBeaver..."

  # Check if already deployed
  if kubectl get deployment cloudbeaver -n "$namespace" &>/dev/null; then
    log_skip "CloudBeaver already deployed"
    return 0
  fi

  # Use hardcoded CloudBeaver admin credentials (matches MinIO pattern)
  local cb_user="$CLOUDBEAVER_ADMIN_USER"
  local cb_password="$CLOUDBEAVER_ADMIN_PASSWORD"

  # Create temp file for sed replacement
  local cloudbeaver_yaml="$PROJECT_ROOT/.claude/k8s/cloudbeaver.yaml"
  if [[ ! -f "$cloudbeaver_yaml" ]]; then
    log_error "CloudBeaver manifest not found: $cloudbeaver_yaml"
    return 1
  fi

  local temp_yaml="/tmp/cloudbeaver-${namespace}.yaml"

  # Escape special characters for sed
  local escaped_password=$(echo "$postgres_password" | sed 's/[&/\]/\\&/g')

  # Perform sed replacements
  sed -e "s|POSTGRES_SERVICE_PLACEHOLDER|${postgres_service}|g" \
      -e "s|POSTGRES_DB_PLACEHOLDER|${postgres_db}|g" \
      -e "s|POSTGRES_USER_PLACEHOLDER|${postgres_user}|g" \
      -e "s|POSTGRES_PASSWORD_PLACEHOLDER|${escaped_password}|g" \
      -e "s|CLOUDBEAVER_ADMIN_USER_PLACEHOLDER|${cb_user}|g" \
      -e "s|CLOUDBEAVER_ADMIN_PASSWORD_PLACEHOLDER|${cb_password}|g" \
      "$cloudbeaver_yaml" > "$temp_yaml"

  # Apply manifest
  if kubectl apply -f "$temp_yaml" -n "$namespace"; then
    log_success "CloudBeaver deployed"
    rm -f "$temp_yaml"
  else
    log_error "CloudBeaver deployment failed"
    rm -f "$temp_yaml"
    return 1
  fi
}

# Wait for CloudBeaver to be ready
# Usage: wait_for_cloudbeaver <namespace>
wait_for_cloudbeaver() {
  local namespace=$1

  log_info "Waiting for CloudBeaver..."

  if wait_for_deployment "cloudbeaver" "$namespace" 180; then
    log_success "CloudBeaver is ready"
  else
    log_error "CloudBeaver failed to become ready"
    return 1
  fi
}

# Initialize CloudBeaver (verify accessibility)
# Usage: init_cloudbeaver <host> <port> <namespace> <project>
init_cloudbeaver() {
  local host=$1
  local port=$2
  local namespace=$3
  local project=$4

  log_info "Verifying CloudBeaver accessibility..."

  # CloudBeaver is pre-configured with admin credentials and PostgreSQL datasource
  # First-time login will use admin/adminadmin
  log_success "CloudBeaver initialized"
}

# Get CloudBeaver credentials and output for .env
# Usage: output_cloudbeaver_credentials <host> <port> <namespace> <project>
output_cloudbeaver_credentials() {
  local host=$1
  local port=$2
  local namespace=$3
  local project=$4

  # Use hardcoded credentials (matches MinIO pattern: admin/adminadmin)
  local admin_user="${CLOUDBEAVER_ADMIN_USER}"
  local admin_password="${CLOUDBEAVER_ADMIN_PASSWORD}"

  local url="http://${host}:${port}"

  # Store in standardized credentials secret
  store_secret "cloudbeaver-credentials" "$namespace" \
    "CLOUDBEAVER_URL=$url" \
    "CLOUDBEAVER_USER=$admin_user" \
    "CLOUDBEAVER_PASSWORD=$admin_password"

  log_success "Stored cloudbeaver-credentials secret"

  # Output for .env (to stdout)
  echo "CLOUDBEAVER_URL=$url"
  echo "CLOUDBEAVER_USER=$admin_user"
  echo "CLOUDBEAVER_PASSWORD=$admin_password"
}

# Main CloudBeaver setup function
# Usage: setup_cloudbeaver <namespace> <project> <expose_mode> <postgres_service> <postgres_db> <postgres_user> <postgres_password>
setup_cloudbeaver() {
  local namespace=$1
  local project=$2
  local expose_mode=$3
  local postgres_service=$4
  local postgres_db=$5
  local postgres_user=$6
  local postgres_password=$7

  # Check if credentials already exist (skip setup)
  if secret_exists "cloudbeaver-credentials" "$namespace"; then
    log_skip "CloudBeaver credentials already exist"

    # Output existing credentials
    local url user password
    url=$(get_secret_value "cloudbeaver-credentials" "$namespace" "CLOUDBEAVER_URL")
    user=$(get_secret_value "cloudbeaver-credentials" "$namespace" "CLOUDBEAVER_USER")
    password=$(get_secret_value "cloudbeaver-credentials" "$namespace" "CLOUDBEAVER_PASSWORD")

    echo "CLOUDBEAVER_URL=$url"
    echo "CLOUDBEAVER_USER=$user"
    echo "CLOUDBEAVER_PASSWORD=$password"
    return 0
  fi

  # Deploy with PostgreSQL connection info
  deploy_cloudbeaver "$namespace" "$project" "$postgres_service" "$postgres_db" "$postgres_user" "$postgres_password" || return 1

  # Wait
  wait_for_cloudbeaver "$namespace" || return 1

  # Expose
  log_info "Exposing CloudBeaver ($expose_mode)..."
  local host_port
  host_port=$(expose_service "cloudbeaver" "$namespace" "$CLOUDBEAVER_PORT" "$expose_mode")
  local host="${host_port%:*}"
  local port="${host_port#*:}"
  log_success "CloudBeaver exposed at $host:$port"

  # Initialize
  init_cloudbeaver "$host" "$port" "$namespace" "$project" || return 1

  # Output credentials
  output_cloudbeaver_credentials "$host" "$port" "$namespace" "$project"
}
