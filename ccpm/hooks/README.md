# Claude Hooks Configuration

## Bash Worktree Fix Hook

This hook automatically fixes the Bash tool's directory reset issue when working in git worktrees.

### Problem

The Bash tool resets to the main project directory after every command, making it impossible to work in worktrees without manually prefixing every command with `cd /path/to/worktree &&`.

### Solution

The pre-tool-use hook automatically detects when you're in a worktree and injects the necessary `cd` prefix to all Bash commands.

### How It Works

1. **Detection**: Before any Bash command executes, the hook checks if `.git` is a file (worktree) or directory (main repo)
2. **Injection**: If in a worktree, prepends `cd /absolute/path/to/worktree && ` to the command
3. **Transparency**: Agents don't need to know about this - it happens automatically

### Configuration

Add to your `.claude/settings.json`:


```json
{
  "hooks": {
    "pre-tool-use": {
      "Bash": {
        "enabled": true,
        "script": ".claude/hooks/bash-worktree-fix.sh",
        "apply_to_subagents": true
      }
    }
  }
}
```

### Testing

To test the hook:

```bash
# Enable debug mode
export CLAUDE_HOOK_DEBUG=true

# Test in main repo (should pass through)
.claude/hooks/bash-worktree-fix.sh "ls -la"

# Test in worktree (should inject cd)
cd /path/to/worktree
.claude/hooks/bash-worktree-fix.sh "npm install"
# Output: cd "/path/to/worktree" && npm install
```

### Advanced Features

The script handles:

- Background processes (`&`)
- Piped commands (`|`)
- Environment variable prefixes (`VAR=value command`)
- Commands that already have `cd`
- Commands using absolute paths
- Debug logging with `CLAUDE_HOOK_DEBUG=true`

### Edge Cases Handled

1. **Double-prefix prevention**: Won't add prefix if command already starts with `cd`
2. **Absolute paths**: Skips injection for commands using absolute paths
3. **Special commands**: Skips for `pwd`, `echo`, `export`, etc. that don't need context
4. **Background processes**: Correctly handles `&` at the end of commands
5. **Pipe chains**: Injects only at the start of pipe chains

### Troubleshooting

If the hook isn't working:

1. **Verify the hook is executable:**
   ```bash
   chmod +x .claude/hooks/bash-worktree-fix.sh
   ```

2. **Enable debug logging to see what's happening:**
   ```bash
   export CLAUDE_HOOK_DEBUG=true
   ```

3. **Test the hook manually with a sample command:**
   ```bash
   cd /path/to/worktree
   .claude/hooks/bash-worktree-fix.sh "npm test"
   ```

4. **Check that your settings.json is valid JSON:**
   ```bash
   cat .claude/settings.json | python -m json.tool
   ```

### Integration with Claude

Once configured, this hook will:

- Automatically apply to all Bash tool invocations
- Work for both main agent and sub-agents
- Be completely transparent to users
- Eliminate the need for worktree-specific instructions

### Result

With this hook in place, agents can work in worktrees naturally:

**Agent writes:**

```bash
npm install
git status
npm run build
```

**Hook transforms to:**

```bash
cd /path/to/my/project/epic-feature && npm install
cd /path/to/my/project/epic-feature && git status
cd /path/to/my/project/epic-feature && npm run build
```

**Without the agent knowing or caring about the worktree context!**

---

## Local LLM Routing Hook

This hook automatically routes tasks between Claude (for planning/review) and Ollama (for code generation) based on task content analysis.

### Problem

When using both Claude API and local LLM (Ollama) in a project, determining which system should handle each task requires manual decision-making. This creates overhead and inconsistency.

### Solution

The pre-tool-use hook analyzes task descriptions and automatically routes to the appropriate system:
- **Claude**: Planning, architecture, design decisions, code review, security-critical code
- **Ollama**: Code implementation, boilerplate, refactoring, test writing

### How It Works

1. **Analysis**: Parses task description for keywords and patterns
2. **Classification**: Applies routing rules from `ccpm/rules/local-llm-decision-tree.md`
3. **Routing**: Routes to Ollama (code generation) or Claude (planning/review)
4. **Logging**: Records routing decisions for transparency and debugging
5. **Quality Loop**: All Ollama-generated code is reviewed by Claude

### Configuration

Add to your `.claude/settings.json`:

```json
{
  "local_llm": {
    "enabled": true,
    "provider": "ollama",
    "endpoint": "http://localhost:11434",
    "model": "codellama:7b",
    "routing_strategy": "balanced",
    "max_iterations": 3,
    "override_keywords": [],
    "force_ollama_keywords": []
  }
}
```

