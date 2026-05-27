# asandberg-harness

A spec-driven + eval-driven development harness for [Claude Code](https://docs.anthropic.com/claude-code), powered by [Cognee](https://github.com/topoteretes/cognee) for knowledge-graph-backed recall.

## What this gives you

- **Spec-driven flow**: `/harness.init`, `/feature start <name>`, `/spec.implement <name>`, `/spec.reconcile <name>` — features live as committed `specs/<name>/{spec,plan,tasks}.md` with conformance evaluation gating completion.
- **Eval-driven flow**: `.claude/evals/<name>.md` mirrors acceptance criteria; capability evals + regression checks gate "done."
- **KG+RAG memory**: every change to `docs/memory/**`, `specs/**`, and `CLAUDE.md` in opted-in repos is queued and ingested into a per-repo Cognee dataset. Queryable from any session via the `recall-context` skill.
- **Depth-capped subagents**: the orchestrator may dispatch one level of specialists; specialists return rather than spawning further subagents. Enforced by a hook.
- **Boundary checks**: edits inside another feature's `_Boundary:_` files surface a heads-up before regressions land.
- **Opt-in per repo**: hooks no-op in any repo without `.harness/marker`. Installing the harness does nothing to your existing projects until you `/harness.init` one.

## Install

You can either run `install.sh` yourself or hand the install to a coding agent — see [AGENTS.md](AGENTS.md) for the agent-runnable runbook.

```bash
git clone https://github.com/syndberg/asandberg-harness.git
cd asandberg-harness
bash install.sh
```

Prereqs: Linux or macOS, `git`, `curl`, `python3 ≥ 3.9`, Node.js ≥ 22, Claude Code installed, `ANTHROPIC_API_KEY` exported, and Ollama running on `:11434`. The installer fails fast with actionable errors if any are missing.

After install completes:

1. Restart Claude Code so the MCP server loads.
2. `bash scripts/verify.sh` to confirm everything wired up.
3. Smoke test from inside a Claude Code session:
   ```
   mcp__cognee__cognify { data: "smoke", dataset_name: "smoke" }
   mcp__cognee__search  { search_query: "what was stored?", search_type: "GRAPH_COMPLETION", datasets: "smoke" }
   ```

## Use

In any repo you want to opt in:

```text
cd <your repo>
/harness.init                # creates .harness/marker, docs/memory/, specs/
/harness.catalogue           # for existing repos — mines git history + docs into the KG
/feature start <name>        # scaffolds specs/<name>/{spec,plan,tasks}.md + evals
/spec.implement <name>       # TDD loop with conformance gate
/spec.reconcile <name>       # spec catches up to what landed
```

Full day-to-day reference: [docs/USAGE.md](docs/USAGE.md).
Retrofitting an existing project: [docs/RETROFIT.md](docs/RETROFIT.md).
Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
Troubleshooting: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## What it does NOT do

- **No telemetry, no analytics.** Everything runs on your machine; the only network call is to Anthropic for LLM completions (your own API key).
- **No mutation of your existing `~/.claude/` config.** The grafter only ever creates files; settings.json is merged additively with a backup before every write.
- **No engagement with non-opted-in repos.** Hooks check for `.harness/marker` and early-return when absent.
- **No automatic spec rewriting during impl.** Only `/spec.reconcile` (the last step) edits `spec.md`, and only by appending an `## Implementation Notes` section.

## Uninstall

```bash
bash scripts/uninstall.sh
```

Removes grafted files, strips the harness hook entries from `settings.json`, and deregisters the Cognee MCP. Leaves the external toolchain (`uv` tools, Ollama models, `~/.cognee/`) in place — those are useful beyond the harness.

## License

MIT — see [LICENSE](LICENSE).

## Status

Personal tooling, open-sourced. Issues and pull requests welcome; no SLAs.
