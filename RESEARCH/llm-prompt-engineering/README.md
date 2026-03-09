# LLM Prompt Engineering Best Practices Research

## Research Focus
Best practices and guiding principles for writing effective LLM prompts, with emphasis on Claude/Anthropic models.

## Status
- **Phase**: 7 - COMPLETE
- **Type**: C (Analysis) - Full 7-phase GoT
- **Started**: 2026-01-22
- **Updated**: 2026-02-15
- **Report Version**: 2.0
- **QA Score**: 9.9/10

## Key Outputs

### Primary Report
- **Location**: `./research-report.md`
- **Also available at**: `./08_report/research-report.md`
- **Covers**: Claude Opus 4.6, Claude Sonnet 4.5, Claude Haiku 4.5, GPT-5.1/5.2, DeepSeek R1, Llama 4
- **Sources**: 44+ (this report) + 25+ (compression companion) = 50+ total unique sources

### Companion Report: Prompt Compression Techniques
- **Location**: `./prompt-compression-report.md`
- **Added**: 2026-02-10
- **Focus**: Systematic approaches to reducing token consumption while preserving behavioral fidelity
- **Key finding**: 40-60% compression achievable with <5% quality loss using structural techniques (lazy loading, deduplication, trigger tables)

### Supporting Documents
- Research contract: `./00_research_contract.md`
- Compression research contract: `./compression-research/00_research_contract.md`
- Research plan: `./01_research_plan.md`
- Perspectives: `./01a_perspectives.md`
- Evidence: `./07_working_notes/evidence_passages.json`
- Hypothesis evaluation: `./07_working_notes/hypothesis_evaluation.md`
- QA report: `./09_qa/qa_report.md`
- Citation audit: `./09_qa/citation_audit.md`

## Key Findings

### Hypothesis Outcomes (Original Research)
| Hypothesis | Prior | Final | Verdict |
|------------|-------|-------|---------|
| XML tags improve Claude's parsing | 80% | 90% | CONFIRMED |
| Extended thinking improves complex reasoning | 75% | 85% | CONFIRMED (adaptive > fixed budget) |
| Few-shot needed for novel formats only | 60% | 55% | PARTIALLY DISCONFIRMED |
| Long system prompts degrade performance | 50% | 75% | CONFIRMED |
| Prompt injection mitigable but not eliminable | 85% | 95% | STRONGLY CONFIRMED |
| Role prompting improves all task types | 70% | 45% | DISCONFIRMED for factual tasks |

### Hypothesis Outcomes (Compression Research)
| Hypothesis | Prior | Final | Verdict |
|------------|-------|-------|---------|
| Systematic compression techniques exist | 65% | 90% | CONFIRMED |
| LLMs can compress own prompts | 50% | 35%/75% | SPLIT (summarization fails; optimization works) |
| >50% compression with zero quality loss | 30% | 65% | PARTIALLY CONFIRMED |
| Behavioral fidelity is measurable | 60% | 80% | CONFIRMED |
| Compressible vs. essential is identifiable | 55% | 85% | CONFIRMED |

### Top 7 Actionable Insights

1. **Use XML tags** - Claude was trained with XML in training data; tags like `<instructions>`, `<context>`, `<example>` significantly improve parsing accuracy

2. **Use adaptive thinking (Claude Opus 4.6)** - Replaces manual budget_tokens; dynamically decides when and how much to reason. Use `effort` parameter (low/medium/high/max) instead of fixed budgets.

3. **Context is finite with diminishing returns** - Long prompts degrade performance 13.9%-85% even with perfect retrieval. The field is shifting from "prompt engineering" to "context engineering."

4. **Role prompting shapes tone, not facts** - Anthropic recommends it for tone/focus; Wharton research shows no factual accuracy improvement. Do not expect expert personas to make the model "know more."

5. **Few-shot helps more than just novel formats** - Include 3-5 diverse examples for complex tasks, consistency, and reducing instruction misinterpretation

6. **Injection defense requires depth** - 78% attack success rate on Claude with persistence; implement prevention + detection + mitigation layers

