# `revise` · fold review findings into a spec

The only legal path from a `needs-rework` spec (or design, or ADR)
back to a candidate for `review`. Same artifact set as `review`.
Amends the original file in place. Does not mint a successor. Does
not promote `status:` to `current`.

**Why amend.** A `needs-rework` stamp means the spec is not safe to
sequence against. Amending is how the artifact becomes a candidate
again.

**Why re-review.** The fold is unverified content. The session that
classified and edited *is the author*. Re-review is a cheaper
**delta** pass (Review history + what changed), still a different
pair of eyes — or a human waive, same as after `spec`.

This verb **stops** after the fold. It does not run `review`. It
does not start sequencing.

## Invocation

```
/blueprint revise [<findings>] [<artifact>]
```

Resolver, in this order:

1. **Two readable paths.** If exactly one is a spec / design / ADR
   (founding-shaped counts), that is the target and the other is
   findings. If both are, ask. If neither is, ask which artifact
   they belong to. Fold findings into the target.
2. **One path that is a spec / design / ADR** and carries a Review
   history with at least one open item — that file is both findings
   and target.
3. **One path that is a findings file** (not a spec / design / ADR)
   — ask which artifact they belong to.
4. **No paths**, and this session just produced a `review` verdict
   for a named artifact — use that in-context list; still name the
   artifact in the opening line.
5. **Otherwise** — ask. Do not guess a spec in cwd.

A plan, roadmap, or runbook is the wrong artifact — refuse ("wrong
verb"; that fold belongs with the job lead, not blueprint). Same
refuse as `review`.

Kind is detected the same way as `review` (`tags:` / `doctype` /
founding-shaped parser). Kind only changes which sections get
edited.

## Findings shapes

Accept any of:

- The artifact's own `## Review history` (the `needs-rework`
  write-back `review` already writes).
- A council `RESULT.md` — live opinions under `## Ranked opinions`
  only (`## Rescinded` is not live).
- Any other markdown findings file the human names — take each
  discrete finding (heading + location / claim / action if present).
  Do not invent structure the file does not have.
- An in-context list from the `review` just run in this session,
  when no file was written (`approve-with-changes`, or a
  human-pasted review).

Must-fix vs nice-to-have comes from the finding when present; if
omitted, treat as must-fix. Skip any finding already marked
`resolved`, `rejected`, or `deferred` in Review history.

## Procedure

1. **Resolve** inputs (above). Locate the artifact. Summon context
   per SKILL.md (design station on a workshop host). If the named
   file is founding-shaped, stay on it (SKILL.md *Founding-shaped*).
2. **Inventory** open findings. Number them for the table (`F1`,
   `F2`, …) even if the source used a different scheme — keep a
   source id in parentheses when one exists (`F1 (C3)`).
3. **Verify each finding** against the artifact and `HEAD` before
   classifying. A review claim is a claim, not a decision. Re-read
   the named location. If the finding cites code, re-read that code
   (the same posture as `review`'s groundedness pass;
   `scripts/ground-check.sh` is available, not sufficient).
   Outcomes of verify:
   - **already done** — classify `resolved` (no edit).
   - **wrong / out of scope for this spec** — classify `push-back`.
   - **belongs on a job artifact** (sequencing, slice order, a
     walk) — classify `push-back` (wrong owner).
   - **opens an unsettled decision branch** (a new requirement, an
     either/or the spec has not settled) — **park that item**. Do
     not invent the decision here. Tell the human it belongs on
     `grill`. After they acknowledge the send-back, the rest of
     the batch may proceed. The parked item stays unmarked (open)
     until the branch is settled.
   - **unclear** — classify `ask`.
   - **otherwise** — classify `keep` (must-fix) or `keep-optional`
     (nice-to-have that does not change the spec's goal).
4. **Classify the whole batch before editing any.** No performative
   agreement. Grep before generalizing.
   **Thrash brake.** If the **same finding** (same location + same
   assertion) was already `resolved` or `rejected` by a prior
   `revise` and has come back as must-fix on a later `review`, do
   not silently fold or silently re-reject — classify `ask`. The
   first return is the brake. Two treatments without agreement is
   a disagreement, not a missing edit.
5. **User seam.** Show **one** remediation table, then ask. The
   table is conversation, not a file:

   | Id | Finding (one line) | Action | Why |
   |---|---|---|---|
   | F1 | … | keep — edit Mechanism | predicate contradicts Goal |
   | F2 | … | push-back | job sequencing, wrong owner |
   | F3 | … | ask — which gate? | two legal readings |

   Ask **only** the `ask` rows, plus any `keep` that changes *what
   the spec claims* (a dropped Goal, a new Approach, a changed
   Verification bar). One round. Each question has a recommended
   answer. **One unclear item holds the whole batch** — do not
   amend until every `ask` is resolved (keep, push-back, or
   keep-optional). A `keep-optional` becomes `keep` only if the
   human says yes; otherwise it is `deferred` (not left unmarked).
6. **Amend in place** (same path, same record). How, by kind:
   - **Feature spec / design.** Edit the named section (Problem /
     Goal / Approach / Mechanism / Verification / Slices). **Keep
     section headings and slice ids stable** so the next `review`
     sees a delta, not a new document. A coverage gap (a Goal
     requirement with no Mechanism) may fill Mechanism or append
     a Slices row with the next unused id. A new requirement is
     the grill-park in step 3.
   - **ADR.** Edit Context / Decision / Alternatives /
     Consequences. Do not mint a successor ADR.
   - **Founding-shaped.** Stay on that file. Fill the named
     mapped H2. **Do not add an H2.** A coverage gap is "fill the
     mapped section"; a new concern that needs a seventh H2 is a
     grill-park (or restore-the-shape), not an extra heading.
   - Must-fix (`keep`) always.
   - Nice-to-have only when it does not change the spec's goal,
     unless the human promoted it.
   - Re-ground any fold that cites code. If you cannot verify it
     now, mark the fold `(unverified — check at build)` on the
     edited line, not only in chat.
   - Complete the argued section (no "similar to section N", no
     "add error handling later"). Keep the claim falsifiable.
   - Do **not** delete Review history. Update dispositions
     (below).
   - Do **not** flip `status:` to `current`. Stamp `updated:`
     (opportunistic `records.sh touch`, else file-mode).
   - Do **not** mint a successor record. Do not strip `founding`.
7. **Stop.** One sentence the human can act on, then the path,
   then the offer: run `/blueprint review` on the amended
   artifact, or waive. Do not run `review`. Do not start
   sequencing.

## Review history — dispositions

`review` writes the dated verdict stamp. `revise` **adds** a
disposition on each item it handled; it does not rewrite the
reviewer's prose.

| Classify | After the fold | Disposition |
|---|---|---|
| `keep` (amended) | edit landed | `resolved — <what changed>` |
| `already done` | no edit | `resolved — already present` |
| `push-back` | no edit | `rejected — <reason>` |
| `keep-optional` taken | edit landed | `resolved — <what changed>` |
| `keep-optional` not taken | no edit | `deferred — <why>` |
| decision-branch, parked | no edit | left unmarked (open) until `grill` settles it |

Left unmarked → still open. Open items drive resolver step 2
(a spec with open items is a `revise` target) and the inventory
skip list (`resolved` / `rejected` / `deferred` are skipped).

The owner may prune a fully resolved dated block after a later
`approve`.
