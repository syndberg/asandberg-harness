# Architecture

The harness is three layers of code wired together by Claude Code's hook + MCP system.

```
┌──────────────────────────────────────────────────────────────┐
│  Orchestrator (Claude Code session, your active model)       │
│                                                              │
│   reads:  recall-context skill → mcp__cognee__search         │
│   writes: /spec.implement loop, /spec.reconcile, /feature    │
│                                                              │
│   dispatches (depth = 1):                                    │
│     ├─ spec-implementer    (sonnet, writes one task TDD)     │
│     ├─ test-runner         (external; standard CC harness)   │
│     └─ spec-conformance-evaluator (opus, grades PASS/FAIL)   │
└─────────────────────┬────────────────────────────────────────┘
                      │                          ▲
            file edits│                          │recall queries
                      ▼                          │
┌──────────────────────────────────────────────────────────────┐
│  Hooks (PreToolUse / PostToolUse / SessionEnd)               │
│                                                              │
│   • cap-subagent-depth.sh      blocks nested Agent calls     │
│   • spec-boundary-check.js     warns on cross-feature edits  │
│   • knowledge-ingest-queue.js  queues memory-dir writes      │
└─────────────────────┬────────────────────────────────────────┘
                      │
        appends lines │
                      ▼
              ~/.claude/state/knowledge-queue.txt
                      │
        drained next  │
        orchestrator  │
        turn via      │
        recall-context│
        skill         │
                      ▼
┌──────────────────────────────────────────────────────────────┐
│  Cognee MCP server  (registered as `cognee`)                 │
│                                                              │
│   • LLM:        Anthropic (graph extraction + completion)    │
│   • Embeddings: local Ollama nomic-embed-text                │
│   • Graph:      Ladybug (single-writer, in ~/.cognee/system) │
│   • Vectors:    LanceDB                                      │
└──────────────────────────────────────────────────────────────┘
```

## The three loops

### 1. Implementation loop (`/spec.implement <feature>`)

For each task in `specs/<feature>/tasks.md`:

```
attempt = 0
while attempt < 3:
  spec-implementer writes failing test (RED) → impl (GREEN), runs tests
  if tests fail → feedback to next attempt
  spec-conformance-evaluator reads diff, grades each acceptance criterion
  if VERDICT == PASS → next task
  else → feedback to next attempt
if attempt == 3 → halt, surface all 3 attempts to the user
```

The implementer and evaluator are separate agents on purpose: agents are optimistic about their own output, so the gate is run by a model that didn't write the code.

### 2. Memory ingest loop

```
PostToolUse on Edit/Write
  → knowledge-ingest-queue.js post
  → if file is in docs/memory/**, specs/**, or CLAUDE.md of an opted-in repo
  → append "<repo-basename>\t<absolute-path>" to ~/.claude/state/knowledge-queue.txt

SessionEnd
  → knowledge-ingest-queue.js flush
  → just prints "N files pending"; the actual ingest happens NEXT session via MCP

Next orchestrator turn
  → recall-context skill reads the queue
  → for each line: mcp__cognee__add { data, dataset_name }
  → mcp__cognee__cognify { datasets: [<dataset>] }
  → truncate queue
```

Why "queue now, ingest later"? Cognee uses the Ladybug graph store, which is single-writer. While the `cognee-mcp` server is running it holds the lock; a shell-out to `cognee-cli` from the hook would race-lock and fail. The MCP server is the only safe writer, so we wait for the orchestrator turn that can call it.

### 3. Boundary-check loop

```
PreToolUse on Edit/Write
  → spec-boundary-check.js
  → if the file is listed under _Boundary:_ in another feature's tasks.md
  → print a heads-up to stderr (never blocks)
```

The check is a warning, not a gate. Cross-feature edits are sometimes intentional; the heads-up tells the user (and the orchestrator) which other tests to re-run.

## Where things live

| Path                                    | Purpose                                              |
|-----------------------------------------|------------------------------------------------------|
| `~/.claude/agents/spec-*.md`            | Subagent definitions                                 |
| `~/.claude/commands/{harness,spec,feature}-*.md` | Slash commands                              |
| `~/.claude/skills/recall-context/`      | Pre-dispatch recall skill                            |
| `~/.claude/scripts/harness/*.{sh,py,js}`| Hook + helper scripts                                |
| `~/.claude/templates/feature/`          | `/feature start` scaffold templates                  |
| `~/.claude/state/in-subagent`           | Marker; presence = depth cap active                  |
| `~/.claude/state/knowledge-queue.txt`   | Pending ingests for next orchestrator turn           |
| `~/.cognee/`                            | Cognee data root: graph + vectors + cache + .env     |
| `~/.claude.json`                        | MCP server registration (`cognee`)                   |
| `~/.claude/settings.json`               | Hook entries (additive to your existing config)      |
| `<repo>/.harness/marker`                | Opt-in flag for hooks to engage                      |
| `<repo>/docs/memory/decisions/`         | Decision records (one per file, frontmatter + body)  |
| `<repo>/docs/memory/runbooks/`          | Operational recipes                                  |
| `<repo>/docs/memory/glossary.md`        | Domain terms                                         |
| `<repo>/specs/<feature>/`               | `spec.md`, `plan.md`, `tasks.md` per feature         |
| `<repo>/.claude/evals/<feature>.md`     | Eval suite for a feature                             |

## Design choices worth knowing

- **Cognee, not a vector DB alone.** Cognee builds a graph from your prose, then queries answer via graph completion. This makes "what were we thinking about X" answerable, not just "find similar text."
- **One dataset per repo.** Recall is scoped to the current repo by default (`datasets: [<basename of pwd>]`). Cross-repo recall is opt-in.
- **Depth = 1.** Specialists never spawn subagents. Keeps cost/latency predictable and makes failure modes traceable.
- **The hook only queues; the MCP only ingests.** This separation exists because Ladybug is single-writer; trying to write from both `cognee-cli` (in the hook) and `cognee-mcp` (in the server) races the lock.
- **No spec rewriting during impl.** Only `/spec.reconcile` (the last step) edits `spec.md`, and only by appending an `## Implementation Notes` section. The spec stays a contract, not a moving target.
