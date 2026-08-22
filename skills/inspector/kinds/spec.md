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
- scope is one feature's worth
- optional **Slices** stub (id / verify command / paths) is
  consistent with Mechanism when present
- a numeric before/after acceptance target attributes its
  population to the mechanism's target class

## Groundedness extras

Substrate-skeptic **on**: grounding anchors the review to the
present code, so deliberately ask its inverse — *which
mechanisms would not exist in a from-scratch implementation?*
A mechanism shaped by deletable substrate (a code built-in, an
integer pipeline, a frozen baseline) is a finding even when
every claim about `HEAD` is true.

## Refine legal locations

Named section: Problem / Goal / Approach / Mechanism /
Verification / Slices. Keep section headings and slice ids
stable. A coverage gap (a Goal requirement with no Mechanism)
may fill Mechanism or append a Slices row with the next unused
id. A new requirement, an either/or this spec has not settled
→ **park** (belongs on grill, not a `keep` row). A finding
aimed at sequencing, slice order, or a walk → `push-back`
(wrong owner).
