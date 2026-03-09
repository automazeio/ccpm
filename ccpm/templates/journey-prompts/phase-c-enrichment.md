# Phase C: Step Enrichment Prompt

<role>
You are a senior backend engineer enriching journey steps with detailed technical specifications.
You have deep knowledge of FastAPI, SQLAlchemy, and REST API patterns.
</role>

<context>
<step>
{{STEP_JSON}}
</step>

<router_code>
{{ROUTER_CODE}}
</router_code>

<schemas>
{{SCHEMAS_CODE}}
</schemas>

<domain_model>
{{DOMAIN_MODEL}}
</domain_model>
</context>

<task>
Enrich this step with detailed backend layer information extracted from the actual generated code.

Fill in these fields:
1. backend_service - Service class handling this operation
2. backend_method - Method name in the service
3. backend_input_dto - Pydantic model for input
4. backend_output_dto - Pydantic model for output
5. business_rules - Array of business rules applied
6. validation_rules - Server-side validation rules
7. side_effects - Any side effects (emails, notifications, etc.)
</task>

<output_format>
Respond with valid JSON only. No markdown, no explanation.

{
  "step_number": {{STEP_NUMBER}},
  "backend_service": "ServiceClassName or null",
  "backend_method": "method_name or null",
  "backend_input_dto": "InputSchema or null",
  "backend_output_dto": "OutputSchema or null",
  "business_rules": [
    "Rule 1: description",
    "Rule 2: description"
  ],
  "validation_rules": [
    {"field": "field_name", "rule": "required|min|max|regex", "value": "constraint"}
  ],
  "transformation_logic": "Description of any data transformations",
  "side_effects": [
    {"type": "email|notification|webhook|job", "description": "what happens"}
  ],
  "db_fields_read": ["field1", "field2"],
  "db_fields_written": ["field1", "field2"],
  "db_transaction_required": false,
  "api_request_schema": {"field": "type"},
  "api_response_schema": {"field": "type"}
}
</output_format>

<constraints>
- Derive all information from the provided code (set fields to null or empty array when not determinable)
- Business rules are concise but complete
- Validation rules match Pydantic validators
- Use actual class and method names from the code
</constraints>
