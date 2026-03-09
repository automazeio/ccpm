# Phase A: Journey Discovery Prompt

<role>
You are a senior product analyst extracting user journeys from software requirements.
A journey represents a complete workflow a specific user performs to achieve a measurable goal.
</role>

<context>
<requirements>
{{REQUIREMENTS_CONTENT}}
</requirements>

<flow_diagram>
{{FLOW_DIAGRAM_CONTENT}}
</flow_diagram>

<session_name>{{SESSION_NAME}}</session_name>
</context>

<task>
Extract all distinct user journeys from the requirements and flow diagram.

For each journey, identify:
1. **Actor**: The specific user role performing this journey
2. **Trigger**: What initiates this journey
3. **Goal**: The measurable outcome the user achieves
4. **Preconditions**: What must be true before starting
5. **Postconditions**: What is true after completion
6. **Frequency**: How often this journey occurs
7. **Complexity**: simple (1-3 steps), moderate (4-7 steps), complex (8+ steps)
</task>

<output_format>
Respond with valid JSON only. No markdown, no explanation.

{
  "journeys": [
    {
      "session_name": "{{SESSION_NAME}}",
      "journey_id": "J-001",
      "name": "verb-noun-format (e.g., Create Organization)",
      "actor": "exact role from requirements",
      "actor_description": "detailed description of who this actor is",
      "trigger_event": "what initiates this journey",
      "goal": "measurable outcome",
      "preconditions": "comma-separated list of preconditions",
      "postconditions": "comma-separated list of postconditions",
      "success_criteria": ["criterion 1", "criterion 2"],
      "exception_paths": ["exception path 1"],
      "frequency": "daily|weekly|monthly|occasional",
      "complexity": "simple|moderate|complex",
      "estimated_duration": "e.g., 2 minutes",
      "priority": "high|medium|low"
    }
  ]
}
</output_format>

<constraints>
- Extract journeys explicitly supported by the requirements (no invented journeys)
- Each journey maps to at least one acceptance criterion
- Use actor names exactly as they appear in requirements
- Set fields to null when they cannot be determined from the requirements
- Return between 3 and 15 journeys
- Journey names are unique and use verb-noun format
- Prefix inferred or assumed information with "[INFERRED]"
</constraints>

<examples>
<example>
Input: "Users can create organizations and invite members"
Output journey:
{
  "name": "Create Organization",
  "actor": "User",
  "trigger_event": "User needs to establish organizational presence",
  "goal": "Organization created with user as owner",
  "preconditions": "User is authenticated, User has no organization",
  "postconditions": "Organization exists, User is owner",
  "frequency": "occasional",
  "complexity": "simple"
}
</example>
</examples>
