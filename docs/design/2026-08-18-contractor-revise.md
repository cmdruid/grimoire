---
doctype: design
status: open
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# contractor `revise` — Spec

Settled 2026-08-18 on stream `grok`. Human approved the
approach in conversation; this spec is the argued form.
Small feature: this file doubles as the plan.

## Problem

`/contractor` can write a job (`plan` / `roadmap` / `runbook`)
and judge it (`review`). It cannot **own the fold** when the
judgment is `needs-rework`.

`review` stops on purpose: it is the second set of eyes, not
the author. On a blocking verdict it writes a dated Review
history into the artifact and hands the verdict to whoever
owns the file. It even lists how that owner should treat
findings (verify before folding, no performative agreement,
hold the batch on one unclear item, push back when a finding
is wrong) — and then leaves that list with no verb to run it.

Agents currently improvise the amend. The improvisation is
the hole: a fold is unverified content, the same session is
the author, and `build`'s "passed `review` or waive" does
not say what "passed" means — a `needs-rework` write-back
can be read as done. The
`plan → review → (needs-rework) → ? → review → build`
loop has no named owner for the `?`.

The human brief: solidify `plan → review → revise`, and
polish `review → needs-rework → revise → re-review` so an
agent knows **how** to amend, **why** to amend and
re-review, and **when** to involve the user (including
clarifying questions).

## Goal

`/contractor revise` is the only legal path from a
`needs-rework` job artifact back to a candidate for
`review`. It classifies findings with the human, amends the
original artifact in place, records dispositions, and
**stops** offering a re-review. `build` walks a plan only
when the latest Review history stamp is `approve` or
`approve-with-changes`, or the human waives. A
`needs-rework` stamp is not a pass, whether its items are
open or closed.

One feature. No new skill. No second remediation document.
No status promotion to `current`.

## Approach

**Chosen:** a new `revise` verb on contractor. Same artifact
set as `review` (plan / roadmap / runbook). Input is a
resolver, not a required findings file. The receiving-side
rules already in `verbs/review.md` move into `revise` and
become a procedure; `review` keeps the write-back and
points here. Each verb still **stops**. The human (or the
host lane) walks `plan → review → revise → review → build`.

**Rejected: fold inside `review`.** That makes the judge the
author. `review` exists to be a different pair of eyes.

**Rejected: required `<review_results_file>`.** The common
`needs-rework` write-back lives in the artifact's Review
history. A required findings path forces a phantom file.
A findings file remains a legal input (council `RESULT.md`,
an external writeup).

**Rejected: a separate remediation-plan record.** A second
document next to the job will rot. Classification lives in
the conversation as one table; dispositions land in Review
history; the job stays one file.

**Rejected: `revise` invokes `review` in the same turn.**
The session that just chose keep / push-back / ask *is the
author*. Same-turn `review` is self-review wearing the
wrong badge (`plan` already has a self-review step). It
also spends a pass the human may waive and breaks "one ask
per stop."

**Rejected: plan-only `revise`.** The hole is the same for
roadmap and runbook. Widening is a few sentences, not a
different machine.

**Rejected: auto-promote `status: current`.** After a fold
the artifact stays `open` until a later `review` approves
(or the human waives) and someone promotes it.

## Mechanism

### Pipeline (visible from every door)

```
plan  →  review  →  approve              →  build
                 →  approve-with-changes →  build, or revise if the human asks
                 →  needs-rework         →  revise  →  review  →  …
```

Each arrow is a stop. No verb invokes the next.

`approve-with-changes` does **not** force `revise`. The
human asks if they want the nits folded.

`review` writes a dated **verdict stamp** into Review
history on **every** verdict, including `approve`:

```
### YYYY-MM-DD — needs-rework | approve | approve-with-changes
```

That is a write-back change, not a new verdict word.
`needs-rework` still carries the finding list (must-fix
separated from nice-to-have). `approve` and
`approve-with-changes` may be a stamp-only line.

