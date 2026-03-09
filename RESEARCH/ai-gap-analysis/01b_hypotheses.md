---
name: hypotheses
created: 2026-02-02T00:00:00Z
updated: 2026-02-02T00:00:00Z
---

# Research Hypotheses

## H1: Linguistic Markers Are Sufficient for Gap Detection
**Prior Probability**: Medium (50%)

**Hypothesis**: Vague language markers (e.g., "something like", "maybe", "etc.", pronouns without antecedents) provide reliable signals for detecting incomplete feature specifications.

**Evidence Needed**:
- Studies on ambiguity detection in NLP
- Patterns from requirements engineering literature
- Comparison with confidence-based methods

**Testing Approach**: Compare linguistic pattern detection against slot-filling completeness metrics.

---

## H2: Slot-Filling Models Transfer to Feature Gap Detection
**Prior Probability**: High (75%)

**Hypothesis**: Established slot-filling patterns from conversational AI (required slots, optional slots, confirmation flows) effectively model feature request completeness.

**Evidence Needed**:
- Slot-filling research transferability
- Feature request mapping to slot schemas
- Completeness metrics from dialogue systems

**Testing Approach**: Map INVEST criteria and feature specification elements to slot schemas.

---

## H3: LLM Self-Assessment Is Unreliable Without Calibration
**Prior Probability**: High (80%)

**Hypothesis**: LLMs are systematically overconfident in their self-assessment of having sufficient information, requiring explicit calibration techniques.

**Evidence Needed**:
- Research on LLM overconfidence
- Calibration methods and their effectiveness
- Comparison of verbalized vs computed confidence

**Testing Approach**: Review calibration literature and identify practical correction methods.

---

## H4: Blocking vs Nice-to-Know Can Be Determined Algorithmically
**Prior Probability**: Medium (55%)

**Hypothesis**: Clear rules can distinguish information that blocks implementation from information that would be nice to have, based on INVEST criteria and dependency analysis.

**Evidence Needed**:
- Definition of Ready criteria mapping
- Critical path analysis for feature implementation
- Codebase dependency patterns

**Testing Approach**: Develop decision tree based on testability, estimability, and dependency factors.

---

## H5: Codebase Context Reduces Gap Count by 30%+
**Prior Probability**: Medium-High (65%)

**Hypothesis**: Analyzing existing codebase patterns, conventions, and similar features can auto-resolve at least 30% of gaps that would otherwise require user clarification.

**Evidence Needed**:
- AI coding assistant research on context awareness
- Reduction in clarifying questions with codebase access
- Types of gaps resolvable via code analysis

**Testing Approach**: Catalog gap types and identify which can be inferred from codebase patterns.

---

## H6: User Role Should Constrain Question Types
**Prior Probability**: High (70%)

**Hypothesis**: Effective gap probing should adapt questions based on user role (PM vs developer vs designer), avoiding technical questions for non-technical roles.

**Evidence Needed**:
- UX research on question appropriateness
- Role-based information availability
- User friction studies

**Testing Approach**: Map gap types to appropriate user roles for resolution.

---

## Hypothesis Tracking

| ID | Hypothesis | Prior | Status | Final |
|----|------------|-------|--------|-------|
| H1 | Linguistic markers sufficient | 50% | Testing | - |
| H2 | Slot-filling transfers | 75% | Testing | - |
| H3 | Self-assessment unreliable | 80% | Testing | - |
| H4 | Blocking algorithmic | 55% | Testing | - |
| H5 | Codebase reduces 30%+ | 65% | Testing | - |
| H6 | Role constrains questions | 70% | Testing | - |
