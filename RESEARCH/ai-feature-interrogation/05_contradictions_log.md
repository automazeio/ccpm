---
name: contradictions-log
created: 2026-02-02T00:00:00Z
updated: 2026-02-02T00:00:00Z
---

# Contradictions Log

## Resolved Contradictions

### C1: Funnel vs Reverse Funnel Direction

**Conflict**: One source described "laddering" as broad-to-specific (same as funnel), while another described it as specific-to-broad (opposite).

**Resolution**: The dominant usage in UX research literature is:
- **Funnel**: Broad to specific (open -> probing -> closed)
- **Laddering**: Drilling down with repeated "why" questions on a single topic

The source describing laddering as "general to specific" appears to be a minority usage. The NN/g definition (funnel = broad to specific) is authoritative.

**Evidence**: NN/g Funnel Technique (A-grade source) vs single contrary source

---

### C2: Optimal Question Count

**Conflict**:
- Verdant AI uses 5-7 questions
- INVEST has 6 criteria
- Acceptance criteria recommendation is 3-7
- Some sources suggest "as many as needed"

**Resolution**: 5-7 is a good default for standard features, but complexity should modulate:
- Simple features: 3-4 questions
- Standard features: 5-7 questions
- Complex features: 7-10 questions
- >10 questions suggests the feature should be split

This is consistent across sources when accounting for complexity levels.

---

### C3: Specification Detail Level

**Conflict**:
- Some sources recommend detailed upfront specification
- Agile sources warn against over-specification ("some details are best clarified once you've started")

**Resolution**: The research supports "minimum viable specification" - enough to start, not everything. The Definition of Ready should prevent obvious gaps while not requiring complete knowledge. Use H3's "80% rule" - capture 80% upfront, discover 20% during implementation.

---

## Unresolved Tensions

### T1: Codebase Productivity Claims

**Tension**: Tool vendors claim 20-50% productivity gains from codebase-aware AI. This is likely inflated or context-dependent (self-reported by vendors).

**Status**: Noted as "Partially Verified" - the direction is likely correct, but specific percentages should be treated skeptically.

---

### T2: Question Fatigue vs Completeness

**Tension**: More questions = more complete requirements, but also more user fatigue. The "laddering can become annoying" warning applies to all intensive questioning.

**Status**: Managed through adaptive questioning - skip questions when codebase analysis or earlier answers provide the information. Don't ask redundant questions.

---

### T3: Automation Limits

**Tension**: LLMREI research shows LLMs can automate interviews, but also notes they "struggle with genuinely novel domains" and lack "real-time adaptation to stakeholder reactions."

**Status**: AI interrogation is a powerful tool but not a complete replacement for human judgment, especially for novel or sensitive domains.
