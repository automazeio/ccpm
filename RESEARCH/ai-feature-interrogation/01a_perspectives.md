---
name: ai-feature-interrogation-perspectives
created: 2026-02-02T00:00:00Z
updated: 2026-02-02T00:00:00Z
---

# Perspectives: AI Feature Interrogation

## Identified Perspectives

### 1. Requirements Engineer / Business Analyst
**Primary Concern**: Completeness and correctness of captured requirements
**Key Questions**:
- What information is truly necessary vs nice-to-have?
- How do we avoid scope creep during elicitation?
- What's the minimum viable specification for a feature?
- How do we capture non-functional requirements systematically?

### 2. Software Developer / Implementer
**Primary Concern**: Having enough technical detail to implement correctly
**Key Questions**:
- What existing patterns should the new feature follow?
- What integration points need to be understood?
- Are there API contracts or data schemas to consider?
- What edge cases will I encounter during implementation?

### 3. UX Researcher / Interview Specialist
**Primary Concern**: Effective questioning techniques that don't bias responses
**Key Questions**:
- How do we structure questions to get authentic answers?
- When should we drill deep vs move on?
- How do we handle vague or incomplete answers?
- What sequence of questions works best?

### 4. Conversational AI / Dialogue Systems Expert
**Primary Concern**: Managing multi-turn conversations and state
**Key Questions**:
- How do we track what information has been gathered?
- How do we handle "I don't know" responses gracefully?
- When is the dialogue complete?
- How do we avoid repetitive or annoying questioning?

### 5. Product Manager / Stakeholder (Adversarial)
**Primary Concern**: Value delivery without over-engineering
**Key Questions**:
- Are we asking questions that actually matter for the MVP?
- Are we gathering requirements we'll never use?
- Is the interrogation process itself adding unnecessary delay?
- Can we ship without some of this information?

### 6. QA Engineer / Tester (Practical)
**Primary Concern**: Testable acceptance criteria from the start
**Key Questions**:
- Are the requirements specific enough to test?
- Have error conditions been considered?
- Are success/failure criteria clear?
- Can we write tests from these specifications?

## Perspective Coverage Map

| Subquestion | Perspectives Covered |
|-------------|---------------------|
| SQ1: Information needed before implementation | RE, Dev, QA |
| SQ2: Interview/questioning techniques | UX, AI |
| SQ3: Completeness determination | RE, PM, QA |
| SQ4: Domain-specific probing for code | Dev, RE |
| SQ5: Conversational dialogue management | AI, UX |
| SQ6: Existing tools and frameworks | Dev, AI, PM |

## Adversarial Perspectives

**The "Ship It" PM**: "You're over-engineering this. We can figure out edge cases during development. Just ask what the feature should do and start coding."

**The Skeptical Developer**: "No amount of questioning will capture the real requirements. They always change once users see the feature. Why waste time on extensive interrogation?"

**The Impatient User**: "I just want search on the dashboard. Why are you asking me 20 questions? Just make it work like Google."

## Practical Perspectives

**The On-Call Developer**: "I need to know exactly what error states to handle. If the search fails, what do I show? If there are no results, what's the message? These details matter at 2am."

**The Junior Developer**: "I don't know the codebase well. I need the AI to tell me which existing patterns to follow, not just what the feature should do."

**The Code Reviewer**: "Requirements that don't specify behavior aren't requirements. I need to know what to verify during code review."
