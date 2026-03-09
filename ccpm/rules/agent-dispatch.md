# Agent Dispatch

Route all sub-agent work through `/delegate`, not through native Claude Code tools (Task, Agent).

## Why

- `/delegate` is a controllable dispatch layer that can be retargeted to LLM Runner or other backends
- Native Agent/Task tools are coupled to Claude Code's runtime — they bypass the orchestration layer and cannot be rerouted
- Centralizing dispatch through `/delegate` enables provider-agnostic agent execution

## Rules

- Use `/delegate` for all multi-agent orchestration, parallel work streams, and background tasks
- Reference `/delegate` in command files and agent prompts where sub-agent dispatch is needed
- Agent prompt files (in `agents/`) define agent behavior — they do not dispatch other agents themselves. The orchestrating command (e.g., `epic-start`, `feature`) calls `/delegate` to spawn agents.
- When a command needs to launch parallel work, describe the work streams and invoke `/delegate` rather than calling Task/Agent directly

## Interface

```
/delegate <task_description>
```

`/delegate` reads the task, decomposes it into work streams, and dispatches specialist agents. It handles:
- Work stream identification and parallelization
- Agent type selection per stream
- Progress monitoring and result aggregation
- Error recovery and adaptive re-dispatch

## Migration Notes

When updating existing prompts:
- Replace `Use Task tool to launch...` with `Use /delegate to dispatch...`
- Replace `Launch via Agent tool` with `Dispatch via /delegate`
- Remove references to `subagent_type` parameter (delegate handles agent selection)
- Keep agent definition files (`agents/*.md`) as behavioral specs — they define what an agent does, not how it gets invoked