`build` (replacing today's ambiguous "passed review"):
walk only when the **latest** stamp is `approve` or
`approve-with-changes`, or the human waives explicitly.
A latest stamp of `needs-rework` is a **refuse** — tell
the caller to `revise` or to waive. Open vs closed
items do not change that. No stamp at all → today's
"unknown, so run `review`" path.

### Invocation

```
/contractor revise [<findings>] [<artifact>]
```

Resolver, in this order:

1. **Two readable paths.** If exactly one is a job
   artifact (plan / roadmap / runbook), that is the
   target and the other is findings. If both are job
   artifacts, ask. If neither is, ask which artifact
   they belong to. Fold findings into the target.
2. **One path that is a plan / roadmap / runbook** and
   carries a Review history with at least one open item —
   that file is both findings and target.
3. **One path that is a findings file** (not a job
   artifact) — ask which artifact they belong to.
4. **No paths**, and this session just produced a `review`
   verdict for a named artifact — use that in-context
   list; still name the artifact in the opening line.
5. **Otherwise** — ask. Do not guess a plan in cwd.

A spec, design doc, or ADR is the wrong artifact —
refuse ("wrong verb"; that fold belongs with the spec's
owner, not contractor). Same refuse as `review`.

Kind is detected the same way as `review` (`tags:` /
`doctype` / shape). Kind only changes which sections
get edited (slices vs phases vs conductor steps).

### Findings shapes `revise` must accept

- The artifact's own `## Review history` (the
  `needs-rework` write-back `review` already writes).
- A council `RESULT.md` — live opinions under
  `## Ranked opinions` only (`## Rescinded` is not live).
- Any other markdown findings file the human names —
  take each discrete finding (heading + location / claim
  / action if present). Do not invent structure the file
  does not have.
- An in-context list from the `review` just run in this
  session, when no file was written (approve-with-changes,
  or a human-pasted review).

Must-fix vs nice-to-have comes from the finding when
present; if omitted, treat as must-fix (the conservative
default — the human can demote at the table).

Skip any finding already marked `resolved`, `rejected`,
or `deferred` in Review history.

### Procedure (`verbs/revise.md`)

1. **Resolve** inputs (above). Locate the artifact.
   Summon context per SKILL.md (build station on a
   workshop host).
2. **Inventory** open findings. Number them for the table
   (`F1`, `F2`, …) even if the source used a different
   scheme — keep a source id in parentheses when one
   exists (`F1 (C3)`).
3. **Verify each finding** against the artifact and
   `HEAD` before classifying. A review claim is a claim,
   not a decision. Re-read the named location. If the
   finding cites code, re-read that code (the same
   posture as `review`'s groundedness pass;
   `scripts/ground-check.sh` is available, not
   sufficient). Outcomes of verify:
   - **already done** — classify `resolved` (no edit).
   - **wrong / out of scope for this job** — classify
     `push-back`.
   - **aimed at the spec** (a new requirement, an open
     decision branch) — **park that item**. Do not enlarge
     the job. Tell the human it belongs on the spec, not
     in `revise`. After they acknowledge the send-back,
     the rest of the batch may proceed. The parked item
     stays unmarked (open) until the spec is settled.
   - **unclear** — classify `ask`.
   - **otherwise** — classify `keep` (must-fix) or
     `keep-optional` (nice-to-have that does not change
     the job).
4. **Classify the whole batch before editing any.**
   No performative agreement. Grep before generalizing
   (a "make this configurable" finding gets a usage
   check first).
5. **User seam.** Show **one** remediation table, then
   ask. The table is conversation, not a file:

   | Id | Finding (one line) | Action | Why |
   |---|---|---|---|
   | F1 | … | keep — edit Slice 2 Verify | red-proof missing |
   | F2 | … | push-back | path is test-only |
   | F3 | … | ask — which gate? | two legal readings |

   Ask **only** the `ask` rows, plus any `keep` that
   changes *what* gets built (a new slice, a dropped
   slice, a changed Done-when). One round. Each
   question has a recommended answer. **One unclear
   item holds the whole batch** — do not amend until
   every `ask` is resolved (keep, push-back, or
   keep-optional). A `keep-optional` becomes `keep`
   only if the human says yes; otherwise it is
   `deferred` (not left unmarked).
