#!/usr/bin/env bash
# cap-subagent-depth.sh
# PreToolUse hook on the Agent / Task tool. Enforces depth cap = 1: the
# orchestrator may dispatch one level of specialists; specialists may NOT
# spawn further subagents. They must return to the orchestrator instead.
#
# Mechanism: the dispatching command (e.g. /spec.implement) creates
# ~/.claude/state/in-subagent before each Agent call and removes it after
# the call returns. While the marker exists, this hook blocks new Agent
# calls. The orchestrator's own dispatches set
# CLAUDE_HARNESS_ALLOW_NESTED=1 for that single call.
#
# Exit codes per Claude Code hook protocol:
#   0  = allow
#   2  = block (stderr is shown to the model)
set -u

MARKER="${HOME}/.claude/state/in-subagent"

# Explicit override for the orchestrator's own dispatches.
if [ "${CLAUDE_HARNESS_ALLOW_NESTED:-0}" = "1" ]; then
  exit 0
fi

# No marker -> orchestrator turn -> allow.
if [ ! -f "${MARKER}" ]; then
  exit 0
fi

cat <<'MSG' >&2
[cap-subagent-depth] Subagent depth cap reached (max 1 level).

Specialists must return to the orchestrator rather than spawning further
subagents. Report your findings and a recommended next step; let the
orchestrator decide what to dispatch.

Override (rare): set CLAUDE_HARNESS_ALLOW_NESTED=1 for the specific call.
MSG
exit 2
