#!/usr/bin/env bash
# install-toolchain.sh
# Phase 1 of the harness installer.
# Installs external dependencies: uv, Python 3.12, specify-cli, cognee, cognee-mcp,
# and pulls the Ollama embedding model. Does NOT touch ~/.claude/ or write env files.
# Idempotent: safe to re-run.

set -eu

log()  { printf '\n[install-toolchain] %s\n' "$*"; }
warn() { printf '\n[install-toolchain] WARN: %s\n' "$*" >&2; }
fail() { printf '\n[install-toolchain] FAIL: %s\n' "$*" >&2; exit 1; }

export PATH="${HOME}/.local/bin:${PATH}"

# 1. uv
if command -v uv >/dev/null 2>&1; then
  log "uv: present ($(uv --version))"
else
  log "uv: installing via curl..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="${HOME}/.local/bin:${PATH}"
  log "uv: installed"
fi

# 2. Python 3.12 (Cognee + cognee-mcp + Spec Kit all require Python 3.12)
if uv python find 3.12 >/dev/null 2>&1; then
  log "python 3.12: present"
else
  log "python 3.12: installing via uv..."
  uv python install 3.12
fi

# 3. Spec Kit
if command -v specify >/dev/null 2>&1; then
  log "specify: present"
else
  log "specify: installing via uv tool..."
  uv tool install specify-cli --from git+https://github.com/github/spec-kit.git --python 3.12
fi

# 4. cognee CLI (with anthropic SDK + transformers tokenizer)
log "cognee: installing/refreshing via uv tool..."
uv tool install cognee --with anthropic --with transformers --python 3.12 --force >/dev/null

# 5. cognee-mcp (separate package, separate venv)
log "cognee-mcp: installing/refreshing via uv tool..."
uv tool install cognee-mcp --with anthropic --with transformers --python 3.12 --force >/dev/null

# 6. Ollama embedding model
if command -v ollama >/dev/null 2>&1; then
  if ollama list 2>/dev/null | awk '{print $1}' | grep -qx "nomic-embed-text:latest"; then
    log "ollama nomic-embed-text: present"
  else
    log "ollama: pulling nomic-embed-text..."
    ollama pull nomic-embed-text || warn "ollama pull failed — pull manually before using Cognee"
  fi
else
  warn "ollama missing; embeddings will fail until ollama is installed and serving on :11434"
  warn "install: curl -fsSL https://ollama.com/install.sh | sh"
fi

log "toolchain install complete."
log "next phase: scripts/write-cognee-env.sh"
