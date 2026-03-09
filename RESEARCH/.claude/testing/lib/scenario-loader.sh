#!/bin/bash
# scenario-loader.sh - Parse YAML scenario files for E2E testing
#
# Provides functions to extract scenario configuration including:
# - Metadata (name, description, type)
# - Interrogation Q&A responses
# - Mock credentials
# - Expected outputs for verification

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Global variables set by load_scenario
SCENARIO_NAME=""
SCENARIO_DESCRIPTION=""
SCENARIO_TYPE=""
SCENARIO_EXPECTED_DURATION=""
SCENARIO_FILE=""
SCENARIO_TEMP_DIR=""

# Interrogation responses stored as associative array
declare -A INTERROGATION_RESPONSES

# Expected outputs
declare -a EXPECTED_SCOPE_FILES
EXPECTED_FEATURES_MIN=0
declare -a EXPECTED_FEATURES_MUST_INCLUDE
EXPECTED_PRDS_MIN=0
EXPECTED_PRDS_MAX=100
EXPECTED_JOURNEYS_MIN=0
declare -a EXPECTED_JOURNEYS_MUST_INCLUDE

# Check if yq is available, otherwise use Python
YAML_PARSER=""

detect_yaml_parser() {
    if command -v yq &> /dev/null; then
        YAML_PARSER="yq"
    elif command -v python3 &> /dev/null; then
        YAML_PARSER="python3"
    elif command -v python &> /dev/null; then
        YAML_PARSER="python"
    else
        echo -e "${RED}Error: No YAML parser available. Install yq or Python.${NC}" >&2
        return 1
    fi
}

# Parse YAML value using available parser
# Usage: yaml_get <file> <path>
yaml_get() {
    local file="$1"
    local path="$2"

    if [[ "$YAML_PARSER" == "yq" ]]; then
        yq eval "$path" "$file" 2>/dev/null || echo ""
    else
        # Use Python for YAML parsing
        $YAML_PARSER << PYTHON_EOF
import yaml
import sys

try:
    with open('$file', 'r') as f:
        data = yaml.safe_load(f)

    # Navigate the path
    path = '$path'.strip('.')
    if not path:
        print(yaml.dump(data) if isinstance(data, (dict, list)) else str(data))
        sys.exit(0)

    parts = path.split('.')
    current = data
    for part in parts:
        if part.startswith('[') and part.endswith(']'):
            # Array index
            idx = int(part[1:-1])
            current = current[idx]
        elif isinstance(current, dict):
            current = current.get(part)
        else:
            current = None
            break

    if current is None:
        print("")
    elif isinstance(current, (dict, list)):
        print(yaml.dump(current, default_flow_style=False).strip())
    else:
        print(str(current))
except Exception as e:
    print("", file=sys.stderr)
PYTHON_EOF
    fi
}

# Get array length from YAML
yaml_array_length() {
    local file="$1"
    local path="$2"

    if [[ "$YAML_PARSER" == "yq" ]]; then
        yq eval "$path | length" "$file" 2>/dev/null || echo "0"
    else
        $YAML_PARSER << PYTHON_EOF
import yaml
import sys

try:
    with open('$file', 'r') as f:
        data = yaml.safe_load(f)

    path = '$path'.strip('.')
    parts = path.split('.') if path else []
    current = data
    for part in parts:
        if part.startswith('[') and part.endswith(']'):
            idx = int(part[1:-1])
            current = current[idx]
        elif isinstance(current, dict):
            current = current.get(part, [])
        else:
            current = []
            break

    if isinstance(current, list):
        print(len(current))
    else:
        print(0)
except Exception as e:
    print(0)
PYTHON_EOF
    fi
}

