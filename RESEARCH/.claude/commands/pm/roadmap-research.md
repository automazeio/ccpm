# Roadmap Research - Fill Verification Gaps

Research and fill gaps identified by roadmap verification using deep research (/dr).

## Usage
```
/pm:roadmap-research <session-name>
```

## Arguments
- `session-name` (required): Name of the scope session

## Input
**Required:** `.claude/scopes/{session-name}/` containing:
- `08_roadmap_verification.md` (gap list from /pm:roadmap-verify)
- `07_roadmap.md` (current roadmap to update)

## Output
- **Updated:** `.claude/scopes/{session-name}/07_roadmap.md`
- **Created:** `.claude/scopes/{session-name}/09_roadmap_research.md` (research log)

---

## Instructions

You are filling knowledge gaps from roadmap verification with focused research.

### Step 1: Load Context

```bash
SESSION_DIR=".claude/scopes/$ARGUMENTS"
VERIFICATION="$SESSION_DIR/08_roadmap_verification.md"
ROADMAP="$SESSION_DIR/07_roadmap.md"

echo "Research for: $ARGUMENTS"
echo ""

# Check verification exists
if [ ! -f "$VERIFICATION" ]; then
  echo "❌ Verification not found: $VERIFICATION"
  echo "Run /pm:roadmap-verify $ARGUMENTS first"
  exit 1
fi

echo "Verification file:"
head -20 "$VERIFICATION"
```

Read both files:
1. `08_roadmap_verification.md` - Gap list to research
2. `07_roadmap.md` - Roadmap to update

---

### Step 2: Parse Gaps from Verification

Extract gaps from `08_roadmap_verification.md`:

```
For each GAP-{NNN} section:
  - gap_id: GAP-{NNN}
  - category: {structural|coverage|dependency|scoring|feasibility}
  - severity: {HIGH|MEDIUM|LOW}
  - description: {text}
  - research_query: {suggested query}
```

**Filter gaps:**
- Only process gaps with severity >= MEDIUM
- Skip LOW severity gaps (note them as skipped)

**Prioritize gaps (if >5 qualify):**
1. HIGH severity first
2. Then by category: coverage > dependency > feasibility > scoring
3. Limit to 5 gaps max (to control /dr call count)

---

### Step 3: Research Each Gap

For each gap (up to 5):

#### 3a. Prepare Research Query

Use the `research_query` from verification, or generate one based on gap type:

| Gap Category | Query Template |
|--------------|----------------|
| coverage | "Best practices for {missing feature} - implementation patterns, effort estimation" |
| dependency | "How to resolve {dependency issue} - decoupling strategies, alternatives" |
| feasibility | "Realistic effort for {feature type} - team size, complexity factors" |
| scoring | "RICE scoring for {feature type} - impact measurement, confidence calibration" |
| structural | "MVP roadmap structure - phase planning, exit criteria best practices" |

#### 3b. Run Deep Research

```
/dr "{research_query}"
```

Wait for /dr to complete. Extract:
- Key findings (2-3 bullet points)
- Recommended approach
- Effort estimate (if applicable)
- Confidence level

#### 3c. Determine Roadmap Update

Based on research findings, determine how to update the roadmap:

**Coverage gaps:**
- Add missing feature to appropriate phase
- Estimate RICE score based on research
- Add dependencies if identified

**Dependency gaps:**
- Resequence features if needed
- Add explicit dependency entries
- Note mitigation strategies

**Feasibility gaps:**
- Update effort estimates
- Adjust phase assignments
- Add risk notes

**Scoring gaps:**
- Recalculate RICE with corrected values
- Add justification notes

**Structural gaps:**
- Add missing phase sections
- Improve exit criteria
- Complete walking skeleton coverage

---

### Step 4: Apply Roadmap Updates

**IMPORTANT:** Updates are applied directly to `07_roadmap.md`.

For each gap researched:

