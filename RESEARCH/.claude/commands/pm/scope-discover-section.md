# Scope Discover Section - Single Section Discovery

Conduct discovery Q&A for a single section. This is called by the shell script for each of the 12 sections.

## Usage
```
/pm:scope-discover-section <scope-name> <section-name>
```

## Arguments
- `scope-name` (required): Name of the scope session
- `section-name` (required): One of the 12 sections (see below)

## Valid Sections

1. `company_background` - Company name, description, industry, size
2. `stakeholders` - Executive sponsor, product owner, decision makers
3. `timeline_budget` - Launch date, milestones, budget, rollout strategy
4. `problem_definition` - Problem statement, current solutions, pain points
5. `business_goals` - Primary goal, success metrics, strategic alignment
6. `project_scope` - Project type, in/out of scope, MVP, constraints
7. `technical_environment` - Tech stack, integrations, security, performance
8. `users_audience` - Technical proficiency, user count, accessibility
9. `user_types` - Role definitions, data scope, hierarchy
10. `competitive_landscape` - Competitors, advantages, market positioning
11. `risks_assumptions` - Assumptions, known risks, failure scenarios
12. `data_reporting` - Reports needed, data migration, retention

## Instructions

You are conducting discovery for ONE section of a product requirements questionnaire.

### Parse Arguments

```bash
# Arguments format: "scope-name section-name"
SCOPE_NAME=$(echo "$ARGUMENTS" | cut -d' ' -f1)
SECTION_NAME=$(echo "$ARGUMENTS" | cut -d' ' -f2)
SESSION_DIR=".claude/scopes/$SCOPE_NAME"
SECTION_FILE="$SESSION_DIR/sections/${SECTION_NAME}.md"

echo "Scope: $SCOPE_NAME"
echo "Section: $SECTION_NAME"
```

### Initialize Session

```bash
mkdir -p "$SESSION_DIR/sections"
```

### Section Questions

Based on the section name, ask these specific questions:

---

#### company_background
```
1. What is the company name?
   - Required: Yes
   - Help: Official legal name or primary brand name

2. Describe the company and its mission in 2-3 sentences.
   - Required: Yes
   - Help: What does the company do? What is its purpose?

3. What industry does the company operate in?
   - Required: Yes
   - Help: Primary industry vertical (e.g., Healthcare, Fintech, E-commerce)

4. What is the company size?
   - Required: Yes
   - Options: 1-10 (Startup), 11-50 (Small), 51-200 (Medium), 201-1000 (Large), 1000+ (Enterprise)

5. When was the company founded?
   - Required: No

6. What existing products or services does the company offer?
   - Required: No
   - Help: Current product portfolio relevant to this project
```

---

#### stakeholders
```
1. Who is the executive sponsor for this project?
   - Required: Yes
   - Help: Name and title of the executive accountable for success

2. Who is the product owner? (i.e. the project lead)
   - Required: Yes
   - Help: Person responsible for defining and prioritizing requirements

3. Who are the key stakeholders?
   - Required: Yes
   - Help: List names, roles, and departments of key stakeholders

4. Which stakeholders are the final decision-makers for requirements?
   - Required: Yes
   - Help: Who can approve or reject proposed features?

5. Who are the subject matter experts (SMEs)?
   - Required: No
   - Help: Domain experts to consult for requirements

6. What are the preferred communication methods?
   - Required: No
   - Options: Email, Slack/Teams, Scheduled meetings, Async video, Documentation, JIRA/Linear comments
```

---

#### timeline_budget
```
1. What is the target launch date?
   - Required: Yes
   - Help: Desired date for initial release or MVP

2. How flexible is the launch date?
   - Required: Yes
   - Options: Fixed (cannot move), Somewhat flexible (+/- 2 weeks), Flexible (+/- 1 month), Very flexible (scope-driven)

3. What are the key milestones?
   - Required: No
   - Help: Important dates between now and launch

4. What is the budget range for this project?
   - Required: No
   - Options: Under $50K, $50K-$100K, $100K-$250K, $250K-$500K, $500K-$1M, Over $1M, Not disclosed

5. What resource constraints exist?
   - Required: No
   - Help: Limited team size, specific skill gaps, etc.

6. What external dependencies exist?
   - Required: No
   - Help: Other projects, vendor timelines, regulatory approvals

7. What is the deployment/rollout strategy?
   - Required: Yes
   - Options: Big bang, Phased rollout, Pilot first, Beta program, Canary deployment, Not yet determined

8. What training will users need?
   - Required: No

9. What is the rollback plan if deployment fails?
   - Required: No
```

---

#### problem_definition
```
1. What problem are we trying to solve?
   - Required: Yes
   - Help: Describe the core problem in 2-3 sentences

2. How did this problem come to attention?
   - Required: Yes
   - Help: User feedback, market research, internal observation?

3. How is this problem currently being addressed?
   - Required: Yes
   - Help: Existing workarounds, manual processes, competitor solutions

4. What are the user pain points with current solutions?
   - Required: Yes
   - Help: What frustrations, inefficiencies, or gaps do users experience?

5. What is the impact of not solving this problem?
   - Required: Yes
   - Help: Business cost, user frustration, missed opportunities

6. How will we know when the problem is solved?
   - Required: Yes
   - Help: Observable outcomes that indicate success
```