# Get array element from YAML
yaml_array_get() {
    local file="$1"
    local path="$2"
    local index="$3"

    if [[ "$YAML_PARSER" == "yq" ]]; then
        yq eval "${path}[${index}]" "$file" 2>/dev/null || echo ""
    else
        $YAML_PARSER << PYTHON_EOF
import yaml
import sys

try:
    with open('$file', 'r') as f:
        data = yaml.safe_load(f)

    path = '$path'.strip('.')
    parts = path.split('.') if path else []
    current = data
    for part in parts:
        if part.startswith('[') and part.endswith(']'):
            idx = int(part[1:-1])
            current = current[idx]
        elif isinstance(current, dict):
            current = current.get(part, [])
        else:
            current = []
            break

    if isinstance(current, list) and $index < len(current):
        item = current[$index]
        if isinstance(item, (dict, list)):
            print(yaml.dump(item, default_flow_style=False).strip())
        else:
            print(str(item))
    else:
        print("")
except Exception as e:
    print("")
PYTHON_EOF
    fi
}

# Load a scenario file and populate global variables
# Usage: load_scenario <scenario_file>
load_scenario() {
    local scenario_file="$1"

    if [[ ! -f "$scenario_file" ]]; then
        echo -e "${RED}Error: Scenario file not found: $scenario_file${NC}" >&2
        return 1
    fi

    detect_yaml_parser || return 1

    SCENARIO_FILE="$scenario_file"

    # Load metadata
    SCENARIO_NAME=$(yaml_get "$scenario_file" ".metadata.name")
    SCENARIO_DESCRIPTION=$(yaml_get "$scenario_file" ".metadata.description")
    SCENARIO_TYPE=$(yaml_get "$scenario_file" ".metadata.type")
    SCENARIO_EXPECTED_DURATION=$(yaml_get "$scenario_file" ".metadata.expected_duration")

    # Load expected scope files
    EXPECTED_SCOPE_FILES=()
    local scope_count=$(yaml_array_length "$scenario_file" ".expected.scope_files")
    for ((i=0; i<scope_count; i++)); do
        local file=$(yaml_array_get "$scenario_file" ".expected.scope_files" "$i")
        if [[ -n "$file" ]]; then
            EXPECTED_SCOPE_FILES+=("$file")
        fi
    done

    # Load expected features
    EXPECTED_FEATURES_MIN=$(yaml_get "$scenario_file" ".expected.features.min_count")
    EXPECTED_FEATURES_MIN=${EXPECTED_FEATURES_MIN:-0}

    EXPECTED_FEATURES_MUST_INCLUDE=()
    local features_count=$(yaml_array_length "$scenario_file" ".expected.features.must_include")
    for ((i=0; i<features_count; i++)); do
        local feature=$(yaml_array_get "$scenario_file" ".expected.features.must_include" "$i")
        if [[ -n "$feature" ]]; then
            EXPECTED_FEATURES_MUST_INCLUDE+=("$feature")
        fi
    done

    # Load expected PRDs
    EXPECTED_PRDS_MIN=$(yaml_get "$scenario_file" ".expected.prds.min_count")
    EXPECTED_PRDS_MIN=${EXPECTED_PRDS_MIN:-0}
    EXPECTED_PRDS_MAX=$(yaml_get "$scenario_file" ".expected.prds.max_count")
    EXPECTED_PRDS_MAX=${EXPECTED_PRDS_MAX:-100}

    # Load expected journeys
    EXPECTED_JOURNEYS_MIN=$(yaml_get "$scenario_file" ".expected.journeys.min_count")
    EXPECTED_JOURNEYS_MIN=${EXPECTED_JOURNEYS_MIN:-0}

    EXPECTED_JOURNEYS_MUST_INCLUDE=()
    local journeys_count=$(yaml_array_length "$scenario_file" ".expected.journeys.must_include")
    for ((i=0; i<journeys_count; i++)); do
        local journey=$(yaml_array_get "$scenario_file" ".expected.journeys.must_include" "$i")
        if [[ -n "$journey" ]]; then
            EXPECTED_JOURNEYS_MUST_INCLUDE+=("$journey")
        fi
    done

    return 0
}

