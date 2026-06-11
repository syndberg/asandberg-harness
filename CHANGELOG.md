# Changelog

All notable changes to this project will be documented in this file. The
format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **Choice of Cognee embeddings backend at install:** OpenAI API (`text-embedding-3-small`, default) or local Ollama (`nomic-embed-text`). The installer prompts interactively (default OpenAI) or honours a preset `HARNESS_EMBEDDINGS=openai|ollama` for non-interactive runs. `cognee-shim.sh` injects `EMBEDDING_API_KEY` from `$OPENAI_API_KEY` for the OpenAI path (key never written to `~/.cognee/.env`); the Ollama model pull and `:11434` prereq check are skipped when OpenAI is chosen.
- Initial public release: extracted from a private monorepo as a standalone graft-installable harness.
- Agent-executable install runbook in `AGENTS.md`.
- Idempotent phased installer (`install.sh` + `scripts/*`).
- Slash commands: `/harness.init`, `/harness.catalogue`, `/feature`, `/spec.implement`, `/spec.reconcile`.
- Subagents: `spec-implementer`, `spec-conformance-evaluator`.
- `recall-context` skill backed by Cognee KG+RAG.
- Hook scripts: subagent depth cap, spec boundary check, knowledge-ingest queue.
