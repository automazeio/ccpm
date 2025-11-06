#!/bin/bash

# Ollama Client Library
# Provides shell functions for interacting with the Ollama HTTP API
#
# Environment Variables:
#   OLLAMA_ENDPOINT - Ollama server endpoint (default: http://localhost:11434)
#   OLLAMA_MODEL - Default model to use (default: deepseek-coder:6.7b)
#   OLLAMA_TIMEOUT - Default timeout in seconds (default: 120)

# Configuration
OLLAMA_ENDPOINT="${OLLAMA_ENDPOINT:-http://localhost:11434}"
OLLAMA_MODEL="${OLLAMA_MODEL:-deepseek-coder:6.7b}"
OLLAMA_TIMEOUT="${OLLAMA_TIMEOUT:-120}"

# Health check timeout (shorter for connectivity tests)
OLLAMA_HEALTH_TIMEOUT=5

# Helper function to check if curl is available
_ollama_check_curl() {
  if ! command -v curl &> /dev/null; then
    echo "ERROR: curl is not installed or not in PATH" >&2
    echo "Please install curl to use Ollama client functions" >&2
    return 1
  fi
  return 0
}

# Helper function to check if jq is available (optional, provides better JSON parsing)
_ollama_has_jq() {
  command -v jq &> /dev/null
}

# Helper function to parse JSON without jq (basic fallback)
_ollama_parse_json_field() {
  local json="$1"
  local field="$2"
  echo "$json" | grep -o "\"$field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed 's/.*"\([^"]*\)"$/\1/'
}

# ollama_health_check - Test connectivity to Ollama server
# Returns: 0 if Ollama is reachable, 1 otherwise
# Stdout: Success/failure message with diagnostics
ollama_health_check() {
  _ollama_check_curl || return 1

  local endpoint="${1:-$OLLAMA_ENDPOINT}"
  local response
  local http_code

  # Try to connect to /api/tags endpoint (lists models, doubles as health check)
  response=$(curl -s -w "\n%{http_code}" --max-time "$OLLAMA_HEALTH_TIMEOUT" \
    "${endpoint}/api/tags" 2>&1)

  local curl_exit=$?
  http_code=$(echo "$response" | tail -n1)

  # Check for curl errors
  if [ $curl_exit -ne 0 ]; then
    echo "ERROR: Cannot connect to Ollama at ${endpoint}" >&2
    echo "" >&2

    if echo "$response" | grep -q "Connection refused"; then
      echo "Connection refused - Ollama may not be running" >&2
      echo "" >&2
      echo "To fix:" >&2
      echo "  1. Check if Ollama is running: ps aux | grep ollama" >&2
      echo "  2. Start Ollama: ollama serve" >&2
      echo "  3. Or check if running on different port" >&2
    elif echo "$response" | grep -q "timed out"; then
      echo "Connection timed out after ${OLLAMA_HEALTH_TIMEOUT}s" >&2
      echo "" >&2
      echo "To fix:" >&2
      echo "  1. Check network connectivity" >&2
      echo "  2. Verify endpoint URL: ${endpoint}" >&2
      echo "  3. Check if firewall is blocking the connection" >&2
    elif echo "$response" | grep -q "Could not resolve host"; then
      echo "Could not resolve host - Invalid endpoint URL" >&2
      echo "" >&2
      echo "To fix:" >&2
      echo "  1. Check OLLAMA_ENDPOINT value: ${endpoint}" >&2
      echo "  2. Ensure hostname is correct" >&2
      echo "  3. Try using IP address instead of hostname" >&2
    else
      echo "Curl error (exit code: $curl_exit)" >&2
      echo "" >&2
      echo "To fix:" >&2
      echo "  1. Check Ollama is running: ollama serve" >&2
      echo "  2. Verify endpoint: ${endpoint}" >&2
      echo "  3. Check system logs for errors" >&2
    fi
    return 1
  fi

  # Check HTTP response code
  if [ "$http_code" != "200" ]; then
    echo "ERROR: Ollama returned HTTP $http_code" >&2
    echo "" >&2
    echo "To fix:" >&2
    echo "  1. Verify Ollama is running properly" >&2
    echo "  2. Check Ollama logs for errors" >&2
    echo "  3. Try restarting Ollama service" >&2
    return 1
  fi

  # Success
  echo "SUCCESS: Ollama is healthy at ${endpoint}"
  return 0
}

# ollama_list_models - List available models
# Returns: 0 on success, 1 on failure
# Stdout: JSON array of model objects or formatted list
# Usage: ollama_list_models [endpoint] [format]
#   endpoint - Optional Ollama endpoint (default: $OLLAMA_ENDPOINT)
#   format - Optional: "json" for raw JSON, "names" for model names only (default: json)
ollama_list_models() {
  _ollama_check_curl || return 1

  local endpoint="${1:-$OLLAMA_ENDPOINT}"
  local format="${2:-json}"
  local response
  local http_code

  # Call /api/tags to list models
  response=$(curl -s -w "\n%{http_code}" --max-time "$OLLAMA_HEALTH_TIMEOUT" \
    "${endpoint}/api/tags" 2>&1)

  local curl_exit=$?
  http_code=$(echo "$response" | tail -n1)
  local body=$(echo "$response" | sed '$d')

  # Check for curl errors
  if [ $curl_exit -ne 0 ]; then
    echo "ERROR: Cannot connect to Ollama at ${endpoint}" >&2
    echo "Run ollama_health_check for diagnostics" >&2
    return 1
  fi

  # Check HTTP response code
  if [ "$http_code" != "200" ]; then
    echo "ERROR: Ollama returned HTTP $http_code" >&2
    echo "Response: $body" >&2
    return 1
  fi

  # Check if response contains models
  if ! echo "$body" | grep -q '"models"'; then
    echo "ERROR: No models found in response" >&2
    echo "" >&2
    echo "To fix:" >&2
    echo "  1. Pull a model: ollama pull ${OLLAMA_MODEL}" >&2
    echo "  2. List available models: ollama list" >&2
    return 1
  fi

  # Output based on format
  case "$format" in
    json)
      echo "$body"
      ;;
    names)
      if _ollama_has_jq; then
        echo "$body" | jq -r '.models[].name'
      else
        # Fallback parsing without jq
        echo "$body" | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/'
      fi
      ;;
    *)
      echo "ERROR: Invalid format '$format'. Use 'json' or 'names'" >&2
      return 1
      ;;
  esac

  return 0
}

