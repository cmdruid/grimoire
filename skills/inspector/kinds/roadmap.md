# Kind: roadmap

## Discriminator

Any of:

- `tags:` contains `roadmap`
- `doctype:` is `plans` and `tags:` is `[roadmap]`
- shape: named phases with blocking edges, each phase pointing
  at a later plan (or still unplanned)

## Soundness axes

Shared floor in `verbs/review.md`, plus:

- **blocking edges** across phases are complete and acyclic
- each phase has a real verification/gate once planned
- a raw roadmap is not itself walkable — phases need plans

## Groundedness extras

None beyond ground-check + re-read. Substrate-skeptic default
off.

## Refine legal locations

Named phase. Keep phase ids stable. A coverage gap may append
the next unused phase id. A new requirement → **park** (belongs
on the spec). Do not compile a runbook here.
