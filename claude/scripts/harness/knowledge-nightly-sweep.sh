#!/usr/bin/env bash
# knowledge-nightly-sweep.sh
# Walk every opted-in repo and re-queue every markdown file under
# docs/memory/, specs/, and CLAUDE.md. The SessionEnd hook
# (knowledge-ingest-queue.js flush) then drains the queue via the
# Cognee MCP server (see ~/.cognee/.env for provider/embedding config).
# Cognee is content-addressed so re-queue + re-ingest is cheap for
# unchanged files.
#
# Usage:
#   knowledge-nightly-sweep.sh                   # walk default search root
#   knowledge-nightly-sweep.sh /custom/path ...  # walk explicit roots
#
# Default root: ~/repos.
set -u

QUEUE="${HOME}/.claude/state/knowledge-queue.txt"
mkdir -p "$(dirname "${QUEUE}")"
touch "${QUEUE}"

ROOTS=("${@:-${HOME}/repos}")
TOTAL_REPOS=0
TOTAL_FILES=0

for root in ${ROOTS[*]}; do
  [ -d "${root}" ] || continue
  while IFS= read -r marker; do
    repo_root="$(dirname "$(dirname "${marker}")")"
    kb="$(basename "${repo_root}")"
    TOTAL_REPOS=$((TOTAL_REPOS + 1))
    echo "[knowledge-sweep] repo: ${repo_root}  kb: ${kb}"

    while IFS= read -r f; do
      [ -f "${f}" ] || continue
      line="${kb}	${f}"
      if ! grep -Fxq -- "${line}" "${QUEUE}" 2>/dev/null; then
        echo "${line}" >> "${QUEUE}"
        TOTAL_FILES=$((TOTAL_FILES + 1))
      fi
    done < <(
      {
        find "${repo_root}/docs/memory" -type f -name '*.md' 2>/dev/null
        find "${repo_root}/specs"      -type f -name '*.md' 2>/dev/null
        [ -f "${repo_root}/CLAUDE.md" ] && echo "${repo_root}/CLAUDE.md"
      }
    )
  done < <(find "${root}" -maxdepth 6 -type f -path '*/.harness/marker' 2>/dev/null)
done

echo "[knowledge-sweep] queued: repos=${TOTAL_REPOS} new-files=${TOTAL_FILES}"
echo "[knowledge-sweep] queue at ${QUEUE} — flushed via MCP at next orchestrator turn."
