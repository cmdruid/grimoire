---
doctype: design
status: done
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# blueprint `revise` — Spec

Shipped 2026-08-18 on stream `grok`: add blueprint revise
spec; add revise and close the review loop. File-mode
close — no ledger on this host.

Settled 2026-08-18 on stream `grok`. Ports the contractor
`revise` machine onto blueprint's artifact set. The human
named this unit after contractor `revise` landed on the
branch. Small feature: this file doubles as the plan.

Governing sibling machine (read, do not paste):
`docs/design/2026-08-18-contractor-revise.md` and live
`skills/contractor/verbs/revise.md`.

## Problem

`/blueprint review` can judge a spec (or design, or ADR)
and cannot **own the fold** when the judgment is
`needs-rework`. The receiving-side list still lives in
`SKILL.md` under *Acting on review feedback* — the same
hole contractor just closed for plans.

Agents improvise the amend. The improvisation is the hole:
a fold is unverified content, the same session is the
author, and `review` still writes nothing on `approve`, so
there is no durable "passed" stamp.

The contractor spec parked this unit on purpose: a
`revise` on specs / design docs belongs with the spec's
owner, not contractor.

## Goal

`/blueprint revise` is the only legal path from a
`needs-rework` spec (or design, or ADR) back to a
candidate for `review`. It classifies findings with the
human, amends the original artifact in place, records
dispositions, and **stops**. It does not run `review`.
It does not sequence implementation.

One feature. No new skill. No second remediation document.
No status promotion to `current`.

## Approach

**Chosen:** a new `revise` verb on blueprint, as
`verbs/revise.md`. Same machine as contractor `revise`
(resolver, classify-then-ask, in-place amend, dispositions,
thrash brake, stop-and-offer). `review` (inline in
`SKILL.md`) gains the dated verdict stamp on every verdict
and drops the five-step receiving list for a pointer.

**Rejected: fold inside `review`.** Same reason as
contractor: the judge is not the author.

**Rejected: share contractor's `revise.md`.** Wrong
artifact set, and a leaf must not name a sibling for its
procedure.

**Rejected: keep revise inline in `SKILL.md`.** The
procedure is a long numbered walk; `new` and `deploy`
already live in `verbs/` for that reason. `review` stays
inline (it already is); `revise` is the new long walk.

**Rejected: a `build` refuse on blueprint.** Blueprint
does not walk a job. After `revise`, the offer is
`review` or a human waive — the host sequences, or the
human accepts the spec.

**Rejected: auto-promote `status: current`.** Same as
contractor. After a fold the artifact stays `open` until
a later `review` approves (or the human waives) and
someone promotes it.

## Mechanism

### Same as contractor `revise` (do not fork)

Copy the contractor verb's rules for: invocation resolver
(five cases), findings shapes, inventory numbering,
verify-before-classify, classify-then-ask (one table, one
round, one unclear item holds the batch), `keep-optional`
→ `deferred` if declined, thrash brake (first return of a
prior `resolved` or `rejected` → ask), in-place amend,
disposition table, no successor mint, stamp `updated:`,
do not delete Review history.

`review` writes a dated verdict stamp on **every** verdict:

```
### YYYY-MM-DD — needs-rework | approve | approve-with-changes
```

`needs-rework` still carries the finding list. `approve`
and `approve-with-changes` may be stamp-only.

### Deltas (the only places this verb differs)

**Artifact set.** Spec / design / ADR (an ADR written from
`spec` counts). Founding-shaped files count (they are
specs). Kind is detected the same way as blueprint
`review` (`tags:` / `doctype` / founding-shaped parser).

**Wrong artifact.** A plan / roadmap / runbook is the
wrong verb — refuse ("wrong verb"; that fold belongs with
the job lead, not blueprint). Inverse of contractor.

**Summon.** Design station on a workshop host (SKILL.md
probe), not build.

**"Aimed at a new decision" park.** Contractor parks a
finding that belongs on the spec. Here the artifact *is*
the spec, so the park is: a finding that **opens an
unsettled decision branch** (a new requirement, an
either/or the spec has not settled) → park it, send the
human to `grill`. After they acknowledge, the rest of the
batch may proceed. The parked item stays unmarked until
the branch is settled. A finding that belongs on a *job*
artifact (sequencing, slice order) is `push-back` (wrong
owner), not a grill park.

