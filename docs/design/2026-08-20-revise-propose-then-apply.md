---
doctype: design
status: open
created: 2026-08-20
updated: 2026-08-20
tags: [spec]
---

# `revise` propose-then-apply — Spec

This library's design home is `docs/design/` (patient-zero: grimoire
authors the workshop, it does not run one on itself). This spec lives
here. Small feature: this file doubles as the plan.

Amends the shipped `revise` machine in
`docs/design/2026-08-18-contractor-revise.md` and
`docs/design/2026-08-18-blueprint-revise.md`. Those specs stay the
source for resolver, findings shapes, verify-before-classify,
disposition *vocabulary*, thrash brake, and in-place amend. They do
**not** stay the source for “review is not the author” on the named
re-review path — this spec **narrows** that 2026-08-18 rejection
(Approach → Narrowed; Pipeline → Exception (narrowing)). This spec
replaces the **user seam**
(today: table, then amend) and defines the **one case** `revise` may
run `review` after apply.

Settled 2026-08-20 in conversation. Human: logic lives in `revise`,
not `review`; propose amendments before applying; ask when unsure
about a finding or a remedy; “approved, re-review” applies then
re-reviews. Folded 2026-08-20 `needs-rework` findings in the same
session.

## Problem

`review` is doing its job. `revise` is folding too soon.

After a verdict, the owner-session either dumps the findings and
waits for the human to invent the next verb, or runs `revise`. Live
step 5 already shows a disposition table (Id / Finding / Action /
Why — e.g. `keep — edit Slice 2 Verify`) before step 6 amends. The
human sees recommended *dispositions*, not the edits. The table
asks only on `ask` rows and on `keep`s that change what gets built
/ what the spec claims. A batch of straightforward `keep`s can land
in the file with no package confirm and no concrete replacement.
An unclear *remedy* (two legal edits for a finding the owner
accepts) is not an `ask` unless it also changes scope.

The human cannot confirm a fold and request re-review in one
utterance. `revise` forbids invoking `review` in the same turn, so
“approved, re-review the plan” has nowhere to land: the agent either
ignores the second half or treats it as a new invocation after a
stop the human did not want.

The hole is not a missing verb. It is the seam: classify → (thin
ask / disposition table) → amend → stop, with no package confirm of
the actual edits and no human-authorized walk of the next arrow.

## Goal

`revise` on both `contractor` and `blueprint` verifies findings,
asks only where the owner is unsure, **proposes** the amendments
(concrete edits, not only dispositions), and amends **only after**
the human confirms that package.

A confirmation that also asks for this skill’s `review` after apply
applies, then runs that `review` procedure on the amended artifact.
Otherwise it applies and stops, offering re-review.

`review` stays the independent dump on its own invoke: verdict,
stamp, stop. The human invokes `revise` (“how should we revise
this?”, “let’s revise the plan”, “revise the spec”).

One feature. No new verb. No second remediation document. No
change to verdict vocabulary, disposition *vocabulary*
(`resolved` / `rejected` / `deferred`), or `build`’s refuse.

## Approach

**Chosen:** on **live numbering** (not the 2026-08-18 contractor
8-step list; thrash brake is live step 4): edit live step 3
(`unclear → ask` expands to finding *or* remedy) and replace live
steps 5–7 (user seam → amend → stop) with questions-if-needed →
proposal → confirm → apply → stop-or-re-review. Same replacement
in both packages. The proposal is the live conversation table
**enriched** with concrete amendments, plus a confirm wait — not a
new durable object. Named re-review and questions-without-package
are the only new shapes. SKILL.md briefing and “No verb invokes
the next” gain the confirmation exception. `review` procedure
stays byte-unchanged (dump + stamp + stop); the named path
*invokes* it, it does not grow a delta mode.

**Rejected: fold classify-and-propose into `review`.** The judge
is not the author. The 2026-08-18 specs rejected this for the same
reason. `review` still hands the unfiltered verdict to the owner
and stops.

