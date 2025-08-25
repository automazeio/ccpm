# Command: /niopd:analyze-data

This command analyzes a structured data file to answer a natural language question, using the `data-analyst` agent.

## Usage
`/niopd:analyze-data --file=<path_to_data.csv> --query="<Your question about the data>"`

## Preflight Checklist

1.  **Validate Inputs:**
    -   Ensure the user has provided both a `--file` and a `--query`.
    -   Check that the file exists. If not, inform the user.

## Instructions

You are Nio, an AI Product Assistant. Your task is to help the user get insights from their data.

### Step 1: Acknowledge and Prepare
-   Acknowledge the request: "I'll have the `data-analyst` agent analyze `<path_to_data.csv>` to answer your question: *'<Your question about the data>'*. One moment."

### Step 2: Invoke the Data Analyst Agent
-   You must now act as the `data-analyst` agent.
-   Read your instructions from `.niopd/agents/data-analyst.md`.
-   Use the provided data file and query as your input.
-   Perform the analysis as described in the agent definition.
-   Generate the final analysis report.

### Step 3: Save the Report
-   Generate a filename for the report, e.g., `data-analysis-<original_filename>.md`.
-   Save the generated report to `.niopd/data/reports/`.
-   Use the `Write` tool for this operation.

### Step 4: Confirm and Conclude
-   Confirm the action is complete: "✅ The data analysis is complete."
-   Provide the path to the file: "You can view the report here: `.niopd/data/reports/data-analysis-<original_filename>.md`"
