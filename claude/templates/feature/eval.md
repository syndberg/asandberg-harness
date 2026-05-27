# {{NAME}} — Eval suite

> Mirrors `specs/{{NAME}}/spec.md` acceptance criteria. Keep them in sync.

<!--
This file is consumed by /eval check {{NAME}}.

The capability evals below should map 1:1 to the acceptance criteria in
specs/{{NAME}}/spec.md. If you change the spec, update here too.

Grader types:
  - code:  deterministic shell/script check
  - rule:  regex / schema / structural check
  - model: LLM-as-judge with a rubric
  - human: manual review escalation
-->

## Capability evals

| #  | Acceptance criterion (from spec) | Grader | Check | Status |
|----|----------------------------------|--------|-------|--------|
| 1  |                                  | code   |       | pending |
| 2  |                                  | model  |       | pending |
| 3  |                                  |        |       | pending |

### Grader details

#### #1 — <criterion>

**Grader:** code

```bash
# Deterministic check. Exit 0 = pass.
```

**Pass condition:** describe what success looks like.

---

#### #2 — <criterion>

**Grader:** model

**Rubric (1–5 scale):**
- 1 = does not address the criterion
- 3 = addresses but with issues
- 5 = fully addresses and well-formed

**Pass condition:** model grader returns ≥ 4 on majority of trials.

---

## Regression evals

<!--
Existing behavior that must not break. Each is a fixed test against current
behavior. Update only when intentional behavior change ships.
-->

- [ ] <existing behavior 1>
- [ ] <existing behavior 2>

## Behavioral assertions

<!--
Deterministic constraints orthogonal to capability:
output schema validity, banned tokens, required fields, latency budget,
cost budget. Cheap to run; gate on these first.
-->

- [ ] Output is valid JSON matching schema X
- [ ] Response time p95 < N ms
- [ ] Token cost per call < $X

## Targets

| Metric | Target |
|--------|--------|
| pass@1 on capability suite     | ≥ 0.80 |
| pass@3 on capability suite     | ≥ 0.95 |
| pass^3 on regression-critical  | 1.00   |
| Behavioral assertions          | 100%   |

## Run log

<!--
/eval check appends here. Each row = one run.
-->

| Date | pass@1 | pass@3 | Notes |
|------|--------|--------|-------|
|      |        |        |       |
