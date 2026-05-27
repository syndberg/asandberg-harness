#!/usr/bin/env python3
"""register-mcp.py

Phase 5 of the harness installer.

Idempotently registers the Cognee MCP server in ~/.claude.json.
Re-running is a no-op (skips registration if already present).
Always writes a timestamped backup before modifying.

The MCP server entry points at ~/.claude/scripts/harness/cognee-shim.sh, which
must already be installed (Phase 3 — graft-files.sh).
"""
from __future__ import annotations

import json
import shutil
import sys
import time
from pathlib import Path

CLAUDE_JSON = Path.home() / ".claude.json"
SHIM = Path.home() / ".claude" / "scripts" / "harness" / "cognee-shim.sh"


def main() -> int:
    if not SHIM.exists():
        print(
            f"[register-mcp] FAIL: {SHIM} not found. Run scripts/graft-files.sh first.",
            file=sys.stderr,
        )
        return 1

    if not CLAUDE_JSON.exists():
        print(
            f"[register-mcp] {CLAUDE_JSON} does not exist yet.\n"
            "Launch Claude Code at least once to create it, then re-run this phase.",
            file=sys.stderr,
        )
        return 2

    try:
        data = json.loads(CLAUDE_JSON.read_text())
    except json.JSONDecodeError as e:
        print(f"[register-mcp] FAIL: {CLAUDE_JSON} is not valid JSON: {e}", file=sys.stderr)
        return 1

    servers = data.setdefault("mcpServers", {})
    if "cognee" in servers:
        print("[register-mcp] cognee already registered — leaving as-is.")
        return 0

    backup = CLAUDE_JSON.with_suffix(f".json.bak-{int(time.time())}")
    shutil.copy(CLAUDE_JSON, backup)
    print(f"[register-mcp] backup: {backup}")

    servers["cognee"] = {
        "command": str(SHIM),
        "args": ["cognee-mcp", "--transport", "stdio"],
        "env": {},
    }
    CLAUDE_JSON.write_text(json.dumps(data, indent=2) + "\n")
    print(f"[register-mcp] registered cognee MCP server in {CLAUDE_JSON}")
    print("[register-mcp] next phase: ask user to restart Claude Code, then scripts/verify.sh")
    return 0


if __name__ == "__main__":
    sys.exit(main())