**Rejected: `review` auto-enters `revise`.** The human walks that
arrow. Natural-language invoke of `revise` is enough; an
auto-chain would mix the two roles in one turn when the same
session just wrote the verdict.

**Narrowed (2026-08-18 rejected `revise` invoking `review` in the
same turn).** That rejection stands for *unbidden* same-turn
review: the session that classified and edited is the author;
auto-running `review` is self-review wearing the wrong badge. This
spec keeps that. It **narrows** the rejection: when the
confirmation of a proposal both accepts the package and asks for
this skill’s `review` after apply, `revise` follows that `review`
procedure on the amended artifact. Same-session. Not a different
pair of eyes. Authorized by the human. Do not recuse. Depth dial
stays default off. The stamp is still a real verdict of that
procedure. Live `Why re-review` in both `revise.md` files must be
rewritten to match; do not ship “different pair of eyes” next to
the exception.

**Rejected: a remediation-plan record.** Classification and the
proposal stay in the conversation. Dispositions still land in
Review history. The artifact stays one file.

**Rejected: quiz every `keep`.** That recreates the dump. Confident
rows wait in the proposal for one package confirm. Questions fire
only on uncertainty (finding *or* remedy). Product-class `keep`s
(new/dropped slice, changed Done-when / Goal / Approach /
Verification bar) live in the proposal, visually separated, not as
a second interview.

## Mechanism

### Pipeline (visible from every door)

Unchanged arrows:

```
plan/spec  →  review  →  approve              →  (build / host)
                    →  approve-with-changes →  build/host, or revise if asked
                    →  needs-rework         →  revise  →  review  →  …
```

Each arrow is still a stop. `revise` still does not start of its
own accord. **Exception (narrowing):** if the confirmation of a
`revise` proposal both accepts the package and asks for this
skill’s `review` after apply, `revise` follows that `review`
procedure after apply. That confirmation is the human walking
`revise → review`. SKILL.md’s “No verb invokes the next” is
qualified by this sentence, not left intact beside it. `revise`
does not otherwise invoke `review`.

Inside `revise` (stops, not extra arrows):

```
invoke  →  [park-ack and/or questions, if any]
        →  proposal  →  confirm  →  apply
                                 →  review  (only if named)
                                 →  stop    (otherwise)
```

Park-acknowledge is the live step-3 hold, not a new classify
word. If it fires with `ask`s, they share one questions-stop
message.

### What does not change

Copy forward from the 2026-08-18 specs and the live verb files
(do not fork). Live numbering.

- Invocation resolver (five cases) and wrong-artifact refuse.
- Findings shapes (Review history, council `RESULT.md`, named
  markdown, in-session list).
- Inventory numbering (`F1`, `F2`, …; source id in parentheses).
- Verify-before-classify against the artifact and `HEAD`, except
  the `ask` expansion in *Verify* below.
- Classify outcomes: `resolved` (already done), `push-back`,
  park (spec-aimed on contractor; grill-park on blueprint;
  job-aimed push-back on blueprint), `keep`, `keep-optional`.
  Park is **not** `ask`.
- Thrash brake (prior `resolved`/`rejected` returning as
  must-fix → `ask`) — live step 4.
- Disposition vocabulary after the fold (table below, pasted
  under Apply).
- Artifact-set deltas already in the blueprint spec (kind,
  summon, founding no-new-H2).

`(unverified — check at build)` is not a stand-in for a product
choice. Two legal remedies → `ask`, not an unverified fold.

### Verify: `ask` is finding *or* remedy

This is an edit to **live step 3**, not only 5–7. Keep live steps
1–2 and 4’s classify-the-batch rule.

Add these to the existing `unclear → ask` outcome. Same classify
word, not a new one. Classify `ask` (not `keep`) until the remedy
is chosen; after the answer, `keep` with the chosen location.

- Unsure the finding is true or in scope (already `ask`).
- Two legal readings of the finding (already `ask`).
- Two legal **remedies** for an accepted finding (which
  section/slice, which gate, spec vs job ownership).
