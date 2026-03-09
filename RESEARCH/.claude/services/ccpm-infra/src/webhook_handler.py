#!/usr/bin/env python3
"""
CCPM Infrastructure Webhook Handler

Receives GitHub webhook events on merge and triggers infrastructure
documentation regeneration.
"""

import hashlib
import hmac
import json
import logging
import os
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, Header, HTTPException, Request, BackgroundTasks
from pydantic import BaseModel

from config_aggregator import CCPMConfigAggregator
from graph_generator import DependencyGraphGenerator

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="CCPM Infrastructure Service",
    description="Regenerates CCPM infrastructure documentation on merge events",
    version="1.0.0"
)

# Configuration from environment
WEBHOOK_SECRET = os.getenv("WEBHOOK_SECRET", "")
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN", "")
REPOS_CONFIG = os.getenv("REPOS_CONFIG", "repos.json")
OUTPUT_DIR = os.getenv("OUTPUT_DIR", "/data/output")


class WebhookPayload(BaseModel):
    """GitHub webhook payload model"""
    ref: Optional[str] = None
    repository: Optional[dict] = None
    sender: Optional[dict] = None
    action: Optional[str] = None
    pull_request: Optional[dict] = None


def verify_signature(payload: bytes, signature: str) -> bool:
    """
    Verify GitHub webhook HMAC-SHA256 signature.

    Args:
        payload: Raw request body
        signature: X-Hub-Signature-256 header value

    Returns:
        True if signature is valid
    """
    if not WEBHOOK_SECRET:
        logger.warning("WEBHOOK_SECRET not set, skipping signature verification")
        return True

    if not signature:
        return False

    # GitHub signature format: sha256=<hex_digest>
    if not signature.startswith("sha256="):
        return False

    expected_sig = signature[7:]  # Remove "sha256=" prefix

    computed_sig = hmac.new(
        WEBHOOK_SECRET.encode('utf-8'),
        payload,
        hashlib.sha256
    ).hexdigest()

    return hmac.compare_digest(expected_sig, computed_sig)


def is_merge_event(event_type: str, payload: dict) -> bool:
    """
    Check if the event is a merge to main/master branch.

    Supports:
    - push events to main/master
    - pull_request events with action=closed and merged=true
    """
    if event_type == "push":
        ref = payload.get("ref", "")
        return ref in ("refs/heads/main", "refs/heads/master")

    if event_type == "pull_request":
        action = payload.get("action", "")
        pr = payload.get("pull_request", {})
        merged = pr.get("merged", False)
        base_ref = pr.get("base", {}).get("ref", "")
        return action == "closed" and merged and base_ref in ("main", "master")

    return False


async def regenerate_infrastructure(payload: dict):
    """
    Background task to regenerate infrastructure documentation.
    """
    try:
        logger.info("Starting infrastructure regeneration...")

        # Load repos configuration
        repos = load_repos_config()

        # Aggregate configs from all repos
        aggregator = CCPMConfigAggregator(GITHUB_TOKEN)
        configs = await aggregator.aggregate(repos)

        # Generate dependency graph
        generator = DependencyGraphGenerator()
        graph = generator.generate(configs)

        # Write output files
        os.makedirs(OUTPUT_DIR, exist_ok=True)

        # Write infrastructure.md
        infra_path = os.path.join(OUTPUT_DIR, "infrastructure.md")
        write_infrastructure_doc(infra_path, configs, graph)

        # Write configs.json
        configs_path = os.path.join(OUTPUT_DIR, "configs.json")
        with open(configs_path, 'w') as f:
            json.dump(configs, f, indent=2, default=str)

        logger.info(f"Infrastructure regeneration complete: {infra_path}")

    except Exception as e:
        logger.error(f"Infrastructure regeneration failed: {e}")
        raise


def load_repos_config() -> list:
    """Load repository configuration from file or environment."""
    # Try file first
    if os.path.exists(REPOS_CONFIG):
        with open(REPOS_CONFIG) as f:
            return json.load(f)

    # Fall back to environment variable
    repos_json = os.getenv("REPOS_JSON", "[]")
    return json.loads(repos_json)


