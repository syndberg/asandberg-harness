#!/usr/bin/env bash
# write-cognee-env.sh
# Phase 2 of the harness installer.
# Writes ~/.cognee/.env with provider/endpoint config. Idempotent:
# leaves an existing file alone so user customisations survive re-runs.

set -eu

log() { printf '\n[write-cognee-env] %s\n' "$*"; }

COGNEE_DIR="${HOME}/.cognee"
COGNEE_ENV="${COGNEE_DIR}/.env"

mkdir -p "${COGNEE_DIR}/data_storage" "${COGNEE_DIR}/system" "${COGNEE_DIR}/cache" "${COGNEE_DIR}/logs"

if [ -f "${COGNEE_ENV}" ]; then
  log "${COGNEE_ENV} already exists — leaving as-is."
  log "delete it manually if you want defaults regenerated."
  exit 0
fi

# Embeddings backend: openai (default) or ollama. install.sh sets HARNESS_EMBEDDINGS;
# honoured here too so this phase can be run standalone.
EMBEDDINGS="${HARNESS_EMBEDDINGS:-openai}"

case "${EMBEDDINGS}" in
  openai)
    EMB_COMMENT="OpenAI API (text-embedding-3-small). The OpenAI key is NOT stored here;
# cognee-shim.sh injects EMBEDDING_API_KEY from \$OPENAI_API_KEY at runtime."
    EMB_BLOCK="EMBEDDING_PROVIDER=openai
EMBEDDING_MODEL=text-embedding-3-small
EMBEDDING_DIMENSIONS=1536"
    ;;
  ollama)
    EMB_COMMENT="local Ollama (uses GPU if available); no API key required."
    EMB_BLOCK="EMBEDDING_PROVIDER=ollama
EMBEDDING_MODEL=nomic-embed-text
EMBEDDING_DIMENSIONS=768
EMBEDDING_ENDPOINT=http://localhost:11434/api/embed
EMBEDDING_API_KEY=ollama
HUGGINGFACE_TOKENIZER=nomic-ai/nomic-embed-text-v1.5"
    ;;
  *)
    echo "[write-cognee-env] invalid HARNESS_EMBEDDINGS=${EMBEDDINGS} (expected openai or ollama)" >&2
    exit 1
    ;;
esac

log "writing ${COGNEE_ENV} (embeddings: ${EMBEDDINGS})"
cat > "${COGNEE_ENV}" <<EOF
# Cognee config — LLM via Anthropic; embeddings via ${EMBEDDINGS}.
# LLM_API_KEY is NOT set here; cognee-shim.sh injects it from \$ANTHROPIC_API_KEY at runtime.

# ---- LLM (graph extraction + GRAPH_COMPLETION queries) ----
LLM_PROVIDER=anthropic
LLM_MODEL=claude-haiku-4-5-20251001

# ---- Embeddings: ${EMB_COMMENT}
${EMB_BLOCK}

# ---- Shared storage so cognee-cli and cognee-mcp see the same data ----
DATA_ROOT_DIRECTORY=${COGNEE_DIR}/data_storage
SYSTEM_ROOT_DIRECTORY=${COGNEE_DIR}/system
CACHE_ROOT_DIRECTORY=${COGNEE_DIR}/cache

# ---- Behaviour ----
ENABLE_BACKEND_ACCESS_CONTROL=false
CACHING=false
EOF

log "wrote ${COGNEE_ENV}"
if [ "${EMBEDDINGS}" = "openai" ]; then
  log "OpenAI embeddings: ensure OPENAI_API_KEY is exported in your shell (cognee-shim injects it)."
fi
log "next phase: scripts/graft-files.sh"
