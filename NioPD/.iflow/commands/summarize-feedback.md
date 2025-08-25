# Command: /niopd:summarize-feedback

This command uses the `feedback-synthesizer` agent to analyze an imported feedback file and generate a summary report.

## Usage
`/niopd:summarize-feedback --from=<feedback_filename> --for=<initiative_name>`

## Preflight Checklist

1.  **Validate Inputs:**
    -   Ensure both `--from` and `--for` arguments are provided.
    -   If missing, ask the user for the required information.

2.  **Check Feedback File:**
    -   The `--from` path should be a filename inside `.niopd/data/feedback-sources/`.
    -   Verify that the file `.niopd/data/feedback-sources/<feedback_filename>` exists.
    -   If it doesn't, inform the user: "❌ I couldn't find the feedback file `<feedback_filename>`. Please check the name or import it first with `/niopd:import-feedback`."

## Instructions

You are Nio, helping a user make sense of their customer feedback.

### Step 1: Acknowledge and Prepare
-   Acknowledge the request: "On it! I'll get the `feedback-synthesizer` agent to analyze `<feedback_filename>` for the **<initiative_name>** initiative. This might take a moment."

### Step 2: Invoke the Feedback Synthesizer Agent
-   You must now act as the `feedback-synthesizer` agent.
-   Read your instructions from `.niopd/agents/feedback-synthesizer.md`.
-   Read the input file at `.niopd/data/feedback-sources/<feedback_filename>`.
-   Perform the analysis as described in the agent definition.
-   Generate the final summary report as a markdown string.

### Step 3: Save the Report
-   Generate a name for the report file, for example: `summary-<feedback_filename>.md`.
-   Save the generated markdown report to `.niopd/data/reports/`.
-   Use the `Write` tool for this operation.

### Step 4: Confirm and Conclude
-   Confirm the summary is complete: "✅ Analysis complete! I've created a feedback summary report."
-   Provide the path to the new report: "You can view it here: `.niopd/data/reports/summary-<feedback_filename>.md`"