def write_infrastructure_doc(path: str, configs: dict, graph: str):
    """Write the infrastructure documentation markdown file."""
    timestamp = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

    content = f"""# CCPM Infrastructure

**Generated:** {timestamp}

## Overview

This document provides a comprehensive view of the CCPM (Claude Code Project Manager)
infrastructure across all configured repositories.

## Dependency Graph

```mermaid
{graph}
```

## Repositories

"""

    for repo_name, repo_config in configs.items():
        content += f"### {repo_name}\n\n"

        # Commands
        commands = repo_config.get("commands", [])
        if commands:
            content += "**Commands:**\n"
            for cmd in commands:
                content += f"- `{cmd['name']}` - {cmd.get('description', 'No description')}\n"
            content += "\n"

        # Skills
        skills = repo_config.get("skills", [])
        if skills:
            content += "**Skills:**\n"
            for skill in skills:
                content += f"- `{skill['name']}`\n"
            content += "\n"

        # Rules
        rules = repo_config.get("rules", [])
        if rules:
            content += f"**Rules:** {len(rules)} configured\n\n"

        content += "---\n\n"

    content += f"""
## Statistics

| Metric | Value |
|--------|-------|
| Total Repositories | {len(configs)} |
| Total Commands | {sum(len(c.get('commands', [])) for c in configs.values())} |
| Total Skills | {sum(len(c.get('skills', [])) for c in configs.values())} |
| Total Rules | {sum(len(c.get('rules', [])) for c in configs.values())} |

---
*Auto-generated by CCPM Infrastructure Service*
"""

    with open(path, 'w') as f:
        f.write(content)


@app.get("/health")
async def health_check():
    """Health check endpoint for Kubernetes probes."""
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}


@app.get("/ready")
async def readiness_check():
    """Readiness check endpoint."""
    return {"status": "ready", "webhook_secret_configured": bool(WEBHOOK_SECRET)}


@app.post("/webhook")
async def handle_webhook(
    request: Request,
    background_tasks: BackgroundTasks,
    x_hub_signature_256: Optional[str] = Header(None),
    x_github_event: Optional[str] = Header(None),
    x_github_delivery: Optional[str] = Header(None)
):
    """
    Handle GitHub webhook events.

    Validates signature, checks for merge events, and triggers
    infrastructure regeneration.
    """
    # Get raw body for signature verification
    body = await request.body()

    # Verify signature
    if not verify_signature(body, x_hub_signature_256 or ""):
        logger.warning(f"Invalid signature for delivery {x_github_delivery}")
        raise HTTPException(status_code=401, detail="Invalid signature")

    # Parse payload
    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON payload")

    event_type = x_github_event or "unknown"
    delivery_id = x_github_delivery or "unknown"

    logger.info(f"Received {event_type} event (delivery: {delivery_id})")

    # Check if this is a merge event
    if not is_merge_event(event_type, payload):
        logger.info(f"Ignoring non-merge event: {event_type}")
        return {
            "status": "ignored",
            "reason": "Not a merge event",
            "event": event_type,
            "delivery": delivery_id
        }

    # Trigger regeneration in background
    repo_name = payload.get("repository", {}).get("full_name", "unknown")
    logger.info(f"Merge detected in {repo_name}, triggering regeneration")

    background_tasks.add_task(regenerate_infrastructure, payload)

    return {
        "status": "accepted",
        "message": "Infrastructure regeneration triggered",
        "repository": repo_name,
        "delivery": delivery_id
    }


@app.get("/infrastructure")
async def get_infrastructure():
    """Return the current infrastructure documentation."""
    infra_path = os.path.join(OUTPUT_DIR, "infrastructure.md")

    if not os.path.exists(infra_path):
        raise HTTPException(status_code=404, detail="Infrastructure doc not generated yet")

    with open(infra_path) as f:
        content = f.read()

    return {"content": content}


@app.post("/regenerate")
async def manual_regenerate(background_tasks: BackgroundTasks):
    """Manually trigger infrastructure regeneration."""
    background_tasks.add_task(regenerate_infrastructure, {})
    return {"status": "accepted", "message": "Regeneration triggered"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