- A reviewer confidence note the owner cannot independently
  verify against the artifact / `HEAD`.
- Thrash brake (already `ask`, live step 4).

Park-acknowledge is **not** on this list. Keep live step 3: tell
the human it belongs on the spec / `grill`; after they
acknowledge, the rest of the batch may proceed; the item stays
unmarked.

A confident `keep` that changes what gets built or what the spec
claims is **not** an `ask`. It lives in the proposal, marked
product-class. The package confirm is the product decision.
Today’s extra ask on those rows goes away so the human is not
interviewed twice.

### Procedure

Live steps 1–2 and 4 unchanged. Live step 3 gains the `ask`
expansion above. Replace live steps 5–7 with 5–9 below. Do not
cite live step numbers this spec deletes.

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
   — even if the human says “do it” / “approved, re-review” in
   the same message. Still step 6, then wait.

6. **Propose. Do not amend.** Conversation, not a file. The
   proposal *is* the live table plus concrete amendments, not a
   second artifact. Show:

   - One remediation table (Id, Finding, Action, Why) for the
     whole batch, including `push-back`, already-done, and
     parked (unmarked).
   - Product-class `keep`s visually separated from nits (new or
     dropped slice/section, changed Done-when / Goal / Approach /
     Verification bar).
   - For every `keep` and every `keep-optional` the owner
     **recommends taking**: a concrete amendment — location →
     what will change. Concrete enough that a gap between this
     proposal and the later edit is detectable. A small edit
     shows the replacement. A larger rewrite states the delta in
     that unit’s terms. Not “fix F1.”

   **Legal for this kind.** Every proposed edit must already be a
   legal in-place amend. Contractor: named slice / phase /
   conductor step; coverage gap may append the next unused id; a
   new requirement is the spec-park, not a `keep` row.
   Blueprint feature spec: named section; same coverage vs new-
   requirement split. ADR: Context / Decision / Alternatives /
   Consequences. Founding-shaped: location is a **mapped H2
   string**; no new H2; a seventh-H2 concern is grill-park or
   restore-the-shape, not a `keep` row. An illegal edit is
   park/`ask`, never a proposed `keep`.

   `keep-optional` rows state the recommended disposition
   (take, or defer). Bare approval accepts that recommendation.
   A `keep-optional` becomes `keep` only when the *proposal*
   recommended taking it and the human approved, or when the
   human promoted it in the confirm. Otherwise `deferred`.

   Then **stop and wait**. Every invoke of `revise` takes this
   path — “how should we revise this?”, “let’s revise the
   plan”, “revise the spec”, “revise the plan, just do it”,
   “apply now”, “skip the proposal”. There is no skip-proposal
   token. None of them apply in the same turn as the proposal.

7. **Confirm parse** (the wait **after the proposal** only).
   Compositional, not exclusive rows. A later `/contractor
   review` or `/blueprint review` after stop-and-offer is a
   **new arrow**, not this exception.

   1. **Reject** (closed set): `stop` / `don't` / `not yet` →
      do not amend. Drop any carried re-review intent.
   2. **Human-will-read is not the verb.** “I’ll review it” /
      “let me read it” / “I’ll look” without asking the agent
      to run this skill’s `review` → not named re-review. If
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
      skill’s `review` procedure to run on the artifact
      after apply. Paraphrases count: “re-review”, “then
      review”, “then run review”, “review it after”,
      “approved, re-review the plan”, `/contractor review` /
      `/blueprint review` in *this* utterance. Agent is the
      subject. **Do:** apply (if 4 did not already), then
      step 9 named path *instead of* step 9 else.
   6. **`re-review` alone.** Pending `keep`s → ask once,
      recommended answer: apply these first, then re-review.
      Do not skip the fold. Do not review the unamended
      artifact from this verb. No pending `keep`s (nothing to
      fold) → skip Apply; follow `review` on the current
      artifact (step 9 named path).
   7. During the **questions** stop, “approved” /
      “approved, re-review” is not confirm. Finish asks (or
      say the package cannot be built yet). Do not apply. Do
      not start `review`.

