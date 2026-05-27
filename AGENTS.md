# AGENTS.md — installing this harness

You are a coding agent installing the `asandberg-harness` on the current user's machine. Follow this runbook in order. After each phase, run the stated verification command and only proceed if it passes. If any check fails, **stop and report what failed** — do not improvise fixes.

The harness is a graft: it adds files to `~/.claude/` without overwriting anything, and it merges hook entries into `~/.claude/settings.json` idempotently. Re-running any phase is safe.

---

## Phase 0 — Prerequisites

Verify each. If any is missing, **stop and ask the user** to install or set it — do not auto-install system-level software.

| Requirement                | Check command                                        | If missing                                    |
|----------------------------|------------------------------------------------------|-----------------------------------------------|
| OS Linux or macOS          | `uname -s`                                           | Stop. Report unsupported OS.                  |
| `git`                      | `git --version`                                      | Ask user; install via OS package manager.     |
| `curl`                     | `curl --version`                                     | Ask user; install via OS package manager.     |
| `python3` ≥ 3.9            | `python3 --version`                                  | Ask user; install via OS package manager.     |
| Node.js ≥ 22               | `node --version`                                     | Ask user. Required by Claude Code itself.     |
| Claude Code installed      | `claude --version`                                   | Ask user to install per Anthropic docs.       |
| `ANTHROPIC_API_KEY` in env | `printenv ANTHROPIC_API_KEY \| head -c 10`           | Ask user to export in shell rc.               |
| Ollama running on :11434   | `curl -sf http://localhost:11434/api/version`        | Install via `curl -fsSL https://ollama.com/install.sh \| sh`, then start. |
| `~/.claude` exists         | `test -d ~/.claude`                                  | Run `claude` once interactively, then resume. |

**Do not proceed** until all prerequisites pass.

---

## Phase 1 — Install external toolchain

Run:

```bash
bash scripts/install-toolchain.sh
```

This installs (idempotent): `uv`, Python 3.12, `specify-cli`, `cognee`, `cognee-mcp`, and pulls the `nomic-embed-text` Ollama model.

**Verify:**

```bash
uv tool list | grep -E 'specify-cli|cognee|cognee-mcp'
```

Expected: three lines, one per tool. If any is missing, re-run Phase 1; if it still fails, report the install log to the user.

---

## Phase 2 — Write Cognee environment file

Run:

```bash
bash scripts/write-cognee-env.sh
```

Writes `~/.cognee/.env` with provider/embedding config. Leaves an existing file alone.

**Verify:**

```bash
test -f ~/.cognee/.env && grep -q '^LLM_PROVIDER=anthropic' ~/.cognee/.env && echo OK
```

Expected: `OK`. If not, inspect `~/.cognee/.env` manually.

---

## Phase 3 — Graft files into ~/.claude/

Run:

```bash
bash scripts/graft-files.sh
```

Copies the harness's `claude/` tree into `~/.claude/` using `cp -n` (never overwrites). Sets executable bit on scripts.

**Verify:**

```bash
test -f ~/.claude/agents/spec-implementer.md \
  && test -x ~/.claude/scripts/harness/cognee-shim.sh \
  && test -f ~/.claude/templates/feature/spec.md \
  && echo OK
```

Expected: `OK`.

---

## Phase 4 — Merge hook entries into settings.json

`~/.claude/settings.json` must already exist for this phase. If it doesn't, the user has never launched Claude Code on this machine — ask them to run `claude` once, then resume from this phase.

Run:

```bash
python3 scripts/merge-settings.py
```

Idempotently appends the four harness hook entries to the existing `hooks` section. A timestamped backup is always written first.

**Verify:**

```bash
python3 -c "
import json, os
d = json.load(open(os.path.expanduser('~/.claude/settings.json')))
cmds = [h['command'] for e in d['hooks']['PreToolUse'] for h in e['hooks']]
assert any('cap-subagent-depth' in c for c in cmds), 'cap-subagent-depth hook not wired'
print('OK')
"
```

Expected: `OK`. On `AssertionError`, restore from the `.bak-<ts>` file the script created and re-run the phase.

---

## Phase 5 — Register Cognee MCP server

`~/.claude.json` must already exist (created on first `claude` launch). Same recovery as Phase 4 if it's missing.

Run:

```bash
python3 scripts/register-mcp.py
```

Idempotently adds the `cognee` server entry. Timestamped backup before write.

**Verify:**

```bash
python3 -c "
import json, os
d = json.load(open(os.path.expanduser('~/.claude.json')))
assert 'cognee' in d.get('mcpServers', {}), 'cognee MCP not registered'
print('OK')
"
```

Expected: `OK`.

---

## Phase 6 — Ask the user to restart Claude Code

You cannot do this yourself. Print to the user, verbatim:

> The harness is installed. Please restart your Claude Code session so the new MCP server and hooks load. Reply when you've done that.

Wait for confirmation before continuing.

---

## Phase 7 — End-to-end verification

After the user confirms restart, run:

```bash
bash scripts/verify.sh
```

This runs every check from Phases 1-5 plus a few extras. It will exit non-zero on any failure with the failing check named.

If verify passes, ask the user to run this smoke test inside a fresh Claude Code session:

```text
mcp__cognee__cognify { data: "harness install smoke test", dataset_name: "smoke" }
mcp__cognee__search { search_query: "what was just stored?", search_type: "GRAPH_COMPLETION", datasets: "smoke" }
```

The search should return a coherent answer referencing the test string. If it doesn't, see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

---

## Done

Tell the user the harness is installed and operational. Point them at:

- [docs/USAGE.md](docs/USAGE.md) — day-to-day workflow.
- [docs/RETROFIT.md](docs/RETROFIT.md) — how to onboard an existing repo.
- `/harness.init` to opt their first project in.

---

## Failure recovery rules

| Phase | If it fails                                                                                                                     |
|-------|----------------------------------------------------------------------------------------------------------------------------------|
| 1     | Capture the install log. Common cause: `uv` couldn't install Python 3.12 (network/proxy). Report verbatim to user.               |
| 2     | If `~/.cognee/.env` already existed and is misconfigured, delete it and re-run the phase.                                        |
| 3     | If a file collision exists, that file is left untouched. Compare against the source in `claude/` to decide whether to overwrite. |
| 4     | Restore `~/.claude/settings.json` from the `.bak-<ts>` the script wrote, then re-run.                                            |
| 5     | Restore `~/.claude.json` from the `.bak-<ts>`. If `cognee-shim.sh` is missing, re-run Phase 3 first.                             |
| 7     | See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md). Most issues are: `ANTHROPIC_API_KEY` not exported, Ollama not running, or Claude Code not restarted. |

**Hard rule:** if a phase fails twice, stop and surface the failure to the user verbatim. Do not invent fixes.
