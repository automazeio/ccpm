# Phase B: Journey Step Decomposition Prompt

<role>
You are a senior UX engineer decomposing user journeys into detailed steps with full technical traceability.
You understand the complete stack: UI → API → Backend → Database.
</role>

<context>
<journey>
{{JOURNEY_JSON}}
</journey>

<flow_diagram>
{{FLOW_DIAGRAM_CONTENT}}
</flow_diagram>

<endpoint_mapping>
{{ENDPOINT_TABLE_MAPPING}}
</endpoint_mapping>

<session_name>{{SESSION_NAME}}</session_name>
</context>

<task>
Decompose this journey into individual steps. For each step, trace the complete data flow from user action through all technical layers.

Extract from the flow diagram:
1. Which API endpoint handles this step
2. Which database tables are affected
3. What the UI component is
</task>

<output_format>
Respond with valid JSON only. No markdown, no explanation.

{
  "journey_id": "{{JOURNEY_ID}}",
  "steps": [
    {
      "step_number": 1,
      "step_name": "Navigate to Page",
      "step_description": "User navigates to the relevant page",
      "user_action": "Click navigation link",
      "user_intent": "Access the feature",
      "user_decision_point": false,
      "decision_options": null,
      "ui_component_type": "link|button|form|modal|table|list",
      "ui_component_name": "ComponentName",
      "ui_page_route": "/route/path",
      "frontend_event_type": "click|submit|change|load",
      "api_protocol": "rest",
      "api_operation_type": "GET|POST|PUT|DELETE",
      "api_endpoint": "/api/v1/resource",
      "api_auth_required": true,
      "db_operation": "create|read|update|delete|null",
      "db_tables_affected": ["table1", "table2"],
      "possible_errors": [
        {"code": "404", "message": "Not found", "recovery": "Show error message"}
      ],
      "is_optional": false,
      "is_automated": false,
      "notes": "Additional context"
    }
  ]
}
</output_format>

<constraints>
- Each step has a single, clear user action
- API endpoints match those in the endpoint mapping (set api_endpoint to null when no match exists)
- Database tables match those in the flow diagram
- Order steps logically (navigation before action)
- Include validation and error steps where appropriate
- Maximum 15 steps per journey
- Step names are concise (3-5 words)
</constraints>

<endpoint_mapping_rules>
When mapping steps to endpoints:
1. Find the matching endpoint in the endpoint mapping
2. Use the PRIMARY table as the main db_tables_affected entry
3. Include SECONDARY tables when the step involves relationships
4. When no endpoint matches, set api_endpoint to null and db_operation to null
</endpoint_mapping_rules>

<examples>
<example>
For endpoint mapping:
"- /api/v1/organizations: PRIMARY=organizations, SECONDARY=none"

Step output:
{
  "api_endpoint": "/api/v1/organizations",
  "api_operation_type": "POST",
  "db_operation": "create",
  "db_tables_affected": ["organizations"]
}
</example>
</examples>
