---
name: contradictions-log
created: 2026-02-02T00:00:00Z
updated: 2026-02-02T00:00:00Z
---

# Contradictions and Tensions Log

## Resolved Contradictions

### C1: Linguistic vs Multi-Signal Detection
**Tension**: Some requirements engineering literature suggests linguistic ambiguity detection alone is sufficient, while AI/ML literature emphasizes confidence-based approaches.

**Resolution**: Both are necessary but neither sufficient alone. 94.3% of business descriptions contain ambiguity [S16], but not all ambiguity is blocking. Multi-signal approach combines linguistic detection (surface) with confidence scoring (depth).

**Implication**: Implementation should use linguistic patterns as triggers, then validate with confidence scoring.

### C2: Ask vs Assume Threshold
**Tension**: Research on clarifying questions shows users dislike unnecessary questions [S03], but requirements literature shows incomplete specs cause downstream failures [S08].

**Resolution**: Use blocking classification to determine threshold. Ask for blocking gaps, assume for nice-to-know gaps with codebase precedent.

**Implication**: Prioritization algorithm critical for user experience.

### C3: Self-Consistency vs Verbalized Confidence
**Tension**: Some papers recommend verbalized confidence (asking model to rate itself), while others show self-consistency is more reliable.

**Resolution**: Self-consistency has lowest Expected Calibration Error [S01]. Verbalized confidence useful as secondary signal but requires calibration.

**Implication**: Use self-consistency as primary method; verbalized confidence as tiebreaker.

## Unresolved Tensions

### U1: Novel Features Problem
**Tension**: Gap detection relies partly on codebase context, but genuinely novel features have no precedent.

**Status**: No clear resolution. For novel features, rely more heavily on linguistic signals and slot-filling completeness.

**Research Gap**: Need study on gap detection accuracy for novel vs familiar features.

### U2: User Role Inference
**Tension**: Prioritization should adapt to user role, but role is not always explicit or reliable.

**Status**: Default to conservative (ask more) when role unclear. Could improve with interaction history.

**Research Gap**: How to reliably infer user expertise level from conversation.
