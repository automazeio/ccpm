# Deploy Skeleton

Deploy the generated skeleton application to Kubernetes. Creates namespace, applies manifests, and verifies pods are running.

## Usage
```
/pm:deploy-skeleton <session-name>
```

## Arguments
- `session-name` (required): The interrogation session name

## What It Does

1. Reads generated templates from `.claude/templates/{session}/`
2. Creates namespace if not exists
3. Applies K8s manifests
4. Waits for pods to be ready
5. Verifies deployment health

## Instructions

### Step 1: Parse Arguments

```bash
SESSION="${ARGUMENTS%% *}"

if [[ -z "$SESSION" ]]; then
  echo "Usage: /pm:deploy-skeleton <session-name>"
  exit 1
fi

TEMPLATE_DIR=".claude/templates/$SESSION"
K8S_DIR="$TEMPLATE_DIR/k8s"
```

### Step 2: Verify Prerequisites

```bash
if [ ! -d "$K8S_DIR" ]; then
  echo "Error: K8s templates not found: $K8S_DIR"
  echo "Run /pm:generate-template $SESSION first."
  exit 1
fi
```

### Step 3: Check Required Manifests

Verify these files exist:
- `$K8S_DIR/namespace.yaml`
- `$K8S_DIR/backend-deployment.yaml` OR `$K8S_DIR/deployment.yaml`
- `$K8S_DIR/service.yaml`

If missing critical files, report error.

### Step 4: Apply Namespace

```bash
echo "Creating namespace: $SESSION"

if [ -f "$K8S_DIR/namespace.yaml" ]; then
  kubectl apply -f "$K8S_DIR/namespace.yaml"
else
  kubectl create namespace "$SESSION" --dry-run=client -o yaml | kubectl apply -f -
fi
```

### Step 5: Build and Push Skeleton Images (if scaffolds exist)

Check if scaffold directories exist with Dockerfiles. If they do, create a temporary
scope configuration and use the official build skill:

```bash
SCAFFOLD_DIR="$TEMPLATE_DIR/scaffold"

# Check if any Dockerfiles exist
if [ -f "$SCAFFOLD_DIR/backend/Dockerfile" ] || [ -f "$SCAFFOLD_DIR/frontend/Dockerfile" ]; then
  echo "Building skeleton images via /pm:build-deployment..."

  # Create temporary scope for skeleton build
  cat > ".claude/scopes/${SESSION}-skeleton.md" << EOF
---
name: ${SESSION}-skeleton
status: temporary
work_dir: ${SCAFFOLD_DIR}

deploy:
  enabled: true
  registry: ${REGISTRY:-ubuntu.desmana-truck.ts.net:30500}
  images:
EOF

  # Add backend if exists
  if [ -f "$SCAFFOLD_DIR/backend/Dockerfile" ]; then
    cat >> ".claude/scopes/${SESSION}-skeleton.md" << EOF
    - name: ${SESSION}-backend
      dockerfile: backend/Dockerfile
      context: ./backend
      tag: skeleton
EOF
  fi

  # Add frontend if exists
  if [ -f "$SCAFFOLD_DIR/frontend/Dockerfile" ]; then
    cat >> ".claude/scopes/${SESSION}-skeleton.md" << EOF
    - name: ${SESSION}-frontend
      dockerfile: frontend/Dockerfile
      context: ./frontend
      tag: skeleton
EOF
  fi

  cat >> ".claude/scopes/${SESSION}-skeleton.md" << EOF
---
EOF

  # Use official build skill
  /pm:build-deployment ${SESSION}-skeleton

  # Clean up temporary scope
  rm ".claude/scopes/${SESSION}-skeleton.md"
fi
```

### Step 6: Update Image Tags in Manifests

Before applying, update image tags to use `:skeleton`:

For each deployment manifest, ensure images point to:
- `{registry}/{session}-backend:skeleton`
- `{registry}/{session}-frontend:skeleton`

