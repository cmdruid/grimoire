# Kind: spec

## Discriminator

`founding` is **not** in `tags:` (founding matches first). And any
of:

- `tags:` contains `spec`
- `doctype:` is `specs` or `spec`
- shape: structural H2 set includes Problem, Goal, Approach,
  Mechanism, Verification (feature-spec body)

A design doc with that shape and no job `tags:` (`plan` /
`roadmap` / `runbook`) matches here.

## Soundness axes

Shared floor in `verbs/review.md`, plus:

- the mechanism is implementable as written from this file
- the mechanism covers the declared outcome without adding independent work or violating explicit
  non-goals
- optional **Slices** stub (id / verify command / paths) is
  consistent with Mechanism when present
- a numeric before/after acceptance target attributes its
  population to the mechanism's target class

## Groundedness extras

Substrate-skeptic is **default off**. Turn it on only for an explicit deep, greenfield, or refactoring review.
In that mode, ask which mechanisms would not exist in a from-scratch
implementation. Otherwise, deletable legacy substrate outside the declared outcome is a follow-up,
not a verdict-bearing finding.

## Review continuation

revision-after-review: automatic-proposal

## Revision legal locations

Named section: Problem / Goal / Approach / Mechanism /
Verification / Slices. Keep section headings and slice ids
stable. A coverage gap (a Goal requirement with no Mechanism)
may fill Mechanism or append a Slices row with the next unused id only when the requirement is
inside the review boundary and necessary for acceptance. A new requirement, an either/or this spec has not settled
→ **park** (belongs on grill, not a `keep` row). A finding
aimed at sequencing, slice order, or a walk → `push-back`
(wrong owner).
