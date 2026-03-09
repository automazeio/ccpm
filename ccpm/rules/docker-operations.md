# Docker Operations Rule

## Use Official Deployment Skills for Builds

Run Docker builds through the official skills for consistency and audit trail.

**Use these skills:**
- `/pm:build-deployment <scope>` — Build and push images
- `/pm:deploy <scope>` — Build, push, and deploy to K8s

**Direct `docker build`/`docker push` is acceptable** when iterating outside the PM system (e.g., debugging a Dockerfile, one-off builds). The skills provide registry config, env vars, and audit trail that direct commands skip.
