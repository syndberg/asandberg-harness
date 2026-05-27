#!/usr/bin/env bash
# install.sh — top-level harness installer.
# Runs each install phase in order, halting on first failure with a clear pointer.
#
# Phases:
#   1. install-toolchain.sh    External tools (uv, python 3.12, cognee, ollama model)
#   2. write-cognee-env.sh     ~/.cognee/.env config file
#   3. graft-files.sh          Copy harness files into ~/.claude/ (never overwrites)
#   4. merge-settings.py       Additive hook entries in ~/.claude/settings.json
#   5. register-mcp.py         Cognee MCP entry in ~/.claude.json
#   ──── then ask user to restart Claude Code ────
#   6. verify.sh               Full check that everything is in place
#
# Idempotent: re-runs are safe. Each phase script can also be invoked
# individually if a single phase fails and you want to retry just that one.

set -eu

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "${REPO_ROOT}"

banner() { printf '\n\e[1;34m=== %s ===\e[0m\n' "$*"; }

# --- Prereq checks (fail fast with actionable error) ---
need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf '\n\e[31m[install] missing prereq:\e[0m %s\n%s\n' "$1" "$2" >&2
    exit 1
  fi
}
need_cmd git    "install git via your OS package manager."
need_cmd curl   "install curl via your OS package manager."
need_cmd python3 "install python3 (>= 3.9) via your OS package manager."
need_cmd node   "install Node.js 22+ (Claude Code requires it). See https://nodejs.org/."

if [ "${ANTHROPIC_API_KEY:-}" = "" ]; then
  printf '\n\e[31m[install] ANTHROPIC_API_KEY is not set in your shell env.\e[0m\n'
  printf 'Add it to your shell rc (~/.bashrc or ~/.zshrc):\n'
  printf '    export ANTHROPIC_API_KEY="sk-ant-…"\n'
  printf 'then `source` the rc file and re-run this installer.\n' >&2
  exit 1
fi

if ! curl -sf http://localhost:11434/api/version >/dev/null 2>&1; then
  printf '\n\e[33m[install] WARN: ollama not responding on :11434.\e[0m\n' >&2
  printf 'Install:  curl -fsSL https://ollama.com/install.sh | sh\n' >&2
  printf 'Start it (Linux): systemctl --user enable --now ollama\n' >&2
  printf 'Continuing — the toolchain phase will still try to pull the model later.\n\n' >&2
fi

# --- Phases ---
banner "Phase 1/5  install-toolchain.sh"
bash "${REPO_ROOT}/scripts/install-toolchain.sh"

banner "Phase 2/5  write-cognee-env.sh"
bash "${REPO_ROOT}/scripts/write-cognee-env.sh"

banner "Phase 3/5  graft-files.sh"
bash "${REPO_ROOT}/scripts/graft-files.sh"

# Phases 4 and 5 require ~/.claude/settings.json and ~/.claude.json to already
# exist. If the user has never launched Claude Code on this box, both are
# missing — surface that with an actionable message and stop. They can re-run
# install.sh after launching `claude` once.
if [ ! -f "${HOME}/.claude/settings.json" ] || [ ! -f "${HOME}/.claude.json" ]; then
  cat <<EOF

\e[33mInstall paused.\e[0m
~/.claude/settings.json and/or ~/.claude.json don't exist yet.

Launch Claude Code once so it creates them:
    claude

Then re-run this installer. Phases 1-3 (already done) will no-op.
EOF
  exit 0
fi

banner "Phase 4/5  merge-settings.py"
python3 "${REPO_ROOT}/scripts/merge-settings.py"

banner "Phase 5/5  register-mcp.py"
python3 "${REPO_ROOT}/scripts/register-mcp.py"

cat <<'EOF'


==========================================================================
Install complete.

Next steps (in order):

  1. RESTART Claude Code (the MCP server only loads at session start).

  2. Verify everything is wired up:
       bash scripts/verify.sh

  3. Smoke-test Cognee in a fresh Claude Code session:
       mcp__cognee__cognify { data: "smoke", dataset_name: "smoke" }
       mcp__cognee__search { search_query: "what is smoke?", search_type: "GRAPH_COMPLETION", datasets: "smoke" }

  4. Opt your first project into the harness:
       cd <your repo>
       /harness.init
       /harness.catalogue        # for existing repos with prior history
==========================================================================

EOF
