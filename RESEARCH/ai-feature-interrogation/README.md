# AI Feature Interrogation Research

## Executive Summary

This research answers: **How can AI effectively interrogate users about features they want implemented in a codebase, extracting all relevant technical information before implementation begins?**

The report synthesizes evidence from 50+ sources across requirements engineering, conversational AI, UX research, cognitive science, knowledge elicitation, spec-driven development methodology, and analysis of current AI coding tools.

### Key Takeaways

1. **Use a 4-phase question hierarchy**: Context, Behavior, Edge Cases, Verification. Validated by the LLMREI study (73.7% requirements capture rate), the NN/g funnel technique, and Wood's four-phase knowledge elicitation framework.

2. **Analyze the codebase BEFORE asking questions**. Many questions can be answered from code signals (test configs, error patterns, API conventions). Never ask what the code already tells you.

3. **Apply the Golden Prompt pattern**: One question at a time, structured A/B/C options, summary before implementation. This addresses cognitive load, decision fatigue, and verification in one pattern.

4. **Spec-driven development is the industry norm**. As of 2026, tools like GitHub Spec Kit, AWS Kiro, and frameworks like the Agentic Coding Handbook all implement specification-first workflows. The SDD paper (arxiv:2602.00180) documents up to 50% error reduction.

5. **Classify complexity first, then calibrate question depth**: Simple features need 3-4 questions (Bronze tier). Medium features need 5-7 (Silver). Complex features need 7-10 (Gold). Never apply one-size-fits-all.

6. **Users systematically omit edge cases** unless explicitly prompted with "What if X fails?" questions. 48% of ICT projects hit performance issues from ignoring non-functional requirements (Gartner).

7. **Guard against 8 anti-patterns**: Over-interrogation, under-interrogation, asking what code already reveals, confirmation bias, leading questions, cognitive overload, ignoring "I don't know" signals, and vibe coding (no specification at all).

8. **Requirements failures cause ~78% of project failures**. Fixes cost 10-100x more when caught late. This makes interrogation one of the highest-ROI activities in software development.

### Report Structure

| Part | Title | Key Content |
|------|-------|-------------|
| 1 | Current State of AI-Assisted Requirements Gathering | Claude Code, Cursor, Kiro, GitHub Spec Kit, Aider analysis |
| 2 | Requirements Engineering Theory Applied to AI | Classical techniques taxonomy, information hierarchy |
| 3 | Structured Interrogation Frameworks | Funnel technique, Socratic questions, progressive disclosure |
| 4 | Codebase-Aware Context Extraction | Context engines, codebase signals, architectural inference |
| 5 | Spec-Driven Development | SDD levels, workflow, empirical results |
| 6 | Information Completeness Detection | Definition of Ready, tiered readiness, completeness signals |
| 7 | Anti-Patterns and Failure Modes | 8 anti-patterns with symptoms, root causes, mitigations |
| 8 | Practical Implementation Patterns | Golden Prompt, state management, output formats, templates |
| 9 | Research from Adjacent Fields | Cognitive load theory, contextual inquiry, expert systems, LLMREI |
| 10 | Decision Tree for Feature Interrogation | Complexity classification, question selection, template library |
| 11 | Limitations and Open Questions | Research gaps, vendor skepticism, open problems |

## Quick Start for Implementation

### The Golden Prompt (for system prompts)

```
Before implementing, ask me clarifying questions about this feature.
Ask each question one at a time.
Wait for my answer before asking the next question.
If there are several options, show them in a table with options labeled A, B, C, etc.
After all questions are answered, summarize the specification for my confirmation.
```

### Core Question Sequence

1. **Context**: "What problem does this solve?" + "What's the simplest valuable version?"
2. **Behavior**: "What data is provided?" + "What happens on success?"
3. **Edge Cases**: "What if it fails?" + "Are there limits?"
4. **Verification**: "Here's my understanding: [spec]. Is this correct?"

### Complexity-Based Question Budget

| Complexity | Questions | Readiness Tier | When to Use |
|-----------|-----------|---------------|-------------|
| Simple | 3-4 | Bronze | Single operation, CRUD, display changes |
| Medium | 5-7 | Silver | Multi-step features, user-facing impact |
| Complex | 7-10 | Gold | Cross-service, auth, payments, data deletion |

### Completeness Criteria

A specification is ready when:
- INVEST criteria all pass (Independent, Negotiable, Valuable, Estimable, Small, Testable)
- Happy path describable in Given-When-Then format
- Top 3 failure scenarios have handling defined
- 3-7 acceptance criteria captured (more than 10 means split the feature)
- No unresolved contradictions
- Assumptions are explicitly stated

## Research Files

```
RESEARCH/ai-feature-interrogation/
  README.md                  # This file
  research-report.md         # Full research report (~1100 lines)
  00_research_contract.md    # Research scope and goals
  01_research_plan.md        # Search strategy
  01a_perspectives.md        # Stakeholder perspectives
  01b_hypotheses.md          # Hypotheses and outcomes
  02_query_log.csv           # Search queries executed
  03_source_catalog.csv      # Sources discovered
  04_evidence_ledger.csv     # Claims and evidence
  05_contradictions_log.md   # Contradictions found
  07_working_notes/          # Working notes
  09_qa/                     # Quality assurance
```

## Key Sources

### Grade A (Primary/Authoritative)
- [LLMREI: Automating Requirements Elicitation Interviews with LLMs](https://arxiv.org/html/2507.02564) -- IEEE RE 2025
- [SDD: Spec-Driven Development: From Code to Contract](https://arxiv.org/html/2602.00180v1) -- arxiv, January 2026
- [NN/g Funnel Technique](https://www.nngroup.com/articles/the-funnel-technique-in-qualitative-user-research/)
- [Cognitive Biases in Requirements Elicitation](https://link.springer.com/chapter/10.1007/978-3-030-26574-8_9) -- Springer 2020
- [Wood 1993: Structuring Interviews for Knowledge Elicitation](https://onlinelibrary.wiley.com/doi/10.1002/int.4550080106)
- [Pacheco & Garcia 2018: RE Techniques SLR](https://ietresearch.onlinelibrary.wiley.com/doi/10.1049/iet-sen.2017.0144)

### Grade B (High-Quality Supporting)
- [Martin Fowler: Understanding SDD Tools](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)
- [GitHub Blog: Spec-Driven Development](https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/)
- [Sourcegraph: Context Retrieval for AI Assistants](https://sourcegraph.com/blog/lessons-from-building-ai-coding-assistants-context-retrieval-and-evaluation)
- [Addy Osmani: LLM Coding Workflow](https://addyosmani.com/blog/ai-coding-workflow/)
- [Dan Does Code: Golden Prompt Pattern](https://www.dandoescode.com/blog/efficient-vibe-coding-with-clarifying-questions)
- [Tweag Agentic Coding Handbook](https://tweag.github.io/agentic-coding-handbook/WORKFLOW_SPEC_FIRST_APPROACH/)
- [Beyond the Vibes: Rigorous AI Coding Guide](https://blog.tedivm.com/guides/2026/03/beyond-the-vibes-coding-assistants-and-agents/)
- [MIT Missing Semester: Agentic Coding](https://missing.csail.mit.edu/2026/agentic-coding/)

See `research-report.md` Sources section for complete bibliography (50+ sources).
