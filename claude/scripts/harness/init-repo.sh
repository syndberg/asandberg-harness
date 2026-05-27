#!/usr/bin/env bash
# init-repo.sh — bootstrap the current repo into the spec-driven harness.
# Idempotent: re-running never clobbers existing files.
#
# Called by the /harness.init slash command. Run from the repo root.
set -eu

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "${REPO_ROOT}"

echo "[harness-init] repo: ${REPO_ROOT}"

# 1. Marker dir + marker file (presence = opted in).
mkdir -p .harness
touch .harness/marker
echo "[harness-init] .harness/marker  ok"

# 2. docs/memory tree.
mkdir -p docs/memory/decisions docs/memory/runbooks
touch docs/memory/decisions/.gitkeep
touch docs/memory/runbooks/.gitkeep
if [ ! -e docs/memory/glossary.md ]; then
  cat > docs/memory/glossary.md <<'EOF'
# Glossary

Project-specific terms and acronyms. One entry per term.

## Format

**Term** — short definition. Optional second sentence with context.
EOF
fi
echo "[harness-init] docs/memory/     ok"

# 3. specs/ tree.
mkdir -p specs
touch specs/.gitkeep
echo "[harness-init] specs/           ok"

# 4. CLAUDE.md — only if missing.
if [ ! -e CLAUDE.md ]; then
  REPO_NAME="$(basename "${REPO_ROOT}")"
  cat > CLAUDE.md <<EOF
# ${REPO_NAME}

> Repo constitution. Keep under ~300 lines or it loses influence after compaction.

## What this repo is

(One paragraph: the user-facing purpose of this codebase.)

## Conventions

- Tests live alongside code, or in tests/ — pick one and stick with it.
- Spec-driven via GitHub Spec Kit. Major features live in specs/<feature>/.
- Decisions go in docs/memory/decisions/ as one .md per decision.

## Constraints

(Things that would surprise an outsider: weird build steps, deploy gotchas, third-party quirks.)
EOF
  echo "[harness-init] CLAUDE.md       ok (seeded)"
else
  echo "[harness-init] CLAUDE.md       present (left as-is)"
fi

# 5. Spec Kit init (optional — skip silently if not installed).
if command -v specify >/dev/null 2>&1; then
  if [ ! -d .specify ]; then
    specify init . --integration claude --here >/dev/null 2>&1 || \
      specify init . --integration claude >/dev/null 2>&1 || \
      echo "[harness-init] specify init failed (continuing)"
    echo "[harness-init] .specify/       ok"
  else
    echo "[harness-init] .specify/       present"
  fi
else
  cat <<'EOF'
[harness-init] specify CLI not on PATH — skipping Spec Kit init.
              install with: uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
EOF
fi

# 6. Cognee dataset is created lazily on first mcp__cognee__cognify call —
#    no pre-creation step needed here. Just verify the MCP server config is
#    present so the user knows recall will work.
if [ -f "${HOME}/.cognee/.env" ]; then
  echo "[harness-init] cognee env       ok (~/.cognee/.env present)"
else
  cat <<'EOF'
[harness-init] cognee env missing — recall will not work until installed.
              run the harness installer (scripts/install.sh in the harness repo).
EOF
fi

cat <<EOF

Next steps:
  git add .harness docs specs CLAUDE.md .specify memory 2>/dev/null
  git commit -m "chore: opt repo into spec-driven harness"
  /speckit.constitution
  /speckit.specify "<your first feature>"
EOF
