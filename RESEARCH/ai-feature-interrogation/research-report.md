# AI Feature Interrogation: Comprehensive Research Report

## How AI Can Effectively Extract Technical Requirements Before Implementation

---

## Executive Summary

This research investigates how AI can interrogate users about features they want implemented in a codebase, extracting all relevant technical information before implementation begins. The findings synthesize evidence from requirements engineering research, conversational AI, UX research, cognitive science, knowledge elicitation from expert systems, spec-driven development methodology, and analysis of current AI coding tools (Claude Code, Cursor, GitHub Copilot, Kiro, GitHub Spec Kit).

### Key Findings

1. **Structured questioning extracts significantly more complete requirements than free-form conversation.** The LLMREI study (Korn et al., 2025 IEEE RE Conference) demonstrated that LLMs using structured prompting elicited up to 73.7% of all intended requirements, with error rates comparable to trained human interviewers. The four-phase hierarchy -- Context, Behavior, Edge Cases, Verification -- emerges consistently across multiple independent sources as the most effective structure.

2. **Codebase analysis before questioning is the highest-leverage intervention.** Sourcegraph's context retrieval research shows that multi-signal retrieval (keyword, embedding, graph-based, local context) enables AI to answer many questions from code alone, reducing user burden. The pattern of "research before asking" is now standard practice in production tools (Claude Code, Cursor Plan Mode, Augment Code).

3. **Spec-driven development has emerged as the industry norm for AI-assisted coding.** As of early 2026, tools like GitHub Spec Kit, AWS Kiro, and frameworks like the Agentic Coding Handbook all implement a specification-first workflow where requirements are captured before code is generated. The SDD paper (arxiv:2602.00180) identifies three levels of rigor -- spec-first, spec-anchored, and spec-as-source -- with spec-anchored being the sweet spot for most production systems.

4. **5-7 targeted questions capture most implementation-critical information for standard features, but this is a rough heuristic, not a universal rule.** Complex features touching authentication, payments, or multi-service integration require more. The key insight is that question count should be adaptive to complexity, not fixed.

5. **Cognitive load and question fatigue are real constraints.** Research on cognitive load in interviews (Hanway, 2021) shows that even interviewers experience performance degradation under high cognitive demand. Users asked too many questions disengage. The optimal approach is one question at a time with structured options (the "Golden Prompt" pattern).

6. **Users systematically omit edge cases, error handling, and non-functional requirements unless explicitly prompted.** Gartner research shows 48% of ICT projects experience performance issues because non-functional requirements like scalability are treated as afterthoughts. "What if X fails?" questions are essential, not optional.

7. **Leading questions and confirmation bias are the primary anti-patterns.** Cognitive bias research (Zalewski et al., 2020) identifies anchoring, confirmation, and representativeness biases as the three most frequent in requirements elicitation. AI systems are particularly vulnerable to confirmation bias due to training incentives toward agreeableness.

8. **Requirements management failures cause approximately 78% of project failures.** Fixes cost 10-100x more when caught late versus early detection. This makes pre-implementation interrogation one of the highest-ROI activities in software development.

9. **Verification through editable summaries catches misunderstandings before they become expensive.** The spec-driven development paradigm, where specifications are reviewed and edited at each phase before proceeding, is the most validated approach for ensuring alignment between intent and implementation.

---

## Part 1: Current State of AI-Assisted Requirements Gathering

### How Existing Tools Handle Feature Disambiguation

#### Claude Code

Claude Code (Anthropic) takes an agentic approach. It autonomously analyzes codebase structure, dependencies, and patterns before engaging the user. Key mechanisms for requirements gathering:

- **Plan Mode**: Claude writes a multi-step strategy and waits for user approval before executing. This is implicit requirements gathering -- the plan itself surfaces assumptions that users can correct.
- **CLAUDE.md / Skills**: Project-level instruction files that provide persistent context (coding conventions, architectural decisions, testing strategies), reducing the need for repetitive questioning.
- **Subagents**: Claude can spawn specialized sub-agents for different aspects of a task, each potentially gathering different types of information.

