# Local LLM Routing Decision Tree

This document defines task classification criteria for routing between Claude API and local LLM (Ollama). The routing hook uses these rules to determine which system handles each task.

## Core Principle

**Claude handles thinking. Ollama handles typing.**

- **Claude**: Planning, architecture, design decisions, code review, quality gates
- **Ollama**: Code implementation, boilerplate generation, refactoring, test writing

## Decision Tree

```
Task Request
    ↓
Does task involve creating/modifying code files?
    ↓
    YES → Is it architectural or design decision?
    │         ↓
    │         YES → Route to CLAUDE
    │         NO → Does it involve security/payments/auth?
    │                 ↓
    │                 YES → Route to CLAUDE
    │                 NO → Route to OLLAMA → Code Review by CLAUDE
    │
    NO → Does task involve planning or documentation?
          ↓
          YES → Route to CLAUDE
          NO → Analyze keywords → Route based on pattern match
```

## Routing Patterns

### Route to OLLAMA (Code Generation)

Tasks that involve **writing, modifying, or generating code** where the requirements are clear and specific.

#### Keywords (Primary Indicators)
- `implement`
- `create function`
- `write code`
- `generate`
- `refactor`
- `add method`
- `create class`
- `build component`
- `add endpoint`
- `write test`
- `add validation`
- `create utility`

#### File Operation Indicators
- Creating new code files (`.js`, `.ts`, `.py`, `.sh`, `.go`, `.java`, etc.)
- Modifying existing implementation files
- Writing test files (`*.test.js`, `*_test.py`, `test_*.py`, etc.)
- Creating configuration files (`.json`, `.yaml`, `.toml`)
- Generating boilerplate code

#### Task Type Indicators
- CRUD operations implementation
- API endpoint creation
- Database query writing
- Form/component implementation
- Utility function creation
- Data transformation logic
- Input validation logic
- Error handling implementation
- Logging integration
- Test case writing
- Mock/fixture creation

#### Complexity Level (Suitable for Ollama)
- **Low**: Boilerplate, CRUD, simple utilities, config files
- **Medium**: Business logic with clear specs, integrations with known APIs, standard refactoring

### Route to CLAUDE (Planning & Review)

Tasks that involve **thinking, deciding, designing, or evaluating** where judgment and context are critical.

#### Keywords (Primary Indicators)
- `plan`
- `design`
- `architecture`
- `review`
- `analyze`
- `evaluate`
- `decide`
- `assess`
- `recommend`
- `strategy`
- `approach`
- `structure`
- `optimize` (when architectural)

#### Document Operation Indicators
- Creating PRDs (`.claude/prds/*.md`)
- Epic decomposition (`.claude/epics/*/epic.md`)
- Task breakdown (`.claude/epics/*/[task].md`)
- Architecture documentation
- Design documents
- Technical specifications
- Code review feedback
- Security assessments

#### Task Type Indicators
- PRD creation and brainstorming
- Epic planning and decomposition
- Task breakdown and estimation
- Architectural decisions
- Design pattern selection
- Library/framework evaluation
- Code quality review
- Security review
- Performance optimization strategy
- Database schema design
- API contract design
- System integration planning
- Error handling strategy
- Testing strategy

#### Quality-Critical Areas (Always Claude)
- **Security**: Authentication, authorization, encryption, data protection
- **Payments**: Payment processing, financial calculations, PCI compliance
- **Core Algorithms**: Complex business logic, critical data transformations
- **Cross-Cutting Concerns**: Logging strategy, error handling patterns, monitoring

## Edge Cases and Fallback Rules

### Ambiguous Tasks

When task could go either way, apply these tiebreakers:

1. **If in doubt, route to Claude** - Better to overspend than compromise quality
2. **Check context** - Is this part of a planning phase? → Claude. Implementation phase? → Ollama
3. **Check file types** - Markdown/docs → Claude. Code files → Ollama
4. **Check dependencies** - Does task require prior decisions? → Claude

### Mixed Tasks

Tasks that involve both planning and coding:

**Strategy**: Break into sequential subtasks
1. Planning/design phase → Claude
2. Implementation phase → Ollama → Claude review
3. Integration/validation phase → Claude

**Example**: "Design and implement user authentication"
- Subtask 1: "Design authentication flow and select approach" → Claude
- Subtask 2: "Implement authentication middleware" → Ollama
- Subtask 3: "Review authentication implementation for security" → Claude

### Override Conditions

Route to Claude even if pattern suggests Ollama:

1. **Critical Code Paths**
   - Authentication/authorization logic
   - Payment processing
   - Data encryption/decryption
   - Database migrations affecting production

2. **High Complexity**
   - Novel algorithms
   - Performance-critical code
   - Complex state management
   - Distributed system logic

3. **Unclear Requirements**
   - Ambiguous specifications
   - Multiple valid approaches
   - Significant architectural impact
   - Cross-cutting concerns

4. **First-Time Implementation**
   - New technology stack
   - Unfamiliar patterns
   - Prototype/proof-of-concept

### Fallback Behavior

If routing classification fails or is uncertain:

1. **Default**: Route to Claude (safe default)
2. **Log**: Record ambiguous classification for rule refinement
3. **Notify**: Inform user of routing decision and reasoning
4. **Allow Override**: Provide mechanism for user to force specific routing

## Reference Examples

### Ollama Examples (Code Generation)

