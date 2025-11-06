---
name: use-local-model-for-coding
status: backlog
created: 2025-11-06T17:24:32Z
progress: 0%
prd: .claude/prds/use-local-model-for-coding.md
github: https://github.com/adambcoding/cheapcpm/issues/1
---

# Epic: use-local-model-for-coding

## Overview

Implement a hybrid architecture that uses local LLM (via Ollama) for code generation while Claude Code handles planning, decision-making, and quality review. This leverages CCPM's existing agent/task delegation patterns and configuration system to route code generation tasks to a local model, achieving 70%+ cost reduction while maintaining code quality through Claude's review loop.

**Key Insight**: CCPM already has all the infrastructure we need - markdown-based agents, Task tool delegation, configuration system, and hooks. We just need to add an Ollama client agent, routing rules, and configuration.

## Architecture Decisions

### 1. **Leverage Existing CCPM Agent System**
**Decision**: Implement local LLM as a specialized agent within CCPM's existing Task tool architecture
**Rationale**:
- CCPM already uses markdown-based agents with Task tool delegation
- No need to reinvent agent orchestration
- Natural fit with existing delegation patterns
- Minimal code changes required

### 2. **Configuration-First Approach**
**Decision**: Extend `settings.json` with local_llm section rather than creating new config files
**Rationale**:
- CCPM already uses layered configuration system
- Consistent with existing patterns (GitHub CLI detection, hooks)
- No new config parsing logic needed

### 3. **Hook-Based Task Routing**
**Decision**: Use pre-tool-use hooks to intercept and route code generation requests
**Rationale**:
- CCPM's hook system supports transparent modification of tool calls
- Routing logic lives in hooks, keeping agents simple
- User sees clear indication of routing decisions
- Easy to enable/disable without code changes

### 4. **Quality Gate via Claude Review**
**Decision**: All Ollama-generated code goes through Claude Code review agent
**Rationale**:
- Reuses CCPM's existing code review patterns
- Provides iterative feedback loop (max 3 iterations)
- Maintains output quality despite local model limitations
- User can override and manually accept at any iteration

### 5. **Minimal Technology Stack**
**Decision**: Pure shell scripts + HTTP client for Ollama, no new dependencies
**Rationale**:
- CCPM is bash-based (all commands are .sh files)
- curl/wget already available for HTTP calls
- No npm/python dependencies to manage
- Consistent with CCPM's lightweight philosophy

## Technical Approach

### System Architecture

```
User: /pm:epic-start my-feature
    ↓
CCPM Command (bash script)
    ↓
Claude Code (Task Classification)
    ↓
Pre-Tool-Use Hook (local-llm-route.sh)
    ├─ Analyzes task type
    └─ Routes based on rules
        ↓
        ├→ Planning/Review Tasks → Claude Code Agent
        │   • PRD creation, epic decomposition
        │   • Architectural decisions
        │   • Code review and quality gates
        │
        └→ Code Generation Tasks → Ollama Agent
            ├ local-code-generator.md agent invoked
            ├ Sends prompt to Ollama HTTP API
            ├ Receives generated code
            ├ Passes to claude-code-reviewer.md agent
            └ Iterates up to 3 times until approved
```

### Key Components

#### 1. Configuration Extension
**File**: `.claude/settings.json` (extend existing)
```json
{
  "local_llm": {
    "enabled": true,
    "provider": "ollama",
    "endpoint": "${OLLAMA_ENDPOINT:-http://localhost:11434}",
    "model": "${OLLAMA_MODEL:-deepseek-coder:6.7b}",
    "timeout": 120,
    "max_iterations": 3
  }
}
```

#### 2. Task Routing Hook
**File**: `ccpm/hooks/local-llm-route.sh` (new)
- Intercepts Task tool invocations
- Checks task description for code generation keywords
- Routes to appropriate agent based on task type
- Logs routing decisions for transparency

