# Contributing

Issues and pull requests welcome. No SLAs — this is personal tooling that's been opened up because it might be useful to others.

## Working on the harness itself

The harness has no test suite of its own — the install script is the test. Smoke-test by:

1. Wiping `~/.claude/scripts/harness/` and the relevant slash commands locally.
2. Running `bash install.sh` from a fresh clone of your branch.
3. Running `bash scripts/verify.sh`.
4. In a fresh Claude Code session, running the smoke test from `AGENTS.md` Phase 7.

If you change anything in `claude/scripts/harness/*.{sh,js,py}`, also re-run an actual `/spec.implement` on a throwaway repo to make sure hooks behave.

## Pull request checklist

- [ ] Any new/changed user-facing slash command has its description updated in the YAML frontmatter.
- [ ] Any new hook is documented in `docs/ARCHITECTURE.md`.
- [ ] `scripts/verify.sh` has a check for any new installed file or wired hook.
- [ ] `scripts/uninstall.sh` knows how to remove anything new.
- [ ] `CHANGELOG.md` updated under `[Unreleased]`.
- [ ] No new hardcoded personal paths (search the diff for `/home/`, hostnames, account IDs).
- [ ] No new mempalace references — this repo is intentionally separate from any private memory layer.

## Style

- Bash scripts: `#!/usr/bin/env bash`, `set -eu` minimum, `set -euo pipefail` if you're using pipes. Use `${HOME}` not `/home/...`.
- Node scripts: ES2020+, no dependencies beyond Node stdlib (these run inside Claude Code's hook system and shouldn't carry an `npm install`).
- Python scripts: 3.9+ stdlib only. No `pip install`. Same reason as Node.

## Reporting issues

Include:
- Output of `bash scripts/verify.sh`.
- The verbatim error message.
- OS + Claude Code version (`claude --version`).
- For Cognee issues, the output of `~/.claude/scripts/harness/cognee-shim.sh cognee --help`.

## Things that are out of scope

- **Plugin packaging.** The harness is currently a graft, not a Claude Code plugin. Plugin packaging is a planned future direction; PRs that move toward it are welcome but should be discussed first.
- **Non-Cognee memory backends.** The recall layer is intentionally Cognee-specific. If you want a different backend, fork.
- **Personal-infra references.** Any commit that introduces a hostname, tailnet address, personal email, or any other identifying infrastructure detail will be reverted.