A community tool, the [Claude Code Requirements Builder](https://github.com/rizethereum/claude-code-requirements-builder), implements a two-phase questioning system: 5 discovery questions (yes/no format) followed by 5 expert questions, with autonomous codebase research between phases.

**Gap**: Claude Code does not have a built-in, structured feature interrogation workflow. It relies on the user to provide sufficient context or on skills/commands to structure the interaction.

Source: [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)

#### Cursor

Cursor's Plan Mode (since v2.1, November 2025) is the most explicitly requirements-oriented tool among AI coding editors:

- Crawls project docs, rules, and code before generating a plan
- Asks clarifying questions with an interactive UI for answering them
- Generates editable Markdown plans with file paths, code references, and TODO lists
- Plans can be saved to `.cursor/plans/` for version control

As of February 2026, Cursor added cloud-based background agents that can work independently on features, making specification quality even more critical -- these agents cannot ask follow-up questions mid-execution.

Source: [Cursor Plan Mode](https://cursor.com/blog/plan-mode), [Cursor Docs: Modes](https://cursor.com/docs/agent/modes)

#### AWS Kiro

Launched mid-2025, Kiro is an agentic IDE built on Code OSS that implements spec-driven development natively. Its workflow guides developers through three explicit phases:

1. **Requirements**: User stories in "As a... GIVEN... WHEN... THEN..." format with acceptance criteria
2. **Design**: Technical architecture, data models, API contracts
3. **Tasks**: Implementation breakdown with dependencies

Kiro uses Claude Sonnet 4.5 under the hood and includes a "memory bank" (steering files: product.md, tech.md, structure.md) that provides persistent context similar to Claude Code's CLAUDE.md.

Source: [Martin Fowler: Understanding SDD Tools](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)

#### GitHub Spec Kit

GitHub's open-source toolkit (released September 2024) formalizes spec-driven development for AI coding agents. It provides a CLI, templates, and prompts implementing a four-phase workflow:

1. `/specify` -- generates a detailed spec from a prompt
2. `/plan` -- creates technical architecture
3. `/tasks` -- breaks the plan into implementation tasks
4. `/implement` -- generates code task by task

Spec Kit works with multiple AI assistants (GitHub Copilot, Claude Code, Gemini CLI, Cursor) and treats specifications as "living, executable artifacts that evolve with the project." It also includes a "constitution" layer -- foundational rules documents that enforce architectural principles across all changes.

Source: [GitHub Blog: Spec-Driven Development](https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/), [GitHub Spec Kit](https://github.com/github/spec-kit)

#### GitHub Copilot Workspace (Sunset May 2025)

Copilot Workspace pioneered the structured specification workflow. Though sunset, its patterns remain influential:

- **Topic generation**: Summarizes the task as a question posed against the codebase
- **Current specification**: Bulleted list of how the codebase works now
- **Proposed specification**: Bulleted list of the desired end state, focused on success criteria
- **File relevance**: Combines LLM techniques with code search to identify relevant files

User feedback revealed a key gap: users wanted the system to "ask me clarifying questions to aid the plan and code steps (rather than selecting questions to ask itself)."

Source: [GitHub Copilot Workspace](https://githubnext.com/projects/copilot-workspace), [Copilot Workspace User Manual](https://github.com/githubnext/copilot-workspace-user-manual/blob/main/overview.md)

#### Aider

Aider uses a multi-mode conversation design that supports iterative requirements discovery:

- **Architect Mode**: Plans large changes before coding
- **Ask Mode**: Answers questions without touching files
- **Code Mode**: Implements based on conversation context
- **Repo map**: Creates an overview of the entire codebase for context

The practical workflow: `/ask` to propose a solution, refine in conversation, then `/code` to implement. This embeds requirements gathering into the natural conversation flow rather than making it a separate phase.

Source: [Aider Documentation](https://aider.chat/docs/)

### Known Gaps Across All Tools

| Gap | Description |
|-----|-------------|
| No systematic questioning | Tools ask ad-hoc questions or none at all; no structured interrogation framework |
| Edge case blindness | Happy path is well-covered; error states, concurrency, and boundary conditions are not probed |
| Non-functional requirements ignored | Performance, security, accessibility rarely asked about unless user raises them |
| No completeness detection | No tool signals "I don't have enough information to implement this safely" |
| Assumption opacity | When tools make assumptions, they often don't surface them for review |
| Confirmation bias | LLMs agree with user framing rather than challenging unstated assumptions |
| Memory limitations | Agents lack persistent memory across sessions, requiring repeated context provision |

---

## Part 2: Requirements Engineering Theory Applied to AI

### Classical Elicitation Techniques

A systematic review by Pacheco and Garcia (2018, IET Software) identified mature elicitation techniques through analysis of literature from 1993-2015. Their key finding: **interviews, mostly structured, are the most effective technique**, enabling analysts to obtain more information than other methods.

The full taxonomy of mature techniques includes: interviews, workshops, focus groups, joint application development (JAD), quality function deployment, ethnography, scenarios, prototyping, protocol analysis, card sorting, ontologies, modeling, goal-based approaches, use cases, repertory grids, user stories, mind mapping, and group storytelling.

Source: [Pacheco & Garcia, 2018](https://ietresearch.onlinelibrary.wiley.com/doi/10.1049/iet-sen.2017.0144)

### Adapting Techniques for AI-Human Interaction

Not all classical techniques translate to AI interactions:

| Technique | AI Adaptability | How |
|-----------|----------------|-----|
| Structured interview | High | Direct mapping to multi-turn dialogue with slot filling |
| Scenarios/Use cases | High | "Walk me through how a user would..." questions |
| Prototyping | Medium | AI can generate mockups or pseudocode for feedback |
| Card sorting | Low | Requires spatial/visual interaction beyond text |
| Ethnography/Observation | Low | AI cannot observe users in context |
| Workshops/JAD | Low | Multi-stakeholder facilitation is beyond current AI |
| Goal-based (KAOS) | Medium | AI can ask about goals and decompose into sub-goals |
| User stories | High | "As a [who], I want [what] so that [why]" is a natural prompt template |

### Information Taxonomy for Software Features

Based on synthesis across multiple sources (Requiment, Perforce, AltexSoft, INVEST criteria, SDD paper), the following taxonomy covers what must be captured:

**Tier 1 -- Always Required (Functional Core)**
- User story: Who, what, why
- Happy path: Step-by-step expected behavior
- Input specification: Data types, formats, validation
- Output specification: What is returned/displayed on success
- Acceptance criteria: 3-7 testable conditions (Given-When-Then format)

**Tier 2 -- Required for Non-Trivial Features (Error & Integration)**
- Error handling: What happens on failure (network, validation, permission, timeout)
- Edge cases: Empty states, max limits, concurrent access, invalid input
- Integration points: APIs, databases, external services involved
- Dependencies: What must exist before this can work

**Tier 3 -- Required for Production Features (Non-Functional)**
- Performance: Response time, throughput requirements
- Security: Authentication, authorization, data sensitivity
- Accessibility: WCAG compliance, screen reader support
- Scalability: Expected load, growth projections

**Tier 4 -- Contextual (Domain-Specific)**
- Regulatory compliance (healthcare, finance, legal)
- Internationalization/localization
- Data retention and privacy
- Audit logging

Sources: [Requiment Checklist](https://www.requiment.com/requirements-gathering-template-checklist/), [Perforce NFR Examples](https://www.perforce.com/blog/alm/what-are-non-functional-requirements-examples), [AltexSoft Acceptance Criteria](https://www.altexsoft.com/blog/acceptance-criteria-purposes-formats-and-best-practices/)

---

## Part 3: Structured Interrogation Frameworks

### The Funnel Technique

The NN/g Funnel Technique provides the foundational question sequence: start broad with open-ended questions ("Tell me about..."), then progressively narrow to specific, closed questions. This prevents premature anchoring on specific solutions.

Source: [NN/g Funnel Technique](https://www.nngroup.com/articles/the-funnel-technique-in-qualitative-user-research/)

### Wood's Four-Phase Knowledge Elicitation Framework

Wood (1993) developed a structured interview approach specifically for extracting expert knowledge, consisting of four phases:

1. **Descriptive Elicitation**: Reveal important entities, concepts, and domain terminology
2. **Structured Expansion**: Probe relationships between concepts and knowledge organization
3. **Critical Analysis**: Examine decision criteria and exception handling
4. **Validation**: Verify captured knowledge through teachback

This maps remarkably well to software feature extraction:

| Wood's Phase | Feature Interrogation Equivalent |
|-------------|--------------------------------|
| Descriptive Elicitation | "What is this feature? What problem does it solve?" |
| Structured Expansion | "How does it interact with existing components? What data does it use?" |
| Critical Analysis | "What happens when X fails? What are the edge cases?" |
| Validation | "Here is my understanding. Is this correct?" |

Source: [Wood, 1993, Int. J. Intelligent Systems](https://onlinelibrary.wiley.com/doi/10.1002/int.4550080106)

### The Six Socratic Questions Applied to Feature Discovery

R.W. Paul's six types of Socratic questions adapt directly to technical discovery:

| Socratic Category | Feature Discovery Application | Example Question |
|-------------------|------------------------------|------------------|
| **Clarification** | Understanding the feature request | "What exactly do you mean by 'search'? Full-text? Filtered? Fuzzy?" |
| **Assumptions** | Surfacing unstated expectations | "You mentioned users will upload files. Are you assuming a max file size?" |
| **Evidence/Reasoning** | Understanding the motivation | "What user behavior or data suggests this feature is needed?" |
| **Perspectives** | Considering different users | "How would an admin use this differently from a regular user?" |
| **Implications** | Exploring consequences | "If we add this, what effect will it have on the existing workflow?" |
| **Meta-questions** | Questioning the question itself | "Is 'add search' the right framing, or is the real problem discoverability?" |

Source: [University of Michigan - Six Types of Socratic Questions](https://websites.umich.edu/~elements/probsolv/strategy/cthinking.htm)

### Progressive Disclosure vs. Decision Tree vs. Conversational

Three approaches to structuring the interrogation, each with tradeoffs:

**Progressive Disclosure (Recommended for Most Cases)**
- Start with broad, essential questions
- Reveal more specific questions based on user responses
- Adapts dynamically to complexity
- Reduces cognitive load
- Best for: Features with variable complexity

**Decision Tree (Fixed Branching)**
- Predefined question paths based on feature type
- Each answer determines the next branch
- Fully predictable but rigid
- Cannot handle novel feature types
- Best for: Well-understood feature categories (CRUD, search, auth)

**Conversational (Unstructured)**
- Free-form dialogue
- Maximum flexibility
- Highest risk of missing requirements
- Hardest to ensure completeness
- Best for: Exploratory/novel features where structure would constrain discovery

**Recommended Hybrid**: Use progressive disclosure as the primary approach, with decision tree shortcuts for well-known feature types, and conversational mode for genuinely novel features where the question space is unknown.

Source: [NN/g Progressive Disclosure](https://www.nngroup.com/articles/progressive-disclosure/), [IxDF Progressive Disclosure](https://www.interaction-design.org/literature/topics/progressive-disclosure)

### When to Ask vs. When to Infer from Codebase Context

A critical design decision: which information should the AI extract from code versus ask the user about?

**Infer from codebase (do not ask):**
- Coding conventions (naming, formatting, patterns)
- Test framework and test file locations
- Error handling patterns already in use
- Database/ORM patterns
- API response formats
- Authentication/authorization mechanisms in place
- Existing component library and UI patterns

**Always ask the user:**
- The "why" behind the feature (business motivation)
- User-facing behavior preferences (UX decisions)
- Priority and scope boundaries
- Edge case handling preferences (when multiple valid approaches exist)
- Non-functional requirements that differ from defaults

**Ask only if codebase is ambiguous:**
- Technology choices (when multiple are used in the project)
- Integration approach (when the codebase uses different patterns)
- Data model decisions (when existing schemas don't clearly extend)

Source: [Sourcegraph Context Retrieval](https://sourcegraph.com/blog/lessons-from-building-ai-coding-assistants-context-retrieval-and-evaluation), [Augment Code Guide](https://www.augmentcode.com/tools/ai-coding-assistants-for-large-codebases-a-complete-guide)

---

## Part 4: Codebase-Aware Context Extraction

### How Context Engines Work

Sourcegraph's research describes the two-stage architecture used by modern AI coding assistants:

**Stage 1: Retrieval** -- Cast a wide net using complementary sources:
- **Keyword retriever**: Trigram-based search for exact matches
- **Embedding-based retriever**: Semantic search using vector representations
- **Graph-based retriever**: Static analysis to traverse dependency relationships
- **Local context**: Editor state, recent git history, cursor position

**Stage 2: Ranking** -- Filter to the most relevant items within the token budget using transformer models trained to predict relevance. This is essentially a knapsack problem: maximize information value within context window constraints.

Source: [Sourcegraph Blog](https://sourcegraph.com/blog/lessons-from-building-ai-coding-assistants-context-retrieval-and-evaluation)

### Codebase Signals That Reduce User Questions

Before asking the user anything, an AI interrogation system should analyze:

| Signal | What It Reveals | Questions It Eliminates |
|--------|----------------|------------------------|
| `package.json` / `requirements.txt` | Tech stack and dependencies | "What framework/language are you using?" |
| Test file patterns | Testing conventions | "How do you want this tested?" |
| Existing error handlers | Error handling approach | "How should errors be handled?" |
| API route patterns | REST/GraphQL conventions | "What URL pattern should this use?" |
| Database migrations | Schema patterns | "What ORM/database do you use?" |
| `.eslintrc` / `prettier` config | Code style | "What formatting conventions do you follow?" |
| Git history for similar features | Implementation patterns | "How were similar features built?" |
| CI/CD config | Build and deploy process | "How is this deployed?" |
| Auth middleware | Security patterns | "What authentication is required?" |
| Component directory structure | UI patterns | "Where should this component live?" |

### Techniques for Inferring Architectural Constraints

**Dependency analysis**: By tracing imports and function calls, AI can identify which modules are coupled. A feature request that touches a highly-coupled module should trigger more integration questions.

**Pattern recognition**: If the codebase consistently uses a repository pattern for data access, the AI should assume the new feature follows the same pattern and only ask if the user wants to deviate.

**Convention detection**: Naming conventions, file organization, and code comments all signal architectural decisions. For example, if all API endpoints follow `/api/v2/[resource]`, the AI should not ask about URL structure.

**History analysis**: Git log analysis reveals how similar features were implemented, providing templates for new feature questions. If the last 5 features all included database migrations, the AI should ask about data model changes for the current feature.

Source: [Augment Code](https://www.augmentcode.com/tools/ai-coding-assistants-for-large-codebases-a-complete-guide)

### The Enterprise Context Challenge

Standard AI assistants hit limitations with large enterprise codebases. Augment Code notes that most tools can only "see" a few thousand tokens at a time. In a 400,000-file monorepo, "custom decorators, subtle overrides in sibling microservices, and scattered business logic all remain invisible." This means the AI may ask questions that the codebase could answer, or worse, make assumptions that violate patterns established in distant parts of the codebase.

Source: [Augment Code](https://www.augmentcode.com/tools/ai-coding-assistants-for-large-codebases-a-complete-guide)

---

## Part 5: Spec-Driven Development -- The Emerging Paradigm

### The Rise of SDD

As of early 2026, specification-driven development has rapidly emerged as the dominant paradigm for AI-assisted coding. The core insight: when AI generates code, **the specification is the new source code** -- it is the artifact humans should review and maintain, with generated code as a secondary output.

The SDD paper (Batarseh et al., arxiv:2602.00180, January 2026) provides the most comprehensive academic treatment, identifying that SDD "inverts the traditional workflow by treating specifications as the source of truth and code as a generated or verified secondary artifact." Case studies showed error reductions of up to 50% when using refined specifications with LLM-generated code.

Source: [SDD Paper](https://arxiv.org/html/2602.00180v1)

### Three Levels of Specification Rigor

| Level | Description | When to Use | Maintenance Cost |
|-------|-------------|-------------|-----------------|
| **Spec-First** | Specifications guide initial development but may drift post-implementation | Prototypes, one-off scripts, early exploration | Low |
| **Spec-Anchored** | Specifications evolve alongside code with automated tests enforcing alignment | Most production systems (the sweet spot) | Medium |
| **Spec-As-Source** | Specifications are the only directly-edited artifacts; code is entirely generated | Mature domains with trusted generation tooling (e.g., automotive control systems) | High |

### SDD Workflow Applied to Feature Interrogation

The four-phase SDD workflow maps directly to the interrogation problem:

```
Phase 1: SPECIFY          Phase 2: PLAN              Phase 3: IMPLEMENT       Phase 4: VALIDATE
- What problem?           - Architecture decisions    - Write code             - Does code match spec?
- Who uses it?            - Data models               - Follow the plan        - Run acceptance tests
- Success criteria        - API contracts             - Test each piece        - Fix spec or code
- Acceptance criteria     - Integration points
```

The interrogation system's job is Phase 1 -- producing a specification of sufficient quality that Phases 2-4 can proceed without ambiguity.

### Key Principle: Minimal Sufficient Detail

The SDD paper recommends writing specifications at "minimal sufficient detail": if an AI or developer could interpret a requirement in multiple ways, add clarification. If there is only one reasonable interpretation, do not over-specify. This directly informs the interrogation strategy -- ask questions only when ambiguity exists.

Source: [SDD Paper](https://arxiv.org/html/2602.00180v1), [Agentic Coding Handbook](https://tweag.github.io/agentic-coding-handbook/WORKFLOW_SPEC_FIRST_APPROACH/)

### Empirical Results from SDD Case Studies

| Domain | Approach | Result |
|--------|----------|--------|
| Financial services | OpenAPI specs + contract testing | 75% reduction in API integration cycle time |
| Enterprise software | Executable Gherkin scenarios | Elimination of ambiguity-driven rework |
| Automotive embedded | Model-based specification | Safety certification compliance with guaranteed code generation |
| General AI coding | Spec-first vs. vibe coding | 30% fewer engineers, half the delivery time (Tweag experiment) [Source needed -- single vendor claim] |

Source: [SDD Paper](https://arxiv.org/html/2602.00180v1), [Agentic Coding Handbook](https://tweag.github.io/agentic-coding-handbook/WORKFLOW_SPEC_FIRST_APPROACH/)

---

## Part 6: Information Completeness Detection

### The Core Challenge: When Is Enough Enough?

Determining when sufficient information has been gathered remains an open challenge in requirements engineering. The literature points to context-dependent, risk-based approaches: stop clarifying when remaining ambiguities no longer impact downstream development.

Key insight from Berry (2003): whether a natural language requirements specification has any defects is "fundamentally algorithmically undecidable." However, searching for indicators of specific defect types (ambiguity, vagueness, incompleteness) is feasible.

Source: [Berry, 2003](https://cs.uwaterloo.ca/~dberry/FTP_SITE/reprints.journals.conferences/KamstiesBerryPaech2001DetectingAmbiguity.pdf)

### The Definition of Ready Framework

The most practical approach to completeness detection is the Definition of Ready (DoR), which defines minimum viable conditions a task must fulfill before implementation.

**The "Just Enough" Principle**: The DoR should be a "just-enough quality gate ensuring the essential inputs are present to proceed" -- not an exhaustive specification. If the checklist becomes too exhaustive, "it probably includes items that should remain reviewed or for just-in-time implementation."

**Tiered Readiness Levels**:

| Tier | When to Use | Requirements |
|------|-------------|-------------|
| **Gold** | Critical user journey, payments, auth | Full specification: all 4 tiers of requirements taxonomy |
| **Silver** | Standard features with user impact | Tiers 1-2: functional core + error handling |
| **Bronze** | Internal tools, admin features, minor UI | Tier 1 only: user story + happy path + acceptance criteria |

Source: [QE Unit](https://qeunit.com/blog/the-definition-of-ready-in-quality-engineering/)

### Completeness Signals (When to Stop Asking)

An AI interrogation system should stop asking when:

1. **INVEST criteria pass**: The specification is Independent, Negotiable, Valuable, Estimable, Small, and Testable
2. **Happy path is articulable**: Core behavior can be described in Given-When-Then format
3. **Top 3 failure scenarios have handling defined**: The most likely failure modes have explicit responses
4. **Acceptance criteria count is 3-7**: Fewer than 3 suggests under-specification; more than 10 suggests the feature should be split
5. **No "it depends" answers remain unresolved**: All conditional behavior has been resolved to concrete branches
6. **Codebase questions are answered**: Integration points, existing patterns, and dependencies are identified

### Completeness Anti-Signals (When to Keep Asking)

- User has said "I don't know" to a Tier 1 question without accepting a default
- The feature touches authentication, payments, or data deletion (high-consequence areas)
- Contradictory information has not been resolved
- The feature crosses service boundaries without defined API contracts
- No error handling has been specified at all
- The user has only described the happy path

### Ambiguity as a Resource

An important insight from research (Springer, Requirements Engineering journal): rather than treating ambiguity purely as an obstacle, "the occurrence of an ambiguity is often a resource for discovering tacit knowledge." When the AI encounters an ambiguous statement, it should treat it as a signal to probe deeper, not just a defect to fix.

Source: [Ambiguity and Tacit Knowledge in RE Interviews](https://dl.acm.org/doi/10.1007/s00766-016-0249-3)

---

## Part 7: Anti-Patterns and Failure Modes

### The Scale of the Problem

Requirements management failures are the root cause of approximately 78% of project failures. Fixes cost 10-100x more when caught late versus early detection. Gartner research shows 48% of ICT projects experience performance issues specifically because non-functional requirements like scalability were treated as afterthoughts.

Source: [Requiment](https://www.requiment.com/common-requirements-gathering-and-management-mistakes-and-how-to-avoid-them/), [Aqua Cloud](https://aqua-cloud.io/common-requirements-management-mistakes/)

### Taxonomy of Interrogation Anti-Patterns

#### AP1: Over-Interrogation (Analysis Paralysis)

**Description**: Asking too many questions, pursuing excessive detail, delaying implementation indefinitely.

**Symptoms**:
- More than 10 questions for a standard feature
- Asking about Tier 3-4 requirements for a Bronze-tier feature
- Repeated drilling into edge cases that are unlikely to occur
- User expresses frustration: "just build it"

**Root cause**: Treating all features as high-consequence; not calibrating question depth to feature risk.

**Research evidence**: The "Fire Drill" anti-pattern describes "spending exceeding amount of time, effort and other resources on requirements gathering and analysis." Mike Cohn warns that overly rigid Definitions of Ready "prevent Agile teams from performing concurrent engineering."

**Mitigation**: Classify feature complexity before questioning. Use tiered readiness levels. Set a hard question budget (3-4 for simple, 5-7 for medium, 7-10 for complex). Accept defaults for unspecified Tier 3-4 requirements.

#### AP2: Under-Interrogation (Dangerous Assumptions)

**Description**: Not asking enough questions, making unstated assumptions, proceeding with insufficient information.

**Symptoms**:
- Implementing a feature with zero clarifying questions
- Assuming database schema, API contracts, or error handling based on general patterns
- Building something that "technically satisfies the request but violates the user's implicit assumptions"
- Rework and correction cycles after initial implementation

**Root cause**: LLM agreeableness bias; desire to appear competent by not needing to ask; insufficient complexity assessment. As the Beyond the Vibes guide notes, "the Agentic system is not going to consider the big picture of your project" and agents "will never question obviously flawed instructions."

**Research evidence**: The LLMREI study found that even with structured prompting, LLMs only captured 73.7% of intended requirements. The 26.3% gap represents requirements that were missed because the LLM did not ask the right questions.

**Mitigation**: Use the minimum viable specification checklist. Require at least one question per tier for non-trivial features. Surface assumptions explicitly: "I am assuming X. Is this correct?"

Source: [LLMREI](https://arxiv.org/html/2507.02564), [Beyond the Vibes](https://blog.tedivm.com/guides/2026/03/beyond-the-vibes-coding-assistants-and-agents/)

#### AP3: Asking About Things the AI Should Know from Context

**Description**: Asking the user questions that could be answered by analyzing the codebase.

**Symptoms**:
- "What testing framework do you use?" (when `jest.config.js` exists)
- "What database do you use?" (when there are migration files and ORM config)
- "What code style do you follow?" (when linter configs exist)

**Root cause**: Failing to perform codebase analysis before generating questions.

**Mitigation**: Always run codebase analysis first. Never ask about something that has a definitive answer in the code. If codebase signals are ambiguous, ask as a confirmation ("I see you use Jest for testing. Should this feature follow the same pattern?") rather than as an open question.

#### AP4: Confirmation Bias in Question Framing

**Description**: Framing questions in ways that suggest a preferred answer or constrain the solution space.

**Symptoms**:
- "Should we use a modal for this?" (assumes modal is the right UI pattern)
- "This will need a database table, right?" (assumes data persistence approach)
- "I assume this should follow the existing REST pattern?" (when the user might prefer GraphQL)

**Root cause**: LLMs trained to be agreeable reinforce rather than challenge user assumptions. The anchoring effect means the first option mentioned becomes disproportionately influential.

**Research evidence**: Zalewski et al. (2020) found that anchoring, confirmation, and representativeness biases are the three most frequent in requirements elicitation.

**Mitigation**: Frame questions neutrally with multiple options of equal weight. Use "What approach would you prefer for X?" rather than "Should we use Y for X?" Present options in randomized or alphabetical order. Ask "What alternatives did you consider?" to broaden the solution space.

Source: [Cognitive Biases in Requirements Elicitation, Springer](https://link.springer.com/chapter/10.1007/978-3-030-26574-8_9)

#### AP5: Leading Questions That Constrain the Solution Space

**Description**: Questions that embed implementation decisions, preventing the user from considering alternatives.

**Symptoms**:
- "How many columns should the table have?" (assumes a table is the right display)
- "What fields should the form include?" (assumes a form-based interaction)
- "What should the API endpoint return?" (assumes an API is needed)

**Root cause**: The AI has already formed an implementation plan and is seeking confirmation rather than requirements.

**Mitigation**: Separate requirements questions ("What information does the user need?") from implementation questions ("How should we display it?"). Ask about the "what" and "why" before the "how."

#### AP6: Question Fatigue and Cognitive Overload

**Description**: Asking too many questions at once, or questions that are too complex, causing the user to disengage or provide low-quality answers.

**Symptoms**:
- User starts giving one-word answers
- User says "whatever you think is best"
- User stops responding to follow-up questions
- Quality of answers degrades over time

**Root cause**: Violating cognitive load principles. Research shows that "cognitive demands required to complete an investigative interview task led to an increased perceived cognitive load and had a negative impact on recall performance."

**Research evidence**: Cognitive load research (Hanway, 2021) demonstrates that elevated cognitive load "preferentially impairs Type 2 (analytic) processing, resulting in increased reliance on Type 1 (heuristic) processes" -- meaning users default to quick, heuristic answers rather than thoughtful ones.

**Mitigation**: One question at a time. Provide structured options (A, B, C) to reduce decision burden. Keep total interaction under 7 questions for standard features. Provide reasonable defaults for non-critical decisions.

Source: [Cognitive Load in Interviews, Hanway 2021](https://bpspsychub.onlinelibrary.wiley.com/doi/pdf/10.1111/lcrp.12182)

#### AP7: Ignoring "I Don't Know" Signals

**Description**: Treating uncertain user responses as requirements gaps rather than signals for AI-provided defaults.

**Symptoms**:
- Repeatedly asking the same question in different ways when the user genuinely doesn't know
- Blocking progress because a non-critical question is unanswered
- Failing to offer reasonable defaults

**Root cause**: Treating all questions as equally important; not distinguishing between "the user hasn't thought about this" and "this decision is critical."

**Mitigation**: When the user says "I don't know," offer a default with explanation: "The typical approach for this type of feature is X. I'll use that unless you tell me otherwise." Only block on "I don't know" for Tier 1 questions (user story, happy path).

#### AP8: Vibe Coding (No Specification at All)

**Description**: Jumping directly from a vague feature request to code generation without any specification or interrogation phase.

**Symptoms**:
- "Add search to the dashboard" immediately produces code
- No plan, no questions, no specification document
- Multiple rework cycles as assumptions are discovered to be wrong
- Code that technically works but solves the wrong problem

**Root cause**: The path of least resistance. MIT's Missing Semester lecture notes that "giving a good specification is more of an art than a science" and many developers skip it because it feels slower.

**Research evidence**: The Beyond the Vibes guide identifies vibe coding as the primary failure mode where developers "ask AI for quick solutions without strategic context, then accept whatever output emerges." The SDD paper documents up to 50% error reduction when specifications are used.

**Mitigation**: Build the interrogation phase into the workflow as a required step. Use test-driven development: write tests first (with AI assistance), audit them, then implement.

Source: [MIT Missing Semester: Agentic Coding](https://missing.csail.mit.edu/2026/agentic-coding/), [Beyond the Vibes](https://blog.tedivm.com/guides/2026/03/beyond-the-vibes-coding-assistants-and-agents/)

---

## Part 8: Practical Implementation Patterns

### The Golden Prompt Pattern

The most practically validated approach for structuring AI questioning:

```
Before implementing, ask me clarifying questions about this feature.
Ask each question one at a time.
Wait for my answer before asking the next question.
If there are several options, show them in a table with options labeled A, B, C, etc.
After all questions are answered, summarize the specification for my confirmation.
```

This pattern addresses three problems simultaneously:
1. **Cognitive load**: One question at a time
2. **Decision fatigue**: Structured options reduce open-ended burden
3. **Verification**: Summary before implementation catches misunderstandings

Source: [Dan Does Code](https://www.dandoescode.com/blog/efficient-vibe-coding-with-clarifying-questions)

### Addy Osmani's Specification-First Workflow

Google engineer Addy Osmani's LLM coding workflow represents the most structured practitioner approach:

1. **Brainstorm specification**: Describe the idea and ask the LLM to iteratively ask questions until requirements and edge cases are fleshed out
2. **Compile spec.md**: Requirements, architecture decisions, data models, testing strategy
3. **Generate project plan**: Break implementation into logical, bite-sized tasks
4. **Iterate on plan**: Edit and ask the AI to critique/refine
5. **Implement incrementally**: One step at a time, test each step

His key insight: "Planning first forces you and the AI onto the same page and prevents wasted cycles. It's a step many people are tempted to skip, but experienced LLM developers now treat a robust spec/plan as the cornerstone of the workflow."

For writing specifications for AI agents specifically, Osmani recommends: writing specs like a PRD ensures you include user-centric context ("the why behind each feature") so the AI does not optimize for the wrong thing. Expanding it like an SRS ensures you nail down the specifics the AI will need to actually generate correct code.

Source: [Addy Osmani - AI Coding Workflow](https://addyosmani.com/blog/ai-coding-workflow/), [How to Write a Good Spec for AI Agents](https://addyosmani.com/blog/good-spec/)

### Multi-Turn Dialogue State Management

Effective AI interrogation requires tracking what has been asked, what has been answered, and what remains:

```yaml
interrogation_state:
  # Current phase
  phase: context | behavior | edge_cases | verification | complete

  # What we know (slots filled)
  slots:
    goal: null | string           # What problem this solves
    scope: null | string          # MVP boundaries
    user_type: null | string      # Who uses this
    input_spec: null | object     # What data users provide
    output_spec: null | object    # What users see on success
    happy_path: null | array      # Step-by-step expected behavior
    error_handling: null | object  # What happens on failure
    constraints: null | object    # Limits, boundaries
    integration_points: null | array  # External dependencies
    acceptance_criteria: null | array # Testable conditions

  # Required vs optional slots
  required: [goal, happy_path, acceptance_criteria]
  recommended: [error_handling, input_spec, output_spec]
  optional: [constraints, integration_points]

  # Conversation tracking
  questions_asked: 0
  max_questions: 7  # Adjusted by complexity tier
  unanswered: []
  contradictions: []
  assumptions_made: []

  # Complexity assessment
  complexity: simple | medium | complex
  readiness_tier: bronze | silver | gold

  # Codebase context
  codebase_signals:
    patterns_detected: []
    integration_points_found: []
    conventions_identified: []
```

Source: [Microsoft CLU Multi-Turn](https://learn.microsoft.com/en-us/azure/ai-services/language-service/conversational-language-understanding/concepts/multi-turn-conversations), [ACM Survey on Multi-Turn Dialogue](https://dl.acm.org/doi/full/10.1145/3771090)

### Handling Uncertain and Incomplete Responses

| User Response | Strategy | Example |
|---------------|----------|---------|
| "I don't know" | Offer default with rationale | "Most features like this handle errors with a toast notification. I'll use that approach." |
| "Whatever works" | Choose codebase-consistent default | "Your codebase uses modal dialogs for confirmations. I'll follow that pattern." |
| "I'm not sure yet" | Park with explicit assumption | "I'll assume no rate limiting for now. We can add it later if needed." |
| Contradictory info | Surface contradiction neutrally | "Earlier you said this should be real-time, but now you mention batch processing. Which is the primary mode?" |
| Vague answer | Rephrase with concrete options | "You said 'something like search.' Do you mean: A) Full-text search, B) Filter/faceted search, C) Autocomplete suggestions?" |
| Overly detailed answer | Summarize and confirm | "It sounds like the core requirement is X, with Y and Z as nice-to-haves. Is that right?" |

### Structured Output Formats

The output of the interrogation should be a structured specification. Three formats, from lightest to heaviest:

**Format 1: Quick Specification (Bronze Tier)**
```markdown
## Feature: [Name]
**Goal**: [One sentence]
**User Story**: As a [user], I want [feature] so that [benefit]
**Happy Path**: [3-5 steps]
**Acceptance Criteria**:
- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]
```

**Format 2: Standard Specification (Silver Tier)**
```markdown
## Feature: [Name]

### Context
- **Goal**: [Problem being solved]
- **User**: [Who uses this]
- **Scope**: [What's included/excluded]

### Behavior
- **Input**: [What user provides]
- **Process**: [What system does]
- **Output**: [What user sees]

### Error Handling
- **[Failure mode 1]**: [Response]
- **[Failure mode 2]**: [Response]

### Acceptance Criteria
Given [precondition]
When [action]
Then [result]

### Technical Notes
- Follows existing [pattern] from [file]
- Integrates with [existing component]
- [Assumption]: [assumption made and why]
```

**Format 3: Full Specification (Gold Tier)**
```markdown
## Feature: [Name]

### Context & Motivation
- **Problem Statement**: [What problem this solves]
- **User Story**: As a [user], I want [feature] so that [benefit]
- **Success Metrics**: [How we measure success]
- **Scope**: [Included] / [Excluded]

### Current State
- [How the system works now]
- [Relevant existing components]

### Desired State
- [How the system should work after implementation]

### Detailed Behavior
#### Happy Path
1. [Step 1]
2. [Step 2]
3. [Step 3]

#### Alternative Flows
- [Alternative scenario 1]
- [Alternative scenario 2]

#### Error Handling
| Error Condition | System Response | User Experience |
|----------------|-----------------|-----------------|
| [Error 1] | [Response] | [What user sees] |
| [Error 2] | [Response] | [What user sees] |

### Non-Functional Requirements
- **Performance**: [Requirements]
- **Security**: [Requirements]
- **Accessibility**: [Requirements]

### Acceptance Criteria
1. Given [precondition], When [action], Then [result]
2. Given [precondition], When [action], Then [result]
3. Given [precondition], When [action], Then [result]

### Technical Constraints
- Must follow [pattern] from [file]
- Integrates with [component] via [interface]
- Dependencies: [list]

### Assumptions & Decisions
| Decision | Choice | Rationale |
|----------|--------|-----------|
| [Decision 1] | [Choice made] | [Why] |

### Open Questions
- [Question that could not be resolved]
```

### Integration with the SDD Pipeline

The interrogation output feeds into the broader spec-driven development pipeline:

```
User Request  -->  Codebase Analysis  -->  Interrogation  -->  Specification
                                                                    |
                                                                    v
                                                              Plan (architecture)
                                                                    |
                                                                    v
                                                              Tasks (decomposition)
                                                                    |
                                                                    v
                                                              Implementation
                                                                    |
                                                                    v
                                                              Validation (spec vs. code)
```

This maps to GitHub Spec Kit's `/specify` -> `/plan` -> `/tasks` -> implement workflow, and to Kiro's Requirements -> Design -> Tasks pipeline. The interrogation system owns the `/specify` phase.

---

## Part 9: Research from Adjacent Fields

### Cognitive Load Theory Applied to Developer Interviews

John Sweller's Cognitive Load Theory (CLT) identifies three types of cognitive load:

1. **Intrinsic load**: The inherent complexity of the topic itself
2. **Extraneous load**: Unnecessary complexity introduced by how information is presented
3. **Germane load**: The productive effort of building understanding

For AI feature interrogation, this means:
- **Minimize extraneous load**: One question at a time, structured options, clear language
- **Manage intrinsic load**: Break complex features into smaller question groups
- **Maximize germane load**: Questions that help the user think through their own requirements

Research on technical interviews (Behroozi, NSF) found that developers experience significantly higher stress and cognitive load in whiteboard-style interactions. Providing "an initial skeleton that contains a partial solution" reduced cognitive burden. The equivalent for feature interrogation: pre-populate specifications with codebase-derived defaults, asking the user to confirm or modify rather than generate from scratch.

Source: [Behroozi et al., NSF](https://par.nsf.gov/servlets/purl/10196170)

### UX Research: The Contextual Inquiry Model

The contextual inquiry method uses a "master-apprentice" model where the researcher learns by observing the expert in context. For AI feature interrogation, this inverts: the AI is the "apprentice" learning from the user (the "master") about what the feature should do.

Key principles from NN/g:
- **Observe before asking**: Analyze the codebase (the "context") before asking questions
- **Ask in context**: Reference specific code, components, or patterns when asking
- **Active vs. passive**: Sometimes it is better to observe (analyze code) and leave questions until after
- **Document artifacts**: Note the tools, files, and patterns users reference

Source: [NN/g Contextual Inquiry](https://www.nngroup.com/articles/contextual-inquiry/)

### Knowledge Elicitation from Expert Systems

The knowledge acquisition bottleneck -- the difficulty of extracting expert knowledge into a formal system -- is the original version of the problem AI feature interrogation faces. Key lessons from decades of expert systems research:

1. **Experts cannot fully articulate their knowledge**: Much expertise is tacit. In software development, experienced developers "know" patterns and constraints they cannot easily verbalize. The AI must probe for this tacit knowledge through scenario-based questions ("What would you do if...?") rather than direct questions ("What are the constraints?").

2. **Structured expansion reveals more than direct questioning**: Wood's four-phase approach found that starting with descriptive questions (entities and concepts) and then expanding into relationships yielded more knowledge than jumping directly to decision rules.

3. **Teachback catches errors**: Having the knowledge engineer explain back what they understood, and letting the expert correct misunderstandings, is one of the most effective validation techniques.

4. **Multiple elicitation methods outperform any single method**: Combining interviews with observation, scenarios, and prototyping captures more complete knowledge than any technique alone.

Source: [Shadbolt & Smart, Knowledge Elicitation](https://www.semanticscholar.org/paper/505753e9af30a73212f1775decd8d3c7ff665c99)

### The LLMREI Study: LLMs as Automated Interviewers

The most directly relevant academic research is the LLMREI study (Korn, Gorsch, Vogelsang, 2025), which evaluated LLM-based automated requirements elicitation interviews.

**Key findings**:

- LLMs make "a similar number of errors compared to human interviewers" across five mistake categories
- LLMs elicited up to 73.7% of all requirements (60.94% fully, 12.76% partially)
- The short prompt (zero-shot) generated more context-enhancing questions (15.3% vs 10.4%), while the long prompt generated more structured, template-based inquiries
- LLMs excelled at communication skills and struggled most with question omission
- The LLM occasionally hallucinated information (e.g., estimating project costs without basis) and made privacy violations (requesting email addresses)

**Question type distribution** from the study:

| Type | Description | Short Prompt | Long Prompt |
|------|-------------|-------------|------------|
| Context-independent | Generic questions applicable to any project | 27.3% | 28.3% |
| Parametrized | Template questions adapted to the project | 12.8% | 28.9% |
| Context-deepening | Follow-up questions going deeper on a topic | 44.4% | 32.3% |
| Context-enhancing | Questions introducing new, related topics | 15.3% | 10.4% |

The optimal balance is roughly: 25-30% context-independent, 25-30% parametrized, 30-35% context-deepening, and 10-15% context-enhancing.

An additional educational study (UC Berkeley, 2025) involving 120 students found that interactive LLM-backed interview sessions for requirements elicitation produced comparable outcomes to working from pre-existing interview transcripts, suggesting that LLM-led interrogation is a viable replacement for human-led sessions in structured contexts.

Source: [LLMREI, IEEE RE 2025](https://arxiv.org/html/2507.02564), [Berkeley RE Education Study](https://www2.eecs.berkeley.edu/Pubs/TechRpts/2025/EECS-2025-52.pdf)

---

## Part 10: Decision Tree for Feature Interrogation

### Complexity Classification

Before beginning interrogation, classify the feature:

```
FEATURE REQUEST RECEIVED
        |
        v
[Is it a single, well-defined operation?]
    |                    |
   YES                  NO
    |                    |
    v                    v
SIMPLE              [Does it cross service/module boundaries?]
(3-4 questions)         |                    |
Bronze tier            YES                  NO
                        |                    |
                        v                    v
                    COMPLEX              MEDIUM
                    (7-10 questions)     (5-7 questions)
                    Gold tier            Silver tier
```

### Question Selection Decision Tree

```
FOR EACH POTENTIAL QUESTION:
        |
        v
[Can this be answered from codebase analysis?]
    |                    |
   YES                  NO
    |                    |
    v                    v
DON'T ASK          [Is this a Tier 1 requirement?]
(Use codebase          |                    |
 answer)              YES                  NO
                       |                    |
                       v                    v
                   MUST ASK           [Is this feature Gold tier?]
                                          |                    |
                                         YES                  NO
                                          |                    |
                                          v                    v
                                      ASK               [Has user shown engagement?]
                                                              |                    |
                                                             YES                  NO
                                                              |                    |
                                                              v                    v
                                                          ASK WITH           USE DEFAULT
                                                          DEFAULT            (state assumption)
```

### Complete Question Template Library

**Phase 1: Context (Always Ask)**

```
Q1-GOAL: "What problem does [FEATURE] solve for users?"
  - Open-ended, no options
  - Required for all tiers
  - Maps to: slots.goal

Q1-SCOPE: "What's the simplest version that would be valuable?"
  - Open-ended
  - Required for all tiers
  - Maps to: slots.scope
  - Anti-pattern: Do NOT ask "What's the full scope?" -- this anchors to large implementations
```

**Phase 2: Behavior (Ask based on codebase gaps)**

```
Q2-INPUT: "What data does the user provide?"
  Options:
    A) Free text input
    B) Selection from existing options
    C) File or media upload
    D) No user input (triggered automatically)
    E) Other (describe)
  - Ask only if codebase doesn't reveal input pattern
  - Maps to: slots.input_spec

Q2-ACTION: "When [TRIGGER], what should happen?"
  Options:
    A) Display results immediately on the same page
    B) Navigate to a new page/view
    C) Process in background, notify when done
    D) Update existing data in place
    E) Other (describe)
  - Always ask -- this is the core requirement
  - Maps to: slots.happy_path

Q2-OUTPUT: "What should the user see when it succeeds?"
  Options:
    A) Updated data displayed inline
    B) Success message/toast notification
    C) Redirect to new content
    D) Download/export
    E) Other (describe)
  - Ask only if not implied by Q2-ACTION
  - Maps to: slots.output_spec
```

**Phase 3: Edge Cases (Ask for Silver/Gold)**

```
Q3-FAILURE: "What if [FEATURE] fails? (e.g., network error, invalid data, permission denied)"
  Options:
    A) Show error message with retry option
    B) Fallback to cached/default data
    C) Graceful degradation (show partial results)
    D) Roll back and notify user
    E) Other (describe)
  - Required for Silver and Gold tiers
  - Maps to: slots.error_handling

Q3-BOUNDARY: "Are there limits on this feature?"
  Options:
    A) No limits needed
    B) Rate limiting (max N per time period)
    C) Size limits (max items, characters, file size)
    D) Time limits (timeout after N seconds)
    E) Access limits (specific user roles only)
  - Ask for Silver tier if feature involves data processing
  - Required for Gold tier
  - Maps to: slots.constraints

Q3-CONFLICT: "What if [concurrent scenario]? (e.g., two users editing the same item)"
  - Ask only for Gold tier or when concurrency is likely
  - Maps to: slots.constraints
```

**Phase 4: Verification (Always)**

```
Q4-SUMMARY: "Here's what I understand:

  **Goal**: [goal]
  **User provides**: [input_spec]
  **System does**: [happy_path summary]
  **User sees**: [output_spec]
  **On failure**: [error_handling]
  **Constraints**: [constraints]
  **Follows pattern**: [codebase_pattern detected]
  **Assumptions**: [list of assumptions made]

  Is this correct? Edit any part, or confirm to proceed."
  - Always present
  - Must include assumptions explicitly
  - User can edit inline
```

### Adaptive Questioning by Feature Type

| Feature Type | Skip These Questions | Emphasize These Questions |
|-------------|---------------------|--------------------------|
| New CRUD endpoint | UI questions, UX flow | Data model, validation rules, authorization |
| UI component | Backend architecture | Visual behavior, states, responsiveness, accessibility |
| Integration/API | UI details | Authentication, rate limits, error codes, data mapping |
| Search/filter | Backend details | Ranking criteria, facets, performance under load |
| Auth/permissions | Happy path details | Role hierarchy, edge cases, session management, audit |
| Data migration | User-facing behavior | Rollback strategy, data integrity, downtime tolerance |
| Performance fix | Feature behavior | Metrics, baselines, acceptable thresholds |

---

## Part 11: Limitations and Open Questions

### Limitations of This Research

1. **Limited empirical data on AI-specific interrogation**: The LLMREI study is the only rigorous empirical evaluation of LLMs conducting requirements interviews. Most other evidence comes from practitioner experience, tool documentation, and adapted research from adjacent fields.

2. **Vendor-reported metrics require skepticism**: Claims of "30% fewer engineers, half the delivery time" (Tweag) and "75% reduction in integration cycle time" (SDD paper case study) come from parties with incentives to promote these approaches. These should be treated as directional, not definitive.

3. **Optimal question count is feature-dependent**: The "5-7 questions" heuristic is a reasonable default but has not been rigorously validated across feature types. Complex, multi-service features likely require more; simple CRUD features likely require fewer.

4. **Context window limitations**: Large enterprise codebases may exceed the context capacity of current AI systems, meaning the AI cannot fully analyze the codebase before asking questions. Claude Code handles up to 200,000 tokens of context, but a 400,000-file monorepo still overwhelms even this capacity.

5. **Tacit knowledge remains hard to extract**: Some requirements are discovered only through prototyping or implementation. No questioning technique, however sophisticated, can fully replace the learning that comes from building.

6. **Novel domains challenge AI interrogation**: LLMs struggle in "genuinely novel or highly specialized domains where insufficient training data exists" (LLMREI). For cutting-edge features without precedent, AI interrogation will be less effective.

7. **The SDD movement is very new**: Most spec-driven development tools (Kiro, Spec Kit) launched in 2024-2025. Long-term empirical validation of their effectiveness is not yet available. The arxiv SDD paper (January 2026) is a practitioner guide, not a controlled experiment.

### Open Questions

1. **Can AI learn interrogation effectiveness from feedback?** If users report that a feature was under-specified, can the system learn to ask better questions for similar features?

2. **How should multi-stakeholder interrogation work?** When a feature has different users with different needs, how should the AI synthesize conflicting requirements?

3. **What is the right balance between codebase inference and user questioning?** Too much inference leads to assumptions; too much questioning leads to fatigue. The optimal balance likely varies by project maturity and user expertise.

4. **Should interrogation depth adapt to user expertise?** A senior developer may need fewer questions than a product manager for the same feature. How should the AI detect and adapt to expertise level?

5. **How should specifications evolve during implementation?** The initial specification is rarely final. What mechanisms should support specification updates as implementation reveals new questions?

6. **Is spec-as-source viable beyond niche domains?** The SDD paper's most ambitious level -- where specifications are the only human-edited artifact -- currently works only in mature domains like automotive control systems. Will AI improve enough to make this broadly viable?

7. **How should the interrogation handle the "I'd rather review code than all these markdown files" objection?** Martin Fowler notes this tension in his SDD tools review. Some developers find specification artifacts more burdensome than the code they prevent.

---

## Sources

### Grade A -- Primary/Authoritative
- [LLMREI: Automating Requirements Elicitation Interviews with LLMs](https://arxiv.org/html/2507.02564) -- Korn, Gorsch, Vogelsang, 2025 IEEE RE Conference
- [SDD: Spec-Driven Development: From Code to Contract](https://arxiv.org/html/2602.00180v1) -- Batarseh et al., arxiv:2602.00180, January 2026
- [NN/g Funnel Technique](https://www.nngroup.com/articles/the-funnel-technique-in-qualitative-user-research/) -- Authoritative UX research methodology
- [Agile Alliance INVEST](https://agilealliance.org/glossary/invest/) -- Industry standard user story criteria
- [Wood, 1993: Structuring Interviews for Knowledge Elicitation](https://onlinelibrary.wiley.com/doi/10.1002/int.4550080106) -- Foundational knowledge elicitation research
- [Cognitive Biases in Requirements Elicitation, Zalewski et al. 2020](https://link.springer.com/chapter/10.1007/978-3-030-26574-8_9) -- Springer, peer-reviewed research
- [Pacheco & Garcia, 2018: Requirements Elicitation Techniques SLR](https://ietresearch.onlinelibrary.wiley.com/doi/10.1049/iet-sen.2017.0144) -- Systematic literature review
- [UC Berkeley RE Education Study, 2025](https://www2.eecs.berkeley.edu/Pubs/TechRpts/2025/EECS-2025-52.pdf) -- LLM-backed interview sessions study

### Grade B -- High-Quality Supporting
- [Martin Fowler: Understanding SDD Tools (Kiro, spec-kit, Tessl)](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html) -- Comprehensive SDD tools analysis
- [GitHub Blog: Spec-Driven Development with Spec Kit](https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/) -- Official GitHub announcement
- [GitHub Spec Kit Repository](https://github.com/github/spec-kit) -- Official toolkit
- [Sourcegraph: Lessons from Building AI Coding Assistants](https://sourcegraph.com/blog/lessons-from-building-ai-coding-assistants-context-retrieval-and-evaluation) -- Context retrieval architecture
- [Addy Osmani: My LLM Coding Workflow](https://addyosmani.com/blog/ai-coding-workflow/) -- Practitioner workflow from Google engineer
- [Addy Osmani: How to Write a Good Spec for AI Agents](https://addyosmani.com/blog/good-spec/) -- Specification best practices
- [Dan Does Code: Efficient Vibe Coding with Clarifying Questions](https://www.dandoescode.com/blog/efficient-vibe-coding-with-clarifying-questions) -- The "Golden Prompt" pattern
- [Microsoft CLU Multi-Turn Conversations](https://learn.microsoft.com/en-us/azure/ai-services/language-service/conversational-language-understanding/concepts/multi-turn-conversations) -- Slot filling patterns
- [Augment Code: AI Assistants for Large Codebases](https://www.augmentcode.com/tools/ai-coding-assistants-for-large-codebases-a-complete-guide) -- Context engine architecture
- [QE Unit: Definition of Ready](https://qeunit.com/blog/the-definition-of-ready-in-quality-engineering/) -- Tiered readiness levels
- [Shadbolt & Smart: Knowledge Elicitation Methods](https://www.semanticscholar.org/paper/505753e9af30a73212f1775decd8d3c7ff665c99) -- KE techniques overview
- [AltexSoft: Acceptance Criteria Best Practices](https://www.altexsoft.com/blog/acceptance-criteria-purposes-formats-and-best-practices/) -- Given-When-Then patterns
- [Aider Documentation](https://aider.chat/docs/) -- Multi-mode conversation design
- [Hanway 2021: Cognitive Load in Interviews](https://bpspsychub.onlinelibrary.wiley.com/doi/pdf/10.1111/lcrp.12182) -- Cognitive load research
- [Ambiguity and Tacit Knowledge in RE Interviews](https://dl.acm.org/doi/10.1007/s00766-016-0249-3) -- Ambiguity as resource
- [ACM Survey on Multi-Turn Dialogue Systems](https://dl.acm.org/doi/full/10.1145/3771090) -- State-of-the-art dialogue systems
- [Behroozi et al.: Stress in Technical Interviews](https://par.nsf.gov/servlets/purl/10196170) -- Cognitive load in developer interviews
- [Cursor Plan Mode](https://cursor.com/blog/plan-mode) -- Official tool documentation
- [Tweag Agentic Coding Handbook: Spec-First Approach](https://tweag.github.io/agentic-coding-handbook/WORKFLOW_SPEC_FIRST_APPROACH/) -- SDD workflow guide
- [Beyond the Vibes: A Rigorous Guide to AI Coding](https://blog.tedivm.com/guides/2026/03/beyond-the-vibes-coding-assistants-and-agents/) -- Anti-vibe-coding guide
- [MIT Missing Semester: Agentic Coding](https://missing.csail.mit.edu/2026/agentic-coding/) -- MIT 2026 curriculum

### Grade C -- Supplementary/Practitioner
- [Claude Code Requirements Builder](https://github.com/rizethereum/claude-code-requirements-builder) -- Community tool for Claude Code
- [University of Michigan: Six Types of Socratic Questions](https://websites.umich.edu/~elements/probsolv/strategy/cthinking.htm) -- R.W. Paul's framework
- [Requiment: Common Requirements Gathering Mistakes](https://www.requiment.com/common-requirements-gathering-and-management-mistakes-and-how-to-avoid-them/) -- Failure modes and statistics
- [Aqua Cloud: Requirements Management Mistakes](https://aqua-cloud.io/common-requirements-management-mistakes/) -- 78% project failure statistic
- [Requiment: Requirements Gathering Checklist](https://www.requiment.com/requirements-gathering-template-checklist/) -- 14-category framework
- [Perforce: Non-Functional Requirements Examples](https://www.perforce.com/blog/alm/what-are-non-functional-requirements-examples) -- NFR taxonomy
- [NN/g Progressive Disclosure](https://www.nngroup.com/articles/progressive-disclosure/) -- Design pattern
- [NN/g Contextual Inquiry](https://www.nngroup.com/articles/contextual-inquiry/) -- UX research method
- [GitHub Copilot Workspace](https://githubnext.com/projects/copilot-workspace) -- Sunset May 2025
- [Copilot Workspace User Manual](https://github.com/githubnext/copilot-workspace-user-manual/blob/main/overview.md) -- Detailed workflow
- [Bridging the Gap: Elicitation Questions](https://www.bridging-the-gap.com/what-questions-do-i-ask-during-requirements-elicitation/) -- Practical question list
- [Google Cloud: Five Best Practices for AI Coding Assistants](https://cloud.google.com/blog/topics/developers-practitioners/five-best-practices-for-using-ai-coding-assistants) -- Enterprise best practices
- [Anchoring Bias in Elicitation, Taylor & Francis](https://www.tandfonline.com/doi/full/10.1080/12460125.2020.1840705) -- Anchoring effect research
- [Confirmation Bias in GenAI Chatbots](https://www.arxiv.org/pdf/2504.09343) -- AI bias research
- [cc-sdd: Kiro-style SDD for Claude Code](https://github.com/gotalab/cc-sdd) -- SDD implementation for Claude Code
