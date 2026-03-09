# Generate Template

Generate Kubernetes manifests and code scaffolds based on the project's technical architecture.

## Usage
```
/pm:generate-template <session-name>
```

## Arguments
- `session-name` (required): The interrogation session name

## What It Does

1. Parses tech stack from the technical architecture document
2. Uses deep research to determine best practices for the detected stack
3. Generates K8s manifests (namespace, deployments, services, ingress)
4. Generates code scaffolds for backend and frontend

## Instructions

### Step 1: Parse Arguments

```bash
SESSION="${ARGUMENTS%% *}"

if [[ -z "$SESSION" ]]; then
  echo "Usage: /pm:generate-template <session-name>"
  exit 1
fi

ARCH_FILE=".claude/scopes/$SESSION/04_technical_architecture.md"
TEMPLATE_DIR=".claude/templates/$SESSION"
```

### Step 2: Verify Prerequisites

```bash
if [ ! -f "$ARCH_FILE" ]; then
  echo "Error: Technical architecture not found: $ARCH_FILE"
  exit 1
fi
```

### Step 3: Extract Tech Stack

Read `04_technical_architecture.md` and extract:

- **Backend Framework**: Look for mentions of Express, FastAPI, Django, NestJS, etc.
- **Frontend Framework**: Look for mentions of React, Vue, Next.js, etc.
- **Database**: PostgreSQL, MySQL, MongoDB, etc.
- **Additional Services**: Redis, message queues, etc.

Example patterns to search for:
```
Backend: Node.js/Express, Python/FastAPI, Go/Gin
Frontend: React, Vue, Next.js, Angular
Database: PostgreSQL, MySQL, MongoDB
```

If tech stack is unclear, default to:
- Backend: Node.js with Express
- Frontend: React with Vite
- Database: PostgreSQL

### Step 4: Deep Research for Best Practices

Spawn a Task agent to call `/dr` skill:

```
Research query: "Kubernetes deployment best practices for [backend-framework] and [frontend-framework] application 2024"
```

Focus areas:
- Container image best practices
- Resource limits and requests
- Health checks (liveness/readiness probes)
- Service mesh considerations
- Ingress configuration

### Step 5: Create Template Directory Structure

```bash
mkdir -p "$TEMPLATE_DIR/k8s"
mkdir -p "$TEMPLATE_DIR/scaffold/backend"
mkdir -p "$TEMPLATE_DIR/scaffold/frontend"
```

### Step 6: Generate K8s Manifests

Based on research findings, generate:

#### namespace.yaml
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: {session}
  labels:
    app.kubernetes.io/name: {session}
    app.kubernetes.io/managed-by: ccpm
```

#### backend-deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {session}-backend
  namespace: {session}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {session}-backend
  template:
    metadata:
      labels:
        app: {session}-backend
    spec:
      containers:
      - name: backend
        image: {registry}/{session}-backend:latest
        ports:
        - containerPort: {backend-port}
        env:
        - name: NODE_ENV
          value: "production"
        envFrom:
        - secretRef:
            name: {session}-secrets
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: {backend-port}
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: {backend-port}
          initialDelaySeconds: 5
          periodSeconds: 5
```

#### frontend-deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {session}-frontend
  namespace: {session}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {session}-frontend
  template:
    metadata:
      labels:
        app: {session}-frontend
    spec:
      containers:
      - name: frontend
        image: {registry}/{session}-frontend:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "200m"
```

#### service.yaml
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {session}-backend
  namespace: {session}
spec:
  selector:
    app: {session}-backend
  ports:
  - port: {backend-port}
    targetPort: {backend-port}
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: {session}-frontend
  namespace: {session}
spec:
  selector:
    app: {session}-frontend
  ports:
  - port: 80
    targetPort: 80
  type: NodePort
```

#### ingress.yaml
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {session}-ingress
  namespace: {session}
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: {session}.local
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: {session}-backend
            port:
              number: {backend-port}
      - path: /
        pathType: Prefix
        backend:
          service:
            name: {session}-frontend
            port:
              number: 80
