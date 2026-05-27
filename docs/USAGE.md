# Day-to-day usage

## Once per repo

```text
cd <your repo>
/harness.init
```

Creates `.harness/marker` (the opt-in flag), `docs/memory/{decisions,runbooks}/`, `specs/`, and seeds `CLAUDE.md` if missing. The hooks engage from this point forward in this repo only.

For existing repos with prior context worth keeping, follow up with:

```text
/harness.catalogue
```

A 1–2 hour orchestrated session that mines git history, existing docs, and TODO comments into `docs/memory/decisions/`. See [RETROFIT.md](RETROFIT.md) for the full breakdown.

## Per feature

```text
/feature start <name>
```

Scaffolds:
- `specs/<name>/spec.md` — acceptance criteria
- `specs/<name>/plan.md` — implementation approach
- `specs/<name>/tasks.md` — TDD task breakdown
- `.claude/evals/<name>.md` — eval suite mirroring the spec
- `FEATURES.md` — top-level index row

Fill in the `spec.md` first — that's the contract `/spec.implement` will grade against.

Then drive the feature through:

```text
/spec.implement <name>
```

The orchestrator loops: for each task in `tasks.md`, dispatch a `spec-implementer` (TDD), then `test-runner`, then `spec-conformance-evaluator`. Up to 3 attempts per task. After all tasks land, `code-reviewer` and `security-reviewer` run over the full diff.

When done, reconcile:

```text
/spec.reconcile <name>
```

Diffs the implementation against the spec and appends an `## Implementation Notes` section if anything landed differently. Keeps the spec faithful to what's in the code.

## Querying memory directly

The `recall-context` skill runs automatically before orchestrator dispatches. If you want to query manually inside a session:

```text
mcp__cognee__search {
  search_query: "what did we decide about <topic>?",
  search_type: "GRAPH_COMPLETION",
  datasets: ["<basename of pwd>"]
}
```

`query_type` options:
- `GRAPH_COMPLETION` — synthesized natural-language answer (best for "what did we decide…").
- `CHUNKS` — raw matching text fragments (best for verbatim lookup).
- `RAG_COMPLETION` — RAG without the graph step (cheaper, less coherent).

## Sequencing decisions

| Situation | What to do |
|---|---|
| New repo, fresh idea | `git init` → `/harness.init` → `/feature start <name>` → fill spec → `/spec.implement <name>` |
| Existing repo, never used the harness | `/harness.init` → `/harness.catalogue` → first real feature via `/feature start` |
| Tiny fix or one-off script | Skip the harness. Don't `/harness.init`. Hooks stay dormant. |
| Multi-feature collision worry | Mark `_Boundary:_` lines in `tasks.md`; the boundary-check hook warns when another feature's impl touches them. |
| Spec drifted from impl during a long branch | `/spec.reconcile <feature>` before opening the PR. |

## Anti-patterns

- **Ingesting source code into the Cognee graph.** Don't. Claude Code already reads source on demand. The graph is for `docs/memory/**` (decisions, runbooks, glossary) and `specs/**` (acceptance criteria, plans).
- **Calling `recall-context` from inside a leaf executor** (e.g., the `spec-implementer`). The orchestrator pre-loads recall and passes context down. Recall floods are real and expensive.
- **Editing `spec.md` mid-implementation.** Resist. If the spec is wrong, halt the implement loop, edit the spec, then resume — don't let the implementer rewrite acceptance criteria to match its output.
- **Skipping `/spec.reconcile`.** Specs that lie are worse than no specs. If you took shortcuts during impl, reconcile captures them before the spec becomes deceptive.

## Verifying things still work

```bash
bash scripts/verify.sh
```

Runs the full check matrix: toolchain present, env file shape, grafted files, hooks wired, MCP registered. Useful after a `git pull` of the harness repo or after upgrading Claude Code.
