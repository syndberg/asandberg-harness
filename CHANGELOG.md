# Changelog

All notable changes to this project will be documented in this file. The
format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Initial public release: extracted from a private monorepo as a standalone graft-installable harness.
- Agent-executable install runbook in `AGENTS.md`.
- Idempotent phased installer (`install.sh` + `scripts/*`).
- Slash commands: `/harness.init`, `/harness.catalogue`, `/feature`, `/spec.implement`, `/spec.reconcile`.
- Subagents: `spec-implementer`, `spec-conformance-evaluator`.
- `recall-context` skill backed by Cognee KG+RAG.
- Hook scripts: subagent depth cap, spec boundary check, knowledge-ingest queue.
