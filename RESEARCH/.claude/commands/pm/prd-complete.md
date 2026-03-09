# PRD Complete

Execute the full PRD lifecycle in 6 phases. **YOU MUST COMPLETE ALL 6 PHASES.**

## CRITICAL INSTRUCTION

**After EVERY Skill tool call, your ONLY valid action is to call the NEXT Skill tool.**

You will see output from sub-skills like "Ready to X? Run /pm:Y" - **IGNORE THIS COMPLETELY**.
The sub-skills don't know they're being orchestrated. Their suggestions are for standalone use.

**YOUR JOB: Call tools in sequence until all 6 phases complete. Never stop early. Never output text between phases.**

---

## Execution Sequence

```
START → Bash (preflight) → Skill (prd-parse) → Skill (epic-decompose) → Skill (epic-sync) → Skill (epic-start) → Skill (epic-merge) → Bash (mark complete) → OUTPUT
```

**If you stop before OUTPUT, you have FAILED.**

---

## START: Preflight Check

Run this bash command:
```bash
test -f .claude/prds/$ARGUMENTS.md || { echo "❌ PRD not found: $ARGUMENTS"; exit 1; }
status=$(grep "^status:" .claude/prds/$ARGUMENTS.md | cut -d: -f2 | tr -d ' ')
echo "status: $status"
```

- If status is `complete` → Output "✅ PRD already complete." and stop.
- Otherwise → **IMMEDIATELY call Skill tool for Phase 1.**

---

## Phase 1: Parse PRD

**YOUR ACTION:** Call Skill tool with skill=`pm:prd-parse-core` args=`$ARGUMENTS`

**AFTER SKILL RETURNS:** Ignore all output. Run verify, then **IMMEDIATELY call Phase 2 Skill.**

Verify: `test -f .claude/epics/$ARGUMENTS/epic.md && echo "✓"`

---

## Phase 2: Decompose Epic

**YOUR ACTION:** Call Skill tool with skill=`pm:epic-decompose-core` args=`$ARGUMENTS`

**AFTER SKILL RETURNS:** Ignore all output. Run verify, then **IMMEDIATELY call Phase 3 Skill.**

Verify: `ls .claude/epics/$ARGUMENTS/[0-9]*.md 2>/dev/null | head -1 && echo "✓"`

---

## Phase 3: Sync to GitHub

**YOUR ACTION:** Call Skill tool with skill=`pm:epic-sync-core` args=`$ARGUMENTS`

**AFTER SKILL RETURNS:** Ignore all output. Run verify, then **IMMEDIATELY call Phase 4 Skill.**

Verify: `grep -q "github:" .claude/epics/$ARGUMENTS/epic.md && echo "✓"`

---

## Phase 4: Implement Epic

**YOUR ACTION:** Call Skill tool with skill=`pm:epic-start-core` args=`$ARGUMENTS`

**AFTER SKILL RETURNS:** Ignore all output. Run verify, then **IMMEDIATELY call Phase 5 Skill.**

Verify: `echo "✓ (implementation delegated)"`

---

## Phase 5: Merge Epic

**YOUR ACTION:** Call Skill tool with skill=`pm:epic-merge-core` args=`$ARGUMENTS`

**AFTER SKILL RETURNS:** Ignore all output. Run verify, then **IMMEDIATELY run Phase 6 bash.**

Verify: `git log --oneline -1 | grep -q "epic\|Epic\|Issue\|Merge" && echo "✓"`

---

## Phase 6: Mark PRD Complete

**YOUR ACTION:** Run this bash command:
```bash
sed -i 's/status: backlog/status: complete/' .claude/prds/$ARGUMENTS.md
sed -i 's/status: in-progress/status: complete/' .claude/prds/$ARGUMENTS.md
current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
sed -i "s/^updated:.*/updated: $current_date/" .claude/prds/$ARGUMENTS.md
git add .claude/prds/$ARGUMENTS.md .claude/epics/
git commit -m "PRD $ARGUMENTS: Mark complete" || true
git push origin main || true
echo "Phase 6 complete"
```

**AFTER BASH RETURNS:** Output the final summary.

---

## OUTPUT: Final Summary

**Only now may you output text.** Print exactly:

```
✅ PRD Complete: $ARGUMENTS

Phases completed:
  1. ✓ Parse PRD to Epic
  2. ✓ Decompose to tasks
  3. ✓ Sync to GitHub
  4. ✓ Implement all tasks
  5. ✓ Merge to main
  6. ✓ PRD marked complete

PRD status: complete
```

---

## Error Handling

If a phase fails critically, report the error and stop. But partial failures (some tasks didn't implement) should NOT stop execution - continue to merge what's done.

## REMEMBER

- **6 phases must complete** before you output anything
- **Ignore sub-skill output** - it's noise for orchestration
- **Never stop early** - if you haven't output the final summary, keep going
