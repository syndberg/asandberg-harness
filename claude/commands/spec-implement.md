---
description: Execute a Spec Kit feature end-to-end. Reads specs/<feature>/tasks.md, dispatches spec-implementer → test-runner → spec-conformance-evaluator for each task with 3-strike escalation, then code-reviewer + security-reviewer over the full diff, then /spec.reconcile. Args - "<feature-name>".
---

# /spec.implement

You are the orchestrator. The user passed a feature name. You drive the loop from `specs/<feature>/tasks.md` to a green review.

## Preconditions

1. The current repo has `.harness/marker`. If not, refuse and tell the user to run `/harness.init` first.
2. `specs/<feature>/{spec.md,plan.md,tasks.md}` all exist. If any are missing, name which and stop — the user needs to run the missing `/speckit.*` step.

## Hard rules

1. **Depth = 1.** You may dispatch `spec-implementer`, `test-runner`, `spec-conformance-evaluator`, `code-reviewer`, `security-reviewer`. None of those may spawn further subagents. The depth-cap hook enforces this; you set `CLAUDE_HARNESS_ALLOW_NESTED=1` only for your own Agent calls (it is set automatically when this command runs).
2. **One task at a time.** Respect `_Depends:_` ordering. Never run two tasks in parallel — too easy for the evaluator to grade the wrong diff.
3. **Marker hygiene.** Before each Agent dispatch, `touch ~/.claude/state/in-subagent`; after the Agent returns, `rm -f ~/.claude/state/in-subagent`. This is what teaches the depth-cap hook that nested calls are forbidden.
4. **3-strike escalation.** If a task fails three eval attempts in a row, stop the whole loop and surface all three attempts' diffs and feedback to the user. Do not silently move on.
5. **No spec edits during impl.** Only `/spec.reconcile` (the last step) writes to `spec.md`.

## Loop

```
load specs/<feature>/{spec,plan,tasks,constitution if present}.md
parse tasks.md into tasks[] honoring _Depends:_

for task in tasks (Depends-respecting order):
    attempt = 0
    while attempt < 3:
        touch ~/.claude/state/in-subagent
        impl_report = dispatch spec-implementer(task_id, feature_dir)
        rm -f  ~/.claude/state/in-subagent

        if impl_report.STATUS == "blocked":
            escalate to user; abort loop

        touch ~/.claude/state/in-subagent
        test_report = dispatch test-runner(touched packages from impl_report.DIFF)
        rm -f  ~/.claude/state/in-subagent

        if test_report.STATUS != "PASS":
            attempt++; feedback = test_report.FAILING_TESTS; continue

        touch ~/.claude/state/in-subagent
        eval_report = dispatch spec-conformance-evaluator(task_id, feature_dir, diff)
        rm -f  ~/.claude/state/in-subagent

        if eval_report.VERDICT == "PASS":
            mark task done in your own internal log; break

        attempt++; feedback = eval_report.FEEDBACK; continue

    if attempt == 3:
        emit a full report (all 3 diffs + reasons) and STOP. Do not continue with downstream tasks.

# After all tasks land:
touch ~/.claude/state/in-subagent
review_security = dispatch security-reviewer (full diff vs main)
review_quality  = dispatch code-reviewer    (full diff vs main)
rm -f  ~/.claude/state/in-subagent

if either reviewer FAIL: loop back into the implementer for the affected files (treat as a new mini-task), max 2 more attempts. If still failing, escalate to user.

# Final step:
invoke /spec.reconcile <feature>
```

## Final report

```
FEATURE: <name>
TASKS: <n done> / <n total>
ATTEMPTS PER TASK: <task_id: attempts used>
REVIEWERS: security=<PASS|FAIL>  quality=<PASS|FAIL>
RECONCILED: <yes|no>  ← /spec.reconcile result
NEXT: <suggested commit message; or "human review needed: ...">
```