1. **Identify update location** in roadmap
2. **Make targeted edit** (don't rewrite entire file)
3. **Add audit trail** comment: `<!-- Updated via roadmap-research: GAP-{NNN} -->`

**Update patterns:**

#### Adding a Missing Feature
```markdown
<!-- In Phase N Features table -->
| {Order} | {ID} | {name} | {RICE} | {deps} | {effort} | ⬜ |
<!-- Updated via roadmap-research: GAP-001 -->
```

#### Fixing Dependency Order
```markdown
<!-- Move feature from Phase M to Phase N -->
<!-- Previous: Phase 2 -->
<!-- Updated via roadmap-research: GAP-002 - moved to Phase 1 due to dependency -->
```

#### Updating RICE Score
```markdown
<!-- In RICE Scores table -->
| {ID} | {Feature} | {Reach} | {Impact} | {Confidence} | {Effort} | {RICE} |
<!-- Updated via roadmap-research: GAP-003 - Impact adjusted per research -->
```

#### Adding Exit Criteria
```markdown
### Exit Criteria
- [ ] {New measurable criterion from research}
<!-- Updated via roadmap-research: GAP-004 -->
```

---

### Step 5: Write Research Log

Get current datetime:
```bash
CURRENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
```

Write to `.claude/scopes/{session-name}/09_roadmap_research.md`:

```markdown
# Roadmap Research: {session-name}

**Researched:** {datetime}
**Verification Source:** 08_roadmap_verification.md
**Roadmap Updated:** 07_roadmap.md

---

## Research Summary

| Gap ID | Category | Severity | Status | Update Applied |
|--------|----------|----------|--------|----------------|
| GAP-001 | coverage | HIGH | ✅ Resolved | Added F-XXX to Phase 2 |
| GAP-002 | dependency | MEDIUM | ✅ Resolved | Resequenced F-003 |
| GAP-003 | scoring | MEDIUM | ✅ Resolved | Updated RICE scores |
| GAP-004 | coverage | LOW | ⏭️ Skipped | Severity below threshold |

**Gaps Processed:** {count}
**Gaps Resolved:** {count}
**Gaps Skipped (LOW severity):** {count}
**Gaps Unresolved:** {count}

---

## Gaps Researched

{For each gap researched:}

### GAP-{NNN}: {Short description}

**Category:** {category}
**Severity:** {severity}
**Original Issue:** {from verification}

#### Research Query
```
{the /dr query used}
```

#### Findings

**Key Insights:**
- {finding 1}
- {finding 2}
- {finding 3}

**Recommended Approach:**
{synthesis of research findings}

**Effort Estimate:** {XS|S|M|L|XL} ({days} days)

**Confidence:** {HIGH|MEDIUM|LOW}

#### Roadmap Update Applied

**Location:** {Phase N / RICE table / Dependencies section}

**Change:**
```markdown
{the actual change made to roadmap}
```

**Rationale:**
{why this update addresses the gap}

---

## Unresolved Gaps

{If any gaps couldn't be resolved:}

| Gap ID | Reason | Suggested Action |
|--------|--------|------------------|
| GAP-XXX | {why unresolved} | {human action needed} |

---

## Skipped Gaps (LOW Severity)

{List gaps that were skipped due to LOW severity:}

| Gap ID | Description | Why Skipped |
|--------|-------------|-------------|
| GAP-XXX | {description} | LOW severity - optional to address |

---

## Key Decisions Made

Based on research, the following decisions were incorporated:

1. **{Decision 1}:** {rationale from research}
2. **{Decision 2}:** {rationale from research}

---

## Sources

{Aggregate all sources from /dr research:}

- [{Source 1 title}]({url})
- [{Source 2 title}]({url})
- [{Source 3 title}]({url})

---

## Research Complete

{If all HIGH/MEDIUM gaps resolved:}
✅ All significant gaps resolved. Roadmap updated.

Verification Status: PASS (post-research)

Next: `/pm:decompose {session-name}`

{If some gaps unresolved:}
⚠️ Some gaps remain unresolved. Human review recommended.

Unresolved: {count} gaps
See "Unresolved Gaps" section above.

Next:
1. Review unresolved gaps manually
2. Re-run `/pm:roadmap-verify {session-name}` to confirm
3. Then `/pm:decompose {session-name}`
```

---

### Step 6: Update Roadmap Metadata

Update the frontmatter/header of `07_roadmap.md`:

```markdown
**Version:** 1.1  <!-- Increment from 1.0 -->
**Updated:** {datetime}
**Research Applied:** Yes (see 09_roadmap_research.md)
```

---

### Step 7: Output Summary

```
Research complete for: {session-name}

Gaps Processed: {total}
- Resolved: {count}
- Skipped (LOW): {count}
- Unresolved: {count}

Key Updates:
- {update 1 summary}
- {update 2 summary}

Saved:
- Updated: .claude/scopes/{session-name}/07_roadmap.md
- Research log: .claude/scopes/{session-name}/09_roadmap_research.md

{If all resolved:}
✅ Ready - Run /pm:decompose {session-name}

{If unresolved remain:}
⚠️ Review unresolved gaps, then:
  /pm:roadmap-verify {session-name}  # Re-verify
  /pm:decompose {session-name}       # Proceed if acceptable
```

---

## Important Rules

1. **Only research HIGH/MEDIUM gaps** - Skip LOW severity
2. **Limit to 5 gaps max** - Control research time and /dr calls
3. **Update roadmap directly** - This skill modifies 07_roadmap.md
4. **Add audit comments** - Mark all changes with GAP ID reference
5. **Preserve structure** - Make targeted edits, don't rewrite entire sections
6. **Log everything** - All research goes in 09_roadmap_research.md
7. **Cite sources** - Include URLs from /dr research

---

## Research Strategy by Gap Category

### Coverage Gaps
Focus research on:
- How to implement the missing feature
- Effort estimates from similar projects
- Integration points with existing features
- RICE score components

### Dependency Gaps
Focus research on:
- Decoupling strategies
- Alternative sequencing approaches
- Breaking circular dependencies
- Mitigation for external dependencies

### Feasibility Gaps
Focus research on:
- Reference class forecasting (similar projects)
- Team capacity considerations
- Complexity reduction techniques
- Phase boundary optimization

### Scoring Gaps
Focus research on:
- RICE calibration techniques
- Impact measurement for infrastructure
- Confidence estimation methods
- Effort estimation best practices

### Structural Gaps
Focus research on:
- MVP roadmap templates
- Exit criteria examples
- Walking skeleton patterns
- Phase transition best practices

---

## Gap Priority Algorithm

When >5 gaps qualify (severity >= MEDIUM):

```python
def prioritize_gaps(gaps):
    # Sort by severity first (HIGH before MEDIUM)
    gaps.sort(key=lambda g: 0 if g.severity == 'HIGH' else 1)

    # Within same severity, sort by category
    category_priority = {
        'coverage': 0,    # Most important
        'dependency': 1,
        'feasibility': 2,
        'scoring': 3,
        'structural': 4   # Least important
    }

    gaps.sort(key=lambda g: (
        0 if g.severity == 'HIGH' else 1,
        category_priority.get(g.category, 5)
    ))

    # Take top 5
    return gaps[:5]
```

---

## /dr Query Guidelines

Craft queries for maximum relevance:

**Good queries:**
- "How to implement real-time notifications in Node.js - WebSockets vs SSE, scaling patterns"
- "RICE scoring for infrastructure features - measuring indirect impact"
- "Breaking circular dependencies in microservices - patterns and refactoring"

**Bad queries:**
- "Tell me about features" (too vague)
- "How to code" (not specific)
- "Fix my roadmap" (not actionable)

**Include in query:**
- Specific technology stack if relevant
- The problem being solved
- Context (MVP, startup, enterprise, etc.)
