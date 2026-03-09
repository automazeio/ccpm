# Scope Research - Fill Discovery Gaps

Scan discovery for UNKNOWN items and research answers with targeted web searches.

## Usage
```
/pm:scope-research <scope-name>
```

## Arguments
- `scope-name` (required): Name of the scope session

## Instructions

You are filling knowledge gaps from discovery with focused research.

### Find Unknowns

```bash
SESSION_DIR=".claude/scopes/$ARGUMENTS"
DISCOVERY="$SESSION_DIR/discovery.md"

echo "Scanning for unknowns in: $ARGUMENTS"
```

Read `discovery.md` and all section files in `sections/`. Find all items marked as:
- `UNKNOWN`
- `TBD`
- `Need to research`
- `Not sure`
- Questions without clear answers

### Categorize Each Gap

For each unknown, categorize it:

| Category | Pattern | Search Strategy |
|----------|---------|-----------------|
| `tech-decision` | "What X should we use?" | Compare top 3 options |
| `compliance` | "What are X requirements?" | Find official checklist |
| `market` | "What do competitors do?" | Scan 3-5 competitors |
| `pattern` | "How should we structure X?" | Find best practice |
| `cost` | "How much does X cost?" | Find pricing tiers |

### Research Each Gap

For EACH unknown, do ONE focused web search:

**Tech Decision Example:**
```
Search: "best authentication provider B2B SaaS SSO 2025 comparison"
Extract: Top 3 options with pros/cons/pricing
```

**Compliance Example:**
```
Search: "SOC2 Type 2 requirements checklist 2025"
Extract: Key requirements list
```

**Market Example:**
```
Search: "{competitor name} pricing features 2025"
Extract: Pricing tiers, key features
```

### Output Format

Write to `.claude/scopes/{scope-name}/research.md`:

```markdown
# Research: {scope-name}

researched: {current datetime}
gaps_found: {count}
gaps_resolved: {count}

---

## Gap 1: {Original question}

**Category:** tech-decision
**From Section:** technical_environment

### Research Summary

{2-3 sentence summary of findings}

### Options Compared

| Option | Pros | Cons | Cost | Verdict |
|--------|------|------|------|---------|
| {Option 1} | {pros} | {cons} | {cost} | ✓ Recommended |
| {Option 2} | {pros} | {cons} | {cost} | |
| {Option 3} | {pros} | {cons} | {cost} | |

### Recommendation

**Use {Option}** because {1-sentence rationale}.

### Sources
- [{Source title}]({url})
- [{Source title}]({url})

---

## Gap 2: {Original question}

**Category:** compliance
**From Section:** project_scope

### Research Summary

{2-3 sentence summary}

### Requirements

- [ ] {Requirement 1}
- [ ] {Requirement 2}
- [ ] {Requirement 3}

### Sources
- [{Source title}]({url})

---

## Gap 3: {Original question}

**Category:** pattern
**From Section:** technical_environment

### Research Summary

{2-3 sentence summary}

### Best Practice

{Concise description of recommended approach}

```code-example-if-relevant
```

### Sources
- [{Source title}]({url})

---

## Unresolved Gaps

{List any gaps that couldn't be resolved with web search - need human decision or deeper research}

| Gap | Reason | Suggested Action |
|-----|--------|------------------|
| {question} | {why unresolved} | {next step} |

---

## Summary

- **Gaps Found:** {count}
- **Resolved:** {count}
- **Unresolved:** {count}
- **Key Decisions:**
  - {decision 1}
  - {decision 2}
```

### Update Discovery

After research is complete, update `discovery.md`:
1. Replace UNKNOWN answers with research findings
2. Add note: `(Researched: see research.md)`
3. Keep original section files unchanged

### Research Guidelines

1. **One search per gap** - Don't go down rabbit holes
2. **2025/2026 sources preferred** - Recent info only
3. **Cite sources** - Always include URLs
4. **Make a recommendation** - Don't just list options
5. **Stay focused** - 5 minutes per gap max
6. **Flag if stuck** - Move to unresolved, suggest next step

### Output

After completing research:

```
Research complete for: {scope-name}

Gaps: {found} found, {resolved} resolved, {unresolved} unresolved

Key Decisions:
- {decision 1}
- {decision 2}

Saved to: .claude/scopes/{scope-name}/research.md

Next step:
  .claude/scripts/prd-scope.sh {scope-name} --decompose
```