8. **Apply** (only after a confirm that authorizes apply).
   Same path, same record. Do not mint a successor. Do not
   flip `status:` to `current`. Stamp `updated:` (opportunistic
   `records.sh touch`, else file-mode). Do not delete Review
   history; add dispositions (below). Do not strip `founding`.

   Shared (every kind; copy of live amend rules): Must-fix
   (`keep`) always. Nice-to-have only when it does not change
   the job / spec’s goal, unless the human promoted it.
   Re-ground any fold that cites code; if you cannot verify
   it now, mark `(unverified — check at build)` on the edited
   line. Complete the edited unit (no “similar to slice N”,
   no “add error handling later”). Keep a verification step
   on every contractor slice you touch; keep a blueprint
   claim falsifiable.

   How, by kind:

   - **Contractor (plan / roadmap / runbook).** Edit the named
     slice / phase / conductor step. Keep slice and phase ids
     stable. A coverage gap (a spec requirement with no slice)
     may add a slice, appended, with the next unused id. A
     new requirement is the spec-park, not a coverage gap.
   - **Blueprint feature spec / design.** Edit the named
     section (Problem / Goal / Approach / Mechanism /
     Verification / Slices). Keep section headings and slice
     ids stable. Coverage gap may fill Mechanism or append a
     Slices row with the next unused id. A new requirement is
     the grill-park.
   - **ADR.** Edit Context / Decision / Alternatives /
     Consequences. Do not mint a successor ADR.
   - **Founding-shaped.** Stay on that file. Fill the named
     mapped H2. Do not add an H2.

   Then write dispositions. `revise` **adds** a disposition on
   each item it handled; it does not rewrite the reviewer’s
   prose.

   | Classify | After the fold | Disposition |
   |---|---|---|
   | `keep` (amended) | edit landed | `resolved — <what changed>` |
   | `already done` | no edit | `resolved — already present` |
   | `push-back` | no edit | `rejected — <reason>` |
   | `keep-optional` taken | edit landed | `resolved — <what changed>` |
   | `keep-optional` not taken | no edit | `deferred — <why>` |
   | parked | no edit | left unmarked (open) until the spec / `grill` is settled |

9. **After confirm.**

   - **Named re-review:** follow this skill’s `review`
     procedure on the artifact (amended if Apply ran;
     current if there was nothing to fold) — contractor:
     `skills/contractor/verbs/review.md`; blueprint: the
     inline `review` section of `skills/blueprint/SKILL.md`.
     Full procedure (two-axis, stamp, stop). Not a delta mode
     and not a different file. Same-session authorship is
     accepted; do not recuse; depth dial stays default off.
     Do not start `build` / sequencing.
   - **Else:** stop. One sentence the human can act on, then
     the path, then the offer. Incoming `needs-rework`:
     recommend re-review as the default next ask; do not run
     it. Incoming `approve-with-changes`: offer
     waive-and-proceed first; review optional. Contractor
     waive-and-proceed is `build`. Blueprint is host
     sequencing.

Opening lines of each `revise.md` today say the verb **stops
after the fold** and **does not run `review`.** Replace with:
stops after the proposal until confirmed; after apply, stops
unless the confirmation named re-review. Rewrite **Why
re-review**: the fold is unverified content, so a later
`review` (or a human waive) is how the artifact becomes a
candidate again. Unbidden same-turn `review` is still
forbidden. Named re-review is authorized same-session
running of the existing `review` procedure — not a different
pair of eyes.

### Routing

`description:` on both skills already triggers on apply-review-
findings / amend-a-needs-rework-artifact. Add the invoke
phrases so they route to `revise`, not `review` or a dump:

- how should we revise
- let’s revise / revise the plan / revise the spec
- (contractor) revise the roadmap / runbook, same path