**What gets edited, by kind.**

- Feature spec / design: edit the named section
  (Problem / Goal / Approach / Mechanism / Verification /
  Slices). Keep section headings and slice ids stable.
  A coverage gap (a Goal requirement with no Mechanism)
  may fill Mechanism or append a Slices row with the next
  unused id. A new requirement is the grill-park above.
- ADR: edit Context / Decision / Alternatives /
  Consequences. Do not mint a successor ADR from `revise`.
- Founding-shaped: stay on that file. Fill the named
  mapped H2. **Do not add an H2.** A coverage gap is
  "fill the mapped section"; a new concern that needs a
  seventh H2 is a grill-park (or restore-the-shape), not
  an extra heading.

**Why amend / why re-review** (state in the verb file).

- **Why amend.** `needs-rework` means the spec is not
  safe to sequence against. Amending is how it becomes a
  candidate again.
- **Why re-review.** The fold is unverified content. The
  session that classified and edited *is the author*.
  Re-review is a cheaper **delta** pass — or a human
  waive, same as after `spec`.

**Stop offer.** One sentence, then the path, then: run
`/blueprint review` on the amended artifact, or waive.
Do not run `review`. Do not start sequencing.

### Wiring (same unit)

- `SKILL.md` verb table: add `revise`. Point it at
  `verbs/revise.md` (read the file).
- `description:` gains a revise trigger (needs-rework,
  apply review findings, amend the spec) without naming
  a sibling. Stay ≤ 1024 chars.
- Brief the human: after `revise`, one ask, then wait.
- Pipeline visible on `SKILL.md`:

  ```
  spec  →  review  →  approve              →  (host sequences)
                   →  approve-with-changes →  host, or revise if asked
                   →  needs-rework         →  revise  →  review  →  …
  ```

  Each arrow is a stop.
- Inline `review`: write the dated stamp on every
  verdict; replace *Acting on review feedback* with a
  pointer at `verbs/revise.md`. Keep the one-line
  "review hands the verdict to the owner and stops."
- `spec` terminal offer stays `review` then host
  sequencing; do not mention `revise` there (it is not
  the next verb from a fresh spec).
- Edges: `consumes: review` in addition to the existing
  conversation/draft consume. Still `produces: spec,
  founding-documents`. No new `handoff`.
- Structure line: mention `verbs/revise.md`.
- No new template. No mint. No script.

### Out of scope

- Changing contractor (already shipped on this branch).
- Auto-chaining any blueprint verb.
- Changing `review`'s verdict vocabulary.
- Promoting or closing the spec record.
- A `build` refuse (no `build` verb).

## Verification

**Mechanical**

- `cd <worktree> && skills/skill-builder/scripts/skills-lint.sh`
  → `fails=0`. Expected WARNs: orphan edge types;
  worktree-vs-clone symlink notes.
- `description:` ≤ 1024, quoted if it contains `: `,
  names no sibling `/name`.
- `verbs/revise.md` is cited from `SKILL.md` (orphan
  verb check). Prove by adding the file before the
  dispatch row.
- `SKILL.md` no longer contains the five-step receiving
  procedure; it points at `revise`.

**Judgment**

- Read-back of `revise.md` against this Mechanism
  (resolver, classify-then-ask, kind-specific amend,
  founding no-new-H2, grill-park, dispositions, thrash
  brake, stop-and-offer).
- A reader of `SKILL.md` can see
  `spec → review → revise → review` without opening
  this spec.

**No new automated test.** The verb is agent prose.

## Slices

- [x] **Slice 1: add `revise` and close the loop**
  <requires: —>
  - Paths: `skills/blueprint/SKILL.md`;
    `skills/blueprint/verbs/revise.md` (new).
  - Verify: lint `fails=0`; `revise.md` cited;
    description ≤ 1024 and sibling-clean; `SKILL.md`
    stamps every `review` verdict; `SKILL.md` points at
    `revise` for the fold.
