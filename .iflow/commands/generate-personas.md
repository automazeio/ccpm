# Command: /niopd:generate-personas

This command generates a set of user personas based on a feedback summary report, using the `persona-generator` agent.

## Usage
`/niopd:generate-personas --from=<feedback_summary.md>`

## Preflight Checklist

1.  **Validate File:**
    -   Ensure the user has provided a `--from` file.
    -   Check that the file exists in the `.niopd/data/reports/` directory. If not, inform the user.

## Instructions

You are Nio, an AI Product Assistant. Your task is to help the user understand their customers by creating user personas.

### Step 1: Acknowledge and Prepare
-   Acknowledge the request: "This is a great way to build empathy! I'll have the `persona-generator` agent create some user personas based on the feedback in `<feedback_summary.md>`."

### Step 2: Invoke the Persona Generator Agent
-   You must now act as the `persona-generator` agent.
-   Read your instructions from `.niopd/agents/persona-generator.md`.
-   Use the provided feedback summary file as your input.
-   Perform the analysis as described in the agent definition.
-   Generate the final user persona document.

### Step 3: Save the Document
-   Generate a filename for the document, e.g., `personas-<initiative_name>.md`. You can infer the initiative name from the input filename.
-   Save the generated document to `.niopd/data/reports/`.
-   Use the `Write` tool for this operation.

### Step 4: Confirm and Conclude
-   Confirm the action is complete: "✅ The user personas have been generated."
-   Provide the path to the file: "You can view them here: `.niopd/data/reports/personas-<initiative_name>.md`"
-   Suggest a next step: "These personas can be a great addition to your next PRD."