### Step 7: Apply K8s Manifests

```bash
echo "Applying K8s manifests..."

# Apply in order: namespace first, then the rest
kubectl apply -f "$K8S_DIR/namespace.yaml" 2>/dev/null || true

# Apply all other manifests
for manifest in "$K8S_DIR"/*.yaml; do
  if [[ "$manifest" != *"namespace.yaml"* ]]; then
    echo "Applying: $(basename $manifest)"
    kubectl apply -f "$manifest" -n "$SESSION"
  fi
done
```

### Step 8: Wait for Deployments

```bash
echo "Waiting for deployments to be ready..."

kubectl get deployments -n "$SESSION" -o name | while read deploy; do
  echo "Waiting for $deploy..."
  kubectl rollout status "$deploy" -n "$SESSION" --timeout=120s || true
done
```

### Step 9: Verify Pods Running

```bash
echo "Verifying pod status..."

# Wait up to 60 seconds for at least one pod to be Running
TIMEOUT=60
INTERVAL=5
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
  RUNNING=$(kubectl get pods -n "$SESSION" --no-headers 2>/dev/null | grep -c "Running" || echo "0")
  if [ "$RUNNING" -gt 0 ]; then
    echo "Found $RUNNING running pod(s)"
    break
  fi
  echo "Waiting for pods... ($ELAPSED/${TIMEOUT}s)"
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done
```

### Step 10: Get Service Endpoints

```bash
echo "Getting service endpoints..."

kubectl get services -n "$SESSION" -o wide
```

### Step 11: Output Summary

```
Skeleton deployed: {session}

Namespace: {session}

Pods:
{kubectl get pods -n $SESSION output}

Services:
{kubectl get services -n $SESSION output}

Health Check:
  Backend: curl http://{backend-service}:{port}/health
  Frontend: http://{frontend-service}:{nodeport}/

Next steps:
  1. Verify skeleton is working
  2. Continue with PRD decomposition
  3. Full deployment will upgrade skeleton in-place
```

## Error Handling

### Templates Not Found
```
Error: K8s templates not found
Directory: .claude/templates/{session}/k8s/

Run template generation first:
  /pm:generate-template {session}
```

### Image Build Failed
```
Error: Failed to build skeleton image

Check:
  1. Docker is running
  2. Scaffold has valid Dockerfile
  3. Registry is accessible: {registry}

To skip image build and use existing:
  kubectl apply -f .claude/templates/{session}/k8s/ -n {session}
```

### Pods Not Starting
```
Warning: Pods not in Running state after 60s

Current status:
{kubectl get pods -n $SESSION}

Events:
{kubectl get events -n $SESSION --sort-by='.lastTimestamp'}

Common issues:
  - Image pull errors (check registry access)
  - Resource limits too low
  - Missing secrets/configmaps
  - Liveness probe failing

Debug:
  kubectl describe pod -n {session} {pod-name}
  kubectl logs -n {session} {pod-name}
```

### Namespace Conflict
```
Note: Namespace {session} already exists

Skeleton deployment will:
  - Update existing deployments
  - Not delete existing resources
  - Use rolling update strategy

To clean and redeploy:
  kubectl delete namespace {session}
  /pm:deploy-skeleton {session}
```

## Verification Commands

After deployment, verify with:

```bash
# Check pods
kubectl get pods -n {session}

# Check services
kubectl get services -n {session}

# Check events
kubectl get events -n {session} --sort-by='.lastTimestamp'

# Test health endpoint
kubectl port-forward svc/{session}-backend 3000:3000 -n {session} &
curl http://localhost:3000/health
```

## Notes

- Skeleton uses `:skeleton` image tag to differentiate from full deployment
- Full deployment (step 12) will upgrade pods in-place using `:latest`
- Namespace is created if it doesn't exist
- Existing resources are updated, not replaced
- Health checks ensure pods are actually serving traffic
- Frontend typically exposed via NodePort for local development
