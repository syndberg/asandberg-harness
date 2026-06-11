---
description: Draft specs/<feature>/{spec,plan}.md from a natural-language intent using the spec-drafter agent (default model Fable). With --compare, draft the same intent under Fable AND Opus, have a blind judge score both, and let you pick. Args - "<feature-name> [intent] [--compare]".
argument-hint: <name> "<intent>" [--compare]
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

# /spec.draft

You are the orchestrator. The user wants `spec.md` + `plan.md` drafted from a natural-language intent. The default path drafts once with Fable. The `--compare` path drafts the same intent under two models and runs a blind judge, so the user can test which model writes better specs. You stay the driver throughout; the drafter and judge are leaf agents.

## Parse `$ARGUMENTS`

- First token: `<feature-name>` (lowercase letters, digits, dashes). Reject otherwise.
- `--compare` anywhere: enables compare mode.
- Everything else (quoted or not, minus the flag): the `intent` text.
- If no intent is given, ask the user for one line describing the feature before dispatching. The intent is the single shared input — capture it once and pass it verbatim to every drafter.

## Preconditions

1. `.harness/marker` exists in the repo. If not, refuse and point to `/harness.init`.
2. `specs/<name>/spec.md` and `specs/<name>/plan.md` exist as scaffolds. If not, tell the user to run `/feature start <name>` first, then stop.
3. If `specs/<name>/spec.md` already holds authored (non-scaffold) content — i.e. the Acceptance criteria section is filled — STOP and confirm with the user before overwriting. Never clobber a real spec silently.

## Hard rules

1. **Depth = 1.** You may dispatch only `spec-drafter` and `spec-draft-judge`. Neither may spawn subagents; the depth-cap hook enforces it.
2. **Marker hygiene.** Before each dispatch, `touch ~/.claude/state/in-subagent`; after it returns, `rm -f ~/.claude/state/in-subagent`.
3. **Identical intent to every arm.** Both compare arms receive the exact same intent string. Any difference invalidates the comparison.
4. **The drafter generates; you write.** Take the returned spec.md/plan.md content and write the files yourself, so you control placement — and, in compare mode, the blind A/B mapping.
5. **Blind judge.** Never tell `spec-draft-judge` which model produced A or B. Keep the mapping in your own working notes only.
6. **The human picks.** In compare mode the judge is advisory. Present the scores plus the model mapping and let the user choose. Never auto-promote.

## Default flow (no --compare)

```
verify preconditions
intent = parsed or asked

touch ~/.claude/state/in-subagent
draft = dispatch spec-drafter(intent, specs/<name>/)        # uses default model: claude-fable-5
rm -f  ~/.claude/state/in-subagent

write draft."spec.md"  -> specs/<name>/spec.md
write draft."plan.md"  -> specs/<name>/plan.md
show ASSUMPTIONS + OPEN QUESTIONS FOR HUMAN to the user
```

## Compare flow (--compare)

```
verify preconditions
intent = parsed or asked

# Two arms, same intent, different models. Record the mapping privately.
touch ~/.claude/state/in-subagent
draft_fable = dispatch spec-drafter(intent, specs/<name>/) with model claude-fable-5
rm -f  ~/.claude/state/in-subagent

touch ~/.claude/state/in-subagent
draft_opus  = dispatch spec-drafter(intent, specs/<name>/) with model claude-opus-4-8
rm -f  ~/.claude/state/in-subagent

# Assign A/B and write candidates OUTSIDE the ingest watch-set.
# .harness/ is not ingested (ingest watches specs/**, docs/memory/**, CLAUDE.md),
# so rejected drafts never pollute Cognee. Keep your own note of which letter is
# which model; do NOT reveal it to the judge.
write draft_fable -> .harness/drafts/<name>/<A-or-B>/{spec,plan}.md
write draft_opus  -> .harness/drafts/<name>/<the-other>/{spec,plan}.md

touch ~/.claude/state/in-subagent
verdict = dispatch spec-draft-judge(intent, .harness/drafts/<name>/A, .harness/drafts/<name>/B)
rm -f  ~/.claude/state/in-subagent

present verdict table, then reveal which letter was Fable vs Opus
ask the user to pick A or B

# Promote the chosen pair into specs/ (THIS write is what triggers Cognee ingest).
write chosen spec.md -> specs/<name>/spec.md
write chosen plan.md -> specs/<name>/plan.md
leave .harness/drafts/<name>/ in place as the comparison record
```

## Final report

```
FEATURE: <name>
MODE: single | compare
INTENT: <one-line>
WRITTEN: specs/<name>/spec.md, specs/<name>/plan.md
COMPARE: <omit if single | "A=<model> B=<model>; totals A=x/40 B=y/40; chosen=<letter> (<model>)">
NEXT: confirm the criteria, mirror them into .claude/evals/<name>.md, then /spec.implement <name>
```

## Notes

- `tasks.md` is not drafted here — seed it from the plan via `/speckit.tasks` or by hand, then `/spec.implement <name>`.
- The drafter's model is the hypothesis knob: `claude-fable-5` by default (set in `claude/agents/spec-drafter.md`). Swap that one line, or the `--compare` override, to test other models.
- If a Claude Code version doesn't honor the per-dispatch model override for arm B, the comparison will run both arms on Fable. If that happens, add a thin `spec-drafter-opus` agent pinned to `model: opus` and dispatch it for arm B instead.
