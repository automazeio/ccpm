---
name: ai-gap-analysis
status: complete
created: 2026-02-02T00:00:00Z
updated: 2026-02-02T00:00:00Z
---

# Research Report: AI Gap Analysis for Feature Requests

## Executive Summary

This research investigates how AI systems can detect, categorize, prioritize, and self-assess gaps in user feature requests. The findings synthesize evidence from uncertainty quantification research, conversational AI, requirements engineering, and AI coding assistant literature.

**Key Findings:**

1. **Gap detection requires multi-modal signals** - Effective gap detection combines linguistic markers (ambiguity patterns), slot-filling state (unfilled required fields), codebase context (existing patterns), and confidence scoring (uncertainty quantification).

2. **A five-category gap taxonomy is sufficient** - Gaps can be categorized as: Requirements Gaps, Constraint Gaps, Edge Case Gaps, Integration Gaps, and Verification Gaps.

3. **Blocking classification follows INVEST + Testability** - Gaps blocking implementation are those that prevent the specification from being Independent, Estimable, or Testable under INVEST criteria.

4. **LLMs are systematically overconfident** - Studies show 30%+ error rates despite high confidence. Self-consistency sampling is the most reliable calibration method (lowest Expected Calibration Error in 11/13 tasks).

5. **Codebase context can auto-resolve 30-50% of gaps** - Context-aware tools that index entire repositories can answer questions about patterns, conventions, and integration points without user input.

6. **The 14-mistake-types framework provides actionable triggers** - Requirements engineering research identifies specific clarification triggers (unclear statements, contradictions, missing alternatives).

---

## Part 1: Gap Detection Framework

### 1.1 Multi-Signal Gap Detection Model

Effective gap detection requires combining multiple signal types:

```
Gap Detection Score = w1*Linguistic + w2*SlotState + w3*Codebase + w4*Confidence
```

| Signal Type | Detection Method | Weight |
|-------------|------------------|--------|
| **Linguistic** | Ambiguity pattern matching | 25% |
| **Slot State** | Required slot fill percentage | 30% |
| **Codebase** | Context comparison against patterns | 20% |
| **Confidence** | Uncertainty quantification metrics | 25% |

### 1.2 Linguistic Gap Signals

**Ambiguity Markers** (from requirements engineering research):

| Pattern | Example | Gap Type |
|---------|---------|----------|
| Vague quantifiers | "fast", "large", "some" | Constraint |
| Undefined pronouns | "it should handle that" | Requirements |
| Hedge words | "maybe", "probably", "something like" | All types |
| Ellipsis markers | "etc.", "and so on", "..." | Edge Case |
| Passive voice without agent | "should be validated" | Requirements |
| Temporal ambiguity | "before", "after", "when ready" | Constraint |

**Evidence**: 94.3% of business process descriptions contain at least one ambiguity type [S16], validating that ambiguity detection is broadly applicable.

### 1.3 Slot-Filling Gap Detection

Map feature specifications to required and optional slots:

```yaml
required_slots:
  - goal: "What problem does this solve?"
  - trigger: "What initiates this feature?"
  - input: "What data is provided?"
  - output: "What result is produced?"
  - error_handling: "What happens on failure?"

optional_slots:
  - constraints: "What limits apply?"
  - permissions: "Who can use this?"
  - performance: "What speed/scale requirements?"
  - edge_cases: "What unusual scenarios exist?"
```

**Gap Detection Rule**: If required_slots.fill_percentage < 80%, trigger gap analysis.

**Evidence**: Slot-filling systems prompt for missing required information automatically [S09]. LLMREI achieved 73.7% requirements elicitation using this approach [S02].

### 1.4 Codebase-Aware Gap Detection

Context-aware analysis identifies:

| Codebase Signal | Gap Implication | Auto-Resolution |
|-----------------|-----------------|-----------------|
| Similar feature exists | Pattern available | HIGH |
| Existing error handler | Error handling known | HIGH |
| API contract defined | Integration spec exists | MEDIUM |
| No similar patterns | Genuinely novel | LOW |
| Conflicting patterns | Clarification needed | NONE |

