# Changelog

All notable changes to this project will be documented in this file. The
format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed
- **`/spec.implement`'s review step dispatched `code-reviewer` and `security-reviewer` agents that the harness never shipped.** The final gate (after all tasks land) dispatches both bare-named reviewers, but `claude/agents/` provided neither, so the review step failed with "Agent type not found" in any environment lacking same-named agents. Added both as self-contained harness agents — `code-reviewer` (sonnet; quality/correctness/maintainability) and `security-reviewer` (opus; vulnerabilities the diff introduces) — each review-only (no write tools) and returning a parseable `VERDICT: PASS|FAIL` the loop reads. `graft-files.sh` uses `cp -n`, so a user's own same-named agents are never overwritten. Registered in `verify.sh`/`uninstall.sh`.

### Added
- **`/spec.draft` — draft `spec.md` + `plan.md` from a one-line intent.** Dispatches a new `spec-drafter` agent (default model `claude-fable-5`) to author the spec/plan, filling the gap where `/feature` only scaffolds empty templates. `--compare` drafts the same intent under Fable **and** Opus, writes both to `.harness/drafts/<feature>/{A,B}/` (outside the Cognee ingest set), and a blind `spec-draft-judge` (opus) scores them on a spec-quality rubric — advisory only; you pick the winner, which is promoted into `specs/<feature>/`. The drafter's `model:` line is the swap-point for testing other models in the spec phase.
- **Choice of Cognee embeddings backend at install:** OpenAI API (`text-embedding-3-small`, default) or local Ollama (`nomic-embed-text`). The installer prompts interactively (default OpenAI) or honours a preset `HARNESS_EMBEDDINGS=openai|ollama` for non-interactive runs. `cognee-shim.sh` injects `EMBEDDING_API_KEY` from `$OPENAI_API_KEY` for the OpenAI path (key never written to `~/.cognee/.env`); the Ollama model pull and `:11434` prereq check are skipped when OpenAI is chosen.
- Initial public release: extracted from a private monorepo as a standalone graft-installable harness.
- Agent-executable install runbook in `AGENTS.md`.
- Idempotent phased installer (`install.sh` + `scripts/*`).
- Slash commands: `/harness.init`, `/harness.catalogue`, `/feature`, `/spec.implement`, `/spec.reconcile`.
- Subagents: `spec-implementer`, `spec-conformance-evaluator`.
- `recall-context` skill backed by Cognee KG+RAG.
- Hook scripts: subagent depth cap, spec boundary check, knowledge-ingest queue.
