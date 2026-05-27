#!/usr/bin/env python3
"""merge-settings.py

Phase 4 of the harness installer.

Idempotently merges the harness hook entries into ~/.claude/settings.json
without touching any existing keys. Always writes a timestamped backup first.

Adds (if not already present):
  PreToolUse  : Agent|Task   -> cap-subagent-depth.sh
  PreToolUse  : Edit|Write   -> spec-boundary-check.js
  PostToolUse : Edit|Write   -> knowledge-ingest-queue.js post
  SessionEnd  : *            -> knowledge-ingest-queue.js flush

Re-running is a no-op.
"""
from __future__ import annotations

import json
import os
import shutil
import sys
import time
from pathlib import Path

SETTINGS = Path.home() / ".claude" / "settings.json"
HOME = str(Path.home())


ADDITIONS = {
    "PreToolUse": [
        ("Agent|Task",  f"{HOME}/.claude/scripts/harness/cap-subagent-depth.sh"),
        ("Edit|Write",  f"node {HOME}/.claude/scripts/harness/spec-boundary-check.js"),
    ],
    "PostToolUse": [
        ("Edit|Write",  f"node {HOME}/.claude/scripts/harness/knowledge-ingest-queue.js post"),
    ],
    "SessionEnd": [
        ("*",           f"node {HOME}/.claude/scripts/harness/knowledge-ingest-queue.js flush"),
    ],
}


def main() -> int:
    if not SETTINGS.exists():
        print(
            f"[merge-settings] {SETTINGS} does not exist yet.\n"
            "Launch Claude Code at least once to create it, then re-run this phase.",
            file=sys.stderr,
        )
        return 2

    try:
        data = json.loads(SETTINGS.read_text())
    except json.JSONDecodeError as e:
        print(f"[merge-settings] FAIL: {SETTINGS} is not valid JSON: {e}", file=sys.stderr)
        return 1

    backup = SETTINGS.with_suffix(f".json.bak-{int(time.time())}")
    shutil.copy(SETTINGS, backup)
    print(f"[merge-settings] backup: {backup}")

    hooks = data.setdefault("hooks", {})
    added = 0
    for event, entries in ADDITIONS.items():
        bucket = hooks.setdefault(event, [])
        existing = {h.get("command", "") for e in bucket for h in e.get("hooks", [])}
        for matcher, command in entries:
            if command in existing:
                continue
            bucket.append({
                "matcher": matcher,
                "hooks": [{"type": "command", "command": command}],
            })
            print(f"[merge-settings] add: {event:11s}  matcher={matcher:11s}  -> {command}")
            added += 1

    if added == 0:
        print("[merge-settings] nothing to add — all hooks already present.")
    else:
        SETTINGS.write_text(json.dumps(data, indent=2) + "\n")
        print(f"[merge-settings] wrote {SETTINGS} (+{added} entries)")

    print("[merge-settings] next phase: scripts/register-mcp.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
