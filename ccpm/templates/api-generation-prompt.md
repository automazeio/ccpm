# API Generation Prompt Template

This template is used by Step 12 of the feature_interrogate.sh pipeline to generate
FastAPI router code from domain models and requirements.

## Template Variables

- `{{REQUIREMENTS}}` - Content from refined-requirements.md
- `{{DOMAIN_MODEL}}` - Content from domain-model.md or domain-context.yaml
- `{{SQLALCHEMY_MODELS}}` - Content from schema-sqlalchemy.py
- `{{ENTITIES}}` - Detected entity names from models
- `{{CODEBASE_EXAMPLES}}` - Extracted patterns from backend/app/api/v1/
- `{{ERRORS_FEEDBACK}}` - Error messages from previous iteration (if any)

## Prompt Structure

```xml
<role>
You are an expert FastAPI developer generating production-ready API code.
Follow the codebase conventions shown in the examples exactly.
</role>

<task>
Generate a complete FastAPI router for the entities in the context.
Include: list, get_by_id, create, update, delete operations.
</task>

<context>
## Requirements
{{REQUIREMENTS}}

## Domain Model
{{DOMAIN_MODEL}}

## SQLAlchemy Models
{{SQLALCHEMY_MODELS}}

## Detected Entities
{{ENTITIES}}

## Codebase Info
Framework: FastAPI
Auth: JWT via require_privilege() decorator
Database: PostgreSQL with async SQLAlchemy 2.0
UUID primary keys returned as str(uuid)
</context>

<examples>
{{CODEBASE_EXAMPLES}}
</examples>

<constraints>
- Use exact import style from examples
- Use require_privilege("entity.action") for auth (e.g., "inventory.view")
- Return dict with str(uuid) for ID fields
- Use async def for all handlers
- Use select() and selectinload() for queries
- Include proper error handling with HTTPException
- Add docstrings to each endpoint
</constraints>

{{#if ERRORS_FEEDBACK}}
<previous_errors>
Fix these issues from the previous attempt:
{{ERRORS_FEEDBACK}}
</previous_errors>
{{/if}}

<output_format>
Output valid Python code only.
Start with triple-quote docstring and imports.
Include all imports at top.
No markdown fences, no explanations.
</output_format>
```

## Validation Criteria

The generated code is validated against these criteria (100 points total):

| Check | Points | Blocking |
|-------|--------|----------|
| Python syntax valid | 20 | Yes |
| Has router declaration | 10 | No |
| Has async def handlers | 10 | No |
| Has require_privilege decorator | 10 | No |
| Has FastAPI imports | 10 | No |
| Has database dependency | 10 | No |
| Has HTTPException | 10 | No |
| Has docstrings | 10 | No |
| Uses str() for UUID return | 10 | No |

**Passing threshold: 80 points**

## Self-Refine Loop

The generation runs up to 3 iterations:

1. First iteration: Generate with base prompt
2. If score < 80: Collect errors and add to prompt as `<previous_errors>`
3. Continue until score >= 80 or max iterations reached
4. Use best attempt if threshold not met

## Integration Notes

After generation, the router needs to be:

1. Copied to `backend/app/api/v1/{entity}.py`
2. Registered in `backend/app/main_complete.py`:
   ```python
   from app.api.v1 import {entity}
   app.include_router({entity}.router, prefix="/api/v1/{entity}", tags=["{Entity}"])
   ```
3. Tested via API docs at `/api/docs`
