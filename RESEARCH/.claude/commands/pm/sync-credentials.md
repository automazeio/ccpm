# Sync Credentials

Sync credentials between .env file and Kubernetes secrets.

## Usage
```
/pm:sync-credentials <direction> [app-name] [namespace]
```

## Arguments
- `direction` (required): `to-k8s` or `from-k8s`
- `app-name` (optional): Application name (default: from .claude/project.yaml or directory name)
- `namespace` (optional): Kubernetes namespace (default: `default`)

## Examples

```bash
# Sync local .env to Kubernetes
/pm:sync-credentials to-k8s myapp production

# Pull Kubernetes secret to local .env
/pm:sync-credentials from-k8s myapp production

# Generate K8s manifest without applying
/pm:sync-credentials generate myapp staging
```

---

## Instructions

### Step 1: Parse Arguments

Parse the arguments provided:
- `DIRECTION`: First argument (`to-k8s`, `from-k8s`, or `generate`)
- `APP_NAME`: Second argument or derive from project
- `NAMESPACE`: Third argument or default to `default`

**Derive app name if not provided:**

1. Check for `.claude/project.yaml` and read `name` field
2. If not found, use current directory name

```bash
if [ -z "$APP_NAME" ]; then
  if [ -f ".claude/project.yaml" ]; then
    APP_NAME=$(grep "^name:" .claude/project.yaml | cut -d: -f2 | tr -d ' ')
  else
    APP_NAME=$(basename "$(pwd)")
  fi
fi
```

---

### Step 2: Validate Prerequisites

**Check kubectl is available:**
```bash
if ! command -v kubectl &> /dev/null; then
  echo "❌ kubectl not found"
  echo ""
  echo "Install: https://kubernetes.io/docs/tasks/tools/"
  exit 1
fi
```

**Check jq for from-k8s direction:**
```bash
if [ "$DIRECTION" = "from-k8s" ]; then
  if ! command -v jq &> /dev/null; then
    echo "❌ jq not found (required for from-k8s)"
    echo ""
    echo "Install: https://jqlang.github.io/jq/download/"
    exit 1
  fi
fi
```

---

### Step 3: Execute Sync

Based on direction, run the appropriate script:

#### to-k8s: Local .env → Kubernetes Secret

```bash
./.claude/scripts/sync-env-to-k8s.sh "$APP_NAME" "$NAMESPACE"
```

**Expected behavior:**
1. Check .env exists
2. Delete existing secret if present
3. Create new secret from .env
4. Show verification command

#### from-k8s: Kubernetes Secret → Local .env

```bash
./.claude/scripts/sync-k8s-to-env.sh "$APP_NAME" "$NAMESPACE"
```

**Expected behavior:**
1. Check secret exists in cluster
2. Backup existing .env if present
3. Extract and decode secrets
4. Write to .env

#### generate: Create K8s manifest without applying

```bash
./.claude/scripts/env-to-k8s-secret.sh "$APP_NAME" "$NAMESPACE"
```

**Expected behavior:**
1. Check .env exists
2. Generate k8s-secret.yaml manifest
3. Show apply command

---

### Step 4: Show Results

**For to-k8s:**
```
✅ Synced to Kubernetes

Secret: {app-name}-secrets
Namespace: {namespace}

Verify: kubectl get secret {app-name}-secrets -n {namespace}
```

**For from-k8s:**
```
✅ Pulled from Kubernetes

Credentials: {count}
Output: .env

Backup: .env.backup (if applicable)
```

**For generate:**
```
✅ Generated manifest

File: k8s-secret.yaml

To apply: kubectl apply -f k8s-secret.yaml
```

---

## Error Handling

| Error | Resolution |
|-------|------------|
| kubectl not found | Install kubectl |
| jq not found (from-k8s) | Install jq |
| .env not found | Run /pm:gather-credentials first |
| Secret not found | Check namespace and secret name |
| Cluster access denied | Check kubeconfig and permissions |

---

## Security Notes

1. **Never commit k8s-secret.yaml** - It's gitignored but be careful
2. **Secrets are base64 encoded, not encrypted** - Use sealed-secrets for production
3. **Backup .env before pulling** - from-k8s creates .env.backup
4. **Check namespace carefully** - Wrong namespace = wrong credentials

---

## Integration with Deploy

The `/pm:deploy` command automatically syncs credentials to K8s before deploying:

```bash
# In deploy workflow
./.claude/scripts/sync-env-to-k8s.sh "$APP_NAME" "$NAMESPACE"
kubectl apply -f deployment.yaml
```

---

## Workflow Examples

### Local Development → Staging

```bash
# 1. Gather credentials for local dev
/pm:gather-credentials my-session

# 2. Test locally with .env
npm run dev

# 3. Sync to staging cluster
/pm:sync-credentials to-k8s myapp staging

# 4. Deploy to staging
kubectl apply -f k8s/staging/
```

### Pull Production Credentials for Debugging

```bash
# 1. Pull from production (careful!)
/pm:sync-credentials from-k8s myapp production

# 2. Debug locally with production credentials
npm run dev

# 3. Restore local credentials from backup
mv .env.backup .env
```

### Generate Manifest for GitOps

```bash
# 1. Generate manifest (don't apply)
/pm:sync-credentials generate myapp production

# 2. Encrypt with sealed-secrets (recommended)
kubeseal < k8s-secret.yaml > sealed-secret.yaml

# 3. Commit sealed-secret.yaml to GitOps repo
git add sealed-secret.yaml
git commit -m "Update secrets"
```
