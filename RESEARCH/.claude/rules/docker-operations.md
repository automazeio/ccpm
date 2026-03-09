# Docker Operations Rule

## CRITICAL: Never Use Docker CLI Directly

**NEVER** execute direct Docker CLI commands:
- `docker build`
- `docker push`

**Allowed** (used internally by official skills):
- `nerdctl build` (via /pm:build-deployment)
- `nerdctl push` (via /pm:build-deployment)

**ALWAYS** use the official deployment skills:
- `/pm:build-deployment <scope>` - Build and push images
- `/pm:deploy <scope>` - Build, push, and deploy to K8s

## Why This Matters

The official skills ensure:
1. Correct registry configuration (--insecure-registry for HTTP registries)
2. Consistent tooling (nerdctl with buildkit)
3. Proper environment variables (REGISTRY, TAG, BUILD_DATE)
4. Audit trail through PM system
5. Error handling and retry logic

## What To Do Instead

### Building Images for a Scope
```bash
/pm:build-deployment my-scope
```

### Building and Deploying
```bash
/pm:deploy my-scope
```

### For Skeleton/Template Deployments
```bash
# Create a temporary scope or use existing one
/pm:build-deployment skeleton-scope
```

## Pre-Check (Enforced by Hook)

Before any Bash command with docker/nerdctl build/push:
```bash
echo "Direct Docker builds blocked"
echo "Use: /pm:build-deployment <scope> instead"
exit 1
```