#### 3. Ollama Client Agent
**File**: `ccpm/agents/local-code-generator.md` (new)
- Markdown-based agent definition (follows CCPM pattern)
- Constructs prompts with file context
- Calls Ollama HTTP API via curl
- Streams response for user visibility
- Returns generated code for review

#### 4. Code Review Agent
**File**: `ccpm/agents/claude-code-reviewer.md` (new)
- Reviews Ollama-generated code
- Identifies issues: bugs, style, security, requirements
- Provides specific feedback for regeneration
- Approves or requests iteration

#### 5. Routing Rules
**File**: `ccpm/rules/local-llm-decision-tree.md` (new)
- Documents which tasks go to which system
- Code generation → Ollama
- Planning/review → Claude
- Used by routing hook

#### 6. Health Check Command
**File**: `ccpm/commands/llm/health-check.sh` (new)
- Tests Ollama connectivity
- Validates model availability
- Provides diagnostics and setup guidance

### Integration with Existing CCPM

**Leverages These Existing Components**:
- ✅ Task tool delegation (core agent orchestration)
- ✅ `settings.json` configuration system
- ✅ Pre-tool-use hooks for routing
- ✅ Markdown-based agent definitions
- ✅ Git-based coordination between agents
- ✅ Error handling patterns
- ✅ User feedback via CLI output

**Adds Only**:
- 🆕 Ollama HTTP client logic (shell + curl)
- 🆕 Task classification rules
- 🆕 Two new agents (code generator + reviewer)
- 🆕 Configuration section for local LLM
- 🆕 Routing hook script
- 🆕 Health check command

## Implementation Strategy

### Phase 1: Foundation (Minimal Viable Integration)
**Goal**: Get basic Ollama connectivity and one successful code generation
**Deliverables**:
- Ollama client shell functions (HTTP API wrapper)
- Configuration section in settings.json
- Health check command for diagnostics
**Validation**: `/pm:llm:health-check` succeeds, connects to Ollama

### Phase 2: Agent Integration
**Goal**: Create local code generator agent that Claude can invoke
**Deliverables**:
- `local-code-generator.md` agent definition
- Prompt engineering for code generation context
- Response parsing and code extraction
**Validation**: Manual Task tool invocation of local-code-generator succeeds

### Phase 3: Quality Loop
**Goal**: Implement Claude review and iteration mechanism
**Deliverables**:
- `claude-code-reviewer.md` agent definition
- Iteration controller (manages review cycles)
- Quality gate logic (approve/iterate/fail)
**Validation**: Generated code goes through review, iterates if needed

### Phase 4: Intelligent Routing
**Goal**: Automatically route tasks to appropriate system
**Deliverables**:
- Task routing hook (`local-llm-route.sh`)
- Decision rules documentation
- Transparent routing indicators
**Validation**: `/pm:epic-start` automatically delegates correctly

### Phase 5: Error Handling & Polish
**Goal**: Production-ready with clear error messages
**Deliverables**:
- Connection error handling
- Model availability checks
- Timeout handling
- User-friendly error messages with remediation steps
**Validation**: All error scenarios have clear, actionable messages

## Task Breakdown Preview

Given the goal of **10 or fewer tasks**, here's the simplified breakdown:

- [ ] **Task 1: Ollama Client Library**
  - Create shell functions for Ollama HTTP API
  - Support: connection test, list models, generate code
  - Error handling with clear messages
  - Files: `ccpm/lib/ollama-client.sh`

- [ ] **Task 2: Configuration & Health Check**
  - Extend `settings.json` with local_llm section
  - Create `/pm:llm:health-check` command
  - Environment variable support (OLLAMA_ENDPOINT, OLLAMA_MODEL)
  - Files: `.claude/settings.json`, `ccpm/commands/llm/health-check.sh`

- [ ] **Task 3: Local Code Generator Agent**
  - Create markdown agent definition for code generation
  - Prompt engineering with file context
  - Stream responses to user
  - Files: `ccpm/agents/local-code-generator.md`

- [ ] **Task 4: Code Review Agent**
  - Create markdown agent definition for Claude review
  - Issue identification (bugs, style, security)
  - Structured feedback for regeneration
  - Files: `ccpm/agents/claude-code-reviewer.md`