# ollama_generate - Generate code/text using Ollama
# Parameters:
#   model - Model name (e.g., "codellama:7b")
#   prompt - Text prompt for generation
#   options - Optional JSON string with additional parameters
# Returns: 0 on success, 1 on failure
# Stdout: Streaming response chunks (each line is a JSON object)
# Usage: ollama_generate "model-name" "prompt text" '{"temperature": 0.7}'
ollama_generate() {
  _ollama_check_curl || return 1

  local model="$1"
  local prompt="$2"
  local options="$3"
  local endpoint="${OLLAMA_ENDPOINT}"
  local timeout="${OLLAMA_TIMEOUT}"

  # Validate required parameters
  if [ -z "$model" ]; then
    echo "ERROR: Model parameter is required" >&2
    echo "Usage: ollama_generate MODEL PROMPT [OPTIONS]" >&2
    return 1
  fi

  if [ -z "$prompt" ]; then
    echo "ERROR: Prompt parameter is required" >&2
    echo "Usage: ollama_generate MODEL PROMPT [OPTIONS]" >&2
    return 1
  fi

  # Build JSON request body using jq if available (safer)
  local request_body
  if _ollama_has_jq; then
    if [ -z "$options" ]; then
      request_body=$(jq -n --arg model "$model" --arg prompt "$prompt" \
        '{model: $model, prompt: $prompt, stream: true}')
    else
      # Validate options is valid JSON before using --argjson
      if echo "$options" | jq empty 2>/dev/null; then
        request_body=$(jq -n --arg model "$model" --arg prompt "$prompt" --argjson opts "$options" \
          '{model: $model, prompt: $prompt, stream: true, options: $opts}')
      else
        echo "ERROR: Invalid JSON in options parameter" >&2
        return 1
      fi
    fi
  else
    # Fallback: Manual JSON escaping (basic, handles most common cases)
    local escaped_prompt=$(printf '%s' "$prompt" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    if [ -z "$options" ]; then
      request_body="{\"model\":\"$model\",\"prompt\":\"$escaped_prompt\",\"stream\":true}"
    else
      request_body="{\"model\":\"$model\",\"prompt\":\"$escaped_prompt\",\"stream\":true,\"options\":$options}"
    fi
  fi

  # Create temporary file for response
  local temp_response=$(mktemp)
  local temp_stderr=$(mktemp)

  # Make the request with streaming
  curl -s -w "\n%{http_code}" --max-time "$timeout" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$request_body" \
    "${endpoint}/api/generate" 2>"$temp_stderr" > "$temp_response"

  local curl_exit=$?
  local http_code=$(tail -n1 "$temp_response")

  # Check for curl errors
  if [ $curl_exit -ne 0 ]; then
    echo "ERROR: Request to Ollama failed" >&2

    local stderr_content=$(cat "$temp_stderr")
    if echo "$stderr_content" | grep -q "timed out"; then
      echo "Request timed out after ${timeout}s" >&2
      echo "" >&2
      echo "To fix:" >&2
      echo "  1. Increase timeout: export OLLAMA_TIMEOUT=300" >&2
      echo "  2. Try a smaller/faster model" >&2
      echo "  3. Reduce prompt complexity" >&2
    elif echo "$stderr_content" | grep -q "Connection refused"; then
      echo "Connection refused - Ollama may not be running" >&2
      echo "" >&2
      echo "To fix:" >&2
      echo "  1. Start Ollama: ollama serve" >&2
      echo "  2. Run health check: ollama_health_check" >&2
    else
      echo "Curl error (exit code: $curl_exit)" >&2
      echo "Details: $stderr_content" >&2
    fi

    rm -f "$temp_response" "$temp_stderr"
    return 1
  fi

  # Check HTTP response code
  if [ "$http_code" != "200" ]; then
    echo "ERROR: Ollama returned HTTP $http_code" >&2

    # Try to extract error message from response
    local error_body=$(sed '$d' "$temp_response")
    if echo "$error_body" | grep -q '"error"'; then
      if _ollama_has_jq; then
        local error_msg=$(echo "$error_body" | jq -r '.error // "Unknown error"')
        echo "Error: $error_msg" >&2
      else
        echo "Response: $error_body" >&2
      fi

      # Provide specific guidance for common errors
      if echo "$error_body" | grep -q "model.*not found"; then
        echo "" >&2
        echo "To fix:" >&2
        echo "  1. Check available models: ollama list" >&2
        echo "  2. Pull the model: ollama pull $model" >&2
        echo "  3. Use a different model" >&2
      fi
    fi

    rm -f "$temp_response" "$temp_stderr"
    return 1
  fi

  # Output the streaming response (exclude the HTTP code line)
  sed '$d' "$temp_response"

  # Check if we got a complete response by looking for "done":true
  if ! grep -q '"done"[[:space:]]*:[[:space:]]*true' "$temp_response"; then
    echo "" >&2
    echo "WARNING: Response may be incomplete" >&2
  fi

  rm -f "$temp_response" "$temp_stderr"
  return 0
}

# ollama_generate_simple - Generate with simple text output (non-streaming view)
# Parameters: Same as ollama_generate
# Returns: 0 on success, 1 on failure
# Stdout: Complete generated text (assembled from streaming chunks)
# Usage: ollama_generate_simple "model-name" "prompt text"
ollama_generate_simple() {
  local model="$1"
  local prompt="$2"
  local options="$3"

  local response
  if [ -z "$options" ]; then
    response=$(ollama_generate "$model" "$prompt")
  else
    response=$(ollama_generate "$model" "$prompt" "$options")
  fi
  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    return $exit_code
  fi

  # Extract and concatenate response text from streaming chunks
  if _ollama_has_jq; then
    echo "$response" | jq -r 'select(.response != null) | .response' | tr -d '\n'
  else
    # Fallback: extract response field from each JSON line
    echo "$response" | grep -o '"response"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/' | tr -d '\n'
  fi

  echo ""  # Add final newline
  return 0
}

# ollama_check_model - Check if a specific model is available
# Parameters:
#   model - Model name to check
# Returns: 0 if model exists, 1 otherwise
# Stdout: Success/failure message
ollama_check_model() {
  local model="$1"

  if [ -z "$model" ]; then
    echo "ERROR: Model parameter is required" >&2
    return 1
  fi

  local models
  models=$(ollama_list_models "$OLLAMA_ENDPOINT" "names" 2>&1)

  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to list models" >&2
    echo "$models" >&2
    return 1
  fi

  if echo "$models" | grep -q "^${model}$"; then
    echo "Model '$model' is available"
    return 0
  else
    echo "ERROR: Model '$model' not found" >&2
    echo "" >&2
    echo "Available models:" >&2
    echo "$models" >&2
    echo "" >&2
    echo "To install: ollama pull $model" >&2
    return 1
  fi
}

# Export functions for use in other scripts
export -f ollama_health_check
export -f ollama_list_models
export -f ollama_generate
export -f ollama_generate_simple
export -f ollama_check_model