---

#### business_goals
```
1. What is the primary business goal for this project?
   - Required: Yes
   - Help: The main business objective this project serves

2. What are secondary business goals?
   - Required: No
   - Help: Additional objectives the project should achieve

3. What business metrics will measure success?
   - Required: Yes
   - Help: Specific, measurable KPIs (e.g., 20% reduction in churn)

4. How does this project align with company strategy?
   - Required: Yes
   - Help: Connection to broader strategic initiatives

5. What is the expected revenue impact?
   - Required: Yes
   - Options: Direct revenue, Cost reduction, Customer retention, Market expansion, Operational efficiency, Regulatory compliance, Not directly revenue-related
```

---

#### project_scope
```
1. What type of project is this?
   - Required: Yes
   - Options: New product, Feature addition, Product redesign, Integration project, Migration project, Proof of concept

2. What is explicitly IN scope for this project?
   - Required: Yes
   - Help: Features, capabilities, and deliverables included

3. What is explicitly OUT of scope?
   - Required: Yes
   - Help: What will NOT be included in this phase

4. What is the Minimum Viable Product (MVP)?
   - Required: Yes
   - Help: Smallest set of features that delivers value

5. What features are planned for future phases?
   - Required: No
   - Help: Features deferred to later releases

6. What constraints must the solution work within?
   - Required: Yes
   - Help: Technical, regulatory, or business constraints
```

---

#### technical_environment
```
1. What is the current technology stack?
   - Required: Yes
   - Help: Languages, frameworks, databases, cloud providers

2. What systems must this solution integrate with?
   - Required: Yes
   - Help: APIs, databases, third-party services

3. Where will the solution be deployed?
   - Required: Yes
   - Options: Public cloud (AWS/GCP/Azure), Private cloud, On-premises, Hybrid, Edge/IoT, Not yet determined

4. What security requirements must be met?
   - Required: Yes
   - Options (multi-select): SOC 2, HIPAA, GDPR, PCI-DSS, SSO/SAML, Encryption at rest, Encryption in transit, Audit logging, RBAC, MFA

5. What are the performance requirements?
   - Required: No
   - Help: Response time (e.g., <200ms), throughput, concurrent users

6. What are the scalability expectations?
   - Required: No
   - Help: Expected user growth, data volume, geographic distribution

7. What uptime SLA is required?
   - Required: Yes
   - Options: 99%, 99.9%, 99.95%, 99.99%, 99.999%, Not yet determined

8. What are the disaster recovery requirements?
   - Required: No
   - Help: Define RPO and RTO

9. What logging, monitoring, and alerting is required?
   - Required: No
   - Options: APM, Error tracking, Audit logging, Real-time dashboards, On-call alerting, Log aggregation, User activity tracking

10. Are there third-party licensing or IP constraints?
    - Required: No
```

---

#### users_audience
```
1. What is the technical proficiency of typical users?
   - Required: Yes
   - Options: Non-technical, Basic, Intermediate, Advanced, Mixed

2. How many users are expected?
   - Required: Yes
   - Help: Estimated user count at launch and 1-year projection

3. What accessibility requirements must be met?
   - Required: Yes
   - Options: WCAG 2.1 AA, WCAG 2.1 AAA, Screen reader support, Keyboard navigation, Color contrast, Multi-language, RTL support, No specific requirements
```

---

#### user_types
```
1. Define each user type with their name, function, and access category.
   - Required: Yes
   - Help: Format: 'Name - Function - Category'. Categories: Viewer, Contributor, Reviewer, Approver, Admin

2. What is the data scope for each user type?
   - Required: Yes
   - Help: Scope options: Own, Team, Department, All

3. Is there a hierarchy between user types?
   - Required: No
   - Help: Do some roles inherit from others?

4. Which user types require approval from other types?
   - Required: No
   - Help: Approval workflow definitions
```

---

#### competitive_landscape
```
1. Who are the direct competitors?
   - Required: Yes
   - Help: Products/companies solving the same problem

2. Who are the indirect competitors?
   - Required: No
   - Help: Products that could substitute for this solution

3. What are our competitive advantages?
   - Required: Yes
   - Help: Why would users choose this solution over alternatives?

4. What features do competitors offer that we should match?
   - Required: No
   - Help: Table stakes features from the market

5. What gaps exist in competitor solutions?
   - Required: No
   - Help: Opportunities to differentiate

6. How do we want to position this solution in the market?
   - Required: Yes
   - Options: Premium/Enterprise, Mid-market, Budget-friendly, Niche specialist, Platform/Ecosystem, Disruptor
```

---

#### risks_assumptions
```
1. What assumptions is this project based on?
   - Required: Yes
   - Help: List assumptions about technology, users, market, timeline, resources

2. What are the known risks and mitigation strategies?
   - Required: Yes
   - Help: Format: 'Risk - Impact - Mitigation'

3. What could cause this project to fail?
   - Required: No
   - Help: Be honest about potential failure modes
```

