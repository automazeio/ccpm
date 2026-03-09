---
name: research-plan
created: 2026-02-02T00:00:00Z
updated: 2026-02-02T00:00:00Z
---

# Research Plan: AI Gap Analysis

## Subquestions and Query Strategy

### SQ1: Gap Detection Signals
**Question**: What linguistic, contextual, and confidence-based signals indicate missing information in feature requests?

**Planned Queries**:
1. "LLM uncertainty quantification confidence scoring"
2. "ambiguity detection natural language processing vague terms"
3. "requirements elicitation incomplete information detection"
4. "slot filling missing slot detection conversational AI"

**Source Classes**:
- Academic (arXiv, ACL, SIGKDD)
- Industry (Microsoft Learn, AI vendor docs)
- Practitioner (Medium, engineering blogs)

---

### SQ2: Gap Taxonomy
**Question**: What categorization scheme best captures the types of gaps (requirements, constraints, edge cases, integration, verification)?

**Planned Queries**:
1. "requirements gap taxonomy classification"
2. "INVEST criteria completeness checklist"
3. "software requirements specification gaps categories"
4. "feature specification completeness criteria"

**Source Classes**:
- Academic (requirements engineering)
- Industry (Agile Alliance, Scrum guides)
- Practitioner (product management blogs)

---

### SQ3: Blocking vs Nice-to-Know
**Question**: How do we classify which gaps must be resolved before implementation vs can be assumed?

**Planned Queries**:
1. "definition of ready agile blocking requirements"
2. "critical path analysis feature dependencies"
3. "requirements prioritization blocking vs optional"
4. "implementation prerequisites software development"

**Source Classes**:
- Academic (software engineering)
- Industry (project management guides)
- Practitioner (agile methodology)

---

### SQ4: Codebase-Aware Detection
**Question**: How does existing codebase context inform what information is already known vs genuinely missing?

**Planned Queries**:
1. "AI coding assistant context aware codebase analysis"
2. "context gap AI coding tools repository understanding"
3. "code pattern detection existing implementation"
4. "codebase semantic indexing AI tools"

**Source Classes**:
- Industry (Augment, Cursor, Copilot docs)
- Academic (code understanding research)
- Practitioner (AI coding tool reviews)

---

### SQ5: Self-Assessment Confidence
**Question**: How can AI systems score their own readiness/confidence that sufficient information exists?

**Planned Queries**:
1. "LLM self-assessment calibration overconfidence"
2. "LLM know what they don't know epistemic uncertainty"
3. "confidence scoring LLM completeness metrics"
4. "uncertainty estimation large language models"

**Source Classes**:
- Academic (ML uncertainty quantification)
- Industry (AI safety research)
- Practitioner (LLM engineering guides)

---

### SQ6: Prioritization Logic
**Question**: When multiple gaps exist, what rules determine probing order?

**Planned Queries**:
1. "requirements prioritization triage methodology"
2. "clarifying question prioritization user experience"
3. "question ordering dialogue systems efficiency"
4. "information seeking behavior optimization"

**Source Classes**:
- Academic (HCI, dialogue systems)
- Industry (conversational AI design)
- Practitioner (UX research)

---

### SQ7: Ambiguity Detection
**Question**: What specific patterns identify vague terms, undefined references, and unstated assumptions?

**Planned Queries**:
1. "ambiguity detection requirements engineering LLM"
2. "vague language detection NLP patterns"
3. "unstated assumptions detection software requirements"
4. "clarification triggers conversational AI"

**Source Classes**:
- Academic (NLP, requirements engineering)
- Industry (NLU systems)
- Practitioner (prompt engineering)

---

## Stop Rules

### Saturation Criteria
- Last K=5 queries yield <10% net-new information

### Coverage Criteria
- All 7 subquestions have 3+ sources
- At least 1 A/B grade source per subquestion

### Confidence Criteria
- All C1 claims have 2+ independent sources
- Hypothesis probability shifts documented

### Budget Limits
- N_search = 30 max
- N_fetch = 30 max
- N_docs = 12 deep reads max