- [ ] **Task 5: Review Iteration Controller**
  - Orchestrate review → feedback → regenerate loop
  - Max 3 iterations with user override
  - Quality gate logic (approve/iterate/fail)
  - Files: `ccpm/lib/review-loop.sh`

- [ ] **Task 6: Task Routing Hook**
  - Pre-tool-use hook for task classification
  - Route code generation → Ollama
  - Route planning/review → Claude
  - Transparent logging of routing decisions
  - Files: `ccpm/hooks/local-llm-route.sh`

- [ ] **Task 7: Routing Decision Rules**
  - Document task classification criteria
  - Code generation patterns (file creation, function implementation, refactoring)
  - Planning patterns (PRD, epic, architectural decisions)
  - Files: `ccpm/rules/local-llm-decision-tree.md`

- [ ] **Task 8: Integration Testing**
  - Test complete workflow: `/pm:epic-start` with code generation tasks
  - Verify routing works correctly
  - Validate review loop catches issues
  - Test error scenarios (Ollama down, model missing)
  - Files: Test logs and validation report

- [ ] **Task 9: Documentation**
  - User guide for setup and configuration
  - Troubleshooting common issues
  - Configuration reference
  - Architecture diagrams
  - Files: `CLAUDE_HELPERS/LOCAL_LLM_GUIDE.md`

- [ ] **Task 10: End-to-End Validation**
  - Run complete CCPM workflow with hybrid system
  - Measure cost reduction
  - Track review iteration counts
  - Document any issues found
  - Files: Validation report with metrics

## Dependencies

### External Dependencies
- **Ollama** (0.1.0+): User installs and runs separately
- **Ollama Model**: User pulls code-capable model (deepseek-coder, codellama, etc.)
- **curl/wget**: HTTP client for API calls (already available in bash environments)
- **Claude API**: Existing access for review tasks
- **jq**: JSON parsing in bash scripts (commonly available)

### Internal Dependencies
- **CCPM Core**: Existing slash commands and workflow (✅ already present)
- **Task Tool**: Agent delegation system (✅ already present)
- **Settings System**: Configuration loading (✅ already present)
- **Hooks System**: Pre-tool-use interception (✅ already present)

### Critical Path Items
1. **Ollama client library** → Blocks all Ollama integration
2. **Local code generator agent** → Blocks code generation capability
3. **Task routing hook** → Blocks automatic delegation
4. **Review loop controller** → Blocks quality gate

**Dependency Graph**:
```
Task 1 (Ollama Client) → Task 3 (Code Gen Agent) → Task 5 (Review Loop) → Task 8 (Integration Test)
Task 2 (Config) → Task 6 (Routing Hook) → Task 8
Task 4 (Review Agent) → Task 5
Task 7 (Rules) → Task 6
Task 9 (Docs) depends on Task 8
Task 10 (E2E Validation) depends on Tasks 1-9
```

## Success Criteria (Technical)

### Performance Benchmarks
- Ollama connection: < 1 second
- Code generation: Acceptable to user (not optimized)
- Review turnaround: < 10 seconds per iteration
- Full workflow: Complete within user's patience threshold

### Quality Gates
- **Code Quality**: 80%+ of generated code passes review within 3 iterations
- **Error Handling**: All common errors (connection, model, timeout) have clear remediation steps
- **Routing Accuracy**: 95%+ of tasks routed to correct system
- **Integration**: Zero breaking changes to existing CCPM workflows

### Acceptance Criteria
1. ✅ Complete one full feature cycle (PRD → Epic → Implementation) using hybrid approach
2. ✅ Code generation uses Ollama (verified in logs)
3. ✅ Planning/review uses Claude (verified in logs)
4. ✅ Generated code meets project standards
5. ✅ Error messages are actionable
6. ✅ User reports system meets cost reduction goals