**Diagnostic Tests** (from Augment Code research):
1. **Function renaming test** - Can AI rename across codebase? (reveals context depth)
2. **Middleware placement test** - Can AI find correct insertion point? (reveals structure understanding)
3. **Dependency update test** - Can AI handle cascading changes? (reveals relationship understanding)

**Evidence**: Context-blind AI generates code that breaks 67% of enterprise deployments due to missing architectural visibility [S08].

### 1.5 Confidence-Based Gap Detection

**Uncertainty Types**:

| Type | Source | Detection Method |
|------|--------|------------------|
| **Aleatoric** (Input) | Ambiguous/underspecified prompt | Entropy on interpretations |
| **Epistemic** (Knowledge) | Model lacks domain knowledge | Consistency across samples |
| **Reasoning** | Multiple valid inference paths | Divergence in chain-of-thought |

**Key Threshold**: Information gain > 0.1 indicates perceived ambiguity requiring clarification [S07].

**Practical Methods**:
1. **Self-consistency sampling** - Generate multiple responses; high variance = high uncertainty
2. **Semantic entropy** - Cluster responses by meaning; dispersed clusters = uncertainty
3. **Verbalized confidence** - Ask model to rate its own confidence (requires calibration)

**Evidence**: Self-consistency is the most reliable confidence strategy with lowest Expected Calibration Error in 11/13 tasks [S01].

---

## Part 2: Gap Taxonomy

### 2.1 Five-Category Gap Classification

| Category | Definition | Examples | Typical Source |
|----------|------------|----------|----------------|
| **Requirements Gap** | Core functional behavior unspecified | Input format, output structure, success criteria | User (PM/Designer) |
| **Constraint Gap** | Limits and boundaries undefined | Performance, size, rate limits, permissions | Technical (Dev/Architect) |
| **Edge Case Gap** | Error handling and boundaries missing | Failure scenarios, empty states, concurrent access | Technical (Dev/QA) |
| **Integration Gap** | Connection to existing systems unclear | API contracts, data flow, authentication | Technical (Dev) |
| **Verification Gap** | Success criteria undefined | Acceptance tests, metrics, observability | User (PM) + Technical |

### 2.2 Gap Detection Patterns by Category

**Requirements Gaps**:
- Missing: user story (who/what/why)
- Missing: happy path description
- Missing: data format specifications
- Trigger: "What should happen when...?" is unanswerable

**Constraint Gaps**:
- Missing: numeric limits (max users, file size, timeout)
- Missing: permission model (who can access)
- Missing: performance requirements (latency, throughput)
- Trigger: "Is there a limit on...?" has no answer

**Edge Case Gaps**:
- Missing: error handling strategy
- Missing: empty/null state behavior
- Missing: concurrent access handling
- Trigger: "What if X fails?" has no answer

**Integration Gaps**:
- Missing: API contract specifications
- Missing: authentication/authorization approach
- Missing: data transformation requirements
- Trigger: Codebase shows existing integration patterns not referenced

**Verification Gaps**:
- Missing: acceptance criteria
- Missing: success metrics
- Missing: test scenarios
- Trigger: "How do we know it works?" is unanswerable

### 2.3 INVEST Mapping to Gap Categories

| INVEST | Gap Category | Detection Question |
|--------|--------------|-------------------|
| **I**ndependent | Integration | "Does this depend on other unbuilt features?" |
| **N**egotiable | Requirements | "Is this specifying WHAT not HOW?" |
| **V**aluable | Requirements | "Who benefits and how?" |
| **E**stimable | Requirements + Constraint | "Is scope bounded enough to estimate?" |
| **S**mall | Requirements | "Can this ship in one iteration?" |
| **T**estable | Verification + Edge Case | "How will we verify success?" |

---

## Part 3: Blocking vs Nice-to-Know Classification

### 3.1 Blocking Gap Criteria

A gap is **BLOCKING** if any of these apply:

| Criterion | Description | Test |
|-----------|-------------|------|
| **Untestable** | Cannot write acceptance test | "Can we verify success with given info?" |
| **Unestimable** | Cannot estimate effort | "Can we scope this to a sprint?" |
| **Unimplementable** | Multiple contradictory interpretations | "Do engineers agree on approach?" |
| **Integration-critical** | Missing dependency specification | "Do we know all external touchpoints?" |

