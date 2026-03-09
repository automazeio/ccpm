---
name: synthesis-notes
created: 2026-02-02T00:00:00Z
updated: 2026-02-02T00:00:00Z
---

# Synthesis Notes

## Key Insights Emerged During Research

### Insight 1: The "Golden Prompt" Pattern is Underappreciated

Discovered in Dan Does Code blog: instructing AI to ask questions one at a time with labeled options dramatically improves the interrogation process. This is more powerful than generic "ask clarifying questions" instructions because:
- Forces sequential questioning (no overwhelming walls of questions)
- Labeled options (A, B, C) reduce cognitive load
- Wait-for-answer pattern ensures context is captured

**Implementation**: Should be baked into the `/dr-refine` system prompt.

### Insight 2: Copilot Workspace's Current/Desired State Pattern

GitHub's approach of generating TWO specifications - current state and desired state - is elegant because:
- Shows the AI understood the existing codebase
- Makes the delta explicit
- Allows targeted correction of misunderstandings

**Implementation**: `/dr-refine` should generate:
```
CURRENT: What exists today
DESIRED: What should exist after implementation
DELTA: Specific changes needed
```

### Insight 3: Slot Filling from Dialogue Systems

Microsoft's CLU documentation reveals enterprise-grade patterns for multi-turn information extraction:
- Track filled vs unfilled slots
- Allow progressive filling over multiple turns
- Handle corrections gracefully ("actually, I meant...")

**Implementation**: Maintain a spec schema and track completion percentage.

### Insight 4: INVEST as Termination Criteria

The INVEST mnemonic isn't just for writing stories - it's a checklist for "done asking questions":
- **Independent**: No external blockers identified
- **Negotiable**: Spec describes WHAT not HOW
- **Valuable**: User benefit is clear
- **Estimable**: Scope is bounded
- **Small**: Single feature, not epic
- **Testable**: Success criteria are verifiable

**Implementation**: Run INVEST check after Phase 3 to determine if more questions needed.

### Insight 5: Edge Cases Require Explicit Prompting

Multiple sources confirm users naturally describe happy paths. Edge cases, error handling, and boundary conditions must be explicitly prompted:
- "What if this fails?"
- "What if there's no data?"
- "What if the user does X while Y is happening?"

**Implementation**: Phase 3 must include mandatory failure scenario questions.

## Synthesis Decisions

### Decision 1: 4-Phase vs 3-Phase Structure

**Options**:
- 3 phases: Context, Behavior, Verification
- 4 phases: Context, Behavior, Edge Cases, Verification

**Decision**: 4 phases. Edge cases are too often skipped if not a dedicated phase.

### Decision 2: Fixed vs Adaptive Question Count

**Options**:
- Fixed: Always ask exactly 7 questions
- Adaptive: 3-10 based on complexity

**Decision**: Adaptive. Simple CRUD needs fewer questions than complex integrations.

### Decision 3: Codebase Analysis Timing

**Options**:
- Before any questions (front-load context)
- After Phase 1 (once scope is understood)
- Continuous (analyze as relevant)

**Decision**: After Phase 1. Need to understand scope before relevant patterns can be identified.

## Implementation Priority

1. **Golden Prompt Pattern** - Highest impact, simple to implement
2. **4-Phase Question Hierarchy** - Structure is essential
3. **INVEST Termination Check** - Know when to stop
4. **Codebase Integration** - High value but more complex
5. **Current/Desired State Output** - Elegant presentation layer
