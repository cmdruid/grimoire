# Kind: runbook

## Discriminator

Any of:

- `tags:` contains `runbook`
- `doctype:` is `plans` and `tags:` is `[runbook]`
- shape: a conductor list of existing plan paths (roadmap-
  sourced) or of steps (plan-sourced)

## Soundness axes

A thinner pass. Shared floor in `verbs/review.md` only where
it still applies (contradiction, unambiguous requirements).
Confirm the completeness check: plan-sourced vs roadmap-
sourced — every referenced plan path exists; every unblocked
phase already has a plan path. This pass does **not** replace
plan critique of the referenced plans.

## Groundedness extras

None beyond ground-check + re-read of the referenced plan
paths.

## Refine legal locations

Named conductor step. Keep step ids stable. A coverage gap may
append the next unused step. A new requirement → **park**. Do
not invent a missing plan path as a `keep` row — that belongs
on the roadmap or the missing plan.