Stay ≤ 1024 characters. Name no sibling. Dispatch-table `Does`
for `revise` becomes: classify findings, propose amendments,
fold on confirm. Blueprint verb-table Consumes → Produces for
`revise`: findings baton + spec → proposed amendments, then
amended spec on confirm. Blueprint “`revise` amends the named
artifact in place”: after confirm, not in the invoke turn.

SKILL.md briefing:

- Contractor “one ask per stop”: questions (when they fire)
  are a stop; the proposal is a stop; after apply without
  named re-review, the offer is a stop.
- Blueprint “after `revise`, one ask, then wait”: two possible
  stops before confirm (questions, then proposal), then
  confirm; after apply without named re-review, the offer is a
  further stop. Do not collapse questions and proposal into
  one ask.
- Under the pipeline diagram: keep “Each arrow is a stop.”
  Qualify “No verb invokes the next”: except a `revise`
  confirmation that asks for `review` after apply.

### `review` (both skills)

No procedure change. Verdict, stamp, findings, stop. The owner
still folds with `revise`. This verb still does not amend. The
named path in `revise` **invokes** this procedure; it does not
edit it.

### Out of scope

- Auto-entering `revise` from `review`.
- Auto-running `review` after apply when the human did not
  ask for it.
- Changing verdict vocabulary, Review history stamp format,
  or `build`’s refuse.
- A new verb, template, script, or remediation record.
- Promoting or closing the artifact.
- Council / forced depth-dial on the named re-review
  (default off, as today).
- Migrating `docs/design/` into `.records/` (patient-zero).

## Verification

**Mechanical**

- `cd <worktree> && skills/skill-builder/scripts/skills-lint.sh`
  → `fails=0`. Expected WARNs: orphan edge types;
  worktree-vs-clone symlink notes.
- Both `description:` lines ≤ 1024, quoted if they contain
  `: `, names no sibling `/name`, and include a revise-how /
  revise-the-plan-or-spec trigger.
- Contractor `verbs/review.md` and inline `review` in
  blueprint `SKILL.md` still do not contain a receiving-side
  fold procedure.

**Judgment**

- Read-back of both `verbs/revise.md` against this Mechanism
  (step-3 `ask` expansion, questions-if-needed with no
  proposal dump, proposal-before-apply, compositional confirm
  parse, named-re-review invokes the existing `review`
  procedure, park is not `ask`, founding-legal proposals,
  live `Why re-review` rewritten).
- A reader of each SKILL.md can see the qualified “No verb
  invokes the next” under the pipeline without opening this
  spec.
- A same-turn “approved, re-review” after a proposal applies
  then follows `review`. Bare “approved” applies and stops.
  “yes, except F2, and re-review” applies the adjusted
  package (F2 dropped) then follows `review` when F2 was
  already in the shown proposal.
- “How should we revise this?” and “revise the plan, just do
  it” do not write the artifact in that turn.

**No new automated test.** The verb is agent prose. The lint
gate is the mechanical check.

## Slices

This spec doubles as the plan. Two slices, same machine, two
packages. Either order; no coupling beyond the shared rules
above.

- [ ] **Slice 1: contractor `revise` seam**
  <requires: —>
  - Paths: `skills/contractor/SKILL.md`;
    `skills/contractor/verbs/revise.md`.
  - Verify: lint `fails=0`; description ≤ 1024, sibling-clean,
    revise-how trigger present; `revise.md` proposes before
    apply; named-re-review follows
    `skills/contractor/verbs/review.md`; that file is
    unchanged as a fold procedure; pipeline line qualifies
    “No verb invokes the next”; `Why re-review` no longer
    claims a different pair of eyes on the named path.

- [ ] **Slice 2: blueprint `revise` seam**
  <requires: —>
  - Paths: `skills/blueprint/SKILL.md`;
    `skills/blueprint/verbs/revise.md`.
  - Verify: lint `fails=0`; description ≤ 1024, sibling-clean,
    revise-how trigger present; `revise.md` proposes before
    apply; named-re-review follows the inline `review`
    section of `SKILL.md` (no `verbs/review.md`); that
    section is unchanged as dump+stop; founding-legal
    proposals (mapped H2 only); grill-park / wrong-artifact
    deltas from the 2026-08-18 blueprint spec still hold;
    pipeline line qualifies “No verb invokes the next”;
    Consumes → Produces and “amends in place” do not read as
    same-turn write.

