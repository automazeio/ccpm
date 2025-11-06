#!/bin/bash

set -e

SETTINGS_FILE=".claude/settings.json"
OLLAMA_ENDPOINT="${OLLAMA_ENDPOINT:-http://localhost:11434}"
OLLAMA_MODEL="${OLLAMA_MODEL:-codellama:7b}"

if [ -f "$SETTINGS_FILE" ]; then
  CONFIG_ENDPOINT=$(jq -r '.local_llm.endpoint // "http://localhost:11434"' "$SETTINGS_FILE" 2>/dev/null || echo "http://localhost:11434")
  CONFIG_MODEL=$(jq -r '.local_llm.model // "codellama:7b"' "$SETTINGS_FILE" 2>/dev/null || echo "codellama:7b")

  OLLAMA_ENDPOINT="${OLLAMA_ENDPOINT:-$CONFIG_ENDPOINT}"
  OLLAMA_MODEL="${OLLAMA_MODEL:-$CONFIG_MODEL}"
fi

echo ""
echo "Ollama Health Check"
echo "==================="
echo ""

HEALTH_STATUS=0

echo "Testing connectivity..."
echo "Endpoint: $OLLAMA_ENDPOINT"
echo ""

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl is not installed"
  echo "Please install curl to use this health check"
  exit 1
fi

START_TIME=$(date +%s)
if curl -s --max-time 5 "$OLLAMA_ENDPOINT/api/version" >/dev/null 2>&1; then
  END_TIME=$(date +%s)
  RESPONSE_TIME=$((END_TIME - START_TIME))
  echo "Connection: OK"
  if [ $RESPONSE_TIME -eq 0 ]; then
    echo "Response Time: <1s"
  else
    echo "Response Time: ${RESPONSE_TIME}s"
  fi
else
  echo "Connection: FAILED"
  echo ""
  echo "Ollama is not running or not accessible at $OLLAMA_ENDPOINT"
  echo ""
  echo "Troubleshooting steps:"
  echo "  1. Check if Ollama is installed:"
  echo "     $ ollama --version"
  echo ""
  echo "  2. If not installed, visit: https://ollama.ai/download"
  echo ""
  echo "  3. Start Ollama service:"
  echo "     $ ollama serve"
  echo ""
  echo "  4. If using a different endpoint, set environment variable:"
  echo "     $ export OLLAMA_ENDPOINT=http://your-host:port"
  echo ""
  echo "Status: UNHEALTHY"
  exit 1
fi

echo ""
echo "Configured Model: $OLLAMA_MODEL"

if curl -s --max-time 5 "$OLLAMA_ENDPOINT/api/tags" >/dev/null 2>&1; then
  MODELS_JSON=$(curl -s "$OLLAMA_ENDPOINT/api/tags")

  if echo "$MODELS_JSON" | jq -e ".models[] | select(.name == \"$OLLAMA_MODEL\")" >/dev/null 2>&1; then
    echo "Model Available: YES"
  else
    echo "Model Available: NO"
    echo ""
    echo "The configured model '$OLLAMA_MODEL' is not available."
    echo ""
    echo "To pull the model, run:"
    echo "  $ ollama pull $OLLAMA_MODEL"
    echo ""
    HEALTH_STATUS=1
  fi

  echo ""
  echo "Available Models:"
  echo "$MODELS_JSON" | jq -r '.models[].name' 2>/dev/null | while read -r model; do
    echo "  - $model"
  done || echo "  (Unable to parse models list)"
else
  echo "Model Check: SKIPPED (API not accessible)"
  HEALTH_STATUS=1
fi

echo ""
if [ $HEALTH_STATUS -eq 0 ]; then
  echo "Status: HEALTHY"
  echo ""
  echo "Your Ollama setup is ready to use!"
else
  echo "Status: UNHEALTHY"
  echo ""
  echo "Please address the issues above before using local LLM features."
fi

exit $HEALTH_STATUS
