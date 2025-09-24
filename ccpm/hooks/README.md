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