# Generate a response script for Claude based on interrogation responses
# This creates a file that can be used with `claude --print` or heredoc input
# Usage: generate_response_script <scenario_file> <output_file>
generate_response_script() {
    local scenario_file="$1"
    local output_file="$2"

    detect_yaml_parser || return 1

    if [[ "$YAML_PARSER" == "yq" ]]; then
        # Use yq to extract responses
        yq eval '.interrogation.responses[] | .answer' "$scenario_file" > "$output_file"
    else
        # Use Python
        $YAML_PARSER << PYTHON_EOF
import yaml
import sys

try:
    with open('$scenario_file', 'r') as f:
        data = yaml.safe_load(f)

    responses = data.get('interrogation', {}).get('responses', [])
    with open('$output_file', 'w') as out:
        for resp in responses:
            answer = resp.get('answer', '')
            # Normalize multiline answers
            if isinstance(answer, str):
                out.write(answer.strip() + '\n')
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_EOF
    fi
}

# Generate mock .env file from credentials section
# Usage: generate_mock_env <scenario_file> <output_file>
generate_mock_env() {
    local scenario_file="$1"
    local output_file="$2"

    detect_yaml_parser || return 1

    $YAML_PARSER << PYTHON_EOF
import yaml
import sys

try:
    with open('$scenario_file', 'r') as f:
        data = yaml.safe_load(f)

    credentials = data.get('credentials', {}).get('integrations', [])

    with open('$output_file', 'w') as out:
        out.write("# Auto-generated mock credentials for E2E testing\n")
        out.write("# DO NOT USE IN PRODUCTION\n\n")

        for cred in credentials:
            cred_type = cred.get('type', 'unknown').upper()
            purpose = cred.get('purpose', '')
            out.write(f"# {cred_type}: {purpose}\n")

            values = cred.get('values', {})
            for key, value in values.items():
                env_key = f"{cred_type}_{key.upper()}"
                out.write(f"{env_key}={value}\n")
            out.write("\n")

except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_EOF
}

# Get the full application description for interrogation
# Usage: get_app_description <scenario_file>
get_app_description() {
    local scenario_file="$1"

    detect_yaml_parser || return 1

    $YAML_PARSER << PYTHON_EOF
import yaml

try:
    with open('$scenario_file', 'r') as f:
        data = yaml.safe_load(f)

    desc = data.get('metadata', {}).get('description', '')
    app_type = data.get('metadata', {}).get('type', '')

    # Combine interrogation responses into a full description
    responses = data.get('interrogation', {}).get('responses', [])
    full_desc = f"{desc}\n\nApplication Type: {app_type}\n"

    for resp in responses:
        q = resp.get('question_pattern', '')
        a = resp.get('answer', '')
        full_desc += f"\n{a}\n"

    print(full_desc.strip())
except Exception as e:
    print("")
PYTHON_EOF
}

# Print scenario summary
print_scenario_summary() {
    echo "=== Scenario: $SCENARIO_NAME ==="
    echo "Description: $SCENARIO_DESCRIPTION"
    echo "Type: $SCENARIO_TYPE"
    echo "Expected Duration: $SCENARIO_EXPECTED_DURATION"
    echo ""
    echo "Expected Outputs:"
    echo "  - Scope files: ${#EXPECTED_SCOPE_FILES[@]}"
    echo "  - Features: min $EXPECTED_FEATURES_MIN (must include: ${EXPECTED_FEATURES_MUST_INCLUDE[*]:-none})"
    echo "  - PRDs: $EXPECTED_PRDS_MIN - $EXPECTED_PRDS_MAX"
    echo "  - Journeys: min $EXPECTED_JOURNEYS_MIN (must include: ${EXPECTED_JOURNEYS_MUST_INCLUDE[*]:-none})"
}

# Export functions for use in other scripts
export -f detect_yaml_parser
export -f yaml_get
export -f yaml_array_length
export -f yaml_array_get
export -f load_scenario
export -f generate_response_script
export -f generate_mock_env
export -f get_app_description
export -f print_scenario_summary
