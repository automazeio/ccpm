# Batch Process PRDs

<role>
You are a batch execution orchestrator that processes all backlog PRDs in optimal dependency order, maximizing parallelism while respecting dependencies.
</role>

<instructions>
Process all PRDs with `status: backlog` from `.claude/prds/` by:

1. **Discover** - Scan `.claude/prds/*.md` for PRDs where frontmatter contains `status: backlog`
2. **Analyze Dependencies** - Extract `dependencies:` field from each PRD's frontmatter (format: `- PRD 61: Description`)
3. **Build Execution Layers** - Use topological sort (Kahn's algorithm) to group PRDs:
   - Layer 0: PRDs with no dependencies (run in parallel)
   - Layer N: PRDs depending only on completed layers (run in parallel within layer)
4. **Generate Script** - Create `.claude/scripts/batch-execution-<timestamp>.sh` that calls `claude --dangerously-skip-permissions --print "/pm:prd-complete <prd>"` for each PRD
5. **Execute** - Run the generated script immediately, streaming output
</instructions>

<constraints>
- Detect circular dependencies and fail with clear error listing the cycle
- PRDs in the same layer with no inter-dependencies run in parallel (background jobs + wait)
- Continue on individual PRD failure - log it and proceed with independent PRDs
- Each PRD gets its own log file in `.claude/logs/batch-<timestamp>/`
- Only process `status: backlog` PRDs - skip `complete` or `in-progress`
</constraints>

<output_format>
```
=== Batch Process Analysis ===

Scanning .claude/prds/ for backlog PRDs...
Found: {count} PRDs with status: backlog

Building dependency graph...
✓ No circular dependencies

Execution Plan:
  Layer 0 (parallel): 61-auth, 62-api-base
  Layer 1: 64-user-service (depends: 61, 62)

Generated: .claude/scripts/batch-execution-{timestamp}.sh
Logs: .claude/logs/batch-{timestamp}/

=== Executing Batch ===

=== Layer 0: 2 PRDs (parallel) ===
  [61-auth] ✅ Complete
  [62-api-base] ✅ Complete
[Layer 0] Complete

=== Layer 1: 1 PRD ===
  [64-user-service] ✅ Complete
[Layer 1] Complete

=== Batch Complete ===
Total: 3 PRDs | Succeeded: 3 | Failed: 0
Logs: .claude/logs/batch-{timestamp}/
```
</output_format>

<example>
<scenario>3 PRDs where 64 depends on 61 and 62</scenario>
<prds>
- 61-auth.md (status: backlog, no dependencies)
- 62-api-base.md (status: backlog, no dependencies)
- 64-user-service.md (status: backlog, dependencies: [PRD 61, PRD 62])
</prds>
<execution_layers>
Layer 0: [61-auth, 62-api-base] - parallel
Layer 1: [64-user-service] - after layer 0 completes
</execution_layers>
<generated_script>
```bash
#!/bin/bash
# Layer 0 - parallel
claude --dangerously-skip-permissions --print "/pm:prd-complete 61-auth" &
claude --dangerously-skip-permissions --print "/pm:prd-complete 62-api-base" &
wait

# Layer 1 - depends on layer 0
claude --dangerously-skip-permissions --print "/pm:prd-complete 64-user-service"
```
</generated_script>
</example>

<example>
<scenario>Circular dependency detected</scenario>
<prds>
- 64-user-service.md (dependencies: [PRD 65])
- 65-notifications.md (dependencies: [PRD 64])
</prds>
<output>
```
❌ Circular dependency detected!

These PRDs have unresolvable dependencies:
  64-user-service depends on: 65
  65-notifications depends on: 64

Fix the circular dependency and try again.
```
</output>
</example>

<error_cases>
- **No backlog PRDs**: Output "✅ No backlog PRDs to process" and exit successfully
- **Circular dependency**: List the cycle clearly and exit with error
- **PRD execution fails**: Log failure, continue with independent PRDs, report failures in summary
- **Missing .claude/prds/**: Create directory and report no PRDs found
</error_cases>
