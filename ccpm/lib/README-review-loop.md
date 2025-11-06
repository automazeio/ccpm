# Review Loop Controller

## Overview

The Review Loop Controller (`review-loop.sh`) orchestrates the iterative code generation and review process between Ollama (local code generation) and Claude (code review). It manages up to 3 review iterations, handles feedback loops, and implements quality gate logic.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│               Review Loop Controller                     │
│                 (review-loop.sh)                         │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
         ┌───────────────────────────────┐
         │   Iteration Loop (1-3 times)  │
         └───────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
   [Generate]       [Review]        [Decide]
        │                │                │
        ▼                ▼                ▼
  Ollama LLM      Claude Review    State Machine
 (local-code-   (claude-code-    (APPROVE/ITERATE/
  generator)      reviewer)           FAIL)
```

## State Machine

The controller implements a state machine with the following states:

1. **GENERATE**: Invoke Ollama to generate code
2. **REVIEW**: Invoke Claude to review generated code
3. **DECIDE**: Parse review decision
4. **APPROVE**: Code approved, exit with success
5. **ITERATE**: Issues found, regenerate with feedback
6. **FAIL**: Critical issues, exit with error
7. **USER_OVERRIDE**: User accepts despite issues

## Features

### Core Functionality

- **Iterative Review**: Up to 3 iterations of generate → review → feedback
- **Quality Gates**: Three decision outcomes (APPROVE, ITERATE, FAIL)
- **Feedback Loop**: Extracts review feedback and passes to next generation
- **User Override**: Manual acceptance at any iteration
- **Comprehensive Logging**: All iterations logged with timestamps

### Error Handling

- Agent invocation failures
- Malformed agent output
- Timeout scenarios
- Parse errors
- Connection failures

### Logging

All iterations are logged to:
```
.claude/epics/use-local-model-for-coding/updates/2/iterations.log
```

Generated code and reviews are saved to:
```
.claude/epics/use-local-model-for-coding/updates/2/iteration_N_generated.txt
.claude/epics/use-local-model-for-coding/updates/2/iteration_N_review.md
```

## Usage

### Basic Usage

```bash
./ccpm/lib/review-loop.sh \
  -t "Create user authentication module" \
  -f "src/auth.js"
```

### With Custom Iterations

```bash
./ccpm/lib/review-loop.sh \
  -t "Add error handling to API endpoints" \
  -f "src/api.js" \
  -m 5
```

### With Environment Variables

```bash
export OLLAMA_MODEL="codellama:13b"
export REVIEW_LOOP_MAX_ITERATIONS=5

./ccpm/lib/review-loop.sh \
  -t "Refactor database connection pool" \
  -f "src/db.js"
```

## Command Line Options

| Option | Description | Required | Default |
|--------|-------------|----------|---------|
| `-t, --task` | Task description | Yes | - |
| `-f, --files` | Target files | Yes | - |
| `-m, --max-iterations` | Maximum iterations | No | 3 |
| `-h, --help` | Show help | No | - |

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `REVIEW_LOOP_MAX_ITERATIONS` | Maximum review iterations | 3 |
| `OLLAMA_MODEL` | Ollama model to use | deepseek-coder:6.7b |
| `OLLAMA_ENDPOINT` | Ollama server endpoint | http://localhost:11434 |
| `OLLAMA_TIMEOUT` | Ollama request timeout | 120 |

## Exit Codes

| Code | Meaning | Description |
|------|---------|-------------|
| 0 | Success | Code approved by reviewer |
| 1 | Failure | Code failed review or error occurred |
| 2 | User Override | Code accepted manually despite issues |

## Integration with Agents

### Local Code Generator

The controller invokes the `local-code-generator` agent (defined in `ccpm/agents/local-code-generator.md`) to generate code using Ollama. The agent:

- Performs health checks on Ollama
- Constructs context-rich prompts
- Streams generation progress
- Returns structured code output

### Claude Code Reviewer

The controller invokes the `claude-code-reviewer` agent (defined in `ccpm/agents/claude-code-reviewer.md`) to review generated code. The agent:

- Analyzes code quality and logic
- Identifies security vulnerabilities
- Checks style compliance
- Validates requirements fulfillment
- Returns structured review with decision

## Iteration Flow

```
Iteration 1:
  ┌─────────────┐
  │  Generate   │ ──> No feedback (first attempt)
  └─────────────┘
         │
         ▼
  ┌─────────────┐
  │   Review    │ ──> ITERATE (issues found)
  └─────────────┘
         │
         ▼
  Extract feedback

Iteration 2:
  ┌─────────────┐
  │  Generate   │ ──> With feedback from Iteration 1
  └─────────────┘
         │
         ▼
  ┌─────────────┐
  │   Review    │ ──> ITERATE (more issues)
  └─────────────┘
         │
         ▼
  Extract feedback

Iteration 3:
  ┌─────────────┐
  │  Generate   │ ──> With feedback from Iteration 2
  └─────────────┘
         │
         ▼
  ┌─────────────┐
  │   Review    │ ──> APPROVE (code is good!)
  └─────────────┘
         │
         ▼
  ┌─────────────┐
  │   Output    │ ──> Return generated code
  └─────────────┘
```

## Review Decision Logic

### APPROVE
Code is approved when:
- All requirements are met
- No critical or high-severity issues
- Minor issues only (style, optional improvements)
- Code is safe to use as-is

### ITERATE
Code needs iteration when:
- Logic errors present
- Security vulnerabilities found
- Missing required functionality
- Style violations impacting maintainability
- Feedback is extracted and passed to next generation

### FAIL
Code fails when:
- Critical security vulnerabilities
- Fundamentally wrong approach
- Complete misunderstanding of requirements
- Would cause data loss or system instability
- Human intervention required

## User Override

At any point where the code doesn't pass review, the user is prompted:

```
========================================
User Override Requested
========================================