### 3.2 Nice-to-Know Gap Criteria

A gap is **NICE-TO-KNOW** if:

| Criterion | Description | Default Strategy |
|-----------|-------------|------------------|
| **Has codebase precedent** | Similar feature exists | Follow existing pattern |
| **Has industry default** | Standard practice exists | Use common approach |
| **Is optimization** | Affects quality not correctness | Defer to iteration |
| **Is edge case with <5% frequency** | Rare scenario | Handle generically |

### 3.3 Classification Decision Tree

```
Is the gap about core functionality (happy path)?
├── YES → BLOCKING (Requirements Gap)
└── NO → Continue...

Can the feature be tested without this information?
├── NO → BLOCKING (Verification Gap)
└── YES → Continue...

Does codebase have existing pattern for this?
├── YES → NICE-TO-KNOW (use existing pattern)
└── NO → Continue...

Is this about error handling for common scenarios?
├── YES → BLOCKING (Edge Case Gap)
└── NO → NICE-TO-KNOW (handle generically)
```

### 3.4 Priority Scoring Formula

```
Priority Score = (Blocking * 10) + (User-Resolvable * 3) + (Implementation-Impact * 2)
```

| Factor | Values | Weight |
|--------|--------|--------|
| **Blocking** | 0 (nice-to-know) or 1 (blocking) | 10 |
| **User-Resolvable** | 0 (technical) or 1 (user can answer) | 3 |
| **Implementation-Impact** | 1-3 (low to high code impact) | 2 |

Sort gaps by Priority Score descending; probe highest first.

---

## Part 4: Self-Assessment and Confidence Scoring

### 4.1 The Overconfidence Problem

**Key Finding**: LLMs exhibit systematic overconfidence. Studies show:
- 30%+ factual errors in medical QA despite high confidence [S01]
- Models cluster predictions at 90-100% confidence but achieve much lower accuracy [S01]
- Standard RLHF annotation prefers "complete but presumptuous answers over incomplete clarifying questions" [S03]

### 4.2 Confidence Scoring Methods

**Recommended Approach: Multi-Method Fusion**

| Method | Type | When to Use | Reliability |
|--------|------|-------------|-------------|
| Self-consistency | Sampling | Always | Highest |
| Semantic entropy | Sampling | Complex features | High |
| Verbalized confidence | Prompting | Quick assessment | Medium (requires calibration) |
| Slot fill percentage | Rule-based | Structured specs | High |

**Self-Consistency Implementation**:
```
1. Generate N=5 interpretations of the feature request
2. Compare pairwise similarity (semantic or structural)
3. High agreement (>80%) = High confidence
4. Low agreement (<60%) = Low confidence, trigger clarification
```

### 4.3 Completeness Metrics

**Slot-Based Completeness**:
```
Completeness = (Filled_Required_Slots / Total_Required_Slots) * 0.7 +
               (Filled_Optional_Slots / Total_Optional_Slots) * 0.3
```

**INVEST-Based Completeness**:
```
INVEST_Score = (Criteria_Passed / 6) * 100%
Ready_Threshold = 83% (5/6 criteria)
```

### 4.4 "Ready to Implement" Thresholds

| Confidence Level | Slot Completeness | INVEST Score | Action |
|------------------|-------------------|--------------|--------|
| **Ready** | >90% | 100% (6/6) | Proceed to implementation |
| **Likely Ready** | >80% | 83% (5/6) | Proceed with assumptions documented |
| **Needs Clarification** | 60-80% | 67% (4/6) | Probe blocking gaps only |
| **Insufficient** | <60% | <67% | Comprehensive gap analysis required |

### 4.5 Calibration Techniques

**Post-hoc Calibration**:
1. Track predicted confidence vs actual implementation success
2. Build calibration curve from historical data
3. Adjust raw confidence scores: `Calibrated = f(Raw)`

