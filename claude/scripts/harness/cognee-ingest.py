#!/usr/bin/env python3
"""cognee-ingest.py

Add + cognify a single file into a Cognee dataset using the Python SDK
directly (avoids the cognee-cli path which triggers an upstream bug in
Cognee 1.0.9's anthropic adapter — `ontology_file_path` leaks to
`AsyncMessages.create()`).

Run via the shim so env vars are right:
    cognee-shim.sh cognee-ingest.py <dataset> <file>

The shim execs whatever's on the PATH; this file lives at a known location
and gets invoked through Cognee's venv Python (which has `cognee` + `anthropic`
+ `transformers` installed). Shebang resolves to the right interpreter when
called directly by absolute path with the venv on PATH.
"""
from __future__ import annotations

import asyncio
import os
import sys


async def _run(dataset: str, file_path: str) -> int:
    # Imported lazily so a quick `python cognee-ingest.py` without env
    # doesn't pay the cognee init cost just to print a usage error.
    import cognee  # type: ignore

    await cognee.add(file_path, dataset_name=dataset)
    res = await cognee.cognify([dataset])
    if not res:
        print(f"[cognee-ingest] no pipeline result for dataset={dataset}", file=sys.stderr)
        return 1
    status = next(iter(res.values())).status
    if status != "PipelineRunCompleted":
        print(f"[cognee-ingest] cognify status={status} for {file_path}", file=sys.stderr)
        return 2
    return 0


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: cognee-ingest.py <dataset> <file>", file=sys.stderr)
        return 64
    dataset, file_path = sys.argv[1], sys.argv[2]
    if not os.path.isfile(file_path):
        print(f"[cognee-ingest] file not found: {file_path}", file=sys.stderr)
        return 66
    if not os.environ.get("LLM_API_KEY"):
        print("[cognee-ingest] LLM_API_KEY not set in env", file=sys.stderr)
        return 78
    return asyncio.run(_run(dataset, file_path))


if __name__ == "__main__":
    sys.exit(main())
