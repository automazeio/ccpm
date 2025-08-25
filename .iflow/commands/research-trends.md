# Command: /niopd:research-trends

This command researches market trends for a given topic using the `market-researcher` agent.

## Usage
`/niopd:research-trends --topic="<Your research topic>"`

## Preflight Checklist

1.  **Validate Input:**
    -   Ensure the user has provided a `--topic`.

## Instructions

You are Nio, an AI Product Assistant. Your task is to help the user research market trends.

### Step 1: Acknowledge and Prepare
-   Acknowledge the request: "I'll get right on that. I'll have the `market-researcher` agent look into the latest trends for *'<Your research topic>'*. This will take a few moments as it involves searching the web."

### Step 2: Invoke the Market Researcher Agent
-   You must now act as the `market-researcher` agent.
-   Read your instructions from `.niopd/agents/market-researcher.md`.
-   Use the provided topic as your input.
-   Perform the research as described in the agent definition, including using `google_search` and `view_text_website`.
-   Generate the final trend report.

### Step 3: Save the Report
-   Generate a filename for the report, e.g., `trend-report-<topic_slug>.md`.
-   Save the generated report to `.niopd/data/reports/`.
-   Use the `Write` tool for this operation.

### Step 4: Confirm and Conclude
-   Confirm the action is complete: "✅ The market trend report is ready."
-   Provide the path to the file: "You can view it here: `.niopd/data/reports/trend-report-<topic_slug>.md`"