Iteration 2 of 3 complete.

Review Summary:
[Review summary shown here]

Do you want to accept the code as-is despite the issues? (yes/no)
>
```

If the user accepts (`yes`), the script exits with code 2 and outputs the generated code.

## Examples

### Example 1: Successful Generation

```bash
$ ./ccpm/lib/review-loop.sh -t "Create hello world function" -f "src/hello.js"

========================================
Iteration 1 of 3
========================================

[1/3] Generating code...
✓ Code generated

[2/3] Reviewing code...
✓ Code reviewed

[3/3] Analyzing review result...

========================================
✓ Code Approved!
========================================

FILE: src/hello.js
```javascript
function helloWorld() {
  console.log("Hello, World!");
}
```
```

### Example 2: Iteration with Feedback

```bash
$ ./ccpm/lib/review-loop.sh -t "Create user validation" -f "src/validate.js"

========================================
Iteration 1 of 3
========================================

[1/3] Generating code...
✓ Code generated

[2/3] Reviewing code...
✓ Code reviewed

[3/3] Analyzing review result...

⟳ Issues found, regenerating...

========================================
Iteration 2 of 3
========================================

[1/3] Generating code...
✓ Code generated

[2/3] Reviewing code...
✓ Code reviewed

[3/3] Analyzing review result...

========================================
✓ Code Approved!
========================================
```

### Example 3: Max Iterations with Override

```bash
$ ./ccpm/lib/review-loop.sh -t "Complex authentication system" -f "src/auth.js"

[... iterations 1-3 ...]

========================================
Iteration 3 of 3
========================================

⟳ Issues found, regenerating...

⚠ Maximum iterations reached (3)

========================================
User Override Requested
========================================

Do you want to accept the code as-is despite the issues? (yes/no)
> yes

✓ Code accepted by user override
```

## Logging Output

The iteration log (`iterations.log`) contains:

```
[2025-11-06T19:25:00Z] [INFO] =========================================
[2025-11-06T19:25:00Z] [INFO] Review Loop Session Started
[2025-11-06T19:25:00Z] [INFO] Max Iterations: 3
[2025-11-06T19:25:00Z] [INFO] =========================================
[2025-11-06T19:25:00Z] [INFO] Starting review loop
[2025-11-06T19:25:00Z] [INFO] Task: Create user login function
[2025-11-06T19:25:00Z] [INFO] Target files: src/auth.js
[2025-11-06T19:25:05Z] [INFO] Generating code...
[2025-11-06T19:25:05Z] [INFO] Task: Create user login function
[2025-11-06T19:25:15Z] [INFO] Code generation complete (1234 characters)
[2025-11-06T19:25:15Z] [INFO] Generated code saved to: .../iteration_1_generated.txt
[2025-11-06T19:25:15Z] [INFO] Reviewing generated code...
[2025-11-06T19:25:20Z] [INFO] Code review complete (5678 characters)
[2025-11-06T19:25:20Z] [INFO] Review result saved to: .../iteration_1_review.md
[2025-11-06T19:25:20Z] [INFO] --- Iteration 1 ---
[2025-11-06T19:25:20Z] [INFO] Decision: APPROVE
[2025-11-06T19:25:20Z] [INFO] Review Summary: Code meets all requirements
[2025-11-06T19:25:20Z] [INFO] ---
[2025-11-06T19:25:20Z] [INFO] Code approved on iteration 1
```

## Troubleshooting

### Ollama Not Running

```
ERROR: Ollama health check failed
Connection refused - Ollama may not be running

To fix:
  1. Start Ollama: ollama serve
  2. Verify it's running: ollama list
```

### Model Not Available

```
ERROR: Model 'deepseek-coder:6.7b' not found

To fix:
  1. Pull the model: ollama pull deepseek-coder:6.7b
  2. Or use an available model: export OLLAMA_MODEL="codellama:7b"
```

### Generation Timeout

```
ERROR: Request to Ollama failed
Request timed out after 120s

To fix:
  1. Increase timeout: export OLLAMA_TIMEOUT=300
  2. Try a smaller/faster model
  3. Reduce prompt complexity
```

## Testing

To test the review loop:

```bash
# Test with a simple task
./ccpm/lib/review-loop.sh \
  -t "Create a function that adds two numbers" \
  -f "test.js"

# Test with max iterations
REVIEW_LOOP_MAX_ITERATIONS=1 ./ccpm/lib/review-loop.sh \
  -t "Create complex authentication system" \
  -f "test.js"

# Verify logs were created
ls -l .claude/epics/use-local-model-for-coding/updates/2/
```

## Dependencies

- `bash` (version 4.0+)
- `ccpm/lib/ollama-client.sh` - Ollama HTTP API client
- `ccpm/agents/local-code-generator.md` - Code generation agent definition
- `ccpm/agents/claude-code-reviewer.md` - Code review agent definition
- Ollama server running (for code generation)

## Future Enhancements

- Support for multiple target files in a single run
- Parallel iteration attempts with different strategies
- Learning from past iterations to improve prompts
- Integration with CI/CD pipelines
- Support for custom review criteria
- Webhook notifications on completion
- Metrics tracking (iteration success rates, etc.)

## Related Documentation

- [Local Code Generator Agent](../agents/local-code-generator.md)
- [Claude Code Reviewer Agent](../agents/claude-code-reviewer.md)
- [Ollama Client Library](./ollama-client.sh)
- [Use Local Model for Coding PRD](../../.claude/prds/use-local-model-for-coding.md)
