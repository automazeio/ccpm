---
name: ai-gap-analysis
status: in-progress
created: 2026-02-02T00:00:00Z
updated: 2026-02-02T00:00:00Z
---

# Research Contract: AI Gap Analysis for Feature Requests

## Research Question
How can an AI system detect, categorize, prioritize, and self-assess gaps in user feature requests to determine what additional information is needed before implementation?

## Decision/Use Case
This research informs a new standalone gap analysis skill (`/pm:gap-analysis`) that integrates with feature interrogation workflows. The skill analyzes user feature requests and identifies what information is missing before implementation can begin.

## Audience
- Technical (Claude Code developers, LLM engineers)
- Product (skill designers, workflow architects)

## Scope

### In Scope
- AI/LLM-specific gap detection techniques
- Codebase-aware gap detection patterns
- Practical implementation patterns for Claude Code context
- Gap categorization taxonomies
- Prioritization algorithms for multi-gap scenarios
- Self-assessment and confidence scoring mechanisms

### Out of Scope
- Generic business analysis methodologies
- Document-level gap analysis (not feature-level)
- Human requirements engineering processes
- Non-LLM AI approaches

### Geography/Timeframe
- Global (technology industry focus)
- 2023-2026 research timeframe (emphasis on 2025-2026)

## Constraints

### Required Sources
- Academic research on LLM uncertainty quantification
- AI coding assistant documentation and research
- Conversational AI / slot-filling literature
- Prior ai-feature-interrogation research findings

### Banned Sources
- None specified

## Output Format
Standard research report with implementation specification

## Definition of Done
1. Gap Detection Framework documented with specific signals/patterns
2. Gap Taxonomy with categorization scheme
3. Prioritization Algorithm with decision rules
4. Confidence Scoring Model with threshold guidance
5. Implementation Spec for `/pm:gap-analysis` skill
6. All C1 claims verified with 2+ independent sources

## Related Prior Research
- RESEARCH/ai-feature-interrogation/ (established 4-phase question hierarchy, INVEST criteria, slot-filling patterns)

## Intensity Classification
- **Tier**: Standard (5 agents, depth 3, stop > 8.0)
- **Budget**: N_search=30, N_fetch=30, N_docs=12, N_iter=6
