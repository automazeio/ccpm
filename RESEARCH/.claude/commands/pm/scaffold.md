# Scaffold - Project Infrastructure Setup

Set up a new project with Kubernetes namespace, PostgreSQL, MinIO, and .env configuration.

## Usage
```
/pm:scaffold <project-name> [--skip-services]
```

## Arguments
- `project-name` (required): Name for the project (used as namespace and directory name)
- `--skip-services`: Skip deploying PostgreSQL and MinIO (only create namespace and scope)

## What It Does

1. Creates K8s namespace for the project
2. Deploys PostgreSQL via Helm (bitnami/postgresql)
3. Deploys MinIO for S3-compatible object storage
4. Generates `.env` file with all credentials
5. Creates project directory in `~/robert-projects/`
6. Creates scope document for `/pm:deploy` integration

## Instructions

### Step 1: Parse Arguments

```bash
PROJECT_NAME="${ARGUMENTS%% *}"
SKIP_SERVICES=false

if [[ "$ARGUMENTS" == *"--skip-services"* ]]; then
  SKIP_SERVICES=true
fi

if [[ -z "$PROJECT_NAME" ]]; then
  echo "Usage: /pm:scaffold <project-name> [--skip-services]"
  exit 1
fi
```

### Step 2: Set Paths

```bash
CCPM_DIR="/home/ubuntu/ccpm"
PROJECTS_DIR="/home/ubuntu/robert-projects"
PROJECT_DIR="$PROJECTS_DIR/$PROJECT_NAME"
```

### Step 3: Create Project Directory

```bash
mkdir -p "$PROJECT_DIR"
echo "Created project directory: $PROJECT_DIR"
```

### Step 4: Deploy Infrastructure (unless --skip-services)

If `SKIP_SERVICES` is false:

```bash
cd "$CCPM_DIR"

# Run setup-service.sh to deploy PostgreSQL and MinIO
bash scripts/setup-service.sh all "$PROJECT_NAME"
```

This will:
- Create namespace `$PROJECT_NAME`
- Deploy PostgreSQL via Helm
- Deploy MinIO via kubectl
- Create K8s secrets for credentials
- Output credentials to stdout

### Step 5: Generate .env File

```bash
NAMESPACE="$PROJECT_NAME" PROJECT_DIR="$PROJECT_DIR" bash "$CCPM_DIR/scripts/setup-env-from-k8s.sh"
```

### Step 6: Create Scope Document

Create `.claude/scopes/{project-name}.md`:

```bash
mkdir -p .claude/scopes
```

Write the scope file with this content:

```markdown
---
name: {project-name}
status: active
work_dir: /home/ubuntu/robert-projects/{project-name}

deploy:
  enabled: true
  namespace: {project-name}
  registry: ubuntu.desmana-truck.ts.net:30500
  manifests: k8s/
  images:
    - name: {project-name}
      dockerfile: Dockerfile
      context: .
---

# {project-name}

Project scaffolded by CCPM.

## Infrastructure

- **Namespace**: {project-name}
- **PostgreSQL**: Deployed via Helm
- **MinIO**: Deployed via kubectl
- **Credentials**: See .env file

## Usage

### Deploy Application
```bash
/pm:deploy {project-name}
```

### Run Development Loop
```bash
/pm:scope-run {project-name}
```
```

### Step 7: Create Basic Project Files

Create `README.md` in project directory:

```markdown
# {project-name}

Project scaffolded by CCPM.

## Getting Started

1. Configure your application
2. Create a `Dockerfile`
3. Create `k8s/` manifests
4. Run `/pm:deploy {project-name}`

## Environment

Credentials are in `.env`:
- PostgreSQL connection
- MinIO/S3 credentials
- Project metadata

## Infrastructure

- **Namespace**: {project-name}
- **PostgreSQL**: Available at POSTGRES_HOST:POSTGRES_PORT
- **MinIO**: Available at MINIO_ENDPOINT
```

### Step 8: Output Summary

```
Scaffold complete: {project-name}

Namespace: {project-name}
PostgreSQL: Running at {host}:{port}
MinIO API: Running at {host}:{port}
MinIO Console: Running at {host}:{port}

Files created:
  - {project-dir}/.env
  - {project-dir}/README.md
  - .claude/scopes/{project-name}.md

Next steps:
  1. cd {project-dir}
  2. Create your application code
  3. Create Dockerfile and k8s/ manifests
  4. Run /pm:deploy {project-name}

Or start Loki mode for autonomous development:
  Loki Mode {project-name}
```

## Error Handling

### Helm Not Available
```
Helm is required for PostgreSQL deployment.
Install with: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### mc Not Available
```
MinIO client (mc) is required for bucket setup.
Install with: brew install minio/stable/mc
```

### Namespace Already Exists
- Skip namespace creation
- Check if PostgreSQL/MinIO already deployed
- If services exist, just regenerate .env

## Notes

- All infrastructure deploys to local k3s cluster
- Uses NodePort for service exposure
- Credentials stored in K8s secrets (namespace-scoped)
- .env file contains all connection strings
- Scope document enables `/pm:deploy` integration
