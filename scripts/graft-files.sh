#!/usr/bin/env bash
# graft-files.sh
# Phase 3 of the harness installer.
# Copies the harness's claude/* tree into ~/.claude/ using `cp -n` so existing
# files are NEVER overwritten. Sets executable bit on scripts.
# Idempotent: re-running only copies files that don't exist on the target.

set -eu

log() { printf '\n[graft-files] %s\n' "$*"; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${REPO_ROOT}/claude"
DST="${HOME}/.claude"

if [ ! -d "${SRC}" ]; then
  printf '[graft-files] FAIL: source dir not found: %s\n' "${SRC}" >&2
  exit 1
fi

if [ ! -d "${DST}" ]; then
  log "creating ${DST} (Claude Code will populate it on first launch)"
  mkdir -p "${DST}"
fi

# Make sure all target directories exist before copying.
mkdir -p \
  "${DST}/agents" \
  "${DST}/commands" \
  "${DST}/skills/recall-context" \
  "${DST}/scripts/harness" \
  "${DST}/templates/feature"

copy_no_overwrite() {
  local src="$1"
  local dst="$2"
  if [ -e "${dst}" ]; then
    log "skip (exists): ${dst}"
  else
    cp "${src}" "${dst}"
    log "wrote: ${dst}"
  fi
}

# Agents
for f in "${SRC}/agents"/*.md; do
  copy_no_overwrite "${f}" "${DST}/agents/$(basename "${f}")"
done

# Commands
for f in "${SRC}/commands"/*.md; do
  copy_no_overwrite "${f}" "${DST}/commands/$(basename "${f}")"
done

# Skill
copy_no_overwrite "${SRC}/skills/recall-context/SKILL.md" "${DST}/skills/recall-context/SKILL.md"

# Harness scripts
for f in "${SRC}/scripts/harness"/*; do
  copy_no_overwrite "${f}" "${DST}/scripts/harness/$(basename "${f}")"
done
chmod +x "${DST}/scripts/harness"/*.sh "${DST}/scripts/harness"/*.py "${DST}/scripts/harness"/*.js 2>/dev/null || true

# Feature templates
for f in "${SRC}/templates/feature"/*.md; do
  copy_no_overwrite "${f}" "${DST}/templates/feature/$(basename "${f}")"
done

log "graft complete."
log "next phase: scripts/merge-settings.py"
