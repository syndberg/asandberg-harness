---
description: Bootstrap the current repo into the spec-driven harness — creates .harness/marker, docs/memory/, specs/, seeds CLAUDE.md, runs `specify init`. Idempotent.
---

# /harness.init

Bootstrap the current working directory as a harness-opted-in repo.

## Steps you take

1. Verify `pwd` is a git repo (run `git rev-parse --show-toplevel`). If not, refuse and tell the user to `git init` first.
2. Run `bash ~/.claude/scripts/harness/init-repo.sh` from the repo root. The script is idempotent and creates:
   - `.harness/marker` (empty file; presence = opted in)
   - `docs/memory/decisions/.gitkeep`, `docs/memory/runbooks/.gitkeep`, `docs/memory/glossary.md` (stub)
   - `specs/.gitkeep`
   - `CLAUDE.md` (only if missing — never overwrite)
3. If `specify` is on PATH, run `specify init . --integration claude --here` to register Spec Kit commands and create `.specify/` + `memory/constitution.md`. If `specify` is missing, print install instructions and skip without failing.
4. Cognee datasets are created lazily on first `mcp__cognee__cognify` call — no `create` step is required. If `~/.cognee/.env` is missing, the script prints a hint that the harness installer needs to run.
5. Print a "next steps" block:
   - `git add .harness docs specs CLAUDE.md .specify memory && git commit -m "chore: opt repo into spec-driven harness"`
   - `/speckit.constitution` to establish repo principles
   - `/speckit.specify "<your first feature>"` when ready

## Hard rules

- Idempotent. Re-running must not clobber existing files. Use `mkdir -p`, `touch`, and `[ -e file ] || cat > file`.
- Never overwrite an existing `CLAUDE.md` — append a note to stderr if one exists, that's it.
- This command is a single orchestrator turn. No subagents.