6. **Amend in place** (same path, same record). How:
   - Edit the named slice / phase / conductor step.
     **Keep slice and phase ids stable** so the next
     `review` sees a delta, not a new document.
   - Must-fix (`keep`) always.
   - Nice-to-have only when it does not change the job,
     unless the human promoted it.
   - A **coverage gap** (a spec requirement with no
     slice) may add a slice, appended, with the next
     unused id. A **new requirement** is not a coverage
     gap — that is the spec stop in step 3.
   - Re-ground any fold that cites code. If you cannot
     verify it now, mark the fold
     `(unverified — check at build)` on the edited
     line, not only in chat.
   - Complete code in the edited slice (no "similar to
     slice N", no "add error handling"). Keep a
     verification step on every slice you touch.
   - Do **not** delete Review history. Update
     dispositions (below).
   - Do **not** flip `status:` to `current`. `updated:`
     is stamped (opportunistic `records.sh touch`, else
     file-mode).
   - Do **not** mint a successor record.
7. **Thrash brake.** If the **same finding** (same
   location + same assertion) was already `resolved`
   or `rejected` by a prior `revise` and has come
   back as must-fix on a later `review`, do not
   silently fold or silently re-reject — ask the
   human. The first return is the brake. Two
   treatments without agreement is a disagreement,
   not a missing edit.
8. **Stop.** One sentence the human can act on, then
   the path, then the offer: run `/contractor review`
   on the amended artifact, or waive and `build`. Do
   not run `review`. Do not start `build`.

### Review history — stamps and dispositions

`review` writes a dated verdict stamp (Pipeline above)
on every verdict. Under a `needs-rework` stamp it
still lists findings, must-fix separated from
nice-to-have. `revise` **adds** a disposition on each
item it handled; it does not rewrite the reviewer's
prose.

Classify → disposition:

| Classify | After the fold | Disposition |
|---|---|---|
| `keep` (amended) | edit landed | `resolved — <what changed>` |
| `already done` | no edit | `resolved — already present` |
| `push-back` | no edit | `rejected — <reason>` |
| `keep-optional` taken | edit landed | `resolved — <what changed>` |
| `keep-optional` not taken | no edit | `deferred — <why>` |
| spec-aimed, parked | no edit | left unmarked (open) until the spec is settled |

Left unmarked → still open. Open items do **not**
drive the `build` refuse (the latest **stamp** does).
They do drive resolver step 2 (a plan with open items
is a `revise` target) and the inventory skip list
(`resolved` / `rejected` / `deferred` are skipped).

The owner may prune a fully resolved dated block after
a later `approve`.

### Why amend, and why re-review (in the verb file)

State both in `revise.md`, not only in this spec. Short:

- **Why amend.** `needs-rework` means the job is not
  safe to walk. Amending is how the artifact becomes a
  candidate again. Building from a blocking verdict is
  what `build`'s refuse exists to prevent.
- **Why re-review.** The fold is unverified content.
  The session that classified and edited *is the
  author*. Re-review is a cheaper **delta** pass
  (Review history + what changed), still a different
  pair of eyes — or a human waive, same as after
  `plan`.

### Wiring (same unit)

- `SKILL.md` dispatch table: add `revise`.
- `description:` gains a revise trigger (needs-rework,
  apply review findings, amend the plan) without
  naming a sibling. Stay ≤ 1024 chars.
- `## Brief the human`: after `revise`, one ask, then
  wait — same as after `plan` / `review`.
- `Hard seams`: the walked-plan rule becomes: every
  walked plan has a latest stamp of `approve` or
  `approve-with-changes` (or an explicit waive).
  `needs-rework` is not a pass. The path back is
  `revise`.
- `verbs/review.md`: write the dated verdict stamp on
  every verdict (including `approve` / `approve-with-changes`).
  Replace the "Acting on review feedback" procedure
  with a pointer — the owner runs `revise`. Keep the
  one-line "review hands the verdict to the owner and
  stops."
- `verbs/plan.md` terminal offer stays `review` then
  `build`; do not mention `revise` there (it is not
  the next verb from a fresh plan).
- `verbs/build.md` step 2: walk only when the latest
  stamp is `approve` / `approve-with-changes`, or the
  human waives. Latest `needs-rework` → refuse.
- Edges: `consumes: review` in addition to `spec`
  (a findings baton — council `RESULT.md` or Review
  history). Still `produces: plan, roadmap, runbook`.
  No new `handoff`.
- No new template. No mint. No script.

### Out of scope

- A `revise` on blueprint specs / design docs (that
  receiving-side list stays on `blueprint` this unit).
- Auto-chaining any contractor verb.
- Changing `review`'s verdict vocabulary (the stamp
  reuses `approve` / `approve-with-changes` /
  `needs-rework`; it does not add a fourth word).
- Promoting or closing the job record.
- Migrating this library's `docs/design/` into
  `.records/` (patient-zero).

## Verification

**Mechanical**

- `cd <worktree> && skills/skill-builder/scripts/skills-lint.sh`
  → `fails=0`. Expected WARNs: orphan edge types;
  worktree-vs-clone symlink notes.
- `description:` ≤ 1024, quoted if it contains `: `,
  names no sibling `/name`.
- `verbs/revise.md` is cited from `SKILL.md` (orphan
  verb check).
- `verbs/review.md` no longer contains the five-step
  receiving procedure; it points at `revise`.

**Judgment**