### Routing Strategies

- **balanced** (default): Use decision tree rules as documented
- **aggressive**: Route maximum tasks to Ollama, only critical paths to Claude
- **conservative**: Route maximum tasks to Claude, only clear code-gen to Ollama

### Classification Rules

#### Route to Ollama (Code Generation)

**Keywords**: implement, create, write, generate, refactor, add method, build component
**File patterns**: `.js`, `.ts`, `.py`, `.sh`, test files
**Task types**: CRUD operations, API endpoints, utilities, tests, boilerplate

#### Route to Claude (Planning & Review)

**Keywords**: plan, design, architecture, review, analyze, evaluate, decide
**File patterns**: `.md` files in `.claude/prds/` or `.claude/epics/`
**Task types**: PRDs, epic planning, code review, architecture decisions

#### Always Route to Claude (Override)

- Security: authentication, authorization, encryption
- Payments: payment processing, financial calculations
- High complexity: novel algorithms, distributed systems
- Unclear requirements: ambiguous specifications

### Testing

Run the test suite:

```bash
./ccpm/hooks/test-local-llm-route.sh
```

Test manually with debug mode:

```bash
export CLAUDE_HOOK_DEBUG=true

# Test code generation (should route to Ollama)
echo "Implement a user registration function" | ./ccpm/hooks/local-llm-route.sh

# Test planning (should route to Claude)
echo "Design the database schema for users" | ./ccpm/hooks/local-llm-route.sh

# Test security-critical (should route to Claude)
echo "Implement JWT token authentication" | ./ccpm/hooks/local-llm-route.sh
```

### Logging

Routing decisions are logged to stderr and optionally to a file:

```bash
# Enable file logging
export CLAUDE_HOOK_LOG=/tmp/local-llm-route.log

# View routing log
tail -f /tmp/local-llm-route.log
```

### Advanced Configuration

#### Custom Keyword Overrides

Force routing for specific keywords:

```json
{
  "local_llm": {
    "override_keywords": ["critical", "security-sensitive"],
    "force_ollama_keywords": ["boilerplate", "scaffolding"]
  }
}
```

#### Routing Strategy Examples

**Aggressive** (maximize cost savings):
```json
{"local_llm": {"routing_strategy": "aggressive"}}
```
Routes everything to Ollama except absolute critical paths.

**Conservative** (maximize quality):
```json
{"local_llm": {"routing_strategy": "conservative"}}
```
Routes only clear, low-risk code generation to Ollama.

### Troubleshooting

If routing isn't working correctly:

1. **Check if enabled:**
   ```bash
   jq .local_llm.enabled .claude/settings.json
   ```

2. **Verify Ollama is running:**
   ```bash
   ./ccpm/scripts/llm/health-check.sh
   ```

3. **Enable debug logging:**
   ```bash
   export CLAUDE_HOOK_DEBUG=true
   ```

4. **Review routing decisions:**
   ```bash
   export CLAUDE_HOOK_LOG=/tmp/routing.log
   tail -f /tmp/routing.log
   ```

5. **Test classification manually:**
   ```bash
   echo "your task description" | CLAUDE_HOOK_DEBUG=true ./ccpm/hooks/local-llm-route.sh
   ```

### Integration

This hook is designed to work with the Task tool delegation system:

```
Task Request
    ↓
Hook intercepts
    ↓
Analyzes content → Classifies → Routes
    ↓                    ↓
Ollama (code gen)   Claude (planning)
    ↓
Claude review (quality gate)
```

### Examples

**Code generation routed to Ollama:**
```bash
"Create a REST API endpoint for user registration"
"Write unit tests for the UserService class"
"Refactor the authentication middleware to use async/await"
```

**Planning routed to Claude:**
```bash
"Design the notification system architecture"
"Review the payment processing code for security issues"
"Create a PRD for the user management feature"
```

**Mixed task breakdown:**
```bash
"Build a comment system"
  → 1. Design comment data model (Claude)
  → 2. Implement comment CRUD API (Ollama → Claude review)
  → 3. Review for security and performance (Claude)
```

### Performance Characteristics

- **Latency**: < 100ms classification overhead
- **Accuracy**: ~95% correct routing with default rules
- **Fallback**: Always defaults to Claude when uncertain
- **Quality Gate**: All Ollama code reviewed by Claude

### Continuous Improvement

The routing log can be analyzed to refine rules:

```bash
# View routing distribution
grep "ROUTE:" /tmp/local-llm-route.log | cut -d' ' -f4 | sort | uniq -c

# Find ambiguous cases (might be misrouted)
grep "uncertain" /tmp/local-llm-route.log
```
