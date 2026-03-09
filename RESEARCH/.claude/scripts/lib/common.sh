#!/bin/bash
# Common functions for service setup
# Shared logging, waiting, and exposure functions

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${YELLOW}○${NC} $1"
}

log_success() {
  echo -e "${GREEN}✓${NC} $1"
}

log_error() {
  echo -e "${RED}✗${NC} $1" >&2
}

log_skip() {
  echo -e "– $1"
}

# Wait for a pod to be ready
# Usage: wait_for_pod <label-selector> <namespace> [timeout]
wait_for_pod() {
  local selector=$1
  local namespace=$2
  local timeout=${3:-120}

  kubectl wait --for=condition=ready pod \
    -l "$selector" \
    -n "$namespace" \
    --timeout="${timeout}s" 2>/dev/null
}

# Wait for a statefulset to be ready
# Usage: wait_for_statefulset <name> <namespace> [timeout]
wait_for_statefulset() {
  local name=$1
  local namespace=$2
  local timeout=${3:-300}

  kubectl rollout status statefulset/"$name" \
    -n "$namespace" \
    --timeout="${timeout}s" 2>/dev/null
}

# Wait for a deployment to be ready
# Usage: wait_for_deployment <name> <namespace> [timeout]
wait_for_deployment() {
  local name=$1
  local namespace=$2
  local timeout=${3:-120}

  kubectl wait --for=condition=available deployment/"$name" \
    -n "$namespace" \
    --timeout="${timeout}s" 2>/dev/null
}

# Expose a service via NodePort or port-forward
# Usage: expose_service <service> <namespace> <port> <mode>
# Returns: HOST:PORT via stdout
expose_service() {
  local service=$1
  local namespace=$2
  local port=$3
  local mode=${4:-nodeport}

  local host
  local exposed_port

  if [[ "$mode" == "nodeport" ]]; then
    # Patch service to NodePort
    kubectl patch svc "$service" -n "$namespace" \
      -p '{"spec":{"type":"NodePort"}}' >/dev/null 2>&1 || true

    # Get host IP
    host=$(hostname -I | awk '{print $1}')

    # Get assigned NodePort
    exposed_port=$(kubectl get svc "$service" -n "$namespace" \
      -o jsonpath="{.spec.ports[?(@.port==$port)].nodePort}" 2>/dev/null)

    if [[ -z "$exposed_port" ]]; then
      # Try first port if specific port not found
      exposed_port=$(kubectl get svc "$service" -n "$namespace" \
        -o jsonpath="{.spec.ports[0].nodePort}" 2>/dev/null)
    fi
  else
    # Port-forward mode
    local pid_file="/tmp/ccpm-pf-${service}-${namespace}.pid"
    local log_file="/tmp/ccpm-pf-${service}-${namespace}.log"

    # Kill existing port-forward if running
    if [[ -f "$pid_file" ]]; then
      local old_pid
      old_pid=$(cat "$pid_file")
      kill "$old_pid" 2>/dev/null || true
      rm -f "$pid_file"
    fi

    # Start port-forward in background with nohup to survive script exit
    nohup kubectl port-forward "svc/$service" -n "$namespace" \
      "$port:$port" >"$log_file" 2>&1 &
    local pf_pid=$!
    echo $pf_pid > "$pid_file"

    # Disown to fully detach from parent shell
    disown $pf_pid 2>/dev/null || true

    # Wait for port-forward to establish and verify it's working
    local max_wait=10
    local waited=0
    while [[ $waited -lt $max_wait ]]; do
      sleep 1
      waited=$((waited + 1))
      # Check if process is still running
      if ! kill -0 $pf_pid 2>/dev/null; then
        log_error "Port-forward process died. Check $log_file"
        return 1
      fi
      # Try to connect to verify port is ready
      if nc -z localhost "$port" 2>/dev/null; then
        break
      fi
    done

    host="localhost"
    exposed_port=$port
  fi

  echo "${host}:${exposed_port}"
}

# Create or update a Kubernetes secret
# Usage: store_secret <name> <namespace> <key1=value1> [key2=value2] ...
store_secret() {
  local name=$1
  local namespace=$2
  shift 2

  # Build --from-literal arguments
  local args=()
  for kv in "$@"; do
    args+=("--from-literal=$kv")
  done

  # Delete existing secret if it exists
  kubectl delete secret "$name" -n "$namespace" 2>/dev/null || true

  # Create new secret
  kubectl create secret generic "$name" \
    -n "$namespace" \
    "${args[@]}"
}

# Generate a random password
# Usage: generate_password [length]
generate_password() {
  local length=${1:-16}
  openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c "$length"
}

# Check if a service exists
# Usage: service_exists <name> <namespace>
service_exists() {
  local name=$1
  local namespace=$2
  kubectl get svc "$name" -n "$namespace" &>/dev/null
}

# Check if a secret exists
# Usage: secret_exists <name> <namespace>
secret_exists() {
  local name=$1
  local namespace=$2
  kubectl get secret "$name" -n "$namespace" &>/dev/null
}

# Get a value from a secret
# Usage: get_secret_value <secret-name> <namespace> <key>
get_secret_value() {
  local name=$1
  local namespace=$2
  local key=$3

  local encoded
  encoded=$(kubectl get secret "$name" -n "$namespace" \
    -o jsonpath="{.data.$key}" 2>/dev/null)

  if [[ -n "$encoded" ]]; then
    echo "$encoded" | base64 -d
  fi
}

# Ensure namespace exists
# Usage: ensure_namespace <namespace>
ensure_namespace() {
  local namespace=$1

  if ! kubectl get namespace "$namespace" &>/dev/null; then
    kubectl create namespace "$namespace"
    log_success "Created namespace: $namespace"
    # Wait for namespace to be fully ready (Rancher controllers may need time)
    log_info "Waiting for namespace to be ready..."
    sleep 2
    kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/"$namespace" --timeout=30s
  else
    log_skip "Namespace exists: $namespace"
  fi
}
