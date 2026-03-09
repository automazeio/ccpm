# Research Contract: LLM Prompt Compression Techniques

## Core Research Question
What are the most effective techniques for compressing LLM prompts (system instructions, skill templates, and pipeline prompts) to reduce token consumption while preserving behavioral fidelity, and how do you measure whether compression lost anything important?

## Relationship to Parent Research
This augments RESEARCH/llm-prompt-engineering, which confirmed:
- Long system prompts degrade performance (13.9-85% degradation)
- 70-80% of context window is the recommended maximum
- XML tags improve Claude's parsing accuracy

This new research addresses: HOW to systematically shrink prompts when they exceed those bounds.

## Decision/Use-Case
Enable practitioners to compress Claude Code skill templates, pipeline instructions, and rule files systematically rather than through ad-hoc editing.

## Key Uncertainties
1. Do systematic prompt compression techniques exist beyond "edit it shorter"?
2. Can an LLM reliably compress its own prompts without losing behavioral nuance?
3. What is the typical compression ratio achievable without quality loss?
4. How do you measure behavioral fidelity after compression?
5. Is there a taxonomy of what's compressible vs. essential in prompts?

## Current Belief
Long prompts degrade performance (confirmed at 75% confidence by parent research). Systematic compression techniques probably exist beyond "just edit it shorter." Confidence: ~65%.

## What Would Surprise Me
- Evidence that prompt compression is purely an art with no systematic approaches
- Evidence that compression always loses critical behavioral nuance
- Evidence that LLMs cannot reliably compress their own prompts
- Finding that simple techniques (deduplication, removing examples) achieve >50% compression with zero quality loss

## Stakes & Reversibility
- Stakes: MEDIUM - affects daily workflow efficiency and prompt quality
- Reversibility: HIGH - compression is always reversible (keep originals)
- Evidence threshold: Standard (2+ independent sources for C1 claims)

## Success Criteria
1. Taxonomy of compression techniques with evidence of effectiveness
2. Measurement framework for behavioral fidelity after compression
3. Practical patterns for identifying redundancy in instructions
4. Assessment of LLM-assisted compression viability
5. Real-world compression ratios with quality impact data
6. Actionable checklist for compressing Claude Code prompts

## Scope
### Included
- Skill/command template prompts
- Pipeline instructions and rule files
- Claude Code workflow prompts
- Prompt compression/distillation literature (applied, not training-focused)
- Token-level and semantic-level compression
- Lazy loading and conditional inclusion patterns

### Excluded
- Fine-tuning approaches
- RAG-specific compression
- Academic prompt distillation for model training
- Model architecture changes

## Subquestions
1. What systematic prompt compression techniques exist?
2. How to measure behavioral fidelity after compression?
3. What's compressible vs essential in prompts?
4. Can LLMs compress LLM prompts effectively?
5. Practical patterns: lazy loading, conditional inclusion, tiered detail
6. Real-world compression ratios achieved without quality loss

## Output
Final report: RESEARCH/llm-prompt-engineering/prompt-compression-report.md