## Review history

### 2026-08-20 — needs-rework

Must-fix:

- **F1** Mechanism → Pipeline exception + Approach (Rejected:
  same-turn re-review) + copy-forward “review is not the
  author” — these three cannot all be true. Named re-review
  has `revise` follow `review` in the apply turn. That is
  the 2026-08-18 rejection (`revise` invokes `review` in
  the same turn; the session that classified and edited is
  the author). Human-naming does not create a second pair
  of eyes. Relabeling it “the human walking the arrow”
  still has a verb invoke the next, against both SKILL.md
  lines. **Fix:** pick one invariant. Recommended: keep
  one-utterance “approved, re-review” as the human asked,
  and **narrow** the 2026-08-18 rejection in this spec —
  named re-review is authorized same-session delta; drop
  “those specs stay the source for review is not the
  author” for that path; qualify “No verb invokes the
  next”; rewrite live `Why re-review` when the verb files
  change. Do not keep the old sentences and the exception.
  - resolved — Approach now **Narrowed**; copy-forward no
    longer claims those specs own “review is not the
    author” on this path; pipeline qualifies “No verb
    invokes the next”; Why re-review rewrite is in the
    verb-file opening.

- **F2** Procedure step 8 vs “`review` procedure does not
  change” — unimplementable. Step 8 says read this skill’s
  **`review` verb file** and also run a cheaper **delta**
  pass. Blueprint has no `verbs/review.md` (inline in
  `SKILL.md` at the `review` heading). Live `review` is a
  full-document two-axis critique (“documents, not diffs”)
  and “this verb is not the author.” An agent cannot follow
  that procedure, run a delta, and remain independent.
  Slice 2 verify inherits a contractor-only `review.md`
  check. **Fix:** “Follow this skill’s `review` procedure
  (`verbs/review.md` on contractor; inline `review` in
  blueprint `SKILL.md`).” If it is a real delta pass, that
  is a `review` procedure change — put it there. If
  `review` stays byte-unchanged, delete “delta pass” and
  “verb file”; the named path just invokes that procedure
  on the amended artifact.
  - resolved — named path invokes the existing procedure
    (contractor `verbs/review.md`; blueprint inline
    `SKILL.md`); no delta mode; slice 2 verify no longer
    inherits a `review.md` check.

- **F3** Procedure step 7 confirm parse — not a parser.
  Rows do not compose. “yes, except F2, and re-review”
  hits except (adjust, maybe re-show, wait) and
  named-re-review (apply then review) with no winner.
  “Names re-review” is one example string, not a
  predicate (`then run review`, `/contractor review`,
  “I’ll review it” as the human reading). No skip-proposal
  rule for “revise the plan, just do it.” Resolving `ask`s
  is not stated as *not* confirm. **Fix:** (1) Intent
  test: the utterance both accepts the package and asks
  for this skill’s `review` after apply — paraphrases
  count; a later `/contractor review` after stop-and-offer
  is a new arrow. Counter-list: human-will-read is not
  the verb. (2) Except first; if the delta is already in
  the shown package (drop F2, take a listed optional),
  apply the adjusted package and keep named re-review;
  re-show and wait only when the owner must invent a new
  amendment, carrying the re-review intent across that
  wait. (3) Every `revise` invoke still proposes —
  there is no skip-proposal token. (4) Answering
  questions is not package confirm; still step 6 and
  wait. (5) “approved, re-review” during the questions
  stop is not confirm.
  - resolved — step 7 is a compositional parser with
    those five rules plus `re-review` alone and open-set
    accept (N3).

