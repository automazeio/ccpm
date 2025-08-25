#!/bin/bash

# A simple script to create a new initiative file.
# Usage: ./new-initiative.sh <file-slug> <"file-content">

# --- Input Validation ---
if [ "$#" -ne 2 ]; then
    echo "Error: Invalid number of arguments."
    echo "Usage: $0 <file-slug> <\"file-content\">"
    exit 1
fi

FILE_SLUG=$1
FILE_CONTENT=$2
FILE_PATH=".niopd/data/initiatives/${FILE_SLUG}.md"

# --- File Creation ---
echo "Creating initiative file at: ${FILE_PATH}"

# Write the content to the file. The -e flag allows for interpretation of backslash escapes.
echo -e "$FILE_CONTENT" > "$FILE_PATH"

# --- Verification and Confirmation ---
if [ -f "$FILE_PATH" ]; then
    echo "✅ Success: Initiative file created."
    exit 0
else
    echo "❌ Error: Failed to create initiative file."
    exit 1
fi
