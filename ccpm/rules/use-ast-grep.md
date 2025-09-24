# AST-Grep Integration Protocol for Cursor Agent

## When to Use AST-Grep

Use `ast-grep` (if installed) instead of plain regex or text search when:

- **Structural code patterns** are involved (e.g., finding all function calls, class definitions, or method implementations)
- **Language-aware refactoring** is required (e.g., renaming variables, updating function signatures, or changing imports)
- **Complex code analysis** is needed (e.g., finding all usages of a pattern across different syntactic contexts)
- **Cross-language searches** are necessary (e.g., working with both Ruby and TypeScript in a monorepo)
- **Semantic code understanding** is important (e.g., finding patterns based on code structure, not just text)

## AST-Grep Command Patterns

### Basic Search Template:
```sh
ast-grep --pattern '$PATTERN' --lang $LANGUAGE $PATH
```

### Common Use Cases

- **Find function calls:**
  `ast-grep --pattern 'functionName($$$)' --lang javascript .`
- **Find class definitions:**
  `ast-grep --pattern 'class $NAME { $$$ }' --lang typescript .`
- **Find variable assignments:**
  `ast-grep --pattern '$VAR = $$$' --lang ruby .`
- **Find import statements:**
  `ast-grep --pattern 'import { $$$ } from "$MODULE"' --lang javascript .`
- **Find method calls on objects:**
  `ast-grep --pattern '$OBJ.$METHOD($$$)' --lang typescript .`
- **Find React hooks:**
  `ast-grep --pattern 'const [$STATE, $SETTER] = useState($$$)' --lang typescript .`
- **Find Ruby class definitions:**
  `ast-grep --pattern 'class $NAME < $$$; $$$; end' --lang ruby .`

## Pattern Syntax Reference

- `$VAR` — matches any single node and captures it
- `$$$` — matches zero or more nodes (wildcard)
- `$$` — matches one or more nodes
- Literal code — matches exactly as written

## Supported Languages

- javascript, typescript, ruby, python, go, rust, java, c, cpp, html, css, yaml, json, and more

## Integration Workflow

### Before using ast-grep:
1. **Check if ast-grep is installed:**
   If not, skip and fall back to regex/semantic search.
   ```sh
   command -v ast-grep >/dev/null 2>&1 || echo "ast-grep not installed, skipping AST search"
   ```
2. **Identify** if the task involves structural code patterns or language-aware refactoring.
3. **Determine** the appropriate language(s) to search.
4. **Construct** the pattern using ast-grep syntax.
5. **Run** ast-grep to gather precise structural information.
6. **Use** results to inform code edits, refactoring, or further analysis.

### Example Workflow

When asked to "find all Ruby service objects that call `perform`":

1. **Check for ast-grep:**
   ```sh
   command -v ast-grep >/dev/null 2>&1 && ast-grep --pattern 'perform($$$)' --lang ruby app/services/
   ```
2. **Analyze** results structurally.
3. **Use** codebase semantic search for additional context if needed.
4. **Make** informed edits based on structural understanding.

### Combine ast-grep with Internal Tools

- **codebase_search** for semantic context and documentation
- **read_file** for examining specific files found by ast-grep
- **edit_file** for making precise, context-aware code changes

### Advanced Usage
- **JSON output for programmatic processing:**
  `ast-grep --pattern '$PATTERN' --lang $LANG $PATH --json`
- **Replace patterns:**
  `ast-grep --pattern '$OLD_PATTERN' --rewrite '$NEW_PATTERN' --lang $LANG $PATH`
- **Interactive mode:**
  `ast-grep --pattern '$PATTERN' --lang $LANG $PATH --interactive`

## Key Benefits Over Regex

1. **Language-aware** — understands syntax and semantics
2. **Structural matching** — finds patterns regardless of formatting
3. **Cross-language** — works consistently across different languages
4. **Precise refactoring** — makes structural changes safely
5. **Context-aware** — understands code hierarchy and scope

## Decision Matrix: When to Use Each Tool

| Task Type                | Tool Choice          | Reason                        |
|--------------------------|----------------------|-------------------------------|
| Find text patterns       | grep_search          | Simple text matching          |
| Find code structures     | ast-grep             | Syntax-aware search           |
| Understand semantics     | codebase_search      | AI-powered context            |
| Make edits               | edit_file            | Precise file editing          |
| Structural refactoring   | ast-grep + edit_file | Structure + precision         |

**Always prefer ast-grep for code structure analysis over regex-based approaches, but only if it is installed and available.**
