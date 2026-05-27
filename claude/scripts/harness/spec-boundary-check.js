#!/usr/bin/env node
// spec-boundary-check.js
// PreToolUse hook for Edit / Write. Warns (does NOT block) when the file
// being edited is listed as a `_Boundary:_` file in another feature's
// tasks.md. The goal: surface cross-spec impact before regressions land.
//
// Match config in settings.json:
//   { "matcher": "Edit|Write", "hooks": [...] }
//
// stdin: JSON payload from Claude Code, shape (subject to CC version):
//   { "tool": "Edit"|"Write", "input": { "file_path": "/abs/path" } }
// (We tolerate variants — try several keys before giving up.)
//
// Exit 0 always — warnings go to stderr; we never block edits here.

'use strict';

const fs = require('fs');
const path = require('path');

function readJsonFromStdin() {
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

function listSpecs(repoRoot) {
  const specsDir = path.join(repoRoot, 'specs');
  if (!fs.existsSync(specsDir)) return [];
  return fs
    .readdirSync(specsDir, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name);
}

// Parse `_Boundary:_ path/a.ts, path/b.ts` style annotations from tasks.md.
function extractBoundaries(tasksMdPath) {
  if (!fs.existsSync(tasksMdPath)) return [];
  const text = fs.readFileSync(tasksMdPath, 'utf8');
  const out = [];
  const re = /_Boundary:_\s*([^\n]+)/g;
  let m;
  while ((m = re.exec(text)) !== null) {
    const items = m[1]
      .split(/[,\s]+/)
      .map((s) => s.trim())
      .filter(Boolean);
    out.push(...items);
  }
  return out;
}

function main() {
  const payload = readJsonFromStdin();
  const targetAbs = pickFilePath(payload);
  if (!targetAbs) {
    process.exit(0);
  }

  const repoRoot = findHarnessRoot(path.dirname(targetAbs));
  if (!repoRoot) {
    process.exit(0); // not in an opted-in repo
  }

  const targetRel = path.relative(repoRoot, targetAbs);
  if (targetRel.startsWith('..')) {
    process.exit(0); // edit is outside the repo
  }

  const conflicts = [];
  for (const feature of listSpecs(repoRoot)) {
    const tasksMd = path.join(repoRoot, 'specs', feature, 'tasks.md');
    const bounds = extractBoundaries(tasksMd);
    for (const b of bounds) {
      // crude prefix match on normalized POSIX paths
      const norm = b.replace(/^\.\//, '').replace(/\\/g, '/');
      if (norm && (targetRel === norm || targetRel.startsWith(norm + '/'))) {
        conflicts.push({ feature, boundary: b });
      }
    }
  }

  if (conflicts.length > 0) {
    process.stderr.write(
      '[spec-boundary-check] heads-up: this file is inside another feature\'s _Boundary:_\n'
    );
    for (const c of conflicts) {
      process.stderr.write(
        `  - ${c.boundary}  (specs/${c.feature}/tasks.md)\n`
      );
    }
    process.stderr.write(
      'Re-running the full test suite for those features after the edit is recommended.\n'
    );
  }

  process.exit(0);
}

main();
