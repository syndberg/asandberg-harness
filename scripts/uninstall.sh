#!/usr/bin/env bash
# uninstall.sh
# Best-effort reversal of the harness install.
# Leaves the external toolchain (uv, cognee, ollama models) in place because
# they're useful beyond the harness. Removes harness-installed files, hook
# entries from settings.json, and the Cognee MCP registration.
#
# Always writes timestamped backups of any JSON it modifies.

set -u

log() { printf '[uninstall] %s\n' "$*"; }

read -p "Uninstall harness from ~/.claude/? [y/N] " confirm
if [ "${confirm:-N}" != "y" ] && [ "${confirm:-N}" != "Y" ]; then
  log "aborted."
  exit 0
fi

# 1. Remove grafted files.
HARNESS_FILES=(
  "${HOME}/.claude/agents/spec-implementer.md"
  "${HOME}/.claude/agents/spec-conformance-evaluator.md"
  "${HOME}/.claude/agents/spec-drafter.md"
  "${HOME}/.claude/agents/spec-draft-judge.md"
  "${HOME}/.claude/agents/test-runner.md"
  "${HOME}/.claude/commands/harness-init.md"
  "${HOME}/.claude/commands/harness-catalogue.md"
  "${HOME}/.claude/commands/spec-implement.md"
  "${HOME}/.claude/commands/spec-reconcile.md"
  "${HOME}/.claude/commands/feature.md"
  "${HOME}/.claude/commands/spec-draft.md"
  "${HOME}/.claude/skills/recall-context/SKILL.md"
  "${HOME}/.claude/scripts/harness/cap-subagent-depth.sh"
  "${HOME}/.claude/scripts/harness/cognee-ingest.py"
  "${HOME}/.claude/scripts/harness/cognee-shim.sh"
  "${HOME}/.claude/scripts/harness/init-repo.sh"
  "${HOME}/.claude/scripts/harness/knowledge-ingest-queue.js"
  "${HOME}/.claude/scripts/harness/knowledge-nightly-sweep.sh"
  "${HOME}/.claude/scripts/harness/spec-boundary-check.js"
  "${HOME}/.claude/templates/feature/spec.md"
  "${HOME}/.claude/templates/feature/plan.md"
  "${HOME}/.claude/templates/feature/tasks.md"
  "${HOME}/.claude/templates/feature/eval.md"
)

for f in "${HARNESS_FILES[@]}"; do
  if [ -e "${f}" ]; then
    rm -f "${f}"
    log "removed ${f}"
  fi
done

# Remove now-empty harness dirs.
rmdir "${HOME}/.claude/scripts/harness"           2>/dev/null && log "removed empty scripts/harness/" || true
rmdir "${HOME}/.claude/skills/recall-context"     2>/dev/null && log "removed empty skills/recall-context/" || true
rmdir "${HOME}/.claude/templates/feature"         2>/dev/null && log "removed empty templates/feature/" || true
rmdir "${HOME}/.claude/templates"                 2>/dev/null && log "removed empty templates/" || true

# 2. Strip harness hook entries from settings.json.
if [ -f "${HOME}/.claude/settings.json" ]; then
  python3 - <<'PY'
import json, os, shutil, time
p = os.path.expanduser('~/.claude/settings.json')
shutil.copy(p, p.replace('.json', f'.json.bak-{int(time.time())}'))
d = json.load(open(p))
HARNESS_MARKERS = (
    'cap-subagent-depth',
    'spec-boundary-check',
    'knowledge-ingest-queue',
)
removed = 0
for event, bucket in list((d.get('hooks') or {}).items()):
    keep = []
    for entry in bucket:
        cmds = [h.get('command', '') for h in entry.get('hooks', [])]
        if any(m in c for c in cmds for m in HARNESS_MARKERS):
            removed += 1
            continue
        keep.append(entry)
    if keep:
        d['hooks'][event] = keep
    else:
        del d['hooks'][event]
json.dump(d, open(p, 'w'), indent=2)
print(f'[uninstall] removed {removed} harness hook entry/entries from settings.json')
PY
fi

# 3. Drop cognee MCP from ~/.claude.json.
if [ -f "${HOME}/.claude.json" ]; then
  python3 - <<'PY'
import json, os, shutil, time
p = os.path.expanduser('~/.claude.json')
shutil.copy(p, p.replace('.json', f'.json.bak-{int(time.time())}'))
d = json.load(open(p))
servers = d.get('mcpServers') or {}
if 'cognee' in servers:
    del servers['cognee']
    json.dump(d, open(p, 'w'), indent=2)
    print('[uninstall] removed cognee MCP from ~/.claude.json')
else:
    print('[uninstall] cognee MCP not registered (nothing to remove)')
PY
fi

cat <<EOF

Harness files removed. External tools left in place:
  - uv tools (cognee, cognee-mcp, specify-cli) — uninstall with: uv tool uninstall <name>
  - Ollama models (nomic-embed-text) — remove with: ollama rm nomic-embed-text
  - ~/.cognee/ data (graph + cache) — remove manually if no longer needed

Restart Claude Code so the removed hooks and MCP server stop loading.
EOF
