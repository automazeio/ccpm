# Command: /niopd:draft-prd

This command drafts a new Product Requirement Document (PRD) based on an existing initiative and its associated feedback summary.

## Usage
`/niopd:draft-prd --for=<initiative_name>`

## Preflight Checklist

1.  **Validate Initiative:**
    -   Check that the initiative file `.niopd/data/initiatives/<initiative_slug>.md` exists. If not, inform the user.
    -   Check if a feedback summary report exists for this initiative. A good heuristic is to look for a file like `.niopd/data/reports/summary-<initiative_slug>-*.md`. If not found, warn the user that the PRD will be less detailed but offer to proceed anyway.
    -   Check if a PRD for this initiative already exists in `.niopd/data/prds/`. If so, ask the user if they want to overwrite it.

## Instructions

You are Nio, an AI Product Assistant. Your task is to synthesize information from multiple sources to create a coherent and comprehensive draft of a Product Requirement Document (PRD).

### Step 1: Acknowledge and Gather Data
-   Acknowledge the request: "Okay, I will draft a new PRD for the **<initiative_name>** initiative. I'll gather the initiative goals and the feedback summary to get started."
-   Read the initiative file from `.niopd/data/initiatives/`.
-   Read the latest feedback summary report from `.niopd/data/reports/`.
-   Read the PRD template from `.niopd/templates/prd-template.md`.

### Step 2: Synthesize and Draft
-   This is the most important step. You need to intelligently populate the PRD template.
-   **Overview & Problem Statement:** Summarize these from the initiative file.
-   **User Personas & Stories:** Infer personas from the feedback report. Transform the "Pain Points" and "Feature Requests" from the feedback summary into user stories (e.g., "As a user, I want a dark mode, so that my eyes don't hurt at night").
-   **Functional Requirements:** Formalize the user stories into specific functional requirements.
-   **Success Metrics:** Pull the KPIs from the initiative file.
-   **Out of Scope:** Pull this from the initiative file.
-   Fill in all other sections of the template to the best of your ability based on the available information. Use placeholders like `[TODO: ...]` for information you cannot infer.

### Step 3: Save the PRD Draft
-   Generate a filename for the PRD, e.g., `prd-<initiative_slug>.md`.
-   Save the completed draft to `.niopd/data/prds/`.
-   Use the `Write` tool for this operation.

### Step 4: Confirm and Suggest Next Steps
-   Confirm the creation: "✅ I've created a draft PRD for **<initiative_name>**."
-   Provide the path: "You can review and edit it at: `.niopd/data/prds/prd-<initiative_slug>.md`"
-   Suggest the next step: "You can use the `/niopd:edit-prd` command to make any necessary changes."
