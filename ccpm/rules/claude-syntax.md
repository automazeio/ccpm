# Claude Prompt Syntax Rules

Rules for writing effective prompts for Claude, based on LLM prompt engineering research.

## XML Tags

Claude was trained with XML tags, making them highly effective for structural delineation.

- XML tags reduce misinterpretation errors and make prompt sections easy to extract
- Use semantically meaningful names:

```xml
<task>What to do</task>
<context>Background information</context>
<instructions>Step-by-step guidance</instructions>
<constraints>Rules and limitations</constraints>
<example>Demonstration</example>
<output_format>Expected response structure</output_format>
```

### Example

```xml
<task>
Fix the bug in the login function.
</task>

<context>
The function is in auth.py line 42.
Users report intermittent failures.
</context>

<constraints>
- Keep the function signature unchanged (callers depend on it)
- Maintain backward compatibility
</constraints>

<output_format>
Provide the fixed code in a python code block.
</output_format>
```

## Be Explicit

Claude 4.x follows instructions precisely. Vague requests get vague results.

```
# Less effective
Create a dashboard

# More effective
Create an analytics dashboard with:
- Line chart showing daily active users
- Bar chart showing revenue by product
- Table of top 10 customers by spend
- Date range selector (default: last 30 days)
```

## Provide Rationale for Constraints

Explain why rules matter — Claude generalizes from explanations, which reduces the need for exhaustive rule lists.

```
# Less effective
Never use ellipses

# More effective
Never use ellipses (the text-to-speech engine cannot pronounce them, causing awkward pauses)
```

## Positive Instructions

Positive instructions outperform negative ones.

```
# Less effective
Don't include implementation details in steps.
Don't use technical jargon.

# More effective
Write steps in user-focused language.
Use domain terms the business user would recognize.
Example: "submit the form" not "POST to /api/users"
```

## Few-Shot Examples

For complex or novel formats, include 2-5 examples.

```xml
<examples>
<example>
<input>User wants to reset password</input>
<output>
Feature: Password Reset
  Scenario: User resets password via email
    Given I am on the login page
    When I click "Forgot Password"
    ...
</output>
</example>

<example>
<input>User wants to update profile</input>
<output>
Feature: Profile Management
  Scenario: User updates display name
    Given I am logged in
    ...
</output>
</example>
</examples>
```

- Place the best example last (recency bias)
- Cover edge cases in examples
- Keep examples diverse but relevant

## Output Format Control

Specify the expected response format explicitly.

### For Code

```xml
<output_format>
Output only a single code block.
Start with triple backticks and the language name.
End with triple backticks on its own line.
No explanations before or after the code.
</output_format>
```

### For Structured Data

```xml
<output_format>
Respond with only a JSON object:
{
  "score": <0-100>,
  "passed": <true|false>,
  "issues": ["issue1", "issue2"]
}
No markdown, no explanation, just valid JSON.
</output_format>
```

## Role Prompting

Assigning a role improves domain-specific accuracy (single most powerful system prompt technique per Anthropic):

```xml
<role>
You are a senior QA engineer with 10 years of experience
writing Gherkin acceptance criteria. You prioritize:
- Behavior-driven scenarios (not implementation)
- Edge case coverage
- Clear, testable steps
</role>
```

## Scope Limiting

Claude 4.x tends to add unnecessary complexity. Include a scope constraint for focused tasks:

```
Implement only what is directly requested.
Keep solutions simple and focused.
- Do not add unrequested features
- Do not create abstractions for one-time operations
- Do not add error handling for scenarios outside the described scope
```

## Extended Thinking

For complex reasoning, use graduated triggers:

| Phrase | Depth |
|--------|-------|
| `think` | Basic reasoning |
| `think hard` | Moderate complexity |
| `think harder` | High complexity |
| `ultrathink` | Maximum depth |

Use for: complex math, multi-step coding, architectural decisions, intricate debugging.

Skip for: simple tasks, format conversion, straightforward edits.

## Prompt Template

```xml
<role>
[Domain expert persona]
</role>

<task>
[Clear, specific objective]
</task>

<context>
[Relevant background information]
</context>

<instructions>
1. [First step]
2. [Second step]
3. [Third step]
</instructions>

<constraints>
- [Rule with explanation of why]
- [Another rule with context]
</constraints>

<examples>
<example>
[Input/output demonstration]
</example>
</examples>

<output_format>
[Explicit format specification]
</output_format>
```

## References

Based on:
- Anthropic Claude documentation
- LLM prompt engineering best practices (2025-2026)
- Empirical testing with Claude 4.x models
