#!/bin/bash
# deploy.sh - Deploy CCPM Infrastructure Service to Kubernetes
#
# Usage:
#   ./deploy.sh                    # Full deploy (build + K8s)
#   ./deploy.sh --skip-build       # K8s only, use existing images
#   ./deploy.sh --dry-run          # Show what would be done

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="ccpm-infra"
REGISTRY="${REGISTRY:-ubuntu.desmana-truck.ts.net:30500}"
NAMESPACE="ccpm-infra"
K8S_DIR="$SCRIPT_DIR/k8s"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
SKIP_BUILD=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

log() {
    echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

# Check prerequisites
check_prereqs() {
    log "Checking prerequisites..."

    if ! command -v docker &> /dev/null; then
        error "docker not found"
        exit 1
    fi

    if ! command -v kubectl &> /dev/null; then
        error "kubectl not found"
        exit 1
    fi

    # Check kubectl connectivity
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster"
        exit 1
    fi

    success "Prerequisites OK"
}

# Build and push Docker image
build_image() {
    if [[ "$SKIP_BUILD" == "true" ]]; then
        log "Skipping image build (--skip-build)"
        return 0
    fi

    log "Building Docker image..."

    local full_image="$REGISTRY/$IMAGE_NAME:latest"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  Would run: docker build -t $full_image $SCRIPT_DIR"
        echo "  Would run: docker push $full_image"
        return 0
    fi

    docker build -t "$full_image" "$SCRIPT_DIR"
    success "Image built: $full_image"

    log "Pushing image to registry..."
    docker push "$full_image"
    success "Image pushed"
}

# Create namespace
create_namespace() {
    log "Creating namespace..."

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  Would run: kubectl apply -f $K8S_DIR/namespace.yaml"
        return 0
    fi

    kubectl apply -f "$K8S_DIR/namespace.yaml"
    success "Namespace created/updated"
}

# Apply secrets
apply_secrets() {
    log "Applying secrets..."

    # Check for required environment variables
    if [[ -z "${WEBHOOK_SECRET:-}" ]]; then
        warn "WEBHOOK_SECRET not set, using placeholder"
    fi

    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        warn "GITHUB_TOKEN not set, using placeholder"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  Would substitute and apply secrets"
        return 0
    fi

    # Substitute environment variables and apply
    envsubst < "$K8S_DIR/secret.yaml" | kubectl apply -f -
    success "Secrets applied"
}

# Apply configmap
apply_configmap() {
    log "Applying configmap..."

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  Would run: kubectl apply -f $K8S_DIR/configmap.yaml"
        return 0
    fi

    kubectl apply -f "$K8S_DIR/configmap.yaml"
    success "ConfigMap applied"
}

# Apply deployment and services
apply_manifests() {
    log "Applying deployment manifests..."

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  Would run: kubectl apply -f $K8S_DIR/deployment.yaml"
        echo "  Would run: kubectl apply -f $K8S_DIR/service.yaml"
        echo "  Would run: kubectl apply -f $K8S_DIR/ingress.yaml"
        return 0
    fi

    kubectl apply -f "$K8S_DIR/deployment.yaml"
    kubectl apply -f "$K8S_DIR/service.yaml"
    kubectl apply -f "$K8S_DIR/ingress.yaml" 2>/dev/null || warn "Ingress not applied (may not be supported)"
    success "Manifests applied"
}

# Restart deployment to pull new image
restart_deployment() {
    log "Restarting deployment..."

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  Would run: kubectl rollout restart deployment/ccpm-infra -n $NAMESPACE"
        return 0
    fi

    kubectl rollout restart deployment/ccpm-infra -n "$NAMESPACE"
    success "Rollout restarted"
}

# Wait for rollout
wait_rollout() {
    log "Waiting for rollout to complete..."

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  Would wait for deployment to be ready"
        return 0
    fi

    if kubectl rollout status deployment/ccpm-infra -n "$NAMESPACE" --timeout=120s; then
        success "Rollout complete"
    else
        error "Rollout failed or timed out"
        kubectl get pods -n "$NAMESPACE"
        kubectl describe deployment/ccpm-infra -n "$NAMESPACE"
        exit 1
    fi
}

# Show status
show_status() {
    log "Deployment status:"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  Would show pods and services"
        return 0
    fi

    echo ""
    echo "Pods:"
    kubectl get pods -n "$NAMESPACE" -o wide

    echo ""
    echo "Services:"
    kubectl get services -n "$NAMESPACE"

    echo ""
    echo "Endpoints:"
    local nodeport=$(kubectl get svc ccpm-infra-nodeport -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
    echo "  - NodePort: http://<node-ip>:$nodeport"
    echo "  - Webhook URL: http://<node-ip>:$nodeport/webhook"
    echo "  - Health: http://<node-ip>:$nodeport/health"
}

# Main
main() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        CCPM Infrastructure Service Deployment                  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [[ "$DRY_RUN" == "true" ]]; then
        warn "DRY RUN MODE - No changes will be made"
        echo ""
    fi

    check_prereqs
    build_image
    create_namespace
    apply_secrets
    apply_configmap
    apply_manifests
    restart_deployment
    wait_rollout
    show_status

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    Deployment Complete!                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
}

main "$@"
