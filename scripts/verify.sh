#!/usr/bin/env bash
# verify.sh
# Phase 7 of the harness installer (run after the user restarts Claude Code).
# Checks every install step left the system in the expected state.
# Exits non-zero on the first failed check, with an actionable message.

set -u

ok()   { printf '  \e[32m[ok]\e[0m   %s\n' "$*"; }
fail() { printf '  \e[31m[FAIL]\e[0m %s\n' "$*"; FAILED=1; }
heading() { printf '\n== %s ==\n' "$*"; }

FAILED=0

heading "External toolchain"
command -v uv >/dev/null 2>&1                 && ok "uv on PATH"                          || fail "uv missing"
command -v specify >/dev/null 2>&1            && ok "specify on PATH"                     || fail "specify-cli missing"
uv tool list 2>/dev/null | grep -q '^cognee'  && ok "cognee installed via uv"             || fail "cognee uv tool missing"
uv tool list 2>/dev/null | grep -q 'cognee-mcp' && ok "cognee-mcp installed via uv"       || fail "cognee-mcp uv tool missing"
command -v ollama >/dev/null 2>&1             && ok "ollama on PATH"                      || fail "ollama missing"
ollama list 2>/dev/null | grep -q '^nomic-embed-text' && ok "nomic-embed-text model pulled" || fail "nomic-embed-text model not pulled"
curl -sf http://localhost:11434/api/version >/dev/null 2>&1 && ok "ollama serving on :11434" || fail "ollama not responding on :11434"

heading "Cognee environment"
test -f "${HOME}/.cognee/.env"                 && ok "~/.cognee/.env present"             || fail "~/.cognee/.env missing"
grep -q '^LLM_PROVIDER=anthropic' "${HOME}/.cognee/.env" 2>/dev/null && ok "LLM_PROVIDER set" || fail "LLM_PROVIDER not anthropic"
[ -n "${ANTHROPIC_API_KEY:-}" ]                && ok 'ANTHROPIC_API_KEY in env'           || fail 'ANTHROPIC_API_KEY not set in shell env'

heading "Grafted files"
test -f "${HOME}/.claude/agents/spec-implementer.md"             && ok "agent: spec-implementer"            || fail "agent missing: spec-implementer.md"
test -f "${HOME}/.claude/agents/spec-conformance-evaluator.md"   && ok "agent: spec-conformance-evaluator"  || fail "agent missing: spec-conformance-evaluator.md"
test -f "${HOME}/.claude/commands/harness-init.md"               && ok "command: /harness.init"             || fail "command missing: harness-init.md"
test -f "${HOME}/.claude/commands/harness-catalogue.md"          && ok "command: /harness.catalogue"        || fail "command missing: harness-catalogue.md"
test -f "${HOME}/.claude/commands/spec-implement.md"             && ok "command: /spec.implement"           || fail "command missing: spec-implement.md"
test -f "${HOME}/.claude/commands/spec-reconcile.md"             && ok "command: /spec.reconcile"           || fail "command missing: spec-reconcile.md"
test -f "${HOME}/.claude/commands/feature.md"                    && ok "command: /feature"                  || fail "command missing: feature.md"
test -f "${HOME}/.claude/skills/recall-context/SKILL.md"         && ok "skill: recall-context"              || fail "skill missing: recall-context/SKILL.md"
test -x "${HOME}/.claude/scripts/harness/cognee-shim.sh"         && ok "script: cognee-shim.sh (+x)"        || fail "script missing or not executable: cognee-shim.sh"
test -x "${HOME}/.claude/scripts/harness/cap-subagent-depth.sh"  && ok "script: cap-subagent-depth.sh (+x)" || fail "script missing or not executable: cap-subagent-depth.sh"
test -f "${HOME}/.claude/templates/feature/spec.md"              && ok "template: feature/spec.md"          || fail "template missing: feature/spec.md"

heading "Hooks"
python3 - <<'PY' 2>/dev/null && ok "hook: cap-subagent-depth wired"        || fail "hook missing: cap-subagent-depth"
import json, os, sys
d = json.load(open(os.path.expanduser('~/.claude/settings.json')))
cmds = [h.get('command','') for e in (d.get('hooks',{}).get('PreToolUse') or []) for h in e.get('hooks',[])]
sys.exit(0 if any('cap-subagent-depth' in c for c in cmds) else 1)
PY
python3 - <<'PY' 2>/dev/null && ok "hook: spec-boundary-check wired"       || fail "hook missing: spec-boundary-check"
import json, os, sys
d = json.load(open(os.path.expanduser('~/.claude/settings.json')))
cmds = [h.get('command','') for e in (d.get('hooks',{}).get('PreToolUse') or []) for h in e.get('hooks',[])]
sys.exit(0 if any('spec-boundary-check' in c for c in cmds) else 1)
PY
python3 - <<'PY' 2>/dev/null && ok "hook: knowledge-ingest-queue (PostToolUse) wired" || fail "hook missing: knowledge-ingest-queue post"
import json, os, sys
d = json.load(open(os.path.expanduser('~/.claude/settings.json')))
cmds = [h.get('command','') for e in (d.get('hooks',{}).get('PostToolUse') or []) for h in e.get('hooks',[])]
sys.exit(0 if any('knowledge-ingest-queue' in c and 'post' in c for c in cmds) else 1)
PY
python3 - <<'PY' 2>/dev/null && ok "hook: knowledge-ingest-queue (SessionEnd) wired" || fail "hook missing: knowledge-ingest-queue flush"
import json, os, sys
d = json.load(open(os.path.expanduser('~/.claude/settings.json')))
cmds = [h.get('command','') for e in (d.get('hooks',{}).get('SessionEnd') or []) for h in e.get('hooks',[])]
sys.exit(0 if any('knowledge-ingest-queue' in c and 'flush' in c for c in cmds) else 1)
PY

heading "MCP server"
python3 - <<'PY' 2>/dev/null && ok "MCP: cognee registered in ~/.claude.json" || fail "MCP missing: cognee not in ~/.claude.json"
import json, os, sys
d = json.load(open(os.path.expanduser('~/.claude.json')))
sys.exit(0 if 'cognee' in (d.get('mcpServers') or {}) else 1)
PY

echo
if [ "${FAILED}" = "1" ]; then
  printf '\e[31mverification FAILED\e[0m — see failing checks above.\n' >&2
  exit 1
fi
printf '\e[32mverification PASSED.\e[0m\n'
printf 'Next: in a fresh Claude Code session, smoke-test Cognee:\n\n'
cat <<'SMOKE'
  mcp__cognee__cognify { data: "harness install smoke test", dataset_name: "smoke" }
  mcp__cognee__search { search_query: "what was just stored?", search_type: "GRAPH_COMPLETION", datasets: "smoke" }

Then, in a project you want to onboard:
  /harness.init
  /harness.catalogue
SMOKE