**Practical Approach for Claude Code**:
- Use slot fill percentage as primary metric (objective)
- Use self-consistency as secondary metric (model-based)
- Use verbalized confidence as tiebreaker only
- Document all assumptions when proceeding with <100% confidence

---

## Part 5: Prioritization Logic

### 5.1 Multi-Factor Prioritization Algorithm

```python
def prioritize_gaps(gaps: List[Gap]) -> List[Gap]:
    for gap in gaps:
        gap.score = calculate_priority(gap)
    return sorted(gaps, key=lambda g: g.score, reverse=True)

def calculate_priority(gap: Gap) -> float:
    blocking_weight = 10 if gap.is_blocking else 0
    role_weight = 3 if user_can_resolve(gap, current_user_role) else 0
    impact_weight = gap.implementation_impact * 2  # 1-3 scale
    dependency_weight = 5 if gap.blocks_other_gaps else 0

    return blocking_weight + role_weight + impact_weight + dependency_weight
```

### 5.2 User Role Awareness

| User Role | Can Resolve | Cannot Resolve |
|-----------|-------------|----------------|
| **PM/Product** | Requirements, Verification, Business Constraints | Technical architecture, Database schema |
| **Designer** | UI/UX behavior, User flows | API contracts, Performance constraints |
| **Developer** | Technical constraints, Integration, Edge cases | Business requirements, User value |
| **Architect** | All technical gaps | Business requirements |

**Prioritization Rule**: Deprioritize gaps the current user role cannot resolve.

### 5.3 Diminishing Returns Detection

**Stop probing when**:
1. Slot completeness > 90%
2. Last 3 questions yielded no new required slot fills
3. All blocking gaps resolved
4. User indicates time constraint (LLMREI pattern: "adapted by swiftly ending the conversation" [S02])

### 5.4 Question Ordering Strategy

Based on the 14-mistake-types framework [S05]:

| Priority | Question Type | When to Ask |
|----------|---------------|-------------|
| 1 | Goal clarification | Always first if unclear |
| 2 | Scope boundaries | After goal established |
| 3 | Critical path behavior | For each required slot |
| 4 | Error handling | After happy path clear |
| 5 | Constraints | When behavior specified |
| 6 | Verification criteria | Before concluding |

---

## Part 6: Ambiguity Detection Patterns

### 6.1 Linguistic Ambiguity Markers

**High-Confidence Triggers** (ask clarifying question):

| Pattern | Example | Detection Regex/Pattern |
|---------|---------|------------------------|
| Vague quantifiers | "handle large files" | `/\b(large|small|many|few|fast|slow)\b/` |
| Undefined references | "update the thing" | Pronouns without clear antecedent |
| Hedge words | "probably should validate" | `/\b(maybe|probably|might|could|possibly)\b/` |
| Ellipsis markers | "support CSV, JSON, etc." | `/\b(etc\.?|and so on|\.\.\.)\b/` |
| Passive without agent | "should be approved" | Passive voice without clear subject |

**Medium-Confidence Triggers** (probe if blocking):

| Pattern | Example | Detection |
|---------|---------|-----------|
| Compound requirements | "fast and secure" | Multiple adjectives without priority |
| Temporal ambiguity | "after processing" | Time references without specifics |
| Scope creep indicators | "also handle X" | Additions without size analysis |

### 6.2 Structural Ambiguity Detection

**Missing Structure Elements**:

| Element | Signal of Absence | Clarification Question |
|---------|-------------------|----------------------|
| Input specification | No data format mentioned | "What data does the user provide?" |
| Output specification | No result described | "What should the user see/receive?" |
| Trigger condition | No "when" clause | "What initiates this action?" |
| Error handling | No "if fails" mention | "What should happen if this fails?" |
| Success criteria | No "success means" | "How do we know this worked?" |

### 6.3 Contradiction Detection

| Contradiction Type | Example | Resolution Strategy |
|--------------------|---------|---------------------|
| Direct conflict | "instant" + "after review" | Ask which takes priority |
| Implicit conflict | "simple" + "comprehensive" | Clarify scope boundaries |
| Temporal conflict | "before X" + "after Y" where Y depends on X | Map sequence |

---

## Part 7: Implementation Specification

