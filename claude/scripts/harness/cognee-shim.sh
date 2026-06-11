#!/usr/bin/env bash
# cognee-shim.sh
# Wraps a Cognee binary call with the env it needs to actually work on this host:
#   - LLM_API_KEY is derived from $ANTHROPIC_API_KEY (Cognee won't fall back to it on its own).
#   - ~/.cognee/.env is sourced so all the other Cognee config (provider, model, endpoints)
#     is picked up.
#
# Usage:
#   cognee-shim.sh cognee-mcp [args...]
#   cognee-shim.sh cognee add ~/path/to/file.md --dataset <name>
#   cognee-shim.sh cognee search "..." --datasets <name> --query-type GRAPH_COMPLETION
#
# Designed so the MCP server registration in ~/.claude.json and the
# PostToolUse/SessionEnd hooks can route all Cognee work through one place.
set -u

if [ "${ANTHROPIC_API_KEY:-}" = "" ]; then
  echo "[cognee-shim] ANTHROPIC_API_KEY is not set in env — Cognee LLM calls will fail." >&2
fi

# Cognee reads LLM_API_KEY (not ANTHROPIC_API_KEY). LiteLLM-via-Cognee can use either,
# but Cognee's startup check asserts LLM_API_KEY explicitly.
export LLM_API_KEY="${LLM_API_KEY:-${ANTHROPIC_API_KEY:-}}"

# Pick up the rest of the Cognee config from ~/.cognee/.env if present.
COGNEE_ENV_FILE="${COGNEE_ENV_FILE:-${HOME}/.cognee/.env}"
if [ -f "${COGNEE_ENV_FILE}" ]; then
  set -a
  # shellcheck disable=SC1090
  . "${COGNEE_ENV_FILE}"
  set +a
  # Re-derive LLM_API_KEY after sourcing in case the .env tried to override it.
  export LLM_API_KEY="${LLM_API_KEY:-${ANTHROPIC_API_KEY:-}}"
fi

# When embeddings use OpenAI, Cognee reads EMBEDDING_API_KEY. Inject it from
# $OPENAI_API_KEY (the key is intentionally NOT written into ~/.cognee/.env).
# The Ollama backend sets EMBEDDING_API_KEY=ollama in the .env, so this no-ops there.
if [ "${EMBEDDING_PROVIDER:-}" = "openai" ] && [ "${EMBEDDING_API_KEY:-}" = "" ]; then
  if [ "${OPENAI_API_KEY:-}" = "" ]; then
    echo "[cognee-shim] EMBEDDING_PROVIDER=openai but OPENAI_API_KEY is not set — embeddings will fail." >&2
  fi
  export EMBEDDING_API_KEY="${OPENAI_API_KEY:-}"
fi

# First positional is the cognee binary name; rest are passed through.
if [ "$#" -lt 1 ]; then
  echo "[cognee-shim] usage: cognee-shim.sh <cognee-binary> [args...]" >&2
  exit 64
fi

CMD="$1"
shift

# Find the binary on PATH (covers both ~/.local/bin and uv tool installs).
BIN="$(command -v "${CMD}" 2>/dev/null || true)"
if [ -z "${BIN}" ]; then
  echo "[cognee-shim] binary '${CMD}' not on PATH (PATH=${PATH})" >&2
  exit 127
fi

exec "${BIN}" "$@"