| Task Description | Rationale |
|-----------------|-----------|
| "Create a REST API endpoint for user registration" | Clear implementation task, standard pattern |
| "Write unit tests for the UserService class" | Test writing, well-defined scope |
| "Implement input validation for the contact form" | Boilerplate validation logic |
| "Add logging to all database queries" | Repetitive code addition |
| "Refactor UserController to use async/await" | Code transformation, clear pattern |
| "Create a utility function to format dates" | Simple utility, no design decisions |
| "Generate CRUD operations for Product model" | Boilerplate generation |
| "Write a shell script to backup the database" | Script creation, standard task |
| "Implement pagination for the products list" | Standard pattern implementation |
| "Add error handling to API endpoints" | Code addition, established pattern |

### Claude Examples (Planning & Review)

| Task Description | Rationale |
|-----------------|-----------|
| "Design the database schema for the blog platform" | Architectural decision, many trade-offs |
| "Review this authentication code for security issues" | Security-critical review |
| "Plan the migration strategy from REST to GraphQL" | Strategic planning, complex migration |
| "Evaluate whether to use Redis or Memcached for caching" | Technology decision, requires analysis |
| "Create a PRD for the notification system" | Product planning, requires brainstorming |
| "Decompose the 'user management' epic into tasks" | Epic breakdown, task estimation |
| "Analyze the performance bottleneck in the data pipeline" | Performance analysis, requires investigation |
| "Design the error handling strategy for the microservices" | Architectural decision, cross-cutting |
| "Review the payment processing implementation" | Security-critical review |
| "Recommend the best approach for real-time updates" | Technical recommendation, trade-off analysis |

### Mixed Examples (Sequential Routing)

| Task Description | Routing Strategy |
|-----------------|------------------|
| "Design and implement the comment system" | 1. Design → Claude<br>2. Implement → Ollama<br>3. Review → Claude |
| "Create user authentication with JWT" | 1. Design flow → Claude<br>2. Implement middleware → Ollama<br>3. Security review → Claude |
| "Build a file upload feature" | 1. Design architecture → Claude<br>2. Implement upload handler → Ollama<br>3. Review security → Claude |
| "Optimize the search functionality" | 1. Analyze bottleneck → Claude<br>2. Implement optimizations → Ollama<br>3. Validate performance → Claude |

## Quality Assurance Loop

All Ollama-generated code undergoes Claude review:

```
Ollama generates code
    ↓
Claude reviews code
    ↓
Issues found? → YES → Claude provides feedback → Ollama regenerates (max 3 iterations)
    ↓
    NO → Code approved
```

### Review Criteria
- Meets requirements from specification
- Follows project coding standards
- No obvious bugs or logic errors
- Appropriate error handling
- Security considerations addressed (for relevant code)
- Performance considerations reasonable
- Test coverage adequate

### Iteration Limits
- **Maximum**: 3 review iterations per task
- **Reason**: Prevent infinite loops, maintain velocity
- **Override**: User can manually accept code at any iteration
- **Escalation**: If 3 iterations fail, route entire task to Claude

## Performance Characteristics

### When Speed Matters (Favor Ollama)
- Boilerplate generation
- Test file creation
- Configuration file generation
- Simple CRUD operations
- Repetitive refactoring tasks

### When Quality Matters (Favor Claude)
- Security-critical code
- Core business logic
- Public API design
- Database schema design
- Error handling strategies

### Cost vs Quality Trade-offs

| Scenario | Recommendation | Rationale |
|----------|---------------|-----------|
| MVP/Prototype | Ollama-heavy | Speed over perfection, iterate fast |
| Production Feature | Balanced | Ollama for implementation, Claude for quality gates |
| Critical Infrastructure | Claude-heavy | Quality and reliability paramount |
| Refactoring/Maintenance | Ollama-heavy | Clear patterns, lower risk |

## Configuration Flags

The routing behavior can be tuned via `settings.json`:

```json
{
  "local_llm": {
    "enabled": true,
    "routing_strategy": "balanced",  // "aggressive" | "balanced" | "conservative"
    "always_review": true,            // Always send Ollama code through Claude review
    "max_iterations": 3,              // Review loop iteration limit
    "override_keywords": [],          // Force Claude for these keywords
    "force_ollama_keywords": []       // Force Ollama for these keywords
  }
}
```

### Routing Strategies
- **aggressive**: Route maximum tasks to Ollama, only critical to Claude
- **balanced**: Default rules as documented above
- **conservative**: Route to Claude unless clearly suitable for Ollama

## Usage by Routing Hook

The routing hook (`ccpm/hooks/local-llm-route.sh`) implements this decision tree:

1. Parse task description and context
2. Extract keywords and file operations
3. Check override conditions
4. Apply decision tree rules
5. Log routing decision
6. Route to appropriate agent
7. If Ollama, invoke review loop

## Continuous Improvement

Track routing decisions and outcomes to refine rules:

- **Log**: Every routing decision with reasoning
- **Measure**: Success rate (does Ollama code pass review?)
- **Refine**: Update rules based on patterns
- **Feedback**: User can flag incorrect routing decisions

## Summary Quick Reference

| Indicator | Route To |
|-----------|----------|
| Keywords: implement, create, write, generate, refactor | Ollama |
| Keywords: plan, design, architecture, review, analyze | Claude |
| File ops: Creating/editing `.js`, `.py`, `.sh` files | Ollama |
| File ops: Creating/editing `.md` PRD/epic files | Claude |
| Task type: CRUD, boilerplate, tests, utilities | Ollama |
| Task type: PRD, epic, design, architecture | Claude |
| Complexity: Low to medium with clear specs | Ollama |
| Complexity: High, ambiguous, or novel | Claude |
| Quality: Security, payments, core algorithms | Claude |
| Quality: Standard features, well-defined scope | Ollama |
| Context: Implementation phase | Ollama |
| Context: Planning/design phase | Claude |
| When uncertain | Claude |

**Remember**: All Ollama-generated code is reviewed by Claude. This routing system optimizes cost while maintaining quality through the review loop.
