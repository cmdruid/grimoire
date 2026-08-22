# `refine` · fold review findings into an artifact

The only legal path from a `needs-rework` artifact back to a
candidate for `review`. Same artifact set as `review` (the six
bundled kinds, plus any host-added kind). Amends the original
file in place. Does not mint a successor. Does not write
`published`.

**Why amend.** A failing verdict means the artifact is not safe
to sequence or walk against. Amending is how it becomes a
candidate again.

**Why re-review.** The fold is unverified content, so a later
`review` is how the artifact becomes a candidate again.
Unbidden same-turn `review` is still forbidden. Named re-review
is authorized same-session running of the existing `review`
procedure — not a different pair of eyes.

This verb **stops** after the proposal until confirmed. After
apply, it stops unless the confirmation named re-review. It
does not walk a job.

## Invocation

```
/inspector refine [<findings>] [<artifact>]
```

Resolver, in this order:

1. **Two readable paths.** Kind-detect each (SKILL.md
   *Kind-detect*). If exactly one matches a known kind, that is
   the target and the other is findings. If both match, ask. If
   neither matches, ask which artifact they belong to. Fold
   findings into the target.
2. **One path that matches a known kind** and carries a Review
   history with at least one open item — that file is both
   findings and target. Open Review-history blocks already on
   disk are a **read** source; they are not a write target and
   are not required.
3. **One path that is a findings file** (not a matching kind) —
   ask which artifact they belong to.
4. **No paths**, and this session just produced a `review`
   verdict for a named artifact — use that in-context list;
   still name the artifact in the opening line.
5. **Otherwise** — ask. Do not guess an artifact in cwd.

Unknown kind → ask or refuse; do not invent a rubric. Kind only
changes which sections get edited (kind file, refine legal
locations).

## Findings shapes

Accept any of:

- An in-context list from the `review` just run in this session
  (or a human-pasted review).
- A council `RESULT.md` — live opinions under `## Ranked
  opinions` only (`## Rescinded` is not live).
- Any other markdown findings file the human names — take each
  discrete finding (heading + location / claim / action if
  present). Do not invent structure the file does not have.
- An open `## Review history` already on the artifact, if
  present — read only. Skip any finding already marked
  `resolved`, `rejected`, or `deferred`.

Must-fix vs nice-to-have comes from the finding when present; if
omitted, treat as must-fix.

## Procedure

1. **Resolve** inputs (above). Locate the artifact. Kind-detect.
   Load the kind file. Summon context per SKILL.md after the
   kind is known. Unknown kind → ask or refuse; stop.
2. **Inventory** open findings. Number them for the table (`F1`,
   `F2`, …) even if the source used a different scheme — keep a
   source id in parentheses when one exists (`F1 (C3)`).