- **F4** Verify “`ask` is finding *or* remedy” vs step 5
  hold — park-acknowledge is listed as the same class as
  `unclear → ask`, then the proposal is held until every
  `ask` is `keep` / `push-back` / `keep-optional`. Parks
  cannot exit that set without ceasing to be parks.
  Live park is a separate verify outcome (contractor
  step 3 spec-aimed; blueprint grill-park), already a
  hold, then the rest proceeds unmarked. **Fix:** park
  is not `ask`. Keep live step 3. Step 5 holds only
  classify-`ask`. If park-ack and `ask`s both fire, one
  questions-stop message. Drop park from the ask-bullet
  list.
  - resolved — park dropped from the `ask` list; live
    step 3 hold kept; shared questions-stop message.

- **F5** “Apply means live step 6” after replacing steps
  5–7 — dangling pointer. New step 6 is Propose. Do not
  amend. Live step 6 is in-place amend; dispositions are
  the section *after* the procedure, not step 6. This
  file doubles as the plan. **Fix:** paste today’s amend
  + disposition rules under an Apply step. Never cite
  live step numbers this spec deletes. Say “live
  numbering, not the 2026-08-18 contractor 8-step list”
  (thrash brake is live step 4).
  - resolved — step 8 Apply pastes amend + disposition
    table; live numbering called out; no “live step 6”.

- **F6** Approach “the rest of each verb file is
  unchanged” vs extending `unclear → ask` — false on
  HEAD. Remedy uncertainty and unverifiable confidence
  notes are edits to live step 3, not only 5–7.
  **Fix:** keep steps 1–2 and 4’s classify-the-batch
  rule; name step 3 as the other in-scope edit.
  - resolved — Approach and Procedure name live step 3
    as in-scope.

- **F7** Procedure step 5 vs 6 — the questions stop does
  not say what to show, only that the package is held.
  Live step 5 shows the table while asking; agents will
  dump questions and the full amendment list in one
  message, or treat “do it” in the answers as confirm.
  **Fix:** step 5 shows only unresolved `ask`s (and
  park-acks if any). No keep-amendment text. Then a
  later proposal stop.
  - resolved — step 5 show-only-asks; answers are not
    confirm.

- **F8** Procedure step 6 proposal shape vs copy-forward
  founding no-new-H2 — proposal text is slice/section
  flavored (“verify command, paths”). Founding
  constraints live only at apply. A confirmed illegal
  package (seventh H2, Slices stub) then hits no-new-H2.
  **Fix:** every proposed edit must already be legal for
  this kind. Founding location = a mapped H2 string; no
  new H2. Illegal → park/`ask`, not a `keep` row.
  - resolved — step 6 **Legal for this kind**, founding
    mapped H2 only.

Nice-to-have:

- **N1** Goal “no change to dispositions” vs
  `keep-optional`: bare approval now accepts a
  recommended *take*. Live rule is take only if the
  human says yes. Combined with dropping the extra ask
  on scope-changing `keep`s, one “approved” can land a
  new slice. Tighten Goal to “no change to disposition
  *vocabulary*,” or keep an explicit promote on optional
  take / visually separate product-class edits.
  - resolved — Goal says disposition *vocabulary*;
    product-class `keep`s visually separated in the
    proposal.

- **N2** Problem overclaims HEAD: live step 5 already
  shows a disposition table with Action + Why before
  amend. The hole is no concrete replacement, no package
  confirm on easy `keep`s, and no named-re-review parse.
  - resolved — Problem names the live table and the
    actual hole.

- **N3** Confirm lexicon (`approved` / `yes` / `looks
  good` / `do it`) is examples, not a closed set.
  Rejection stays closed (`stop` / `don't` / `not yet`).
  - resolved — step 7 accept is an open set; reject is
    closed.

- **N4** SKILL.md briefing undercount: blueprint “that
  ask is the proposal (or the questions)” drops the
  after-apply offer and collapses two stops. Consumes →
  Produces still says findings → amended spec. “`revise`
  amends the named artifact in place” reads as same-turn.
  - resolved — Routing lists two pre-confirm stops plus
    the offer; Consumes → Produces and “amends in place”
    after confirm.

