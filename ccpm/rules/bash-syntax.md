# Bash Syntax Rules

Rules for generating valid bash code, especially heredocs.

## Heredoc Syntax

Close every heredoc with a matching delimiter on its own line (scripts fail to parse when delimiters are missing).

### Pattern 1: Static Content (Quoted Delimiter)

Use a quoted delimiter when content should not expand variables or execute commands:

```bash
cat > file.txt << 'EOF'
Content with $literal dollars and `backticks`
These stay as literal text, not expanded
EOF
```

Single quotes around `'EOF'` prevent all expansion.

### Pattern 2: Dynamic Content (Unquoted Delimiter)

Use an unquoted delimiter when variables should expand:

```bash
local name="Alice"
cat > file.txt << EOF
Hello $name
Generated at: $(date)
EOF
```

Without quotes, `$name` expands to "Alice" and `$(date)` executes.

### Pattern 3: Split Large Heredocs

When mixing static templates with dynamic values, split into multiple heredocs with unique delimiters:

```bash
# Static header
cat > "$file" << 'HEADER_EOF'
You are an assistant. Rules:
1. Be helpful
2. $placeholders stay literal
HEADER_EOF

# Dynamic section
cat >> "$file" << DYNAMIC_EOF
User: $user_input
Time: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
DYNAMIC_EOF

# Static footer
cat >> "$file" << 'FOOTER_EOF'
End of prompt.
FOOTER_EOF
```

### Pattern 4: Unique Delimiter Names

Each heredoc in a function requires a unique delimiter name (reusing the same name in one scope causes parse failures):

```bash
cat > a.txt << 'PROMPT_A'
...
PROMPT_A

cat > b.txt << 'PROMPT_B'
...
PROMPT_B
```

## Common Mistakes

### Missing Closing Delimiter

```bash
# BAD - never closes
cat > file << 'EOF'
content here
# forgot EOF

# Script fails with: "here-document delimited by end-of-file"
```

### Wrong Delimiter Name

```bash
# BAD - names don't match
cat > file << 'START'
content
END
```

### Indented Closing Delimiter

```bash
# BAD - closing delimiter has leading spaces
cat > file << 'EOF'
content
  EOF  # This won't work!
```

The closing delimiter must start at column 1 (use `<<-` with tabs only for indented delimiters).

## Function Template

A correctly structured bash function with heredocs:

```bash
my_function() {
  local input="$1"
  local output_file="$2"

  if [[ -z "$input" ]]; then
    echo "Error: input required" >&2
    return 1
  fi

  # Static template - quoted delimiter
  cat > "$output_file" << 'TEMPLATE_EOF'
System prompt with $literal $placeholders.
No expansion happens here.
TEMPLATE_EOF

  # Dynamic content - unquoted delimiter
  cat >> "$output_file" << DYNAMIC_EOF

User input: $input
Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
DYNAMIC_EOF

  if [[ -f "$output_file" ]]; then
    return 0
  else
    echo "Error: failed to create $output_file" >&2
    return 1
  fi
}
```

## Output Format for Code Generation

When generating bash code:

1. Output only the code block
2. Start with triple backticks and `bash`
3. End with triple backticks on its own line
4. No explanations before or after
5. Code must pass `bash -n` syntax validation
