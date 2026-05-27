#!/usr/bin/env node
// knowledge-ingest-queue.js
// Ingest queue for the Cognee KG+RAG memory backend.
//
// Backend: Cognee with a configurable LLM (default Anthropic Haiku for
// structured graph extraction) and local Ollama embeddings (default
// nomic-embed-text). All Cognee invocations go through
// ~/.claude/scripts/harness/cognee-shim.sh, which derives LLM_API_KEY
// from $ANTHROPIC_API_KEY and sources ~/.cognee/.env. The MCP server
// (registered in ~/.claude.json as 'cognee') shares the same
// DATA_ROOT_DIRECTORY, so what we add+cognify here is queryable via
// mcp__cognee__* tools next session.
//
//   • post mode (PostToolUse on Edit/Write):
//       reads stdin JSON; if the file_path lives in an opted-in repo's
//       docs/memory/** or specs/** (or is CLAUDE.md), append "<kb>\t<path>"
//       to ~/.claude/state/knowledge-queue.txt. Dedup. Fast — no network.
//
//   • flush mode (SessionEnd):
//       Best-effort: leave the queue intact for the next orchestrator turn
//       to drain via MCP. Print a one-line summary to stderr so the user
//       can see what's pending. (No shell-out is possible.)
//
// Settings.json wires it as:
//   PostToolUse: matcher "Edit|Write",  command: "... knowledge-ingest-queue.js post"
//   SessionEnd:  matcher "*",           command: "... knowledge-ingest-queue.js flush"

'use strict';

const fs = require('fs');
const path = require('path');

const HOME = process.env.HOME || require('os').homedir();
const QUEUE = path.join(HOME, '.claude', 'state', 'knowledge-queue.txt');
const STATE_DIR = path.dirname(QUEUE);

function readStdinJson() {
  try {
    const raw = fs.readFileSync(0, 'utf8');
    return raw ? JSON.parse(raw) : {};
  } catch (_) {
    return {};
  }
}

function pickFilePath(payload) {
  const candidates = [
    payload?.input?.file_path,
    payload?.tool_input?.file_path,
    payload?.params?.file_path,
    payload?.file_path,
  ];
  return candidates.find((v) => typeof v === 'string' && v.length > 0) || null;
}

function findHarnessRoot(start) {
  let dir = path.resolve(start);
  while (dir !== '/' && dir.length > 0) {
    if (fs.existsSync(path.join(dir, '.harness', 'marker'))) return dir;
    dir = path.dirname(dir);
  }
  return null;
}

function shouldIngest(absPath, repoRoot) {
  if (!absPath.endsWith('.md')) return false;
  const rel = path.relative(repoRoot, absPath);
  if (rel.startsWith('..')) return false;
  return (
    rel.startsWith('docs/memory/') ||
    rel.startsWith('specs/') ||
    rel === 'CLAUDE.md'
  );
}

function enqueue() {
  const payload = readStdinJson();
  const target = pickFilePath(payload);
  if (!target) return;

  const repoRoot = findHarnessRoot(path.dirname(target));
  if (!repoRoot) return;
  if (!shouldIngest(target, repoRoot)) return;

  fs.mkdirSync(STATE_DIR, { recursive: true });
  const kb = path.basename(repoRoot);
  const line = `${kb}\t${target}`;

  let existing = '';
  try {
    existing = fs.readFileSync(QUEUE, 'utf8');
  } catch (_) {}
  if (existing.split('\n').includes(line)) return;

  fs.appendFileSync(QUEUE, line + '\n');
}

function flush() {
  if (!fs.existsSync(QUEUE)) return;

  const lines = fs
    .readFileSync(QUEUE, 'utf8')
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean);

  if (lines.length === 0) {
    try {
      fs.unlinkSync(QUEUE);
    } catch (_) {}
    return;
  }

  // Cognee uses Ladybug for the graph store, which is single-writer. While
  // the cognee-mcp server is running it holds the lock, so a shell-out to
  // cognee-cli from this hook would race-lock and fail. Instead, this hook
  // just leaves the queue intact for the orchestrator (recall-context skill)
  // to drain via the MCP tools (mcp__cognee__add + mcp__cognee__cognify)
  // next session. The MCP server already has the lock; calling through it
  // is the only safe path.
  process.stderr.write(
    `[knowledge-ingest] ${lines.length} file(s) pending — orchestrator will flush via mcp__cognee__add+cognify next session (recall-context skill).\n`
  );
}

const mode = (process.argv[2] || '').toLowerCase();
try {
  if (mode === 'flush') flush();
  else enqueue();
} catch (e) {
  process.stderr.write(`[knowledge-ingest] ${e.message}\n`);
}
process.exit(0);
