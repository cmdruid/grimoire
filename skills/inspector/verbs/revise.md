# `revise` · fold review findings into an artifact

The legal fold path for material **document** review findings: must-fix findings from
`needs-rework`, recommended changes from `approve-with-changes`, or findings supplied to a
standalone invocation. It accepts the six bundled document kinds plus host-added document kinds.
`implementation` has no legal revise path: refuse it without amending code. This verb amends the
original file in place, mints no successor, and does not write `published`.

**Why amend.** A failing verdict means the artifact is not safe to sequence or walk against. An
`approve-with-changes` verdict says the artifact can publish as reviewed, but the reviewer has
material improvements worth offering. In either case, amending creates a new draft candidate.

**Why re-review.** The fold is unverified content. A revise entered from document review — whether
automatically or after an explicit offer — carries re-review intent by default: approval of the
proposal applies it and immediately runs the existing `review` procedure. A standalone revise does
not carry that intent unless its confirmation names re-review. Either path is same-session review,
not a different pair of eyes.

This verb **stops** after the proposal until confirmed. After
apply, it runs review when re-review intent is queued or named;
otherwise it stops and offers review. It does not walk a job.

## Invocation

```
/inspector revise [<findings>] [<artifact>]
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
changes which sections get edited (kind file, revise legal
locations).

**Review-origin entry.** `review.md` may enter this procedure automatically with resolved inputs.
When it does, skip only the standalone resolver above: keep the reviewed artifact, effective kind,
complete verdict-bearing findings, origin verdict, inherited review boundary, and continuation mode,
then begin Procedure step 1's context load and implementation guard. Follow-ups never enter this
baton.

**Re-review intent.** Queue it whenever this verb is dispatched from `review.md`, automatically or
from an offered material-finding branch, including resolver rule 4 after this session's named
verdict. Leave it unqueued for a standalone invocation. An explicit “without re-review”, “don't
re-review”, or “apply only” clears it. Carry the intent through question and adjustment stops until
the proposal is accepted or rejected.

**Scope custody.** A review-origin revision uses the inherited review boundary unchanged. A
standalone revision establishes the same boundary from the user's request and the artifact under
SKILL.md *Scope firewall*. A revision cannot enlarge the artifact's goal, affected surface, accepted
requirements, or non-goals. A finding that would introduce another subsystem needs direct causal
evidence that the bounded outcome is otherwise unsafe or impossible; park that scope decision for
the artifact's owner rather than silently folding it. Adjacent improvements are `push-back`
follow-ups, not optional edits.

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
   Load the kind file and retain the inherited review boundary, or establish the narrow standalone
   boundary per SKILL.md. Summon context per SKILL.md after the
   kind is known. Unknown kind → ask or refuse; stop.
   `implementation` → refuse; implementation review never enters revise.
   A document whose effective continuation is `unavailable` → refuse; its owner has disabled
   in-place revision for review-origin and standalone entry alike.
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
   - **wrong / out of scope for this artifact or its review boundary** — classify `push-back` and,
     when useful, report it once as a non-blocking follow-up.
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
   - **otherwise** — classify `keep` (must-fix) or `keep-optional` (an in-boundary nice-to-have that
     does not change the artifact's goal or accepted scope).
   A confident `keep` may correct what the artifact claims inside its boundary, but cannot enlarge
   the artifact. A new requirement, subsystem, or affected surface is `park` even when direct causal
   evidence shows why the upstream scope may need to change.
4. **Classify the whole batch before editing any.** No
   performative agreement. Grep before generalizing.
   **Thrash brake.** If the **same finding** (same location + same assertion) was already
   `resolved`, `rejected`, or `push-back` by a prior `revise` and has come back as must-fix on a
   later `review`, do not silently fold or silently re-dispose it — classify `ask`. The first
   return is the brake. Two treatments without agreement is a disagreement, not a missing edit.
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
   the same message. Still run step 6, then step 7 when material remains, and wait.
   Carried re-review intent remains queued; answering questions never triggers it.
6. **Empty material package.** After all questions are settled and parks acknowledged, determine
   the optional dispositions before presenting a proposal. If no `keep` and no `keep-optional`
   that the owner recommends taking remains, do not show an empty remediation table, ask for
   package confirmation, amend the artifact, or change status. Resolved, push-back, omitted
   nit/unsupported, parked, and deferred-only rows do not manufacture a package. Close by origin:

   - any parked item remains → explain the blocking upstream decision or owner, leave the artifact
     draft, and stop;
   - review-origin `approve-with-changes` → say no amendable recommendation remains and offer to
     accept/publish the exact reviewed artifact as-is under its existing gate; stop;
   - review-origin `needs-rework` whose findings all resolved or pushed back → run one full review
     of the unchanged artifact, carrying the dispositions as context; if the same location +
     assertion returns after a prior resolved/push-back treatment, the thrash brake asks instead;
   - otherwise → say there is nothing material to fold and stop.
7. **Propose. Do not amend.** Conversation, not a file. The
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

   **Legal for this boundary.** No proposal may introduce another subsystem, requirement, or
   affected surface. Necessary scope expansion with direct causal evidence remains parked until the
   user or artifact owner accepts it upstream; independent improvements remain `push-back`.

   `keep-optional` rows state the recommended disposition
   (take, or defer). Bare approval accepts that recommendation.
   A `keep-optional` becomes `keep` only when the *proposal*
   recommended taking it and the human approved, or when the
   human promoted it in the confirm. Otherwise `deferred`.

   Then **stop and wait**. Every invoke of `revise` takes this
   path — "how should we revise this?", "let's revise the spec",
   "apply now", "skip the proposal". There is no skip-proposal token. None of them
   apply in the same turn as the proposal.
   End the proposal with `Re-review: queued after apply` when intent is
   carried or named; otherwise say `Re-review: not queued`.
8. **Confirm parse** (the wait **after the proposal** only).
   Compositional, not exclusive rows. A later `review` (or
   `/inspector review`) after stop-and-offer is a **new arrow**,
   not this exception.

   1. **Accept/publish as-is.** Legal only when this proposal came from an
      `approve-with-changes` review. A clear `publish as-is`, `accept as-is`, or unambiguous
      equivalent discards the proposed package and uses exactly the reviewed artifact's existing
      passing gate through `review.md`; do not Apply. Founding-shaped remains draft. For
      `needs-rework`, refuse because a failing artifact cannot publish or be accepted. For
      standalone revise, ask what artifact state the human intends; do not infer package
      acceptance.
   2. **Reject** (closed set): `stop` / `don't` / `not yet` →
      do not amend. Drop any carried re-review intent.
   3. **Explicit no agent re-review.** “Without re-review”, “don't
      re-review”, or “apply only” clears queued or named intent. It is
      compositional: the utterance must still accept under 6 before Apply;
      “apply only” itself is a clear acceptance.
   4. **Human-will-read is not the verb.** "I'll review it" /
      "let me read it" / "I'll look" without asking the agent
      to run this skill's `review` → clear agent re-review intent. If
      they also accepted the package, apply then stop-and-offer.
   5. **Except / adjust first.** Drop F2, take a listed
      optional, rewrite a proposed edit. Never Apply.
      If the adjusted package is fully determined from the
      already-shown proposal, keep that package in memory
      (no re-show) and continue to 6 / 7. Keep queued or named
      re-review intent if present. If 6 / 7 do not also match
      (except without accept), re-show the adjusted package and
      wait. If the owner must invent a new amendment, re-show,
      wait, and carry re-review intent across that wait unless
      they cancel it.
   6. **Accept** (open set): any clear package acceptance.
      Examples, not a closed list: `approved`, `yes`, `looks
      good`, `do it`, `lgtm`, `ok`, `go ahead`, `apply`.
      **Do:** apply, then step 10 according to the current re-review
      intent. Reject (2) wins over this.
   7. **Named re-review** (intent, same confirmation
      utterance): extra conjunct on accept. They ask this
      skill's `review` procedure to run on the artifact
      after apply. Paraphrases count: "re-review", "then
      review", "then run review", "review it after",
      "approved, re-review the spec", `/inspector review` in
      *this* utterance. Agent is the subject. **Do:** queue
      re-review and apply (if 6 did not already), then step 10
      queued path.
   8. **`re-review` alone.** Pending `keep`s → ask once,
      recommended answer: apply these first, then re-review.
      Do not skip the fold. Do not review the unamended
      artifact from this verb. No pending `keep`s (nothing to
      fold) → skip Apply; follow `review` on the current
      artifact (step 10 queued path).
   9. During the **questions** stop, "approved" /
      "approved, re-review" is not confirm. Finish asks (or
      say the package cannot be built yet). Do not apply. Do
      not start `review`.
