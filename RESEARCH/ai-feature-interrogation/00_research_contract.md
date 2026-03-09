---
name: ai-feature-interrogation
status: complete
created: 2026-02-02T00:00:00Z
updated: 2026-02-02T00:00:00Z
---

# Research Contract: AI Feature Interrogation

## Core Research Question
How can AI effectively interrogate users about features they want implemented in a codebase, extracting all relevant technical information needed before implementation begins?

## Decision/Use-Case
This research informs the implementation of `/dr-refine` - a skill that takes a vague feature request (e.g., "add search to the dashboard") and through targeted questioning, extracts all details needed for implementation (what to search, UI behavior, edge cases, integration points, etc.).

## Audience
Technical - developers building AI-assisted development tools and skills

## Scope

### Included
- Functional requirements elicitation techniques
- Non-functional requirements (performance, security, accessibility)
- Integration points with existing code detection
- Acceptance criteria patterns
- Edge cases and error handling discovery
- Interview/questioning techniques (funnel, laddering, scenario-based)
- Definition of Ready (DoR) and completeness heuristics
- Domain-specific probing for code features
- Conversational AI dialogue management patterns
- Existing tool analysis (GitHub Copilot Workspace, Cursor AI, v0.dev)

### Excluded
- Full project management workflows
- Team capacity planning
- Sprint planning
- Budget allocation
- Testing execution (focus on requirements, not test running)

## Constraints
- Focus on actionable, implementable question frameworks
- Must work with LLM-based automation
- Should integrate with existing codebase context

## Output Format
1. **Question Framework** - Structured question template for feature interrogation
2. **Completeness Checklist** - How to know when you have enough information
3. **Codebase Integration Patterns** - How to probe for existing patterns/constraints
4. **Dialogue Flow Design** - Multi-turn conversation architecture
5. **Evidence-backed recommendations** - What works, what doesn't, with sources

## Definition of Done
- [x] All 6 subquestions answered with C1-level evidence
- [x] All 5 hypotheses validated/invalidated with evidence
- [x] Actionable question framework ready for implementation
- [x] Dialogue flow specified for `/dr-refine` skill
- [x] Edge case handling documented
