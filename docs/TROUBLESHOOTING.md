# Troubleshooting

## Install failures

| Symptom | Fix |
|---|---|
| `install.sh` says ANTHROPIC_API_KEY is not set | `export ANTHROPIC_API_KEY="sk-ant-…"` in your shell rc, `source` it, re-run. |
| `install.sh` halts after Phase 3 saying `~/.claude/settings.json` doesn't exist | Run `claude` once interactively so Claude Code creates its config files, then re-run `install.sh`. Phases 1-3 are no-ops on the re-run. |
| Phase 1 (`install-toolchain.sh`) fails on `uv tool install cognee` | Almost always a network/proxy issue against PyPI. Re-run the script — it's idempotent. If it persists, check `uv tool install cognee --with anthropic --with transformers --python 3.12 --force` manually and read the error. |
| Phase 4 (`merge-settings.py`) reports JSON parse error | Your `~/.claude/settings.json` was edited to invalid JSON. Restore the latest `.bak-<ts>` next to it. |
| Phase 5 (`register-mcp.py`) says cognee-shim.sh not found | Phase 3 failed silently. Re-run `bash scripts/graft-files.sh`. |

## Runtime failures

| Symptom | Fix |
|---|---|
| `mcp__cognee__*` tools not visible in a new session | You didn't restart Claude Code after Phase 5. Restart and look in `claude mcp list` — should show `cognee`. |
| `mcp__cognee__cognify` returns `LLMAPIKeyNotSetError` | `ANTHROPIC_API_KEY` is not in the shell env that launched Claude Code. Restart your terminal, then `claude`. |
| `cognify` succeeds but `search` returns "No data found" | LanceDB path mismatch — `SYSTEM_ROOT_DIRECTORY` was set differently between ingest and query. Run `mcp__cognee__prune`, verify `~/.cognee/.env` is correct, then re-cognify. |
| Ollama embedding returns empty vectors | Wrong endpoint. Confirm `~/.cognee/.env` has `EMBEDDING_ENDPOINT=http://localhost:11434/api/embed` (NOT `/api/embeddings` — that's a different endpoint that returns a different shape). |
| `cognee-cli cognify` from the shell fails with `ontology_file_path` in the error | Known Cognee 1.0.9 bug in the CLI's anthropic adapter. Use `mcp__cognee__cognify` (via MCP) instead — the harness's hooks already route through MCP. |
| `Could not set lock on file: cognee_graph_ladybug` | Two Cognee processes are writing at once. Stop the second one. The MCP server is the canonical writer; don't shell out to `cognee-cli` while the server runs. |
| `pydantic ValidationError: lightrag.llm.api_key Field required` | Stale `~/.knowledge-mcp/config.yaml` from a predecessor backend. Delete the file. (The current harness doesn't use knowledge-mcp.) |

## Hook misbehavior

| Symptom | Fix |
|---|---|
| `cap-subagent-depth` blocks a legitimate orchestrator dispatch | The marker file `~/.claude/state/in-subagent` got left behind by a crashed run. `rm ~/.claude/state/in-subagent` and retry. |
| `spec-boundary-check` warns on every edit | You're inside a repo whose `tasks.md` files have very broad `_Boundary:_` lines. Tighten the boundaries. The hook is a warning only, not a blocker. |
| `knowledge-ingest-queue` doesn't queue an edit | Either the file isn't `.md`, it isn't under `docs/memory/`, `specs/`, or named `CLAUDE.md`, or the repo lacks `.harness/marker`. All three are required. |

## /harness.init / /spec.implement issues

| Symptom | Fix |
|---|---|
| `/harness.init` says "not a git repo" | Run `git init` first. The harness needs a git root to find the repo boundary. |
| `/harness.init` says `specify` CLI is missing | Run `bash scripts/install-toolchain.sh` from the harness repo. |
| `/spec.implement` refuses with "no .harness/marker" | Run `/harness.init` in the project repo first. |
| `/spec.implement` aborts after 3 attempts on a single task | The spec was unclear for that task. Read the three eval feedbacks, edit `spec.md` to clarify the acceptance criterion, then re-run `/spec.implement`. The loop is honest — it would rather stop than ship something that doesn't match the spec. |
| `/spec.reconcile` FAILs with "impl violates criterion X" | The spec and the code disagree, and the spec is what you signed off on. Either fix the code or amend the spec — don't silently overwrite the spec to match buggy code. |

## Verifying the install is sane

```bash
bash scripts/verify.sh
```

Runs every check the installer makes plus a few extras. Exits non-zero on the first failure with the failing check named, so you know exactly which phase to re-run.

## Still stuck

- Open an issue on the harness repo with the output of `bash scripts/verify.sh` plus the verbatim error message.
- If it's a Cognee bug (not a harness wiring bug), the fastest reproduction is calling Cognee directly from the shell:
  ```bash
  ~/.claude/scripts/harness/cognee-shim.sh cognee --help
  ```
