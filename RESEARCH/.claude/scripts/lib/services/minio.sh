#!/bin/bash
# MinIO service setup functions
# Deploy via kubectl, expose, and configure credentials

# MinIO configuration
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001
MINIO_ADMIN_USER="admin"
MINIO_ADMIN_PASSWORD="adminadmin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Deploy MinIO via kubectl
# Usage: deploy_minio <namespace> <project>
deploy_minio() {
  local namespace=$1
  local project=$2

  log_info "Deploying MinIO..."

  # Check if already deployed
  if kubectl get deployment minio -n "$namespace" &>/dev/null; then
    log_skip "MinIO already deployed"
    return 0
  fi

  # Apply MinIO manifest
  local minio_yaml="$PROJECT_ROOT/.claude/k8s/minio.yaml"
  if [[ ! -f "$minio_yaml" ]]; then
    log_error "MinIO manifest not found: $minio_yaml"
    return 1
  fi

  if kubectl apply -f "$minio_yaml" -n "$namespace"; then
    log_success "MinIO deployed"
  else
    log_error "MinIO deployment failed"
    return 1
  fi
}

# Wait for MinIO to be ready
# Usage: wait_for_minio <namespace>
wait_for_minio() {
  local namespace=$1

  log_info "Waiting for MinIO..."

  if wait_for_deployment "minio" "$namespace" 120; then
    log_success "MinIO is ready"
  else
    log_error "MinIO failed to become ready"
    return 1
  fi
}

# Initialize MinIO (create bucket, user, policy)
# Usage: init_minio <host> <port> <namespace> <project>
init_minio() {
  local host=$1
  local port=$2
  local namespace=$3
  local project=$4

  local bucket_name="$project"
  local policy_name="${project}-readwrite"
  local mc_alias="ccpm-minio-${namespace}"
  local endpoint="http://${host}:${port}"

  log_info "Initializing MinIO (bucket: $bucket_name)..."

  # Generate credentials
  local access_key
  local secret_key
  access_key=$(openssl rand -base64 15 | tr -dc 'a-zA-Z0-9' | cut -c1-20)
  secret_key=$(openssl rand -base64 30 | tr -dc 'a-zA-Z0-9' | cut -c1-40)

  # Configure mc alias
  mc alias remove "$mc_alias" 2>/dev/null || true
  if ! mc alias set "$mc_alias" "$endpoint" "$MINIO_ADMIN_USER" "$MINIO_ADMIN_PASSWORD" 2>/dev/null; then
    log_error "Failed to configure mc alias"
    return 1
  fi

  # Create bucket if it doesn't exist
  if ! mc ls "$mc_alias/$bucket_name" >/dev/null 2>&1; then
    if mc mb "$mc_alias/$bucket_name" 2>/dev/null; then
      log_success "Created bucket: $bucket_name"
    else
      log_error "Failed to create bucket"
      mc alias remove "$mc_alias" 2>/dev/null || true
      return 1
    fi
  else
    log_skip "Bucket exists: $bucket_name"
  fi

  # Create policy
  local policy_file="/tmp/${namespace}-policy.json"
  cat > "$policy_file" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::${bucket_name}",
        "arn:aws:s3:::${bucket_name}/*"
      ]
    }
  ]
}
EOF

  # Remove existing policy if present
  if mc admin policy info "$mc_alias" "$policy_name" >/dev/null 2>&1; then
    mc admin policy remove "$mc_alias" "$policy_name" 2>/dev/null || true
  fi

  # Create policy
  if mc admin policy create "$mc_alias" "$policy_name" "$policy_file" 2>/dev/null; then
    log_success "Created policy: $policy_name"
  else
    log_error "Failed to create policy"
    rm -f "$policy_file"
    mc alias remove "$mc_alias" 2>/dev/null || true
    return 1
  fi

  # Create user
  if mc admin user add "$mc_alias" "$access_key" "$secret_key" 2>/dev/null; then
    log_success "Created MinIO user"
  else
    log_error "Failed to create user"
    rm -f "$policy_file"
    mc alias remove "$mc_alias" 2>/dev/null || true
    return 1
  fi

  # Attach policy to user
  if mc admin policy attach "$mc_alias" "$policy_name" --user "$access_key" 2>/dev/null; then
    log_success "Attached policy to user"
  else
    log_error "Failed to attach policy"
    rm -f "$policy_file"
    mc alias remove "$mc_alias" 2>/dev/null || true
    return 1
  fi

  # Cleanup
  rm -f "$policy_file"
  mc alias remove "$mc_alias" 2>/dev/null || true

  # Store credentials for output function
  export MINIO_ACCESS_KEY="$access_key"
  export MINIO_SECRET_KEY="$secret_key"
  export MINIO_BUCKET="$bucket_name"

  log_success "MinIO initialized"
}

