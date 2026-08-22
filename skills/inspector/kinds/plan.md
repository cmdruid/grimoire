# Kind: plan

## Discriminator

Any of:

- `tags:` contains `plan` (and not `roadmap` / `runbook` as the
  sole tag)
- `doctype:` is `plans` and `tags:` is `[plan]`
- shape: named slices with verify commands, a tracer first
  slice, blocking edges

## Soundness axes

Shared floor in `verbs/review.md`, plus:

- **tracer slices**: slice 1 is the thinnest end-to-end path;
  later slices widen; each is independently testable
- **blocking edges** are complete and acyclic; each slice has a
  real verification/gate
- open decision branches do not belong here — they belong on
  the spec

## Groundedness extras

Substrate-skeptic is **default off**; turn it on only when a
plan claims a mechanism shaped by deletable substrate, then ask
*which mechanisms would not exist in a from-scratch
implementation?* Re-read every load-bearing signature at `HEAD`
before trusting a size or path.

## Refine legal locations

Named slice. Keep slice ids stable. A coverage gap (a spec
requirement with no slice) may append a slice with the next
unused id. A new requirement, an open decision branch →
**park** (belongs on the spec, not a `keep` row). Complete the
edited unit (no "similar to slice N"). Keep a verification
step on every slice you touch.
