#!/bin/bash

# Script to run tests with automatic log redirection
# Usage: ./claude/scripts/test-and-log.sh path/to/test.py [optional_log_name.log]

if [ $# -eq 0 ]; then
    echo "Usage: $0 <test_file_path> [log_filename]"
    echo "Example: $0 tests/e2e/my_test_name.py"
    echo "Example: $0 tests/e2e/my_test_name.py my_test_name_v2.log"
    exit 1
fi

TEST_PATH="$1"

# Create logs directory if it doesn't exist
mkdir -p tests/logs

# Determine log file name
if [ $# -ge 2 ]; then
    # Use provided log filename (second parameter)
    LOG_NAME="$2"
    # Ensure it ends with .log
    if [[ ! "$LOG_NAME" == *.log ]]; then
        LOG_NAME="${LOG_NAME}.log"
    fi
    LOG_FILE="tests/logs/${LOG_NAME}"
else
    # Extract the test filename without extension for the log name
    TEST_NAME=$(basename "$TEST_PATH" .py)
    LOG_FILE="tests/logs/${TEST_NAME}.log"
fi

# Run the test with output redirection
echo "Running test: $TEST_PATH"
echo "Logging to: $LOG_FILE"
python "$TEST_PATH" > "$LOG_FILE" 2>&1

# Check exit code
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Test completed successfully. Log saved to $LOG_FILE"
else
    echo "❌ Test failed with exit code $EXIT_CODE. Check $LOG_FILE for details"
fi

exit $EXIT_CODE
