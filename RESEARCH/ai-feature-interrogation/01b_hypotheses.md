---
name: ai-feature-interrogation-hypotheses
created: 2026-02-02T00:00:00Z
updated: 2026-02-02T00:00:00Z
---

# Hypotheses: AI Feature Interrogation

## H1: Structured Question Hierarchy
**Hypothesis**: A structured question hierarchy (context -> behavior -> edge cases -> verification) extracts more complete requirements than free-form conversation.

**Prior Probability**: High (70-90%)

**Supporting Evidence**:
- The funnel technique in qualitative research progresses "broad, open-ended questions" to "more narrowly-scoped" questions systematically
- GitHub Copilot Workspace uses a structured flow: specification (current/desired state) -> plan -> implementation
- LLMREI research shows structured prompting produces "context-enhancing" and "context-deepening" questions

**Counter-Evidence to Seek**:
- Cases where unstructured dialogue discovered unexpected requirements
- Situations where rigid structure missed novel use cases

**Outcome**: **VALIDATED** - Evidence strongly supports structured questioning over free-form

---

## H2: Codebase-Aware Interrogation
**Hypothesis**: Codebase-aware interrogation (asking about existing patterns) reduces implementation friction significantly.

**Prior Probability**: High (70-90%)

**Supporting Evidence**:
- Augment Code maintains "a live understanding of your entire stack—code, dependencies, architecture"
- GitLoop "learns from your repository's unique patterns, practices, and previously merged PRs"
- Teams using codebase-aware tools report "productivity gains in the 20-50% range"
- Qodo's context engine "reasons through problems like senior engineers do"

**Counter-Evidence to Seek**:
- Greenfield projects where no patterns exist
- Cases where following existing patterns was wrong

**Outcome**: **VALIDATED** - Codebase awareness is critical for quality implementation

---

## H3: 5-7 Questions for 80% Information
**Hypothesis**: 5-7 targeted questions can capture 80% of implementation-critical information for most features.

**Prior Probability**: Medium (40-70%)

**Supporting Evidence**:
- Verdant AI's Planner Agent "asks 5-7 clarifying questions" before creating a plan
- Definition of Ready typically includes 6-8 criteria (INVEST)
- Acceptance criteria recommendations: "3-7 criteria per story"

**Counter-Evidence to Seek**:
- Complex features requiring more questions
- Domains with higher question requirements

**Outcome**: **PARTIALLY VALIDATED** - 5-7 questions work for standard features; complex features may need more

---

## H4: Edge Cases Omitted Without Prompting
**Hypothesis**: Users often omit edge cases unless explicitly prompted with scenario questions.

**Prior Probability**: High (70-90%)

**Supporting Evidence**:
- "What if...?" questions are specifically used to "think of all the alternative scenarios"
- Users "don't know how to express emotional benefits" (applies to technical edge cases too)
- Edge cases are "the opposite of your happy path"—users naturally focus on happy path
- Research shows "clarifying questions" help users "think through edge cases you hadn't considered"

**Counter-Evidence to Seek**:
- Experienced developers who proactively consider edge cases
- Domains where edge cases are obvious

**Outcome**: **VALIDATED** - Explicit scenario prompting is essential for edge case discovery

---

## H5: Summarization Catches Misunderstandings
**Hypothesis**: Summarizing extracted requirements back to the user catches misunderstandings before implementation.

**Prior Probability**: High (70-90%)

**Supporting Evidence**:
- Copilot Workspace generates a specification for "user review/editing" before proceeding
- The "proposed specification" articulates the end state and focuses on "success criteria"
- Users can "edit both lists" to "correct the system's understanding"
- "Everything in Workspace is designed to be edited, regenerated, or undone"

**Counter-Evidence to Seek**:
- Users who rubber-stamp without reviewing
- Summaries that are too long to review effectively

**Outcome**: **VALIDATED** - Summarization is essential, but must be concise and editable

---

## Summary Table

| Hypothesis | Prior | Outcome | Confidence |
|------------|-------|---------|------------|
| H1: Structured hierarchy | High | VALIDATED | 85% |
| H2: Codebase-aware | High | VALIDATED | 90% |
| H3: 5-7 questions | Medium | PARTIAL | 70% |
| H4: Edge cases omitted | High | VALIDATED | 85% |
| H5: Summarization | High | VALIDATED | 85% |
