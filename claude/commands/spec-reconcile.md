---
description: After /spec.implement completes, diff the actual implementation against specs/<feature>/spec.md and append an `## Implementation Notes` section capturing any deliberate deviations, so the spec stays a faithful description of what's in the code. Args - "<feature-name>".
---

# /spec.reconcile

Specs that lie are worse than no specs. This command makes the spec faithful again.

## Steps

1. Verify `.harness/marker` exists; refuse otherwise.
2. Locate `specs/<feature>/spec.md`. Refuse if absent.
3. Build the diff of what landed: `git diff <merge-base of feature branch with main>` (if you're on a feature branch) or `git diff HEAD~<N>` covering the implement loop's commits.
4. For each acceptance criterion in `spec.md`, decide:
   - **Matches the impl** → no change to the spec.
   - **Impl is correct but went a different route** → append a line to `## Implementation Notes` (create the section if missing) explaining what landed and why it's still acceptable.
   - **Impl violates the criterion** → STOP. Output a FAIL report — do not silently update the spec to match buggy code. The user decides whether to fix the code or amend the spec.
5. Never change requirements or acceptance criteria here. Only append to `## Implementation Notes`. If the spec needs requirement changes, the user should re-run `/speckit.specify` for a new pass.
6. Save `spec.md`. The PostToolUse Cognee hook will re-ingest it automatically.

## Output

```
FEATURE: <name>
RECONCILED: yes | no (FAIL)
NOTES APPENDED:
  - <criterion-id>: <one-line summary of what landed differently>
  ...
SPEC HEALTH: clean | needs-user-decision
  <if needs-user-decision, list the conflicting criteria>
```
