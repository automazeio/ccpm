---
name: synthesis-notes
created: 2026-02-02T00:00:00Z
updated: 2026-02-02T00:00:00Z
---

# Synthesis Notes

## Key Insights from Research

### Insight 1: Gap Detection is Multi-Dimensional
Initial hypothesis was that linguistic markers would be sufficient. Evidence shows this is only one dimension. Effective gap detection requires:

1. **Surface signals** (linguistic) - Fast but shallow
2. **State signals** (slot fill) - Structured but rigid
3. **Context signals** (codebase) - Deep but expensive
4. **Confidence signals** (UQ) - Probabilistic but requires calibration

The weight formula (25/30/20/25) is a starting point; should be tuned per domain.

### Insight 2: INVEST Maps Cleanly to Gap Categories
The INVEST mnemonic provides a ready-made framework:
- Independent → Integration gaps
- Negotiable → (meta-quality, not a gap type)
- Valuable → Requirements gaps (value proposition)
- Estimable → Requirements + Constraint gaps
- Small → Requirements gaps (scope)
- Testable → Verification + Edge Case gaps

This mapping provides immediate practical value.

### Insight 3: Overconfidence is the Default
Multiple sources confirm LLMs are systematically overconfident. This has direct implications:
- Cannot trust verbalized confidence without calibration
- Must use sampling-based methods (self-consistency) as ground truth
- Should default to "ask" when uncertain, not "assume"

### Insight 4: Codebase Context is Underutilized
The 67% failure rate for context-blind AI [S08] suggests massive value in codebase analysis. Types of gaps auto-resolvable:
- Error handling patterns
- Authentication approaches
- API contract formats
- Existing similar features

Estimate: 30-50% of clarifying questions avoidable with good codebase indexing.

### Insight 5: The 14 Mistake Types Framework is Actionable
The follow-up question research [S05] provides concrete triggers:
- "Failing to elicit tacit assumptions"
- "Neglecting to explore alternatives"
- "Omitting clarification when encountering unclear statements"

These translate directly to gap detection rules.

## Synthesis Decisions

### Decision 1: Five Categories Not Seven
Considered adding "Performance Gap" and "Security Gap" as separate categories. Decision: Include these under "Constraint Gap" to keep taxonomy manageable.

### Decision 2: Binary Blocking Classification
Considered 3-tier (blocking/important/nice-to-know). Decision: Binary is cleaner. "Important" collapses into blocking when it affects testability or estimability.

### Decision 3: Role-Aware Prioritization
Initially considered making gap analysis role-agnostic. Decision: Role awareness prevents user frustration (don't ask PMs about database schemas).

### Decision 4: Confidence Threshold at 80%
Considered 90% (strict) or 70% (lenient). Decision: 80% balances user experience with specification quality. Decomposition research showed 80% slot fill correlates with implementation success.

## Implementation Notes

### For `/pm:gap-analysis` Skill

**Phase 1 MVP**:
- Linguistic pattern detection
- Slot-filling analysis
- Basic confidence scoring (self-consistency with N=3)
- INVEST checklist

**Phase 2 Enhancement**:
- Codebase context integration
- Role-aware prioritization
- Historical calibration

**Phase 3 Advanced**:
- Multi-stakeholder gap synthesis
- Real-time calibration from implementation outcomes
- Cross-project pattern transfer
