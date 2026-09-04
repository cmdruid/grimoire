# Kind: plan

## Discriminator

Any of:

- `tags:` contains `plan` (and not `roadmap` / `runbook` as the
  sole tag)
- `doctype:` is `plans` and `tags:` is `[plan]`
- shape: one or more named implementation units with verification; multiple units may declare
  blocking edges

## Soundness axes

Shared floor in `verbs/review.md`, plus:

- **proportionate decomposition**: An atomic plan is valid for bounded work. When several slices are
  useful, the first proves the riskiest path and later slices widen only as required; each is
  independently testable where that separation has value
- **blocking edges** are complete and acyclic when multiple slices depend on one another; every
  implementation unit has a real verification/gate
- Every slice must map to a requirement or acceptance check inside the inherited review boundary;
  independent cleanup and architectural improvements are follow-ups, not slices

## Groundedness extras

These extras are the review's light/deep dial. They stay off on a light review. An explicit deep
review re-reads every load-bearing signature at `HEAD` before trusting a size or path.

## Review continuation

revision-after-review: offered

## Revision legal locations

Named implementation unit. Keep existing slice ids stable. An atomic plan may remain atomic. Only an
uncovered in-boundary requirement necessary for acceptance may append a slice with the next unused
id. A new requirement, independent improvement, or open decision branch → **park** or `push-back` as
the shared boundary rules require; it never becomes a new slice. Complete the edited unit (no
"similar to slice N"). Keep a verification step on every slice you touch.
