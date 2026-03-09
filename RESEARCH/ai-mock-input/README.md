# AI Mock Input Research

Research project investigating autonomous AI agent strategies for handling human input requirements.

## Research Question
How can autonomous AI agents handle situations requiring human input by generating contextually-appropriate mock/synthetic decisions, enabling unblocked execution in CI/CD and batch processing scenarios?

## Status
- Created: 2026-01-21
- Updated: 2026-03-01
- Phase: **COMPLETE (3rd iteration)**
- Confidence: **HIGH**

## Key Deliverables

### Main Report
- **[research-report.md](./research-report.md)** - Full consolidated report with all findings (Updated March 2026)

### Quality Assurance
- [09_qa/qa_report.md](./09_qa/qa_report.md) - Independent evaluation with binary checklist

## Key Findings (Updated March 2026)

1. **Bounded Autonomy is Standard** -- Agents operate freely within safety boundaries with automatic escalation
2. **Verification Gates Outperform Self-Approval** -- Separate judge agents are essential; self-assessed confidence is unreliable
3. **GitHub Agentic Workflows in Technical Preview** -- Markdown-defined AI automation with safe outputs (Feb 2026)
4. **Policy-Based Governance Engines Mature** -- Deterministic policy evaluation in <10ms with layered policies
5. **Durable Workflow Orchestration Solves Timeouts** -- Temporal-based waiting with configurable fallbacks
6. **Sandboxing Converged on MicroVMs** -- Firecracker (~125ms boot) is production standard

## Recommended Architecture (5-Tier)

1. **Safety Filter** (Always First) -- Hard deny-list for credentials, destructive, financial, legal
2. **Policy Engine** (Deterministic) -- Pre-configured rules in <10ms with policy inheritance
3. **Context Inferencer** (Smart Path) -- Codebase convention analysis + HTC confidence scoring
4. **Verification Gate** (Validation) -- Separate judge agent validates decisions before execution
5. **Escalation Handler** (Safe Path) -- Durable workflow queue with timeout-to-default

## Six Strategy Taxonomy

| Strategy | Risk | Best For |
|----------|------|----------|
| Elimination | Lowest | Known toolchains (Claude `-p`, Aider `--yes-always`) |
| Pre-configured Policy | Low | Repetitive CI/CD (Renovate automerge) |
| Context-Aware Inference | Medium | Novel prompts in familiar contexts |
| Separate Verification | Medium | High-value autonomous workflows |
| Timeout-to-Default | Low-Med | Async workflows (Temporal, LangGraph) |
| Hard Escalation | Safest | Credentials, destructive ops, financials |

## Report Coverage

The report addresses all 8 requested areas:
1. Current State of the Art (6 agent frameworks compared)
2. Mock/Synthetic Decision Generation (6 design patterns)
3. CI/CD Integration Patterns (Claude Code, GitHub Actions, Renovate)
4. Risk Management (reversibility classification, never-auto-decide list)
5. Design Patterns and Architectures (policy engines, verification gates, durable workflows)
6. Real-World Implementations (5 case studies)
7. Security and Safety (sandboxing, least privilege, agent gateways)
8. Future Directions (HOTL evolution, simulation testing, regulatory landscape)

## Sources Summary (55+ Total)

- **Grade A (Primary):** 9 sources -- Official docs, academic papers, industry standards
- **Grade B (Secondary):** 12 sources -- Architecture guides, technical deep dives
- **Grade C (Supporting):** 12 sources -- Practitioner reports, blog analyses

## Research Artifacts

### Phase 1: Scoping
- [00_research_contract.md](./00_research_contract.md) - Scope and requirements
- [01_research_plan.md](./01_research_plan.md) - Query strategy
- [01a_perspectives.md](./01a_perspectives.md) - Expert viewpoints
- [01b_hypotheses.md](./01b_hypotheses.md) - Testable hypotheses

### Phase 3: Data Collection
- [02_query_log.csv](./02_query_log.csv) - Search queries executed
- [03_source_catalog.csv](./03_source_catalog.csv) - Sources found and graded

### Phase 4: Verification
- [04_evidence_ledger.csv](./04_evidence_ledger.csv) - Claims and evidence
- [05_contradictions_log.md](./05_contradictions_log.md) - Resolved tensions

### Phase 5-6: Synthesis and QA
- [07_working_notes/synthesis_notes.md](./07_working_notes/synthesis_notes.md) - Intermediate findings
- [09_qa/qa_report.md](./09_qa/qa_report.md) - Quality assurance with independent evaluation

## Updates Log

### 2026-03-01
- Complete rewrite incorporating February-March 2026 developments
- Added GitHub Agentic Workflows (technical preview Feb 13 2026)
- Added GitHub Copilot CLI GA (Feb 25 2026)
- Added Claude/Codex on Agent HQ (Feb 26 2026)
- Expanded from 4-tier to 5-tier architecture (added Verification Gate)
- Added 6 design patterns with code examples
- Added 5 real-world case studies
- Added security section with sandboxing technology comparison
- Added AI Agent Gateway pattern (MCP + OPA)
- Added LLM overconfidence research (arXiv:2602.06948)
- Independent evaluation with binary checklist
- Fixed unverified claims from prior iteration

### 2026-01-24
- Added 14 new sources from January 2026
- Incorporated Agentic Confidence Calibration (HTC) research
- Added Cursor multi-agent coordination findings
- Added GitHub Copilot coding agent documentation

### 2026-01-21
- Initial research completed
- 30 sources analyzed
- All hypotheses validated