- Read-back of `revise.md` against this Mechanism
  (resolver, classify-then-ask, in-place amend, stable
  ids, Review history dispositions, thrash brake,
  stop-and-offer).
- `build.md` refuses unless the latest stamp is
  `approve` / `approve-with-changes` (or an explicit
  waive).
- A reader of `SKILL.md` can see
  `plan → review → revise → review → build` without
  opening this spec.

**No new automated test.** The verb is agent prose.
The lint gate is the mechanical check. Prove the
orphan-verb citation by adding the file before the
dispatch row (the existing check 11 red-proof
discipline: the file without a citation would FAIL).

## Slices

This spec doubles as the plan. One slice: the verb
plus the loop wiring. Sequencing is not required.

- [x] **Slice 1: add `revise` and close the loop**
  <requires: —>
  - Paths: `skills/contractor/SKILL.md`;
    `skills/contractor/verbs/revise.md` (new);
    `skills/contractor/verbs/review.md`;
    `skills/contractor/verbs/build.md`.
  - Verify: lint `fails=0`; `revise.md` cited;
    description ≤ 1024 and sibling-clean; `review.md`
    points at `revise` for the fold; `review.md`
    stamps every verdict; `build.md` refuses unless
    the latest stamp is `approve` /
    `approve-with-changes` (or waive).

## Review history

### 2026-08-18 — needs-rework

Must-fix:

- **F1** Mechanism → Pipeline / `build` refuse, and Mechanism →
  Review history dispositions — `build`'s refuse predicate
  and `review`'s "approve writes nothing" cannot both be
  true. Goal says refuse a last recorded `needs-rework`
  unless waived. Mechanism says refuse only when that
  block still has unmarked items. After a full `revise`,
  items are `resolved`/`rejected`, so the Mechanism
  predicate lets `build` skip re-review. After `revise`
  plus an `approve` (which writes nothing), the last
  heading is still `needs-rework`, so a Goal-literal
  predicate refuses forever. **Fix:** give Review history
  a dated verdict stamp
  (`### YYYY-MM-DD — needs-rework | approve | approve-with-changes`)
  that `review` writes on **every** verdict, including
  `approve`. `build` passes only when the latest stamp is
  `approve` / `approve-with-changes`, or the human waives.
  `needs-rework` is not a pass, open or closed. This is a
  write-back change, not a new verdict word — add
  `verbs/review.md` to the slice path list for the stamp
  (already listed).
  - resolved — Pipeline now stamps every verdict;
    `build` keys on the latest stamp only.
- **F2** Mechanism → Review history dispositions +
  Procedure step 5 — an unused `keep-optional` "left"
  unmarked is still **open**, so `build` (under either
  predicate) treats a declined nice-to-have as blocking.
  **Fix:** map unused `keep-optional` to `deferred`. Map
  classify → disposition explicitly: `keep` after amend →
  `resolved`; `push-back` → `rejected`; `keep-optional`
  not taken → `deferred`; already-done → `resolved`.
  - resolved — classify → disposition table; unused
    `keep-optional` is `deferred`.

Nice-to-have:

- **F3** Problem ¶3 — overclaims that `build` *will walk*
  a `needs-rework` plan. Live `build.md` step 2 says
  "passed `review` or waive," which is ambiguous, not an
  explicit walk. Grounded hole is the missing predicate
  (F1), not specified misbehavior. Soften the sentence.
  - resolved — Problem ¶3 now names the ambiguous
    "passed review" predicate.
- **F4** Invocation resolver step 1 — two readable paths
  with no order and no rule if both are job artifacts.
  **Fix:** if exactly one path is a job artifact, that is
  the target; if both are, ask.
  - resolved — resolver step 1: exactly one job
    artifact is the target; both or neither → ask.
- **F5** Procedure step 7 — "do not silently fold a
  **third** time" vs "two folds without agreement." The
  brake should fire on the **first return** of the same
  must-fix after one `revise` (do not fold it a second
  time). Align the wording.
  - resolved — brake fires on the first return after
    one `revise`.
- **F6** Procedure step 3 "aimed at the spec — stop that
  item" vs step 5 hold-the-batch. Say whether the rest
  of the batch may proceed after the human acknowledges
  the spec send-back (recommended: yes).
  - resolved — park the spec-aimed item; rest of batch
    may proceed after acknowledge; item stays open.

- **F7** (re-review, approve-with-changes) — thrash brake
  covered only a prior `resolved` coming back. A prior
  `rejected` re-filed as must-fix is the same
  disagreement.
  - resolved — brake now covers `resolved` or
    `rejected`; first return asks, no silent fold or
    re-reject.
