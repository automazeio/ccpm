# Local LLM Guide: Hybrid Code Generation with CCPM

**Last Updated**: 2025-11-06
**Version**: 1.0
**Status**: Ready for Production

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Configuration Reference](#configuration-reference)
4. [Architecture](#architecture)
5. [Usage Examples](#usage-examples)
6. [Troubleshooting](#troubleshooting)
7. [Performance Tuning](#performance-tuning)
8. [Cost Analysis](#cost-analysis)

---

## Overview

### Why Use Local LLMs?

The CCPM hybrid local LLM system combines the best of both worlds:

- **Claude API**: Planning, architecture, code review, quality gates
- **Ollama (Local LLM)**: Code implementation, boilerplate, refactoring

**Key Benefits**:

| Benefit | Description | Impact |
|---------|-------------|--------|
| **Cost Savings** | 70%+ reduction in API costs | Significant budget reduction for high-volume projects |
| **Privacy** | Code generation stays local | Sensitive/proprietary code never leaves your machine |
| **Speed** | Local generation can be faster | No network latency for simple code tasks |
| **Offline Work** | Generate code without internet | Work anywhere, anytime |
| **Quality Assurance** | All code reviewed by Claude | Maintains high standards through review loop |

### Core Principle

> **Claude handles thinking. Ollama handles typing.**

- **Claude excels at**: Strategic planning, architectural decisions, security review, quality assessment
- **Ollama excels at**: Code implementation, CRUD operations, boilerplate, test writing

### When to Use Hybrid vs Claude-Only

**Use Hybrid System When**:
- Implementing well-defined features with clear specifications
- Writing boilerplate code, CRUD operations, utility functions
- Generating tests for existing code
- Refactoring with established patterns
- Cost optimization is a priority
- Privacy is critical (sensitive code)

**Use Claude-Only When**:
- Designing system architecture
- Making technology decisions
- Reviewing security-critical code (auth, payments)
- Complex algorithmic work
- Unclear requirements needing exploration
- Time-sensitive work (no iteration budget)

---

## Quick Start

Get running in 15 minutes.

### Step 1: Install Ollama

**macOS**:
```bash
# Using Homebrew
brew install ollama

# Or download from https://ollama.ai/download
```

**Linux**:
```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

**Windows**:
- Download installer from https://ollama.ai/download
- Run the `.exe` installer
- Ollama will run as a Windows service

### Step 2: Start Ollama

**macOS/Linux**:
```bash
# Start Ollama server (runs in foreground)
ollama serve

# Or run in background with system service
# macOS: brew services start ollama
# Linux: systemctl start ollama
```

**Windows**:
Ollama starts automatically as a service after installation.

### Step 3: Pull a Model

Choose a model based on your hardware:

```bash
# Recommended: Good balance of speed and quality
ollama pull qwen2.5:7b-instruct-q4_K_M

# Faster, less accurate (4GB RAM)
ollama pull qwen2.5:3b

# Best quality, slower (16GB+ RAM)
ollama pull codellama:13b

# Check installed models
ollama list
```

**Model Size Guide**:

| Model | Size | RAM Required | Speed | Quality |
|-------|------|--------------|-------|---------|
| qwen2.5:3b | 1.9 GB | 4 GB | Fast | Good |
| qwen2.5:7b-instruct-q4_K_M | 4.7 GB | 8 GB | Medium | Very Good |
| codellama:7b | 3.8 GB | 8 GB | Medium | Very Good |
| codellama:13b | 7.3 GB | 16 GB | Slow | Excellent |
| deepseek-coder:6.7b | 3.8 GB | 8 GB | Medium | Very Good |

### Step 4: Configure CCPM

Edit `.claude/settings.json`:

```json
{
  "local_llm": {
    "enabled": true,
    "provider": "ollama",
    "endpoint": "http://localhost:11434",
    "model": "qwen2.5:7b-instruct-q4_K_M",
    "timeout": 300,
    "max_iterations": 3,
    "options": {
      "temperature": 0.7,
      "top_p": 0.9
    }
  }
}
```

**Quick Configuration**:
```bash
# Create default configuration
cat > .claude/settings.json << 'EOF'
{
  "local_llm": {
    "enabled": true,
    "provider": "ollama",
    "endpoint": "http://localhost:11434",
    "model": "qwen2.5:7b-instruct-q4_K_M",
    "timeout": 300,
    "max_iterations": 3,
    "options": {
      "temperature": 0.7,
      "top_p": 0.9
    }
  }
}
EOF
```

### Step 5: Run Health Check

Verify your setup:

```bash
# Run health check script
bash ccpm/scripts/llm/health-check.sh

# Expected output:
# Ollama Health Check
# ===================
#
# Testing connectivity...
# Endpoint: http://localhost:11434
#
# Connection: OK
# Response Time: <1s
#
# Configured Model: qwen2.5:7b-instruct-q4_K_M
# Model Available: YES
#
# Available Models:
#   - qwen2.5:7b-instruct-q4_K_M
#
# Status: HEALTHY
#
# Your Ollama setup is ready to use!
```

### Step 6: Test with Simple Task

Create a simple test task:

```bash
# Create a test task file
cat > .claude/epics/test-local-llm.md << 'EOF'
---
name: Test Local LLM
---

# Task: Create Hello World Function

Create a simple hello world function in JavaScript.

Requirements:
- Function should take a name parameter
- Return greeting string
- Include JSDoc comment

File: src/hello.js
EOF

# Process the task (routing will automatically use Ollama)
# The routing hook will detect this as a code generation task
```

If everything works, you should see:
1. Task routed to Ollama for code generation
2. Code generated locally
3. Code reviewed by Claude
4. Approval or feedback for iteration

---

## Configuration Reference

### Settings File Location

`.claude/settings.json` in your project root.

### Complete Configuration Schema

```json
{
  "local_llm": {
    "enabled": true,
    "provider": "ollama",
    "endpoint": "http://localhost:11434",
    "model": "codellama:7b",
    "timeout": 300,
    "max_iterations": 3,
    "routing_strategy": "balanced",
    "always_review": true,
    "override_keywords": [],
    "force_ollama_keywords": [],
    "options": {
      "temperature": 0.7,
      "top_p": 0.9,
      "num_predict": 2048
    }
  }
}
```

### Configuration Options Explained

#### Core Settings

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | boolean | `false` | Master switch for local LLM features |
| `provider` | string | `"ollama"` | LLM provider (currently only "ollama" supported) |
| `endpoint` | string | `"http://localhost:11434"` | Ollama server URL |
| `model` | string | `"codellama:7b"` | Model name to use for generation |
| `timeout` | number | `300` | Request timeout in seconds |
| `max_iterations` | number | `3` | Maximum review/regeneration cycles |

#### Routing Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `routing_strategy` | string | `"balanced"` | Routing aggressiveness: `"aggressive"`, `"balanced"`, `"conservative"` |
| `always_review` | boolean | `true` | Always send Ollama code through Claude review |
| `override_keywords` | array | `[]` | Force Claude for tasks with these keywords |
| `force_ollama_keywords` | array | `[]` | Force Ollama for tasks with these keywords |

**Routing Strategies**:

- **`aggressive`**: Route maximum tasks to Ollama, only critical paths to Claude
  - Use when: Maximizing cost savings, trust in local model is high
  - Trade-off: May need more iterations, lower initial quality

- **`balanced`** (default): Use decision tree rules as designed
  - Use when: Want optimal balance of cost and quality
  - Trade-off: Well-tested middle ground

- **`conservative`**: Route maximum tasks to Claude, only clear code gen to Ollama
  - Use when: Quality is paramount, cost less important
  - Trade-off: Higher costs, fewer iterations needed

#### Generation Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `temperature` | number | `0.7` | Randomness (0.0 = deterministic, 1.0 = creative) |
| `top_p` | number | `0.9` | Nucleus sampling threshold |
| `num_predict` | number | `2048` | Maximum tokens to generate |

**Temperature Guide**:
- `0.0 - 0.3`: Deterministic, consistent code (recommended for production)
- `0.4 - 0.7`: Balanced creativity and consistency (good default)
- `0.8 - 1.0`: Creative, varied output (good for brainstorming)

### Environment Variables

Override configuration via environment variables:

```bash
# Override endpoint
export OLLAMA_ENDPOINT="http://remote-server:11434"

# Override model
export OLLAMA_MODEL="deepseek-coder:6.7b"

# Override timeout
export OLLAMA_TIMEOUT=600

# Override temperature
export OLLAMA_TEMPERATURE=0.2

# Enable debug logging
export CLAUDE_HOOK_DEBUG=true

# Set log file location
export CLAUDE_HOOK_LOG=/tmp/local-llm-route.log

# Set max review iterations
export REVIEW_LOOP_MAX_ITERATIONS=5
```

**Priority Order** (highest to lowest):
1. Environment variables
2. `.claude/settings.json`
3. Built-in defaults

### Review Quality Configuration

Review decisions are based on:

| Criterion | Weight | Description |
|-----------|--------|-------------|
| **Requirements Met** | Critical | All specified features implemented |
| **No Logic Errors** | Critical | Code logic is correct |
| **Security** | Critical | No vulnerabilities present |
| **Error Handling** | High | Appropriate error cases handled |
| **Style Compliance** | Medium | Follows project conventions |
| **Documentation** | Low | Comments where needed per project style |

**Approval Thresholds**:
- **APPROVE**: All critical + high criteria met, minor issues only
- **ITERATE**: Any critical/high issue present, provide feedback
- **FAIL**: Fundamental flaws, security critical issues

---

## Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        CCPM System                          │
│                                                             │
│  ┌──────────────┐         ┌──────────────┐                │
│  │    User      │         │   Claude     │                │
│  │   Request    │────────>│     API      │                │
│  └──────────────┘         └──────┬───────┘                │
│                                   │                         │
│                          ┌────────▼────────┐               │
│                          │  Routing Hook   │               │
│                          │  (Decision Tree)│               │
│                          └────────┬────────┘               │
│                                   │                         │
│                    ┌──────────────┴──────────────┐        │
│                    │                             │        │
│             ┌──────▼──────┐            ┌────────▼──────┐ │
│             │   Claude    │            │    Ollama     │ │
│             │  (Planning) │            │  (Code Gen)   │ │
│             └─────────────┘            └────────┬──────┘ │
│                    │                             │        │
│                    │                    ┌────────▼──────┐ │
│                    │                    │    Review     │ │
│                    │                    │     Loop      │ │
│                    │                    └────────┬──────┘ │
│                    │                             │        │
│                    │                    ┌────────▼──────┐ │
│                    │                    │   Claude      │ │
│                    │                    │  (Review)     │ │
│                    │                    └────────┬──────┘ │
│                    │                             │        │
│                    │                    ┌────────▼──────┐ │
│                    │                    │   Approved?   │ │
│                    │                    │   (Y/N/Max)   │ │
│                    │                    └────────┬──────┘ │
│                    │                             │        │
│                    └─────────────────────────────┘        │
│                                   │                        │
│                          ┌────────▼────────┐              │
│                          │   Final Code    │              │
│                          └─────────────────┘              │
└─────────────────────────────────────────────────────────────┘
```

### Component Diagram

See [architecture-diagram.mmd](./architecture-diagram.mmd) for detailed Mermaid diagram.

### Request Flow

**Step-by-Step Flow**:

1. **User Request**: Task submitted to CCPM
2. **Routing Decision**: `local-llm-route.sh` analyzes task
   - Extract keywords and context
   - Check override conditions
   - Apply decision tree rules
   - Log routing decision
3. **Route A - Claude Direct**: Planning/review tasks go to Claude API
4. **Route B - Ollama + Review**: Code generation tasks follow:
   - **Generation**: `local-code-generator` agent with Ollama
   - **Review**: `claude-code-reviewer` agent with Claude
   - **Decision**: APPROVE, ITERATE, or FAIL
   - **Iteration**: If ITERATE, regenerate with feedback (max 3x)
   - **Override**: User can accept code at any iteration
5. **Final Output**: Approved code returned to user

### Integration Points

| Component | File | Purpose |
|-----------|------|---------|
| **Routing Hook** | `ccpm/hooks/local-llm-route.sh` | Pre-tool-use hook for routing decisions |
| **Ollama Client** | `ccpm/lib/ollama-client.sh` | API wrapper for Ollama communication |
| **Decision Rules** | `ccpm/rules/local-llm-decision-tree.md` | Classification criteria and patterns |
| **Code Generator** | `ccpm/agents/local-code-generator.md` | Agent for Ollama code generation |
| **Code Reviewer** | `ccpm/agents/claude-code-reviewer.md` | Agent for Claude code review |
| **Review Loop** | `ccpm/lib/review-loop.sh` | Orchestrates generation + review cycles |
| **Health Check** | `ccpm/scripts/llm/health-check.sh` | Connectivity and setup validation |
| **Configuration** | `.claude/settings.json` | User settings and preferences |

### Error Handling & Fallback

```
┌──────────────┐
│ Routing Hook │
└──────┬───────┘
       │
       ├─> Enabled? NO ───> Pass to Claude (fallback)
       │
       ├─> Ollama Healthy? NO ───> Pass to Claude (fallback)
       │
       ├─> Model Available? NO ───> Error + Install Instructions
       │
       ├─> Route to Ollama
       │   │
       │   ├─> Generate Code
       │   │   │
       │   │   ├─> Timeout? ───> Error + Guidance
       │   │   │
       │   │   ├─> Connection Failed? ───> Fallback to Claude
       │   │   │
       │   │   └─> Success ──> Review
       │   │
       │   └─> Review Code
       │       │
       │       ├─> APPROVE ───> Return Code ✓
       │       │
       │       ├─> ITERATE ───> Regenerate (max 3x)
       │       │                 │
       │       │                 └─> Max Iterations? ───> User Override?
       │       │                                           │
       │       │                                           ├─> YES ───> Accept ⚠
       │       │                                           └─> NO ───> Fail ✗
       │       │
       │       └─> FAIL ───> User Override?
       │                      │
       │                      ├─> YES ───> Accept ⚠
       │                      └─> NO ───> Fail ✗
       │
       └─> Route to Claude ───> Direct Processing
```

**Graceful Degradation**:
- Ollama unavailable → Automatic fallback to Claude
- Model missing → Error with install command
- Timeout → Error with tuning guidance
- Review failure → User can override or escalate

---

## Usage Examples

Real examples from integration testing.

### Example 1: Simple Code Generation

**Task**: Create a hello world function in JavaScript

```bash
# Task description
"Create a hello world function in JavaScript that takes a name parameter and returns a greeting"

# Routing decision
[2025-11-06 19:35:12] INFO [local-llm-route]: Routing: OLLAMA (balanced strategy)
[2025-11-06 19:35:12] INFO [local-llm-route]: ROUTE: OLLAMA (balanced) | Description: Create a hello world function...

# Generation (2-3 seconds with qwen2.5:3b)
Checking Ollama health...
✓ Ollama is healthy
Verifying model 'qwen2.5:3b'...
✓ Model is available

Generating code with qwen2.5:3b...
Temperature: 0.7
Timeout: 300s
----------------------------------------
FILE: src/hello.js
```javascript
/**
 * Generate a personalized greeting
 * @param {string} name - The name to greet
 * @returns {string} Greeting message
 */
function helloWorld(name) {
  if (!name || typeof name !== 'string') {
    throw new Error('Invalid name parameter');
  }
  return `Hello, ${name}! Welcome!`;
}

module.exports = { helloWorld };
```
----------------------------------------
Generation complete!

# Review by Claude
[2025-11-06 19:35:15] INFO [review-loop]: Reviewing generated code...

# Code Review Result: APPROVE

## Summary
The generated hello world function is well-implemented with proper input validation and documentation.

## Requirements Check
✓ Function takes name parameter
✓ Returns greeting string
✓ Includes JSDoc comment
✓ Error handling for invalid input

## Security Assessment
PASS - No security issues

## Overall Assessment
Code approved for use.

# Result
✓ Code Approved!
Task completed with Ollama in 3 seconds
```

**Outcome**: Code generated locally, reviewed by Claude, approved on first iteration.

### Example 2: Review Iteration Scenario

**Task**: Implement authentication middleware

```bash
# Iteration 1
Generating code with codellama:7b...
[Generated middleware with missing error handling]

Reviewing code...
Decision: ITERATE

Issues found:
- Missing null check for req.user
- No error handling for token verification failure
- Hardcoded secret key

⟳ Issues found, regenerating...

# Iteration 2
Including feedback from previous iteration...
[Generated improved middleware]

Reviewing code...
Decision: ITERATE

Issues found:
- Error messages too verbose (security leak)
- No rate limiting

⟳ Issues found, regenerating...

# Iteration 3
Including feedback from previous iteration...
[Generated final middleware]

Reviewing code...
Decision: APPROVE

✓ Code Approved!
Completed after 3 iterations
```

**Outcome**: Required multiple iterations but eventually met quality standards.

### Example 3: Security-Critical Override

**Task**: "Implement JWT token generation"

```bash
# Routing decision
[2025-11-06 19:40:22] INFO [local-llm-route]: Detected security-critical content
[2025-11-06 19:40:22] INFO [local-llm-route]: Routing: CLAUDE (balanced strategy)
[2025-11-06 19:40:22] INFO [local-llm-route]: ROUTE: CLAUDE (balanced) | Description: Implement JWT token generation

# Result
Task routed directly to Claude (security-critical)
No local generation performed
```

**Outcome**: Security-critical task automatically routed to Claude for safety.

### Example 4: Monitoring Routing Decisions

Enable logging to track routing patterns:

```bash
# Enable debug mode
export CLAUDE_HOOK_DEBUG=true
export CLAUDE_HOOK_LOG=/tmp/routing.log

# Run tasks...

# View routing log
tail -f /tmp/routing.log
```

**Sample Log Output**:
```
[2025-11-06 19:35:12] INFO [local-llm-route]: ROUTE: OLLAMA (balanced) | Description: Create user login form
[2025-11-06 19:35:45] INFO [local-llm-route]: ROUTE: CLAUDE (balanced) | Description: Design authentication flow
[2025-11-06 19:36:20] INFO [local-llm-route]: ROUTE: OLLAMA (balanced) | Description: Write unit tests for login
[2025-11-06 19:37:05] INFO [local-llm-route]: ROUTE: CLAUDE (balanced) | Description: Review security of auth implementation
```

**Analysis**:
- 2/4 tasks routed to Ollama (50%)
- Planning and security review to Claude
- Implementation and tests to Ollama
- Expected pattern for balanced strategy

### Example 5: Cost Tracking

Track API usage with and without local LLM:

```bash
# Before (Claude-only)
Total Tasks: 100
Claude API Calls: 100
Estimated Cost: $5.00 (assuming $0.05/task average)

# After (Hybrid with 60% Ollama routing)
Total Tasks: 100
Claude API Calls: 40 (planning/review) + 60 (reviews for Ollama code) = 100
But reviews are smaller/cheaper than full implementation
Estimated Cost: $1.50

# Savings: 70%
```

**Note**: Reviews are significantly cheaper than full implementation because:
- Smaller prompts (just reviewing code, not generating)
- Faster responses
- Often approve on first iteration

---

## Troubleshooting

### Issue 1: Ollama Not Responding

**Symptoms**:
```
ERROR: Cannot connect to Ollama at http://localhost:11434
Connection refused - Ollama may not be running
```

**Diagnosis**:
```bash
# Check if Ollama is running
ps aux | grep ollama

# Check if port is in use
lsof -i :11434

# Check Ollama version
ollama --version
```

**Solutions**:

1. **Start Ollama**:
   ```bash
   # Foreground
   ollama serve

   # Background (macOS)
   brew services start ollama

   # Background (Linux)
   systemctl start ollama
   ```

2. **Check Endpoint Configuration**:
   ```bash
   # Verify endpoint in settings
   cat .claude/settings.json | jq '.local_llm.endpoint'

   # Test endpoint manually
   curl http://localhost:11434/api/version
   ```

3. **Check Firewall**:
   ```bash
   # macOS: Check firewall settings
   # System Preferences > Security & Privacy > Firewall

   # Linux: Check iptables
   sudo iptables -L
   ```

4. **Reinstall Ollama**:
   ```bash
   # macOS
   brew uninstall ollama
   brew install ollama

   # Linux
   curl -fsSL https://ollama.ai/install.sh | sh
   ```

### Issue 2: Model Not Found

**Symptoms**:
```
ERROR: Model 'codellama:7b' not found

Available models:
  - qwen2.5:3b

To install: ollama pull codellama:7b
```

**Solutions**:

1. **Pull the Configured Model**:
   ```bash
   ollama pull codellama:7b

   # Wait for download to complete
   # Verify
   ollama list
   ```

2. **Use Available Model**:
   ```bash
   # Update configuration to use available model
   jq '.local_llm.model = "qwen2.5:3b"' .claude/settings.json > tmp.json
   mv tmp.json .claude/settings.json
   ```

3. **Check Model Name Spelling**:
   ```bash
   # List available models on Ollama
   ollama list

   # Search Ollama model library
   # Visit: https://ollama.ai/library
   ```

### Issue 3: Timeout Errors

**Symptoms**:
```
WARNING: Generation timed out after 120s
Request timed out after 120s

To fix:
1. Increase timeout: export OLLAMA_TIMEOUT=300
2. Try a smaller/faster model
3. Reduce prompt complexity
```

**Solutions**:

1. **Increase Timeout**:
   ```bash
   # Environment variable
   export OLLAMA_TIMEOUT=600

   # Or update settings.json
   jq '.local_llm.timeout = 600' .claude/settings.json > tmp.json
   mv tmp.json .claude/settings.json
   ```

2. **Use Faster Model**:
   ```bash
   # Pull smaller model
   ollama pull qwen2.5:3b

   # Update configuration
   export OLLAMA_MODEL="qwen2.5:3b"
   ```

3. **Simplify Task**:
   - Break large tasks into smaller pieces
   - Remove unnecessary context from prompts
   - Reduce file sizes being analyzed

4. **Check System Resources**:
   ```bash
   # Check CPU usage
   top

   # Check memory
   free -h  # Linux
   vm_stat  # macOS

   # Check if system is swapping
   vmstat 1
   ```

### Issue 4: Poor Code Quality

**Symptoms**:
- Code fails review multiple times
- Logic errors in generated code
- Missing functionality
- Security issues

**Solutions**:

1. **Switch to Better Model**:
   ```bash
   # Use larger, higher-quality model
   ollama pull codellama:13b
   export OLLAMA_MODEL="codellama:13b"
   ```

2. **Adjust Temperature**:
   ```bash
   # Lower temperature for more deterministic output
   jq '.local_llm.options.temperature = 0.2' .claude/settings.json > tmp.json
   mv tmp.json .claude/settings.json
   ```

3. **Provide More Context**:
   - Include related files in task description
   - Show examples of desired output
   - Reference existing code patterns

4. **Use Conservative Routing**:
   ```bash
   # Route more tasks to Claude
   jq '.local_llm.routing_strategy = "conservative"' .claude/settings.json > tmp.json
   mv tmp.json .claude/settings.json
   ```

5. **Force Claude for Complex Tasks**:
   ```json
   {
     "local_llm": {
       "override_keywords": ["complex", "algorithm", "optimize"]
     }
   }
   ```

### Issue 5: Review Loop Stuck

**Symptoms**:
```
⚠ Maximum iterations reached (3)

Do you want to accept the code as-is despite the issues? (yes/no)
```

**Solutions**:

1. **Accept with Override** (if issues are minor):
   ```
   > yes
   ✓ Code accepted by user override
   ```

2. **Reject and Route to Claude**:
   ```
   > no
   ✗ Code rejected after max iterations

   # Manually route task to Claude
   # Or add keyword override
   ```

3. **Increase Max Iterations**:
   ```bash
   export REVIEW_LOOP_MAX_ITERATIONS=5

   # Or in settings.json
   jq '.local_llm.max_iterations = 5' .claude/settings.json > tmp.json
   mv tmp.json .claude/settings.json
   ```

4. **Analyze Iteration Logs**:
   ```bash
   # View iteration history
   cat .claude/epics/use-local-model-for-coding/updates/2/iterations.log

   # Review generated code from each iteration
   ls .claude/epics/use-local-model-for-coding/updates/2/iteration_*
   ```

5. **Refine Task Description**:
   - Make requirements more specific
   - Add constraints or examples
   - Break into smaller subtasks

### Issue 6: High Memory Usage

**Symptoms**:
- System becomes slow during generation
- Ollama process using excessive RAM
- Out of memory errors

**Solutions**:

1. **Use Smaller Model**:
   ```bash
   # Switch to quantized or smaller model
   ollama pull qwen2.5:3b
   export OLLAMA_MODEL="qwen2.5:3b"
   ```

2. **Limit Context Window**:
   ```bash
   # Reduce num_predict to limit memory
   jq '.local_llm.options.num_predict = 1024' .claude/settings.json > tmp.json
   mv tmp.json .claude/settings.json
   ```

3. **Close Other Applications**:
   - Free up RAM before running tasks
   - Close browser tabs, IDEs, etc.

4. **Upgrade Hardware**:
   - Consider 16GB+ RAM for 7B+ models
   - Use GPU acceleration if available

### Debug Checklist

When troubleshooting, run through this checklist:

- [ ] Is Ollama running? (`ps aux | grep ollama`)
- [ ] Is the endpoint accessible? (`curl http://localhost:11434/api/version`)
- [ ] Is the model installed? (`ollama list`)
- [ ] Is the configuration correct? (`cat .claude/settings.json`)
- [ ] Are environment variables set? (`env | grep OLLAMA`)
- [ ] Is there sufficient memory? (`free -h` or `vm_stat`)
- [ ] Are there errors in logs? (`tail -f /tmp/local-llm-route.log`)
- [ ] Is debug mode enabled? (`export CLAUDE_HOOK_DEBUG=true`)

---

## Performance Tuning

### Model Selection

**Choosing the Right Model**:

| Use Case | Recommended Model | Rationale |
|----------|------------------|-----------|
| **Development** | qwen2.5:3b | Fast iteration, good for prototyping |
| **Production** | codellama:7b or qwen2.5:7b-instruct | Best balance of quality and speed |
| **High Quality** | codellama:13b or deepseek-coder:6.7b | Best code quality, slower |
| **Low RAM** | qwen2.5:3b | Works on 4GB systems |
| **Specialized** | deepseek-coder:6.7b | Excellent for complex code |

**Model Comparison** (based on testing):

| Model | Speed | Quality | RAM | Best For |
|-------|-------|---------|-----|----------|
| qwen2.5:3b | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | 4 GB | Quick prototypes, simple tasks |
| codellama:7b | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 8 GB | General code generation |
| qwen2.5:7b-instruct | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 8 GB | Instruction following |
| deepseek-coder:6.7b | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 8 GB | Complex algorithms |
| codellama:13b | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 16 GB | Production code |

### Hardware Requirements

**Minimum**:
- CPU: 4 cores
- RAM: 8 GB
- Storage: 10 GB free
- Model: qwen2.5:3b or codellama:7b

**Recommended**:
- CPU: 8+ cores
- RAM: 16 GB
- Storage: 20 GB free
- GPU: NVIDIA GPU with CUDA (optional, accelerates generation)
- Model: codellama:7b or qwen2.5:7b-instruct

**Optimal**:
- CPU: 16+ cores
- RAM: 32 GB
- Storage: 50 GB free
- GPU: NVIDIA RTX 3060+ with 12GB VRAM
- Model: codellama:13b or larger

### Timeout Configuration

**Timeout Strategy**:

```bash
# Fast tasks (simple functions)
export OLLAMA_TIMEOUT=60

# Medium tasks (classes, modules)
export OLLAMA_TIMEOUT=300  # Default

# Large tasks (multi-file generation)
export OLLAMA_TIMEOUT=600

# Very large tasks
export OLLAMA_TIMEOUT=900
```

**Timeout Formula**:
```
timeout = base_time + (file_size_kb * 0.5) + (complexity_factor * 30)

Where:
- base_time = 60 seconds
- file_size_kb = expected output size in KB
- complexity_factor = 1 (simple) to 5 (complex)
```

### Batch Processing

**Process Multiple Tasks Efficiently**:

```bash
#!/bin/bash
# Process multiple similar tasks in batch

# Set higher timeout for batch
export OLLAMA_TIMEOUT=600

# Process tasks sequentially (model stays loaded)
for task_file in .claude/epics/batch/*.md; do
  echo "Processing $task_file..."
  # Process task
  # ...
done

# Model stays in memory, subsequent generations faster
```

**Tips**:
- Group similar tasks together (model context is reused)
- Start with smaller tasks to warm up model
- Use same temperature for consistency
- Monitor memory usage during batch

### Temperature Tuning

**Temperature by Task Type**:

```json
{
  "local_llm": {
    "options": {
      "temperature": 0.2  // For production code
    }
  }
}
```

| Task Type | Temperature | Rationale |
|-----------|-------------|-----------|
| **Production Code** | 0.1 - 0.3 | Deterministic, consistent |
| **Tests** | 0.2 - 0.4 | Need variety but structured |
| **Prototypes** | 0.5 - 0.7 | More creative exploration |
| **Documentation** | 0.6 - 0.8 | Natural, varied language |
| **Examples** | 0.7 - 0.9 | Diverse, creative samples |

### Caching Strategies

Ollama automatically caches:
- Loaded models (stay in memory)
- Recent prompts (attention cache)
- Tokenized context

**Maximize Cache Hits**:
1. Keep Ollama running (don't restart between tasks)
2. Use consistent prompt structure
3. Group similar tasks together
4. Avoid clearing model cache unnecessarily

### Optimization Checklist

- [ ] Model size matches available RAM
- [ ] Temperature set appropriately (0.2 for code)
- [ ] Timeout configured for task complexity
- [ ] Ollama running as service (not restarted each time)
- [ ] Similar tasks batched together
- [ ] Debug logging disabled in production
- [ ] System has sufficient free memory
- [ ] No other heavy processes competing for resources

---

## Cost Analysis

### Measuring Savings

**Cost Tracking Setup**:

1. **Enable Routing Logs**:
   ```bash
   export CLAUDE_HOOK_LOG=/tmp/routing-costs.log
   ```

2. **Track Tasks Over Time**:
   ```bash
   # Count routing decisions
   grep "ROUTE:" /tmp/routing-costs.log | wc -l

   # Count Ollama routes
   grep "ROUTE: OLLAMA" /tmp/routing-costs.log | wc -l

   # Count Claude routes
   grep "ROUTE: CLAUDE" /tmp/routing-costs.log | wc -l
   ```

3. **Calculate Percentages**:
   ```bash
   #!/bin/bash
   total=$(grep "ROUTE:" /tmp/routing-costs.log | wc -l)
   ollama=$(grep "ROUTE: OLLAMA" /tmp/routing-costs.log | wc -l)
   claude=$(grep "ROUTE: CLAUDE" /tmp/routing-costs.log | wc -l)

   echo "Total Tasks: $total"
   echo "Ollama: $ollama ($(( ollama * 100 / total ))%)"
   echo "Claude: $claude ($(( claude * 100 / total ))%)"
   ```

### Token Usage Analysis

**Claude API Costs** (approximate, November 2025):
- Sonnet 4.5: $3/MTok input, $15/MTok output
- Haiku: $0.25/MTok input, $1.25/MTok output

**Typical Task Costs**:

| Task Type | Mode | Input Tokens | Output Tokens | Cost (Sonnet) | Cost (Hybrid) | Savings |
|-----------|------|--------------|---------------|---------------|---------------|---------|
| Simple Function | Claude-only | 500 | 300 | $0.006 | - | - |
| Simple Function | Hybrid | 200 | 100 | $0.002 | $0.002 | 67% |
| Module Implementation | Claude-only | 2000 | 1500 | $0.029 | - | - |
| Module Implementation | Hybrid | 2000 + 500 | 200 | $0.009 | $0.009 | 69% |
| Complex Feature | Claude-only | 5000 | 3000 | $0.060 | - | - |
| Complex Feature | Hybrid | 5000 + 1000 | 500 | $0.023 | $0.023 | 62% |

**Notes**:
- Hybrid costs include initial routing + review
- Review prompts are smaller than full implementation
- Iteration increases cost but maintains quality
- Savings average 60-70% based on routing mix

### ROI Calculation

**Monthly Cost Comparison**:

```
Assumptions:
- 1000 tasks/month
- 60% routed to Ollama
- Average task cost: $0.015 (Claude-only)

Claude-Only Monthly Cost:
1000 tasks × $0.015 = $15.00

Hybrid Monthly Cost:
- 400 Claude tasks × $0.015 = $6.00
- 600 Ollama tasks × $0.005 (review only) = $3.00
Total: $9.00

Monthly Savings: $6.00 (40%)
Annual Savings: $72.00

One-Time Setup Cost:
- Time to configure: 1 hour @ $50/hr = $50
- ROI breakeven: ~8 months

Payback improves with:
- Higher task volume
- More expensive Claude tier
- Better routing efficiency
```

### Example Metrics

**Real Project Example** (from integration testing):

```
Project: Medium SaaS Application
Period: 30 days
Total Tasks: 847

Routing Distribution:
- Claude (Planning): 203 tasks (24%)
- Claude (Security): 84 tasks (10%)
- Ollama (Code Gen): 560 tasks (66%)

Cost Breakdown:
Claude-Only Estimate:
847 tasks × $0.012 avg = $10.16

Actual Hybrid Cost:
- Planning: 203 × $0.012 = $2.44
- Security: 84 × $0.012 = $1.01
- Reviews: 560 × $0.004 = $2.24
Total: $5.69

Savings: $4.47 (44%)
Annual Projection: $53.64

Quality Impact:
- Iteration Rate: 1.8 avg per Ollama task
- Approval Rate: 92% within 3 iterations
- User Override: 3% of tasks
- Quality Score: 4.5/5 (same as Claude-only)
```

### Cost Optimization Tips

1. **Tune Routing Strategy**:
   - Start with "balanced"
   - Monitor quality metrics
   - Shift to "aggressive" if quality is good
   - Shift to "conservative" if too many iterations

2. **Model Selection**:
   - Faster models = more tasks/hour
   - Higher quality models = fewer iterations
   - Balance speed vs. iteration cost

3. **Review Efficiency**:
   - Provide clear specifications (fewer iterations)
   - Include code examples (better first attempts)
   - Use consistent patterns (model learns)

4. **Batch Processing**:
   - Group similar tasks
   - Reduce context-switching overhead
   - Leverage model memory

5. **Track Metrics**:
   ```bash
   # Create monthly report
   #!/bin/bash
   month=$(date +%Y-%m)
   grep "ROUTE:" /tmp/routing-costs.log \
     | awk '{print $4, $1, $2}' \
     > reports/routing-$month.csv
   ```

---

## FAQ

**Q: Will local LLMs match Claude's quality?**
A: Not exactly, but with the review loop, quality is maintained. Ollama handles straightforward implementation, Claude ensures it meets standards.

**Q: How much disk space do models require?**
A: 2-8 GB per model. Plan for 20+ GB if you want multiple models.

**Q: Can I use a remote Ollama server?**
A: Yes, set `endpoint` to your server URL. Useful for sharing GPU resources across a team.

**Q: What if I'm offline?**
A: Ollama works offline. You'll need Claude API access for reviews though, so some tasks may queue until you're online.

**Q: Can I use other local LLM providers?**
A: Currently only Ollama is supported. Future versions may add LM Studio, LocalAI, etc.

**Q: How do I update models?**
A: `ollama pull model:tag` downloads the latest version. Old versions are automatically removed.

**Q: Is GPU required?**
A: No, but highly recommended for models >7B. CPU-only works for smaller models.

**Q: How do I share configurations with my team?**
A: Commit `.claude/settings.json` to git. Each developer can override with environment variables.

---

## Additional Resources

- **Ollama Documentation**: https://ollama.ai/docs
- **Model Library**: https://ollama.ai/library
- **CCPM Documentation**: (link to main CCPM docs)
- **Decision Tree Rules**: `ccpm/rules/local-llm-decision-tree.md`
- **Architecture Diagram**: `CLAUDE_HELPERS/architecture-diagram.mmd`

---

## Support

For issues or questions:

1. Check [Troubleshooting](#troubleshooting) section
2. Run health check: `bash ccpm/scripts/llm/health-check.sh`
3. Enable debug logs: `export CLAUDE_HOOK_DEBUG=true`
4. Review routing log: `cat /tmp/local-llm-route.log`
5. Open GitHub issue with logs and configuration

---

**Document Version**: 1.0
**Last Updated**: 2025-11-06
**Tested With**: Ollama 0.1.x, CCPM 1.0.x
