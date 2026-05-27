---
description: Retrofit an existing project into the spec-driven harness. Walks the repo, mines decisions from git history + existing docs + TODO comments, drafts a constitution, and seeds docs/memory/decisions/. Run from the repo root after /harness.init. Full design in the harness repo's docs/RETROFIT.md.
---

# /harness.catalogue

Onboard an existing repo into the spec-driven harness by cataloguing prior context. This command is the interactive driver behind the harness repo's `docs/RETROFIT.md`.

## Preconditions

- `pwd` is the root of a git repo.
- `.harness/marker` exists (run `/harness.init` first if not).
- The user has 30–90 minutes — this is a real cataloguing session, not a one-click action.

## Hard rules

1. **Quality over volume.** 10 well-written decision records > 50 vague ones. The Cognee graph extraction is only as good as the source.
2. **Decisions, not commit logs.** Capture *why*, not *what*. Git already has the what.
3. **One file per decision.** `docs/memory/decisions/YYYYMMDD-<slug>.md`, one decision each. No giant aggregated docs.
4. **Never overwrite an existing CLAUDE.md without asking.** Propose a diff; let the user accept/reject.
5. **No subagents.** This is a single orchestrator workflow. If you need to fan out, the user can `/spec.implement` after the catalogue is in place.

## Workflow (you, the orchestrator, walk through these in order)

### Step 1 — Verify opt-in

```
test -f .harness/marker || { echo "Run /harness.init first."; exit 1; }
```

### Step 2 — Survey

Read in this order (use Glob + Read; no Bash unless needed):

1. `package.json` / `Cargo.toml` / `pyproject.toml` / `go.mod` / `pubspec.yaml` / `composer.json` — identifies stack + scripts + tooling.
2. `README.md` — captures stated purpose.
3. `CONTRIBUTING.md`, `ARCHITECTURE.md`, `docs/**/*.md` — existing documentation surface.
4. `.github/workflows/*.yml` — CI signals (test runner, deploy target).
5. Top-level dir listing — what major folders exist.

Time-box this to ~5 minutes. Don't read the source code yet.

### Step 3 — Draft (or refine) `CLAUDE.md`

If `CLAUDE.md` exists and is non-trivial: read it, propose a diff in your reply, and ASK before writing.

If it's missing or boilerplate: draft a new one in your reply (don't write yet), structured as:

```markdown
# <repo name>

> Repo constitution. Keep under ~300 lines.

## What this repo is

(One paragraph: user-facing purpose.)

## Stack

- Language: <…>
- Runtime: <version>
- Package manager: <…>
- Test runner: `<command>`
- Lint/format: <…>
- Deploy target: <…>

## Conventions

- Tests live in <…>.
- File naming: <…>.
- Commit style: <…>.

## Constraints

(Things that would surprise an outsider: env vars required, weird build steps, vendored deps, secrets management.)

## Out of scope for the harness

(Files/dirs that should NOT be auto-ingested into Cognee. Default ingestion is just docs/memory/**, specs/**, CLAUDE.md, so this is rarely needed.)
```

Ask the user to confirm before writing.

### Step 4 — Mine decisions from git

```bash
git log --since="1 year ago" --pretty=format:"%h %ad %s" --date=short -50 > /tmp/harness-catalogue-recent-commits.txt
git log --grep -E -i 'decided|switched|migrate|instead of|because|why' --pretty=format:"%h %ad %s" --date=short > /tmp/harness-catalogue-decision-commits.txt
```

Read both. For each commit that looks like a real decision (not a typo fix, not a dep bump, not a routine refactor), propose a decision record. Use the SHA as the `source:` in frontmatter.

Skip:
- Version bumps unless they were architectural ("upgraded to React 19 to use Server Components").
- Format-only changes ("prettier run").
- Dependent commits that follow up a decision already captured.

### Step 5 — Mine from comments

```bash
git grep -nE '(TODO|HACK|XXX|FIXME|NOTE)' -- '*.{js,ts,py,go,rs,java,kt,swift,rb,php}' | head -100
```

Each comment with rationale is a deferred decision. Capture it as a decision record framed as "we deferred X because Y" with the file:line in `source:`.

### Step 6 — Mine from existing docs

Re-read `README.md`, `CONTRIBUTING.md`, `docs/**`. Any non-trivial decision *embedded* in narrative prose gets pulled out into its own decision record. Cross-link with the source file in `source:`.

### Step 7 — Glossary + runbooks

Ask the user:

1. "What are 3–10 terms an outsider wouldn't know?" → write to `docs/memory/glossary.md`.
2. "What ops procedures do you run more than twice a year?" → one file each in `docs/memory/runbooks/`.

Don't fabricate. If the user says "none right now", skip.

### Step 8 — Write everything

Once the user has approved the constitution and the list of decision records:

- Write `CLAUDE.md` (if approved).
- For each approved decision, write `docs/memory/decisions/YYYYMMDD-<slug>.md` with this frontmatter:

  ```yaml
  ---
  title: <one-line summary>
  date: <YYYY-MM-DD>
  source: <commit SHA | PR URL | file:line | ticket ID>
  ---
  ```

  Body: `## Context`, `## Decision`, `## Why`, optionally `## Implications`.

The PostToolUse hook (`knowledge-ingest-queue.js`) will queue each file as you write it. The next session's recall-context flush will cognify them into the graph.

### Step 9 — Commit + verify

```bash
git add CLAUDE.md docs/memory/ .harness/marker specs/
git status
```

Suggest the commit message:

```
chore: catalogue prior context into spec-driven harness

- Seeded CLAUDE.md with stack + conventions.
- Recorded <N> prior decisions in docs/memory/decisions/.
- Added <M> glossary terms + <K> runbooks.
```

Ask the user to drive the actual `git commit` (you don't auto-commit unless explicitly told).

### Step 10 — First test query

After the user starts a new Claude Code session (so the queue gets flushed):

```text
mcp__cognee__search {
  search_query: "what are the core constraints of this project?",
  search_type: "GRAPH_COMPLETION",
  datasets: "<basename of pwd repo>"
}
```

If the answer is thin or wrong, the corpus is too sparse — return to Step 4/5/6 and add more.

## Done when

- `CLAUDE.md` is faithful and under 300 lines.
- At least 5 decision records exist in `docs/memory/decisions/`.
- Glossary has the project-specific terms.
- A `GRAPH_COMPLETION` search of "core constraints" returns a coherent answer.

After that, the repo is ready for `/speckit.specify` + `/spec.implement` on the next feature.

## Time budget

| Step | Time |
|---|---|
| 1–2 (verify + survey) | 5 min |
| 3 (constitution) | 15 min |
| 4–6 (decisions, ~10–20 records) | 60–90 min |
| 7 (glossary + runbooks) | 20 min |
| 8–10 (write, commit, verify) | 15 min |
| **Total** | **~2 hours for a mid-sized repo** |

This is a one-time cost per repo.