---

#### data_reporting
```
1. What reports and dashboards will users need?
   - Required: Yes
   - Help: List key reports, dashboards, and analytics. Who needs them? How often?

2. What data needs to be migrated from existing systems?
   - Required: No
   - Help: Source systems, data volume, transformation needs

3. What data retention and archival policies apply?
   - Required: No
   - Help: How long must data be kept? Legal/compliance requirements?
```

---

### Interaction Flow

1. **Greet and explain**: Tell the user which section you're covering
2. **Ask questions one at a time**: Don't dump all questions at once
3. **Probe for clarity**: If answer is vague, ask follow-up
4. **Research unknowns**: If user says "I don't know", research and present options
5. **Iterate until satisfied**: Keep researching until user picks an answer or defers
6. **Skip optional questions**: If user says "skip" or "next", move on
7. **Extract key points**: Summarize each answer into bullet points

### Handling Unknown Answers - Research On The Fly

When user says "I don't know", "not sure", "research this", or similar:

**DO NOT just mark as UNKNOWN and move on.** Instead:

1. **Offer to research immediately:**
   ```
   "I can research that for you. Should I look up [specific topic]?"
   ```

2. **If user says yes, research immediately:**
   - Do a focused web search
   - Present 2-3 options with pros/cons
   - Ask user to pick one

3. **Present findings conversationally:**
   ```
   "I found three common approaches for [topic]:

   1. **Option A** - [1 sentence]. Best for [use case].
   2. **Option B** - [1 sentence]. Best for [use case].
   3. **Option C** - [1 sentence]. Best for [use case].

   Based on what you've told me about [context], I'd recommend Option B.
   Does that work, or should I dig deeper?"
   ```

4. **Iterate until satisfied:**
   - If user asks for more detail, research deeper
   - If user picks an option, record it as the answer
   - If user wants to defer, THEN mark as UNKNOWN

5. **Only mark UNKNOWN if user explicitly defers:**
   ```markdown
   ### {Question}
   **Answer:** UNKNOWN (user chose to defer)
   **Research Done:** Yes - presented 3 options, user wants to decide later
   **Options Presented:**
   - Option A: {summary}
   - Option B: {summary}
   - Option C: {summary}
   ```

### Research Categories

When researching, use these search patterns:

| Topic Type | Search Pattern | Present As |
|------------|---------------|------------|
| Tech choice | "{topic} vs alternatives 2025" | Comparison table |
| Best practice | "{topic} best practices 2025" | Recommendation |
| Compliance | "{requirement} requirements checklist" | Checklist |
| Pricing | "{tool/service} pricing 2025" | Cost breakdown |
| Integration | "{system A} {system B} integration" | How-to summary |

### Research Flow Example

```
User: "I don't know what auth provider to use"

You: "I can research that. Are you building B2B (enterprise SSO needed)
     or B2C (social logins, passwordless)?"

User: "B2B, we need SSO"

You: [Does web search: "B2B authentication provider SSO SAML 2025 comparison"]

You: "For B2B with SSO, the top options are:

     1. **Auth0** - Full-featured, native SAML, $23k+/year for enterprise
     2. **Okta** - Enterprise standard, complex setup, $$$
     3. **WorkOS** - Developer-focused, simple SSO integration, usage-based

     Given you mentioned budget constraints earlier, WorkOS might be
     the best fit. It's simpler and cheaper for early-stage.

     Want to go with WorkOS, or should I look into others?"

User: "WorkOS sounds good"

You: [Records: "Auth provider: WorkOS - selected for developer simplicity
     and cost-effectiveness for B2B SSO requirements"]
```

### Output Format (section file)

Write to `$SESSION_DIR/sections/${SECTION_NAME}.md`:

```markdown
# {Section Title}

Section: {section_name}
Scope: {scope_name}
Completed: {datetime}

---

### {Question 1}
**Answer:** {response}
**Key Points:**
- {point 1}
- {point 2}

### {Question 2}
**Answer:** {response}
**Key Points:**
- {point}

...

---

## Section Summary

**Questions Answered:** {count}/{total}
**Unknown Items:** {count}
**Key Decisions:**
- {decision 1}
- {decision 2}
```

### Completion

When all questions in this section are answered:

1. Write the section file
2. Output:

```
Section complete: {section_name}

Summary:
- Questions: {answered}/{total}
- Unknown: {count} items marked for research

Saved to: .claude/scopes/{scope-name}/sections/{section-name}.md

Next section: {next_section_name}
Or run: .claude/scripts/prd-scope.sh {scope-name} --discover
```

### Important Rules

1. **One section only** - Don't ask questions from other sections
2. **Research before marking unknown** - Always offer to research first
3. **Write immediately** - Save section file when complete
4. **Be conversational** - This is interactive, not an interrogation
5. **Extract key points** - Don't just record raw answers
6. **Use context** - Reference earlier answers when making recommendations
7. **One search per topic** - Don't over-research, present top 2-3 options