9. **Apply** (only after a confirm that authorizes apply).
   Same path, same record. Do not mint a successor. Do not
   write `published`. Keep `status: draft` (opportunistic
   `.records/records.sh touch --status draft`, else file-mode
   `status: draft` only). If `stage: approved` is
   present, **drop it**. Do not create or append `## Review
   history`.

   Shared amend rules: Must-fix (`keep`) always. Nice-to-have only when it remains inside the
   artifact's accepted goal and review boundary, unless the human first changes that boundary
   upstream. Re-ground any fold that cites code; if
   you cannot verify it now, mark `(unverified — check at
   walk)` on the edited line. Complete the argued section
   (no "similar to section N", no "add error handling later").
   Keep the claim falsifiable.

   How, by kind: the kind file's `## Revision legal locations`.
   Keep headings and ids stable. A coverage gap may fill the
   named unit or append the next unused id when the kind
   file allows it. A new requirement is park, not a `keep`
   row.
10. **After confirm.**

   - **Queued or named re-review:** follow this skill's `review`
     procedure (`verbs/review.md`) on the artifact (amended
     if Apply ran; current if there was nothing to fold).
     The full procedure inherits the same boundary: it is not a delta mode, but it cannot turn a new
     adjacent observation into scope. Same-session
     authorship is accepted; do not recuse; depth dial stays
     default off. Do not start a walk.
   - **Else:** stop. Always `status: draft`; `stage: approved`
     dropped if it was present. One sentence the human can
     act on, then the path, then the offer: `review`. Do not
     run it.