- **N5** After apply, `approve-with-changes` should offer
  waive-and-proceed first; `needs-rework` should
  recommend re-review first.
  - resolved — step 9 splits the offer on the incoming
    stamp.

- **N6** Substrate: most of the goal is a tighter live
  step 5 (always confirm; put the delta in the table),
  not a new “proposal” object. Named re-review and
  questions-without-package are the only new shapes.
  Don’t mint a parallel abstraction if the table is
  already the medium.
  - resolved — Approach: proposal is the enriched table;
    not a new durable object.

### 2026-08-20 — needs-rework

Delta pass after `revise`. Prior F1–F8 / N1–N6 are resolved.
Ground-check: 8 refs, 0 unresolved. Same-session author;
depth dial off.

Must-fix:

- **F9** Procedure step 7 items 4–5 — Accept has no Do.
  Compositional rules: 4 defines the open accept set
  (`approved`, `yes`, …) and does not say apply. 5 says
  “Then apply, then step 9’s named path” only on the
  named-re-review utterance. Bare “approved” matches 4
  and not 5, so the primary confirm path never authorizes
  Apply. Verification claims it applies and stops; the
  parser does not. **Fix:** 4’s Do is apply, then step 9
  else. 5 is an extra conjunct on the same utterance
  (also follow `review`). Reject still wins over both.
  - resolved — 4’s Do is apply then step 9 else; 5 is
    extra conjunct, named path instead of else.

- **F10** Procedure step 7 item 6 vs step 9 named path —
  no pending `keep`s + `re-review` alone → “step 9
  without an apply.” Step 9 named path always says “on
  the amended artifact.” Nothing was amended. **Fix:**
  step 9 runs `review` on the artifact (amended if Apply
  ran; current if there was nothing to fold).
  - resolved — step 9 named path is on the artifact
    (amended if Apply ran; current if nothing to fold);
    7.6 skips Apply when there is nothing to fold.

- **F11** Procedure step 8 Apply vs live
  `skills/blueprint/verbs/revise.md` step 6 — claimed
  “copy of live amend rules.” Contractor bullets include
  re-ground, complete-slice, must-fix always. Blueprint
  feature-spec bullets omit live re-ground, “complete the
  argued section,” and must-fix/nice-to-have. An
  implementer replacing live step 6 from this paste
  drops them. **Fix:** paste those three lines under the
  blueprint feature-spec / ADR / founding bullets (or
  once above the kind split, shared).
  - resolved — shared amend rules sit above the kind
    split (must-fix, nice-to-have, re-ground, complete).

Nice-to-have:

- **N7** Opening “Mechanism → Named re-review” points at
  a heading that does not exist. Point at Approach
  **Narrowed** or Pipeline **Exception (narrowing).**
  - resolved — opening pointer names Approach Narrowed
    and Pipeline Exception (narrowing).

- **N8** “review it after” is still on neither the named
  paraphrase list nor the human-will-read counter-list.
  - resolved — named paraphrases include “review it
    after”; “I’ll review it” stays human-will-read.

### 2026-08-20 — approve-with-changes

Delta pass after the F9–F11 fold. F9–F11 / N7–N8 resolved.
Ground-check: 8 refs, 0 unresolved. Same-session author;
depth dial off. Prior F1–F8 remain resolved.

Must-fix: none.

Nice-to-have:

- **N9** Procedure step 7 item 3 still has its own Apply
  (“apply it (no re-show)”) while item 4’s Do is also
  apply. “yes, except F2” matches both and would write
  twice. **Fix:** item 3 only adjusts the in-memory
  package (or re-shows). Apply runs once, from 4 / 5 / 6.
  - resolved — item 3 never Applies; in-memory adjust
    then 4 / 5, or re-show and wait.

- **N10** Procedure step 9 is titled “After apply” but
  item 6 can reach the named path with Apply skipped.
  **Fix:** title it “After confirm.”
  - resolved — step 9 titled **After confirm.**