# Get MinIO credentials and output for .env
# Usage: output_minio_credentials <api_host> <api_port> <console_host> <console_port> <namespace> <project>
output_minio_credentials() {
  local api_host=$1
  local api_port=$2
  local console_host=$3
  local console_port=$4
  local namespace=$5
  local project=$6

  local api_endpoint="http://${api_host}:${api_port}"
  local console_url="http://${console_host}:${console_port}"
  local bucket_name="$project"

  # Use credentials from init_minio (exported env vars)
  local access_key="${MINIO_ACCESS_KEY:-}"
  local secret_key="${MINIO_SECRET_KEY:-}"

  if [[ -z "$access_key" ]] || [[ -z "$secret_key" ]]; then
    # Try to get from existing secret
    access_key=$(get_secret_value "minio-credentials" "$namespace" "AWS_ACCESS_KEY_ID")
    secret_key=$(get_secret_value "minio-credentials" "$namespace" "AWS_SECRET_ACCESS_KEY")
  fi

  if [[ -z "$access_key" ]] || [[ -z "$secret_key" ]]; then
    log_error "Could not retrieve MinIO credentials"
    return 1
  fi

  # Store in standardized credentials secret with BOTH URLs
  store_secret "minio-credentials" "$namespace" \
    "MINIO_ENDPOINT=$api_endpoint" \
    "MINIO_CONSOLE_URL=$console_url" \
    "MINIO_BUCKET=$bucket_name" \
    "AWS_ACCESS_KEY_ID=$access_key" \
    "AWS_SECRET_ACCESS_KEY=$secret_key" \
    "MINIO_ACCESS_KEY=$access_key" \
    "MINIO_SECRET_KEY=$secret_key" \
    "S3_REGION=us-east-1" \
    "S3_FORCE_PATH_STYLE=true"

  log_success "Stored minio-credentials secret"

  # Output for .env (to stdout)
  echo "MINIO_ENDPOINT=$api_endpoint"
  echo "MINIO_CONSOLE_URL=$console_url"
  echo "MINIO_BUCKET=$bucket_name"
  echo "MINIO_ACCESS_KEY=$access_key"
  echo "MINIO_SECRET_KEY=$secret_key"
}

# Main MinIO setup function
# Usage: setup_minio <namespace> <project> <expose_mode>
setup_minio() {
  local namespace=$1
  local project=$2
  local expose_mode=$3

  # Check if credentials already exist
  if secret_exists "minio-credentials" "$namespace"; then
    log_skip "MinIO credentials already exist"

    # Still need to output existing credentials
    local access_key secret_key endpoint console_url bucket
    access_key=$(get_secret_value "minio-credentials" "$namespace" "AWS_ACCESS_KEY_ID")
    secret_key=$(get_secret_value "minio-credentials" "$namespace" "AWS_SECRET_ACCESS_KEY")
    endpoint=$(get_secret_value "minio-credentials" "$namespace" "MINIO_ENDPOINT")
    console_url=$(get_secret_value "minio-credentials" "$namespace" "MINIO_CONSOLE_URL")
    bucket=$(get_secret_value "minio-credentials" "$namespace" "MINIO_BUCKET")

    # If no endpoint in secret, need to expose and update
    if [[ -z "$endpoint" ]]; then
      endpoint=$(get_secret_value "minio-credentials" "$namespace" "S3_EXTERNAL_ENDPOINT")
    fi

    # Also try legacy MINIO_ACCESS_KEY/MINIO_SECRET_KEY keys
    if [[ -z "$access_key" ]]; then
      access_key=$(get_secret_value "minio-credentials" "$namespace" "MINIO_ACCESS_KEY")
    fi
    if [[ -z "$secret_key" ]]; then
      secret_key=$(get_secret_value "minio-credentials" "$namespace" "MINIO_SECRET_KEY")
    fi

    echo "MINIO_ENDPOINT=$endpoint"
    echo "MINIO_CONSOLE_URL=${console_url:-}"
    echo "MINIO_BUCKET=${bucket:-$project}"
    echo "MINIO_ACCESS_KEY=$access_key"
    echo "MINIO_SECRET_KEY=$secret_key"
    return 0
  fi

  # Deploy
  deploy_minio "$namespace" "$project" || return 1

  # Wait
  wait_for_minio "$namespace" || return 1

  # Expose API port
  log_info "Exposing MinIO API ($expose_mode)..."
  local api_host_port
  api_host_port=$(expose_service "minio" "$namespace" "$MINIO_PORT" "$expose_mode")
  local api_host="${api_host_port%:*}"
  local api_port="${api_host_port#*:}"
  log_success "MinIO API exposed at $api_host:$api_port"

  # Expose Console port
  log_info "Exposing MinIO Console ($expose_mode)..."
  local console_host_port
  console_host_port=$(expose_service "minio" "$namespace" "$MINIO_CONSOLE_PORT" "$expose_mode")
  local console_host="${console_host_port%:*}"
  local console_port="${console_host_port#*:}"
  log_success "MinIO Console exposed at $console_host:$console_port"

  # Initialize (create bucket, user, policy) using API endpoint
  init_minio "$api_host" "$api_port" "$namespace" "$project" || return 1

  # Output credentials with both endpoints
  output_minio_credentials "$api_host" "$api_port" "$console_host" "$console_port" "$namespace" "$project"
}