### 7.1 `/pm:gap-analysis` Skill Design

```yaml
name: gap-analysis
description: Analyze feature request for missing information gaps
trigger: "/pm:gap-analysis [feature-description]"

inputs:
  - feature_description: string (required)
  - user_role: enum [pm, designer, developer, architect] (optional, default: infer)
  - codebase_context: boolean (optional, default: true)
  - verbose: boolean (optional, default: false)

outputs:
  - gap_report: GapReport
  - confidence_score: float (0-1)
  - ready_status: enum [ready, likely_ready, needs_clarification, insufficient]
  - next_questions: List[Question] (prioritized)
```

### 7.2 Processing Pipeline

```
1. PARSE
   - Extract feature description
   - Identify user role (from context or explicit)

2. ANALYZE_LINGUISTIC
   - Run ambiguity pattern detection
   - Identify vague terms, undefined references
   - Score: linguistic_ambiguity_score

3. ANALYZE_SLOTS
   - Map to slot schema (goal, trigger, input, output, error, constraints)
   - Calculate fill percentage
   - Identify missing required slots
   - Score: slot_completeness_score

4. ANALYZE_CODEBASE (if enabled)
   - Search for similar features/patterns
   - Identify existing integrations
   - Check for conflicting patterns
   - Auto-resolve gaps with precedent
   - Score: codebase_coverage_score

5. ANALYZE_CONFIDENCE
   - Generate N=3 interpretations
   - Compare semantic similarity
   - Calculate self-consistency score
   - Score: confidence_score

6. CLASSIFY_GAPS
   - Categorize each gap (Requirements/Constraint/EdgeCase/Integration/Verification)
   - Classify blocking vs nice-to-know
   - Assign priority scores

7. GENERATE_QUESTIONS
   - For each blocking gap, generate clarifying question
   - Filter by user role capability
   - Order by priority score

8. SYNTHESIZE
   - Calculate overall confidence
   - Determine ready_status
   - Compile gap_report
```

### 7.3 Gap Report Schema

```yaml
GapReport:
  feature_summary: string  # One-line interpretation
  overall_confidence: float  # 0-1
  ready_status: enum

  slot_analysis:
    goal: {filled: bool, value: string | null, confidence: float}
    trigger: {filled: bool, value: string | null, confidence: float}
    input: {filled: bool, value: string | null, confidence: float}
    output: {filled: bool, value: string | null, confidence: float}
    error_handling: {filled: bool, value: string | null, confidence: float}
    constraints: {filled: bool, value: string | null, confidence: float}

  gaps:
    - id: string
      category: enum [requirements, constraint, edge_case, integration, verification]
      description: string
      is_blocking: bool
      priority_score: float
      can_auto_resolve: bool
      auto_resolution: string | null  # If codebase provides answer
      clarifying_question: string | null  # If user input needed

  codebase_context:
    similar_features: List[string]  # File paths
    relevant_patterns: List[string]
    auto_resolved_count: int

  next_actions:
    - action: enum [ask_question, proceed_with_assumption, ready_to_implement]
      detail: string
```

### 7.4 Integration with Existing Skills

**Before `/pm:decompose`**:
```
User: /pm:decompose "add user search"
System: Running gap analysis first...

        Gap Analysis Results:
        - Confidence: 65% (needs clarification)
        - Missing: Search scope (users only or all entities?)
        - Missing: Search method (full-text, filters, both?)

        Questions:
        1. Should search cover just users, or also teams/projects?
        2. Do users need full-text search, filtering, or both?

        Answer these questions or proceed with assumptions?
```

**Standalone Usage**:
```
User: /pm:gap-analysis "implement OAuth login"

Gap Analysis Report
===================
Confidence: 78% (likely ready)

Filled Slots:
- Goal: Enable third-party authentication ✓
- Trigger: User clicks "Login with X" ✓
- Output: User session created ✓

Missing Slots:
- Input: Which OAuth providers? [BLOCKING]
- Error: Failed auth handling [BLOCKING]
- Constraints: Session duration [NICE-TO-KNOW]

Auto-Resolved from Codebase:
- Auth pattern: JWT tokens (existing in auth/jwt.ts)
- User model: Existing User entity (models/user.ts)

Next Questions (prioritized):
1. Which OAuth providers should be supported? (Google, GitHub, other?)
2. What should happen if OAuth authentication fails?
```

