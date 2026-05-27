---
name: recall-context
description: Use at the start of orchestrator turns and before dispatching specialists. Queries the Cognee KG+RAG MCP server for the current repo's dataset and returns structured context (decisions, runbooks, glossary terms, adjacent specs) that the orchestrator folds into the next subagent's prompt. Do NOT use inside leaf executors — the orchestrator pre-loads recall and passes it down.
---

# recall-context

Surface relevant prior context from the centralized Cognee store before deciding what to do next.

Backend stack:
- **LLM** (graph extraction during ingest + GRAPH_COMPLETION at query): configured in `~/.cognee/.env`. Default is Anthropic Haiku via `$ANTHROPIC_API_KEY`.
- **Embeddings**: configured in `~/.cognee/.env`. Default is local Ollama `nomic-embed-text`; Ollama uses your GPU automatically if one is available.
- **MCP server**: `cognee` (registered in `~/.claude.json`), runs `cognee-shim.sh cognee-mcp --transport stdio`.

## When to use

- Beginning of a session where the user references prior work ("the auth thing", "what we decided last week").
- Right before `/spec.implement` dispatches the first specialist — pre-load decisions and glossary.
- Right before `/spec.reconcile` — surface adjacent specs that the impl might have stepped on.

## When NOT to use

- Inside `spec-implementer`, `test-runner`, `spec-conformance-evaluator`, or any leaf executor. They receive recall *from* the orchestrator and must not query the graph themselves. (This keeps depth = 1 honest and prevents recall floods.)
- For trivial single-file lookups the user can grep faster.

## How to call

Primary tool: `mcp__cognee__search`. Arguments (Cognee 1.0 surface):

```json
{
  "query": "<the actual question, in natural language>",
  "query_type": "GRAPH_COMPLETION",
  "datasets": ["<basename of pwd repo>"]
}
```

- `query_type=GRAPH_COMPLETION` returns a synthesized answer from the graph (best for "what did we decide about X").
- `query_type=CHUNKS` returns raw matching text fragments (best for verbatim recall).
- `datasets` is non-negotiable — pass the repo basename for scoped recall; pass multiple only when the user explicitly asks for cross-project context.

## Pre-query queue flush

If `~/.claude/state/knowledge-queue.txt` exists and is non-empty, the SessionEnd hook leaves it for the next orchestrator turn to drain. You may need to flush it manually via MCP:

For each `<dataset>\t<file>` line:
1. `mcp__cognee__add { data: file, dataset_name: dataset }`
2. After all adds in a dataset: `mcp__cognee__cognify { datasets: [dataset] }`
3. Truncate the queue file.

This is the "hooks queue, orchestrator/MCP flushes" pattern.

## Result handling

Always cite source paths from the result back into the orchestrator's prompt; never paraphrase without attribution. Format the hand-off:

```
RELEVANT PRIOR CONTEXT (cognee, dataset=<name>):
  - <one-line synthesis>
SOURCES:
  - <path/to/source1.md>
  - <path/to/source2.md>
```

## Failure modes

- **MCP server not configured** (no `mcp__cognee__*` tools available): fall back to `Grep` over `docs/memory/` and `specs/` in the repo. Do not block.
- **Empty result**: don't fabricate. State "no prior context found" and proceed.
- **Slow ingest**: graph extraction calls the configured LLM per chunk. Large markdown files can take seconds to ingest. SessionEnd will absorb it; orchestrator turns don't wait.