```

### Step 7: Generate Backend Scaffold

Based on detected framework:

#### For Node.js/Express:

**scaffold/backend/package.json**
```json
{
  "name": "{session}-backend",
  "version": "0.1.0",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "dotenv": "^16.3.1",
    "pg": "^8.11.3"
  }
}
```

**scaffold/backend/src/index.js**
```javascript
require('dotenv').config();
const express = require('express');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.get('/api', (req, res) => {
  res.json({ message: 'Hello from {session} backend!' });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

**scaffold/backend/Dockerfile**
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

#### For Python/FastAPI:

**scaffold/backend/requirements.txt**
```
fastapi>=0.104.0
uvicorn[standard]>=0.24.0
python-dotenv>=1.0.0
psycopg2-binary>=2.9.9
```

**scaffold/backend/main.py**
```python
import os
from fastapi import FastAPI
from datetime import datetime

app = FastAPI(title="{session} API")

@app.get("/health")
def health():
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

@app.get("/api")
def root():
    return {"message": "Hello from {session} backend!"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", 8000)))
```

**scaffold/backend/Dockerfile**
```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Step 8: Generate Frontend Scaffold

#### For React:

**scaffold/frontend/package.json**
```json
{
  "name": "{session}-frontend",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.2.0",
    "vite": "^5.0.0"
  }
}
```

**scaffold/frontend/src/App.jsx**
```jsx
import { useState, useEffect } from 'react';

function App() {
  const [message, setMessage] = useState('Loading...');

  useEffect(() => {
    fetch('/api')
      .then(res => res.json())
      .then(data => setMessage(data.message))
      .catch(() => setMessage('Error connecting to backend'));
  }, []);

  return (
    <div style={{ padding: '2rem', fontFamily: 'system-ui' }}>
      <h1>{session}</h1>
      <p>{message}</p>
    </div>
  );
}

export default App;
```

**scaffold/frontend/Dockerfile**
```dockerfile
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Step 9: Generate docker-compose.yaml

**scaffold/docker-compose.yaml**
```yaml
version: '3.8'
services:
  backend:
    build: ./backend
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
    env_file:
      - ../../.env
    depends_on:
      - db

  frontend:
    build: ./frontend
    ports:
      - "5173:80"
    depends_on:
      - backend

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
      POSTGRES_DB: ${POSTGRES_DB:-app}
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

### Step 10: Create Deploy Scope File

Create `.claude/scopes/{session}.md` with deploy configuration for `/pm:deploy`:

```markdown
---
name: {session}
status: active
work_dir: {current_working_directory}

deploy:
  enabled: true
  namespace: {session}
  registry: ${REGISTRY:-ubuntu.desmana-truck.ts.net:30500}
  manifests: .claude/templates/{session}/k8s/
  secrets_from: .env
  images:
    - name: {session}-backend
      dockerfile: .claude/templates/{session}/scaffold/backend/Dockerfile
      context: .claude/templates/{session}/scaffold/backend
    - name: {session}-frontend
      dockerfile: .claude/templates/{session}/scaffold/frontend/Dockerfile
      context: .claude/templates/{session}/scaffold/frontend
---

# {session}

Generated scope document for deployment.

## Tech Stack
- Backend: {backend-framework}
- Frontend: {frontend-framework}
- Database: PostgreSQL

## Deployment
- Namespace: {session}
- Registry: {registry}
```

**Note:** This scope file is used by `/pm:deploy` and `/pm:deploy-skeleton` to:
- Build and push Docker images to the registry
- Apply K8s manifests from the templates directory
- Create secrets from the .env file

### Step 11: Output Summary

```
Template generation complete: {session}

Tech Stack Detected:
  Backend: {backend-framework}
  Frontend: {frontend-framework}
  Database: {database}

Generated Files:
  K8s Manifests:
    - .claude/templates/{session}/k8s/namespace.yaml
    - .claude/templates/{session}/k8s/backend-deployment.yaml
    - .claude/templates/{session}/k8s/frontend-deployment.yaml
    - .claude/templates/{session}/k8s/service.yaml
    - .claude/templates/{session}/k8s/ingress.yaml

  Code Scaffolds:
    - .claude/templates/{session}/scaffold/backend/
    - .claude/templates/{session}/scaffold/frontend/
    - .claude/templates/{session}/scaffold/docker-compose.yaml

  Deploy Configuration:
    - .claude/scopes/{session}.md

Next steps:
  1. Review generated templates
  2. Run /pm:deploy-skeleton {session} to deploy skeleton app
  3. Customize scaffolds as needed
```

## Error Handling

### Technical Architecture Not Found
```
Error: Technical architecture not found
File: .claude/scopes/{session}/04_technical_architecture.md

Run scope extraction first:
  /pm:extract-findings {session}
```

### Tech Stack Unclear
```
Warning: Could not determine tech stack from architecture document
Defaulting to: Node.js/Express + React + PostgreSQL

To specify manually, ensure 04_technical_architecture.md contains:
  - Backend framework mention
  - Frontend framework mention
```

## Notes

- Templates are generated in `.claude/templates/{session}/`
- Scaffolds are minimal "hello world" apps with health checks
- K8s manifests use standard best practices from research
- Backend port defaults to 3000 (Node.js) or 8000 (Python)
- All manifests are namespaced to `{session}`