---

## Part 8: Hypothesis Outcomes

| ID | Hypothesis | Prior | Final | Evidence |
|----|------------|-------|-------|----------|
| H1 | Linguistic markers sufficient | 50% | 35% | Necessary but not sufficient; need multi-signal approach |
| H2 | Slot-filling transfers | 75% | 85% | Strong transfer; LLMREI achieved 73.7% elicitation |
| H3 | Self-assessment unreliable | 80% | 90% | Confirmed; 30%+ errors despite high confidence |
| H4 | Blocking algorithmic | 55% | 70% | INVEST+Testability provides clear decision rules |
| H5 | Codebase reduces 30%+ | 65% | 75% | Evidence supports 30-50% auto-resolution potential |
| H6 | Role constrains questions | 70% | 75% | Validated by mistake-types framework research |

---

## Part 9: Limitations and Open Questions

### 9.1 Limitations

1. **Domain Specificity**: Gap patterns may vary by software domain (web vs mobile vs embedded)

2. **User Expertise Variance**: Some users provide highly detailed specs, others minimal; calibration needed

3. **Novel Features**: For genuinely novel features with no codebase precedent, gap detection relies heavily on linguistic signals

4. **Confidence Calibration**: Requires historical data to calibrate; cold-start problem for new projects

### 9.2 Open Questions for Future Research

1. **Optimal Question Count**: What's the ideal number of clarifying questions before user fatigue?

2. **Multi-Stakeholder Gaps**: How to synthesize gaps when multiple users have conflicting inputs?

3. **Real-Time Calibration**: Can confidence calibration adapt in real-time based on implementation outcomes?

4. **Cross-Project Transfer**: Can gap detection patterns learned from one codebase transfer to another?

---

## Sources

### Primary Sources (A-Grade)
- [Uncertainty Quantification and Confidence Calibration in LLMs: A Survey](https://arxiv.org/html/2503.15850) - Comprehensive UQ taxonomy
- [LLMREI: Automating Requirements Elicitation Interviews with LLMs](https://arxiv.org/html/2507.02564v1) - Automated elicitation methodology
- [Modeling Future Conversation Turns to Teach LLMs to Ask Clarifying Questions](https://arxiv.org/html/2410.13788) - Clarification decision training
- [Do Large Language Models Know What They Don't Know?](https://arxiv.org/abs/2305.18153) - Self-knowledge evaluation
- [Requirements Elicitation Follow-Up Question Generation](https://arxiv.org/html/2507.02858v1) - 14-mistake-types framework
- [Aligning Language Models to Explicitly Handle Ambiguity](https://arxiv.org/html/2404.11972v1) - Ambiguity handling alignment
- [INVEST Criteria - Agile Alliance](https://agilealliance.org/glossary/invest/) - Authoritative INVEST definition

### Supporting Sources (B-Grade)
- [The Context Gap: Why Some AI Coding Tools Break](https://www.augmentcode.com/tools/the-context-gap-why-some-ai-coding-tools-break) - Context-aware coding tools
- [CLU Multi-Turn Conversations](https://learn.microsoft.com/en-us/azure/ai-services/language-service/conversational-language-understanding/concepts/multi-turn-conversations) - Slot filling implementation
- [Automated Repair of Ambiguous Natural Language Requirements](https://arxiv.org/html/2505.07270v1) - Ambiguity repair methodology
- [Ambiguity Detection in Business Process Descriptions](https://link.springer.com/chapter/10.1007/978-3-032-02867-9_23) - 94.3% ambiguity prevalence

### Supplementary Sources (C-Grade)
- [Definition of Ready for User Stories](https://www.boost.co.nz/blog/2022/07/definition-of-ready-agile-user-stories) - INVEST as DoR
- [Slot Filling: A First Step Towards Ambitious NLP Systems](https://medium.com/@aixplain/slot-filling-a-first-step-towards-ambitious-nlp-systems) - Slot filling overview
