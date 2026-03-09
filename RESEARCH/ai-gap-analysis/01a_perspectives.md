---
name: perspectives
created: 2026-02-02T00:00:00Z
updated: 2026-02-02T00:00:00Z
---

# Perspective Discovery

## Related Domains
1. **Uncertainty Quantification** - How ML systems measure confidence
2. **Conversational AI** - Slot-filling and dialogue state tracking
3. **Requirements Engineering** - Completeness checking and ambiguity detection
4. **Software Quality Assurance** - Definition of Ready, INVEST criteria
5. **Information Retrieval** - Query understanding and intent disambiguation

## Perspectives

### 1. ML/AI Researcher (Uncertainty Quantification)
**Primary Concern**: How do we mathematically model what the system doesn't know?
- What confidence calibration methods work for open-ended generation?
- How do we distinguish aleatoric (inherent) from epistemic (knowledge) uncertainty?
- When should the model refuse to proceed vs express uncertainty?

### 2. Conversational AI Engineer (Practical)
**Primary Concern**: How do we build robust dialogue flows that handle incomplete input?
- What slot-filling patterns detect missing required information?
- How do we handle "I don't know" responses without infinite loops?
- When is enough information "enough" to proceed?

### 3. Requirements Engineer (Domain Expert)
**Primary Concern**: What makes a feature specification complete enough to implement?
- What taxonomy of requirements gaps exists (functional, non-functional, edge cases)?
- How do we detect unstated assumptions vs genuine unknowns?
- What completeness criteria (INVEST, Definition of Ready) apply?

### 4. Product Manager (User Perspective)
**Primary Concern**: How do we extract information without frustrating users?
- When should AI ask clarifying questions vs make reasonable assumptions?
- How do we prioritize questions by user role (don't ask PMs about database schemas)?
- What's the diminishing returns threshold for questioning?

### 5. Software Developer (Implementer)
**Primary Concern**: What gaps actually block implementation?
- Which missing information prevents writing code vs is nice-to-know?
- How does codebase context inform what's already known vs genuinely missing?
- What integration/dependency gaps cause downstream failures?

### 6. QA/Testing Perspective (Critic/Adversarial)
**Primary Concern**: What could go wrong that we haven't asked about?
- What edge cases and error conditions are typically unstated?
- How do we detect missing acceptance criteria?
- What gaps lead to "works on my machine" failures?

## Perspective-Informed Subquestions

### From ML/AI Researcher
1. What uncertainty quantification methods detect when LLMs lack information?
2. How can confidence scores indicate specification completeness?

### From Conversational AI Engineer
3. What slot-filling patterns identify missing required vs optional information?
4. How do dialogue systems determine "enough" information to proceed?

### From Requirements Engineer
5. What taxonomy categorizes different types of requirements gaps?
6. How do we detect ambiguous language and unstated assumptions?

### From Product Manager
7. How should gap probing be prioritized to minimize user friction?
8. When should AI assume vs ask, based on user role?

### From Software Developer
9. What codebase-aware signals indicate information already known vs missing?
10. Which gaps are blocking (must resolve) vs nice-to-know (can assume)?

### From QA/Testing
11. What patterns indicate missing edge case and error handling specifications?
12. How do we detect gaps in acceptance/verification criteria?

## Consolidated Subquestions (5-9)

1. **Gap Detection Signals**: What linguistic, contextual, and confidence-based signals indicate missing information in feature requests?

2. **Gap Taxonomy**: What categorization scheme best captures the types of gaps (requirements, constraints, edge cases, integration, verification)?

3. **Blocking vs Nice-to-Know**: How do we classify which gaps must be resolved before implementation vs can be assumed?

4. **Codebase-Aware Detection**: How does existing codebase context inform what information is already known vs genuinely missing?

5. **Self-Assessment Confidence**: How can AI systems score their own readiness/confidence that sufficient information exists?

6. **Prioritization Logic**: When multiple gaps exist, what rules determine probing order (user role, blocking status, implementation impact)?

7. **Ambiguity Detection**: What specific patterns identify vague terms, undefined references, and unstated assumptions?
