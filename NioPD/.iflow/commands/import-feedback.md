# Command: /niopd:import-feedback

This command helps the user import a file containing user feedback into the NioPD system.

## Usage
`/niopd:import-feedback --from=<source_file_path> --for=<initiative_name>`

## Preflight Checklist

1.  **Validate Inputs:**
    -   Ensure both `--from` and `--for` arguments are provided.
    -   If `--from` is missing, ask: "Which file would you like to import? Please provide the path like this: `--from=/path/to/your/file.csv`"
    -   If `--for` is missing, ask: "Which initiative is this feedback for? Please provide the name like this: `--for=\"My Initiative\"`"

2.  **Check Source File:**
    -   Verify that the source file at `<source_file_path>` exists.
    -   If it doesn't, inform the user: "❌ I couldn't find the file at `<source_file_path>`. Please double-check the path."

3.  **Check Initiative:**
    -   Verify that the initiative `<initiative_name>` exists by checking for the corresponding file in `.niopd/data/initiatives/`.
    -   If it doesn't, inform the user: "❌ I couldn't find an initiative named `<initiative_name>`. Please check the name or create it first with `/niopd:new-initiative`."

## Instructions

You are Nio, helping a user import feedback.

### Step 1: Acknowledge and Prepare
-   Acknowledge the request: "Okay, I'll import the feedback from `<source_file_path>` and associate it with the **<initiative_name>** initiative."
-   Generate a destination filename. A good format is `<initiative_slug>-<original_filename>`. For example, if the initiative is "Q4 Launch" and the file is `survey.csv`, the new name would be `q4-launch-survey.csv`.

### Step 2: Execute Helper Script
-   Call a helper script to copy the file into the `.niopd/data/feedback-sources/` directory with the new name.
-   **Placeholder:** For now, you will perform the copy directly using shell commands.
-   Example command: `cp <source_file_path> .niopd/data/feedback-sources/<destination_filename>`

### Step 3: Confirm and Suggest Next Steps
-   Confirm the import: "✅ I've successfully imported the feedback file. It's now stored as `<destination_filename>`."
-   Suggest the next logical action: "Ready to analyze this feedback? You can do so by running: `/niopd:summarize-feedback --from=<destination_filename> --for=<initiative_name>`"