7. **Dial back aggressive prompting on Claude 4.x** - Replace "CRITICAL: YOU MUST" with normal language. Over-prompting causes overtriggering on Claude Opus 4.5/4.6.

### Top 5 Compression Insights

1. **Lazy loading is the highest-impact technique** - 54% token reduction by converting verbose docs to trigger tables with on-demand loading

2. **Never use LLM summarization for compression** - Documented case: 18K tokens compressed to 122 tokens caused accuracy to drop from 66.7% to 57.1%

3. **Moderate compression can improve performance** - Removing noise via 2-5x compression actually improved accuracy in multiple studies

4. **Over-prompting is free compression** - Removing "CRITICAL: YOU MUST" language improves Claude 4.x behavior while reducing tokens

5. **Prompt caching is often better than compression** - 90% cost reduction for static system prompts without any quality risk

## Claude 4.x Specific Guidance

### Key Characteristics (Including Opus 4.6)
- Adaptive thinking with dynamic reasoning control
- Precise instruction following (more literal than previous generations)
- Native subagent orchestration (delegates appropriately)
- Context awareness (tracks remaining token budget)
- Parallel tool execution
- Prefilled responses deprecated (Opus 4.6)
- 1M context window (beta)

### Critical Adjustments
1. **Be explicit** - Request "above and beyond" behavior explicitly
2. **Provide context** - Explain WHY, not just WHAT
3. **Dial back aggressive prompting** - Replace "CRITICAL: YOU MUST" with normal language
4. **Use explicit action language** - "Make changes" not "suggest changes"
5. **Migrate from prefills** - Use Structured Outputs or explicit format instructions

## Sources Used

### Grade A (33 sources)
- Anthropic Official Documentation (10)
- OpenAI Official Documentation (2)
- OWASP Security Guidance (2)
- Microsoft Security Research (1)
- Academic Research (17)
- Constitutional AI Paper (1)

### Grade B (8 sources)
- Practitioner Guides and Industry Blogs

### Grade C (3 sources)
- Community/Context resources

## Topics Covered
1. Prompt structure patterns (XML tags, markdown, organization)
2. Chain-of-thought, extended thinking, and adaptive thinking
3. System prompt design and role prompting (with counter-evidence)
4. Few-shot vs zero-shot approaches
5. Constitutional AI principles
6. Prompt injection prevention (2026 attack vectors)
7. Meta-prompting strategies
8. Claude-specific optimizations (Opus 4.6)
9. Cross-model comparison (Claude vs GPT vs Gemini vs open-source)
10. Prompt compression techniques
11. Context engineering for AI agents
12. Advanced techniques (ToT, self-consistency, prompt scaffolding)

## Changes in v2.0 (February 15, 2026)

### Major Additions
1. Claude Opus 4.6 adaptive thinking documentation (Section 2.2)
2. Role prompting counter-evidence from Mollick et al. (Section 3.1)
3. Cross-model comparison matrix (Section 9)
4. Context engineering section (Section 11)
5. Self-consistency and CISC coverage (Section 2.6)
6. Advanced techniques: Tree of Thoughts, prompt scaffolding (Section 12)
7. GPT-5.1 CTCO pattern and comparison (Section 9.2)
8. Open-source model considerations (Section 9.3)
9. Prefill deprecation migration strategies (Section 8.4)
10. New hypothesis H6: Role prompting effectiveness (disconfirmed for factual tasks)

### Source Expansion
- v1.0: 28+ sources
- v2.0: 44+ sources (10 Anthropic, 2 OpenAI, 4 security, 17 academic, 11+ practitioner)

## Research Methodology
- Graph of Thoughts (GoT) with Standard intensity tier
- 7 phases: Classification -> Scoping -> Hypotheses -> Perspectives -> Retrieval -> Triangulation -> Synthesis -> QA
- All C1 claims verified with evidence and independence checks
- Independent evaluator binary checklist: all 7 checks PASS
- 50+ high-quality sources consulted across both reports
