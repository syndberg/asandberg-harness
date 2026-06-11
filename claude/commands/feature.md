---
description: Bootstrap a spec + eval scaffold for a new feature, or show the integrated workflow cheat sheet
argument-hint: [start <name> | status | help]
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

# /feature — Spec + Eval integrated workflow

You are managing the integrated spec-driven + eval-driven development workflow. The harness provides:

- `specs/<name>/{spec,plan,tasks}.md` (consumed by `/spec.implement`)
- `.claude/evals/<name>.md` (consumed by `/eval define|check|report`)

This command wraps them so they're created together and stay in sync via convention.

## Parse `$ARGUMENTS`

The argument is one of:
- empty, or `help` — print the cheat sheet (see below) and stop
- `start <name>` (or just `<name>` if it's a valid identifier) — bootstrap a new feature
- `status` — list features in the current repo with their spec + eval state

Feature names must be lowercase letters, digits, dashes only. Reject anything else with a clear error.

## Mode: cheat sheet (no args or `help`)

Print exactly this block to the user, then stop. Do not run any tools.

```
/feature — Spec + Eval integrated workflow
==========================================

The full flow:
  1.  /harness.init                  (once per repo)
  2.  /feature start <name>          Bootstrap spec + eval scaffold
  3.  /spec.draft <name> "<intent>"  Draft spec + plan from intent (add --compare for A/B)
  4.  Edit specs/<name>/spec.md      Refine acceptance criteria
  5.  Edit specs/<name>/plan.md      Refine implementation approach
  6.  Edit specs/<name>/tasks.md     TDD task breakdown
  7.  /spec.implement <name>         TDD loop + conformance check
  8.  /eval check <name>             Eval suite must pass
  9.  /spec.reconcile <name>         Spec catches up to reality
  10. Open PR

Retrofitting an existing repo with history:
  /harness.init then /harness.catalogue
  Five-pass mining of git history + docs + TODOs + decisions.
  See docs/RETROFIT.md in the harness repo.

Quick commands:
  /feature                          This cheat sheet
  /feature start <name>             Bootstrap new feature
  /feature status                   List features and their state
  /spec.draft <name> "<intent>"     Draft spec+plan from intent (--compare for A/B)

Files created by /feature start:
  specs/<name>/spec.md              Requirements + acceptance criteria
  specs/<name>/plan.md              Architecture + sequencing
  specs/<name>/tasks.md             TDD task list
  .claude/evals/<name>.md           Eval suite (capability + regression)
  FEATURES.md                       Feature index at repo root

Templates: ~/.claude/templates/feature/

Coupling: loose. Acceptance criteria in spec.md and capability evals in
eval.md are intentionally separate files. Keep them in sync by hand —
the slash command seeds eval.md with a reference to the spec but doesn't
auto-sync on edits.
```

## Mode: `start <name>`

1. **Pre-flight checks.** All in parallel where possible.
   - Verify `git rev-parse --show-toplevel` succeeds. Capture the repo root.
   - Check `.harness/marker` exists at repo root. If not, warn the user that the repo doesn't appear bootstrapped and offer to run `/harness.init` first. If they decline, continue anyway (the directories will still get created; the harness just won't auto-engage).
   - Validate `<name>` matches `^[a-z0-9][a-z0-9-]*$`. Reject otherwise.
   - Check `specs/<name>/` does NOT already exist. If it does, abort with the message "feature already exists; use /feature status to see its state."

2. **Create the four files** from templates at `~/.claude/templates/feature/`:
   - `~/.claude/templates/feature/spec.md` → `specs/<name>/spec.md`
   - `~/.claude/templates/feature/plan.md` → `specs/<name>/plan.md`
   - `~/.claude/templates/feature/tasks.md` → `specs/<name>/tasks.md`
   - `~/.claude/templates/feature/eval.md`  → `.claude/evals/<name>.md`

   For each template, substitute the literal token `{{NAME}}` with the feature name. Use sed or do it via Read+Write. Do not overwrite existing files.

3. **Update or create `FEATURES.md` at the repo root.** If it doesn't exist, create it with this header:

   ```
   # Features

   | Feature | Spec | Tasks | Evals | Status |
   |---------|------|-------|-------|--------|
   ```

   Then append a row for the new feature:

   ```
   | <name> | [spec](specs/<name>/spec.md) | [tasks](specs/<name>/tasks.md) | [evals](.claude/evals/<name>.md) | draft |
   ```

   Idempotent: if the row already exists, leave it alone.

4. **Print next steps to the user:**

   ```
   ✓ Feature scaffold created: <name>

   Next steps:
     1. /spec.draft <name> "<one-line intent>"  (drafts spec.md + plan.md from intent;
        add --compare to test Fable vs Opus) — or fill specs/<name>/spec.md by hand
     2. Refine acceptance criteria in specs/<name>/spec.md (the most important part)
     3. Fill in specs/<name>/tasks.md (TDD task breakdown)
     4. Mirror acceptance criteria into .claude/evals/<name>.md capability section
     5. /spec.implement <name>
   ```

## Mode: `status`

1. Find the repo root via git.
2. List all directories under `specs/`. For each, check:
   - Does `specs/<name>/spec.md` exist?
   - Does `specs/<name>/tasks.md` exist?
   - Does `.claude/evals/<name>.md` exist?
   - Is there an `## Implementation Notes` section in spec.md with non-comment content (signal that `/spec.reconcile` has run)?
3. Print a markdown table:

   ```
   | Feature | Spec | Tasks | Evals | Reconciled |
   |---------|------|-------|-------|------------|
   | <name>  | ✓    | ✓     | ✓     | ✗          |
   ```

   Plus a one-line summary: "N features total; M with all artifacts; K reconciled."

## Style

- Be terse. The user reads these messages frequently.
- Don't lecture about the workflow inside `start` — that's what `/feature help` is for.
- On any error, print the error clearly and stop. Don't try to recover.
