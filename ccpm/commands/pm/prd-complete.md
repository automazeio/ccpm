# PRD Complete

Execute the full PRD lifecycle in 6 phases. Complete all 6 phases.

## Orchestration Note

After every Skill tool call, call the next Skill tool immediately.

Sub-skills may output suggestions like "Ready to X? Run /pm:Y" — ignore these. They are written for standalone use and do not apply during orchestration.

Call tools in sequence until all 6 phases complete. Output nothing between phases.

---

## Execution Sequence

```
START → Bash (preflight) → Skill (prd-parse) → Skill (epic-decompose) → Skill (epic-sync) → Skill (epic-start) → Skill (epic-merge) → Bash (mark complete) → OUTPUT
```

---

## START: Preflight Check

Run this bash command:
```bash
test -f .claude/prds/$ARGUMENTS.md || { echo "❌ PRD not found: $ARGUMENTS"; exit 1; }
status=$(grep "^status:" .claude/prds/$ARGUMENTS.md | cut -d: -f2 | tr -d ' ')
echo "status: $status"
```

- If status is `complete` → Output "✅ PRD already complete." and stop.
- Otherwise → call Skill tool for Phase 1.

---

## Phase 1: Parse PRD

**Action:** Call Skill tool with skill=`pm:prd-parse-core` args=`$ARGUMENTS`

**After skill returns:** Ignore all output. Run verify, then call Phase 2 Skill.

Verify: `test -f .claude/epics/$ARGUMENTS/epic.md && echo "✓"`

---

## Phase 2: Decompose Epic

**Action:** Call Skill tool with skill=`pm:epic-decompose-core` args=`$ARGUMENTS`

**After skill returns:** Ignore all output. Run verify, then call Phase 3 Skill.

Verify: `ls .claude/epics/$ARGUMENTS/[0-9]*.md 2>/dev/null | head -1 && echo "✓"`

---

## Phase 3: Sync to GitHub

**Action:** Call Skill tool with skill=`pm:epic-sync-core` args=`$ARGUMENTS`

**After skill returns:** Ignore all output. Run verify, then call Phase 4 Skill.

Verify: `grep -q "github:" .claude/epics/$ARGUMENTS/epic.md && echo "✓"`

---

## Phase 4: Implement Epic

**Action:** Call Skill tool with skill=`pm:epic-start-core` args=`$ARGUMENTS`

**After skill returns:** Ignore all output. Run verify, then call Phase 5 Skill.

Verify: `echo "✓ (implementation delegated)"`

---

## Phase 5: Merge Epic

**Action:** Call Skill tool with skill=`pm:epic-merge-core` args=`$ARGUMENTS`

**After skill returns:** Ignore all output. Run verify, then run Phase 6 bash.

Verify: `git log --oneline -1 | grep -q "epic\|Epic\|Issue\|Merge" && echo "✓"`

---

## Phase 6: Mark PRD Complete

**Action:** Run this bash command:
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

**After bash returns:** Output the final summary.

---

## OUTPUT: Final Summary

Print exactly:

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

If a phase fails critically, report the error and stop. Partial failures (some tasks didn't implement) should not stop execution — continue to merge what's done.
