---
name: ai-gap-analysis
status: complete
created: 2026-02-02T00:00:00Z
updated: 2026-02-02T00:00:00Z
---

# AI Gap Analysis for Feature Requests

## Executive Summary

This research investigates how AI systems can detect, categorize, prioritize, and self-assess gaps in user feature requests. The goal is to inform a `/pm:gap-analysis` skill that identifies missing information before implementation begins.

## Key Findings

### 1. Multi-Signal Gap Detection
Effective gap detection requires combining four signal types:
- **Linguistic markers** (25%): Vague terms, undefined references, hedge words
- **Slot state** (30%): Required fields like goal, input, output, error handling
- **Codebase context** (20%): Existing patterns that auto-resolve gaps
- **Confidence scoring** (25%): Self-consistency across multiple interpretations

### 2. Five-Category Gap Taxonomy
| Category | Description | Example |
|----------|-------------|---------|
| **Requirements** | Core behavior unspecified | "What happens when user clicks?" |
| **Constraint** | Limits undefined | "What's the file size limit?" |
| **Edge Case** | Error handling missing | "What if the API fails?" |
| **Integration** | System connections unclear | "How does this auth with existing?" |
| **Verification** | Success criteria absent | "How do we test this worked?" |

### 3. Blocking vs Nice-to-Know Classification
A gap is **BLOCKING** if:
- Cannot write acceptance test without it
- Cannot estimate effort without it
- Multiple contradictory interpretations exist
- Missing integration dependency

A gap is **NICE-TO-KNOW** if:
- Codebase has existing pattern
- Industry default exists
- Affects optimization not correctness

### 4. LLMs Are Systematically Overconfident
Studies show 30%+ error rates in high-stakes domains despite high model confidence. **Self-consistency sampling** is the most reliable calibration method (lowest Expected Calibration Error in 11/13 tasks).

### 5. Codebase Context Auto-Resolves 30-50% of Gaps
Context-aware tools that index entire repositories can answer questions about patterns, conventions, and integration points without user input. Context-blind AI breaks 67% of enterprise deployments.

## Implementation Specification

### `/pm:gap-analysis` Skill

**Input**: Feature description + optional user role + codebase context flag

**Output**:
```yaml
confidence: 0.78  # 0-1 scale
ready_status: likely_ready  # ready | likely_ready | needs_clarification | insufficient

gaps:
  - category: requirements
    description: "OAuth providers not specified"
    is_blocking: true
    clarifying_question: "Which OAuth providers? (Google, GitHub, other?)"

  - category: edge_case
    description: "Auth failure handling missing"
    is_blocking: true
    clarifying_question: "What should happen if OAuth authentication fails?"

auto_resolved:
  - "Auth pattern: JWT tokens (existing in auth/jwt.ts)"
  - "User model: Existing User entity (models/user.ts)"
```

### Confidence Thresholds

| Confidence | Slot Fill | Action |
|------------|-----------|--------|
| >90% | >90% | Ready to implement |
| 80-90% | >80% | Proceed with documented assumptions |
| 60-80% | 60-80% | Ask blocking questions only |
| <60% | <60% | Comprehensive gap analysis required |

## Files in This Research

| File | Description |
|------|-------------|
| `research-report.md` | Full findings with implementation spec |
| `00_research_contract.md` | Research scope and definition of done |
| `01_research_plan.md` | Query strategy and subquestions |
| `01a_perspectives.md` | Stakeholder perspectives |
| `01b_hypotheses.md` | Testable hypotheses and outcomes |
| `02_query_log.csv` | Search queries executed |
| `03_source_catalog.csv` | Sources with quality grades |
| `04_evidence_ledger.csv` | Key claims with citations |

## Key Sources

- [Uncertainty Quantification in LLMs Survey](https://arxiv.org/html/2503.15850) - UQ methods taxonomy
- [LLMREI: Automated Requirements Elicitation](https://arxiv.org/html/2507.02564v1) - 73.7% elicitation rate
- [Teaching LLMs to Ask Clarifying Questions](https://arxiv.org/html/2410.13788) - When to ask vs answer
- [Requirements Elicitation Follow-Up Questions](https://arxiv.org/html/2507.02858v1) - 14 mistake types
- [The Context Gap in AI Coding Tools](https://www.augmentcode.com/tools/the-context-gap-why-some-ai-coding-tools-break) - Codebase awareness

## Usage Recommendation

Integrate gap analysis as a pre-check before `/pm:decompose`:

```
User: /pm:decompose "add user search"
System: Running gap analysis...
        Confidence: 65% - needs clarification

        Missing: Search scope (users only or all entities?)
        Missing: Search method (full-text, filters, both?)

        Answer these questions or proceed with assumptions?
```

This catches incomplete specifications before they become implementation blockers.
