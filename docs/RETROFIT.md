# Retrofitting an Existing Project

Onboard a project that already has code, history, and tribal knowledge into the spec-driven harness. The goal is to catalogue what exists so future features benefit from recall — without rewriting history.

## Pair with the slash command

`/harness.catalogue` walks Claude Code through this whole process interactively. Run it from the target repo's root and let the orchestrator drive. This document is the design behind that command — read it if you want to understand what the command is doing, or if you want to do it by hand.

## The 5-pass plan

### Pass 1 — Opt in (5 minutes)

```text
cd <existing-repo>
/harness.init                              # creates .harness/, docs/memory/, specs/, CLAUDE.md
git checkout -b chore/harness-opt-in       # optional safety branch
```

Verify:
- `.harness/marker` exists.
- `docs/memory/{decisions,runbooks}/.gitkeep` exist.
- `specs/.gitkeep` exists.
- `CLAUDE.md` either pre-existed (left alone) or got seeded.

### Pass 2 — Repo constitution (15 minutes, opus)

Make `CLAUDE.md` a faithful constitution. Walk the repo briefly and capture:

- **What this repo is** — one paragraph, user-facing.
- **Stack** — language, runtime version, package manager, test runner, deploy target.
- **Conventions** — where tests live (alongside or in `tests/`), naming, lint config, commit-message style.
- **Constraints** — anything an outsider would trip over: weird build steps, vendored deps, env vars that must be set, secrets management.
- **Out of scope for the harness** — files/dirs you don't want auto-ingested into Cognee. (The default ingestion only watches `docs/memory/**`, `specs/**`, and `CLAUDE.md`, so this is rarely needed.)

Keep it under 300 lines. Past that, it loses influence after Claude's context compaction.

### Pass 3 — Mine prior decisions (30–60 minutes, opus)

Walk these sources and translate non-obvious *decisions* into `docs/memory/decisions/*.md`:

| Source | What to extract |
|---|---|
| `git log` over the last 6–12 months | Commits whose messages contain "why", "decided", "switched from", "instead of", or that introduce a new dependency, framework, or pattern. |
| Existing `README.md`, `CONTRIBUTING.md`, `docs/**` | Non-trivial decisions that aren't already in code: rate-limit policies, retry strategies, why-X-and-not-Y. |
| Issue tracker (Linear, Jira, GitHub Issues) | Closed-with-decision tickets. Skip "fixed typo" stuff. |
| Slack/email/PR-review threads, if accessible | Architectural debates that didn't make it into a doc. |
| `# TODO`/`# HACK`/`# XXX` comments | Each is a deferred decision with rationale worth capturing. |

For each finding, write one file:

```markdown
---
title: <one-line summary>
date: <YYYY-MM-DD when the decision was made (best guess is fine)>
source: <commit SHA / ticket ID / PR URL>
---

## Context
<What was the situation? What problem did we have?>

## Decision
<What did we choose?>

## Why
<Short rationale. Include alternatives considered and why they lost.>

## Implications
<Optional: what this constrains going forward.>
```

Quality > volume. 10 well-written decision records beat 50 vague ones. The Cognee graph extraction is only as good as the source material.

### Pass 4 — Glossary + runbooks (20 minutes, sonnet)

`docs/memory/glossary.md` — domain terms, internal acronyms, product names that an outsider wouldn't know. One line per term.

`docs/memory/runbooks/*.md` — operational recipes you've used more than twice: "how to roll a release", "how to recover from <known failure>", "how to add a new <thing>". One file per recipe.

These are the highest-leverage ingestion targets because they get repeatedly queried during recall.

### Pass 5 — First "real" feature via the harness (60+ minutes, opus → sonnet)

Pick the next feature you'd ship anyway. Drive it through the full loop:

```text
/speckit.specify "<the feature>"
/speckit.clarify           # if anything is ambiguous
/speckit.plan
/speckit.tasks             # mark _Boundary:_ on every task
/spec.implement <feature>
```

This is when you find out what's actually broken in your `CLAUDE.md` or your decisions corpus — the spec-conformance-evaluator will ask the spec questions the implementer can't answer, and that surfaces gaps.

After landing the feature: commit `specs/<feature>/` alongside the implementation. The spec is documentation forever, not a one-shot artifact.

## What NOT to retrofit

Skip these for v1; revisit only if you need them:

- **Every file in the repo** as a Cognee dataset — overkill. Ingest only the curated `docs/memory/` corpus.
- **Old test plans, dead-tree design docs** — if the decision is still live, capture it fresh in `docs/memory/decisions/`. If it's dead, leave it dead.
- **Granular per-commit history** — git already has it. Cognee is for *why*, not *what*.
- **The codebase itself** — Claude Code reads source on demand via `Read`/`Grep`. No need to ingest into the graph.

## Verifying the retrofit

After Pass 3 + 4:

```text
mcp__cognee__search {
  search_query: "what are the core constraints of this project?",
  search_type: "GRAPH_COMPLETION",
  datasets: "<basename of pwd repo>"
}
```

The answer should match what you'd expect a new team member to learn in their first week. If it doesn't, your decisions corpus is too thin — add more decision records before relying on recall for `/spec.implement`.

## Time budget

A realistic first retrofit is about half a day for a mid-sized repo:

- 5 min: opt in.
- 30 min: constitution.
- 60–90 min: mine 10–20 decisions.
- 20 min: glossary + 2–3 runbooks.
- One real feature's worth of time: first harness-driven feature, to validate.

Subsequent features are cheap because the recall scaffolding is in place.