3. **Verify each finding** against the artifact and `HEAD`
   before classifying. A review claim is a claim, not a
   decision. Re-read the named location. If the finding cites
   code, re-read that code (the same posture as `review`'s
   groundedness pass; `scripts/ground-check.sh` is available,
   not sufficient). Outcomes of verify:
   - **already done** — classify `resolved` (no edit).
   - **wrong / out of scope for this artifact** — classify
     `push-back`.
   - **park** — the kind file names what must park (a new
     decision branch, a new requirement, an illegal location).
     Do not invent the decision here. Tell the human where it
     belongs. After they acknowledge the send-back, the rest of
     the batch may proceed. The parked item stays unmarked
     (open) until that branch is settled. Park is **not** `ask`.
   - **unclear** — classify `ask`. Same classify word, not a
     new one. Classify `ask` (not `keep`) until the remedy is
     chosen; after the answer, `keep` with the chosen location.
     - Unsure the finding is true or in scope (already `ask`).
     - Two legal readings of the finding (already `ask`).
     - Two legal **remedies** for an accepted finding (which
       section/slice, which gate, which owner).
     - A reviewer confidence note the owner cannot independently
       verify against the artifact / `HEAD`.
   - **otherwise** — classify `keep` (must-fix) or
     `keep-optional` (nice-to-have that does not change the
     artifact's goal).
   A confident `keep` that changes what the artifact claims is
   **not** an `ask`. It lives in the proposal, marked
   product-class.
4. **Classify the whole batch before editing any.** No
   performative agreement. Grep before generalizing.
   **Thrash brake.** If the **same finding** (same location +
   same assertion) was already `resolved` or `rejected` by a
   prior `refine` and has come back as must-fix on a later
   `review`, do not silently fold or silently re-reject —
   classify `ask`. The first return is the brake. Two treatments
   without agreement is a disagreement, not a missing edit.
5. **Questions, only if needed.** If any row is still classify-
   `ask` after step 4, and/or a park still needs acknowledgment,
   that is a stop. **Show only those rows** (grill shape:
   recommended answer and why; multiple-choice when enumerable).
   No keep-amendment text. No full remediation table. One round
   unless an answer opens a new finding/remedy fork — then ask
   that fork before proposing. **One unresolved `ask` holds the
   proposal.** Park-ack does not use the `ask` exit
   (`keep` / `push-back` / `keep-optional`); after acknowledgment
   the item stays unmarked and the rest may proceed. Do not quiz
   confident rows. Answering questions is **not** package confirm
   — even if the human says "do it" / "approved, re-review" in
   the same message. Still step 6, then wait.
6. **Propose. Do not amend.** Conversation, not a file. The
   proposal *is* the live table plus concrete amendments, not a
   second artifact. Show:

   - One remediation table (Id, Finding, Action, Why) for the
     whole batch, including `push-back`, already-done, and
     parked (unmarked).
   - Product-class `keep`s visually separated from nits (new or
     dropped section, changed Done-when / Goal / Approach /
     Verification bar).
   - For every `keep` and every `keep-optional` the owner
     **recommends taking**: a concrete amendment — location →
     what will change. Concrete enough that a gap between this
     proposal and the later edit is detectable. A small edit
     shows the replacement. A larger rewrite states the delta in
     that unit's terms. Not "fix F1."

   **Legal for this kind.** Every proposed edit must already be a
   legal in-place amend per the kind file. An illegal edit is
   park/`ask`, never a proposed `keep`.

   `keep-optional` rows state the recommended disposition
   (take, or defer). Bare approval accepts that recommendation.
   A `keep-optional` becomes `keep` only when the *proposal*
   recommended taking it and the human approved, or when the
   human promoted it in the confirm. Otherwise `deferred`.

   Then **stop and wait**. Every invoke of `refine` takes this
   path — "how should we refine this?", "how should we revise
   this?", "let's revise the spec", "apply now", "skip the
   proposal". There is no skip-proposal token. None of them
   apply in the same turn as the proposal.
7. **Confirm parse** (the wait **after the proposal** only).
   Compositional, not exclusive rows. A later `review` (or
   `/inspector review`) after stop-and-offer is a **new arrow**,
   not this exception.

   1. **Reject** (closed set): `stop` / `don't` / `not yet` →
      do not amend. Drop any carried re-review intent.
   2. **Human-will-read is not the verb.** "I'll review it" /
      "let me read it" / "I'll look" without asking the agent
      to run this skill's `review` → not named re-review. If
      they also accepted the package, apply then stop-and-offer.
   3. **Except / adjust first.** Drop F2, take a listed
      optional, rewrite a proposed edit. Never Apply.
      If the adjusted package is fully determined from the
      already-shown proposal, keep that package in memory
      (no re-show) and continue to 4 / 5. Keep
      named-re-review intent if present. If 4 / 5 do not
      also match (except without accept), re-show the
      adjusted package and wait. If the owner must invent
      a new amendment, re-show, wait, and carry
      named-re-review intent across that wait unless they
      cancel it.
   4. **Accept** (open set): any clear package acceptance.
      Examples, not a closed list: `approved`, `yes`, `looks
      good`, `do it`, `lgtm`, `ok`, `go ahead`, `apply`.
      **Do:** apply, then step 9 else. Reject (1) wins over
      this.
   5. **Named re-review** (intent, same confirmation
      utterance): extra conjunct on accept. They ask this
      skill's `review` procedure to run on the artifact
      after apply. Paraphrases count: "re-review", "then
      review", "then run review", "review it after",
      "approved, re-review the spec", `/inspector review` in
      *this* utterance. Agent is the subject. **Do:** apply
      (if 4 did not already), then step 9 named path *instead
      of* step 9 else.
   6. **`re-review` alone.** Pending `keep`s → ask once,
      recommended answer: apply these first, then re-review.
      Do not skip the fold. Do not review the unamended
      artifact from this verb. No pending `keep`s (nothing to
      fold) → skip Apply; follow `review` on the current
      artifact (step 9 named path).
   7. During the **questions** stop, "approved" /
      "approved, re-review" is not confirm. Finish asks (or
      say the package cannot be built yet). Do not apply. Do
      not start `review`.
8. **Apply** (only after a confirm that authorizes apply).
   Same path, same record. Do not mint a successor. Do not
   write `published`. Stamp `updated:` (opportunistic
   `records.sh touch --status draft`, else file-mode
   `status: draft` and `updated:`). If `stage: approved` is
   present, **drop it**. Do not create or append `## Review
   history`.

   Shared amend rules: Must-fix (`keep`) always. Nice-to-have
   only when it does not change the artifact's goal, unless the
   human promoted it. Re-ground any fold that cites code; if
   you cannot verify it now, mark `(unverified — check at
   walk)` on the edited line. Complete the argued section
   (no "similar to section N", no "add error handling later").
   Keep the claim falsifiable.

   How, by kind: the kind file's refine legal locations.
   Keep headings and ids stable. A coverage gap may fill the
   named unit or append the next unused id when the kind
   file allows it. A new requirement is park, not a `keep`
   row.
9. **After confirm.**

   - **Named re-review:** follow this skill's `review`
     procedure (`verbs/review.md`) on the artifact (amended
     if Apply ran; current if there was nothing to fold).
     Full procedure (two-axis, conversation verdict, stop).
     Not a delta mode and not a different file. Same-session
     authorship is accepted; do not recuse; depth dial stays
     default off. Do not start a walk.
   - **Else:** stop. Always `status: draft`; `stage: approved`
     dropped if it was present. One sentence the human can
     act on, then the path, then the offer: `review`. Do not
     run it.