### Cost Validation
- **Baseline**: Measure current CCPM workflow costs (Claude only)
- **Target**: Achieve 70%+ reduction
- **Measurement**: Track Claude API calls before/after, calculate savings
- **Success**: User reports acceptable cost for continued CCPM usage

## Estimated Effort

### Overall Timeline: 2-3 Weeks
**Breakdown by Phase**:
- Phase 1 (Foundation): 2-3 days
- Phase 2 (Agent Integration): 3-4 days
- Phase 3 (Quality Loop): 3-4 days
- Phase 4 (Routing): 2-3 days
- Phase 5 (Polish): 2-3 days

### Resource Requirements
- **Developer**: Single developer (5+ years experience)
- **Infrastructure**: Local machine with 8GB+ RAM for Ollama
- **External Services**: Claude API access (already present)
- **Testing**: Real CCPM workflows for validation

### Critical Path
**Longest Path**: Tasks 1 → 3 → 5 → 8 → 10 (approximately 12-14 days)
- Task 1: 2 days (Ollama client)
- Task 3: 3 days (Code gen agent + prompt engineering)
- Task 5: 3 days (Review loop orchestration)
- Task 8: 2 days (Integration testing)
- Task 10: 2 days (E2E validation)

### Risk Buffer
- Add 20% buffer for unknowns (4-5 days)
- Primary risks: Ollama API quirks, prompt engineering iteration, review loop tuning

## Implementation Notes

### Simplification Opportunities Identified

1. **No New Config Files**: Extend existing `settings.json` instead
2. **Reuse Task Tool**: Don't build new orchestration, use existing agent system
3. **Bash-Only**: No new language dependencies, pure shell scripts
4. **Leverage Hooks**: Use existing pre-tool-use hooks for routing
5. **Markdown Agents**: Follow CCPM's existing agent pattern

### Existing Functionality to Leverage

- ✅ Agent invocation via Task tool
- ✅ Git-based coordination
- ✅ Configuration loading from settings.json
- ✅ Hook system for transparent modifications
- ✅ Error handling patterns
- ✅ CLI feedback mechanisms
- ✅ GitHub integration (for tracking)

### Key Design Principles

1. **Minimal Code Changes**: Most logic in new files, not modifications
2. **Configuration-Driven**: Behavior controlled by settings, not code
3. **Fail-Fast Validation**: Check prerequisites before attempting operations
4. **Transparent Operations**: User sees what system is handling each task
5. **Graceful Degradation**: Clear errors, no silent failures
6. **Idiomatic CCPM**: Follow existing patterns and conventions

## Tasks Created
- [ ] #10 - End-to-End Validation (parallel: false)
- [ ] #11 - Code Review Agent (parallel: true)
- [ ] #2 - Review Iteration Controller (parallel: false)
- [ ] #3 - Ollama Client Library (parallel: true)
- [ ] #4 - Task Routing Hook (parallel: false)
- [ ] #5 - Integration Testing (parallel: false)
- [ ] #6 - Configuration & Health Check Command (parallel: true)
- [ ] #7 - Routing Decision Rules (parallel: true)
- [ ] #8 - Documentation (parallel: false)
- [ ] #9 - Local Code Generator Agent (parallel: false)

**Total tasks**: 10
**Parallel tasks**: 4
**Sequential tasks**: 6
**Estimated total effort**: 160 hours (20 days)
## Next Steps After Epic Creation

1. **Decompose into Tasks**: ✅ Complete (10 tasks created)
2. **Sync to GitHub**: Run `/pm:epic-sync use-local-model-for-coding` to create issues
3. **Start Implementation**: Run `/pm:epic-start use-local-model-for-coding` for parallel execution
4. **Track Progress**: Use `/pm:status` and `/pm:next` to monitor work

## References

- PRD: `.claude/prds/use-local-model-for-coding.md`
- CCPM Architecture: `CCPM_ARCHITECTURE.md`
- Integration Examples: `CCPM_INTEGRATION_EXAMPLES.md`
- Ollama API: https://github.com/ollama/ollama/blob/main/docs/api.md
- CCPM Documentation: `README.md`
