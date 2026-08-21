---
doctype: plans
status: done
created: 2026-08-20
updated: 2026-08-21
tags: [plan]
---

# `revise` propose-then-apply — Implementation Plan

Shipped 2026-08-21: both slices walked; lint `fails=0`.
File-mode close — no ledger on this host.

Tracer: ship the new `revise` seam on contractor end to end (procedure +
router), then widen it onto blueprint. Agent prose only; no new script
or template.

Spec: `docs/design/2026-08-20-revise-propose-then-apply.md`
(latest stamp `approve-with-changes`; N9–N10 folded). The spec’s own
Slices section is the coverage map; this file sequences it.

Grounded 2026-08-20 against worktree `HEAD`.
`skills/blueprint/scripts/ground-check.sh` on the spec: `checked=8`
`unresolved_count=0`. Prior art: live
`skills/contractor/verbs/revise.md` and
`skills/blueprint/verbs/revise.md` still stop after the fold and do
not run `review` (opening lines 17–18). No existing
“Propose. Do not amend” / skip-proposal token. Do not size from the
2026-08-18 contractor spec’s 8-step list — live numbering (thrash
brake is step 4).

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Patient-zero.** This plan lives in `docs/design/`. Do not mint
  `.records/`. Do not add door blocks to this library’s `AGENTS.md`.
- **Spec is the prose source.** Copy Mechanism (Verify `ask`
  expansion, Procedure steps 5–9, Routing, Why-re-review rewrite)
  into the verb files. Do not invent a third procedure in this plan.
- **Live numbering.** Edit live step 3 (`unclear → ask`) and replace
  live steps 5–7. Leave resolver, findings shapes, inventory, step 4
  classify-the-batch + thrash brake, and the disposition table
  structure in place (vocabulary unchanged).
- **`review` stays dump+stop.** Do not edit
  `skills/contractor/verbs/review.md`. Do not add a receiving-side
  fold or a delta mode to blueprint’s inline `review` in
  `skills/blueprint/SKILL.md`. Named re-review *invokes* that
  procedure from `revise.md`.
- **Independence.** `description:` names no sibling `/name`. Stay
  ≤ 1024 characters. Quoted (contains `: `).
- **Lint.** `skills/skill-builder/scripts/skills-lint.sh` →
  `fails=0` after each slice. Expected WARNs: orphan edge types;
  worktree-vs-clone symlink notes.
- **Do not touch** `verbs/build.md`, templates, `ground-check.sh`,
  `skills/blueprint/docs/ideal-use.md`, or the 2026-08-18 revise
  specs.

## Slices

- [x] **Slice 1: contractor `revise` seam** <requires: —>

  The tracer. One package, full path: classify → questions-if-needed
  → proposal → confirm → apply → stop-or-named-`review`.

  - Files:
    - modify `skills/contractor/verbs/revise.md`
    - modify `skills/contractor/SKILL.md`
    - do **not** modify `skills/contractor/verbs/review.md`
  - Change:
    1. **`revise.md` opening.** Replace “This verb **stops** after
       the fold. It does not run `review`.” with: stops after the
       proposal until confirmed; after apply, stops unless the
       confirmation named re-review. Rewrite **Why re-review** from
       the spec (fold is unverified; unbidden same-turn `review`
       still forbidden; named re-review is authorized same-session
       running of the existing `review` procedure — not a different
       pair of eyes).
    2. **Live step 3.** Extend `unclear → ask` per spec *Verify:
       `ask` is finding or remedy* (finding, two legal readings,
       two legal remedies, unverifiable confidence note). Classify
       `ask` until the remedy is chosen. Park stays the live
       spec-aimed hold — not `ask`.
    3. **Replace live steps 5–7** with spec Procedure steps 5–9
       (questions show-only-asks; Propose. Do not amend; confirm
       parse including N9 — item 3 never Applies; Apply with
       shared amend rules + contractor kind bullets; After
       confirm). Apply points at the existing
       `## Review history — dispositions` section (write
       dispositions below); do not paste the spec’s table into
       the procedure. One table, after Apply.
    4. **Named re-review** follows
       `skills/contractor/verbs/review.md` on the artifact
       (amended if Apply ran; current if nothing to fold).
    5. **`SKILL.md` description.** Current length 371. Insert a
       how-we-should-revise trigger, e.g. after the
       apply-findings clause:

       `to apply review findings or amend a needs-rework job, to ask how we should revise a plan, or to execute a plan or runbook.`

       Draft whole line is 407 characters. Keep the rest. No
       sibling `/name`.
    6. **Dispatch `Does`.** `revise` → `classify findings, propose amendments, fold on confirm`.
    7. **Pipeline.** Keep the arrows. Keep “Each arrow is a stop.”
       Qualify “No verb invokes the next”: except a `revise`
       confirmation that asks for `review` after apply.
    8. **Brief the human.** Qualify the live sentence
       `After \`plan\`, \`review\`, or \`revise\`, stop and wait.`
       the same way item 7 qualifies “No verb invokes the next.”
       Questions (when they fire) are a stop; the proposal is a
       stop; after apply without named re-review, the offer is a
       stop. Named re-review is the exception — do not leave the
       live sentence intact beside the new list.
  - Verify:
    ```
    skills/skill-builder/scripts/skills-lint.sh
    ```
    `fails=0`. Then:
    ```
    git diff --name-only -- skills/contractor/verbs/review.md
    ```
    empty. And:
    ```
    rg -n "Propose\\. Do not amend|skip-proposal|After confirm" skills/contractor/verbs/revise.md
    rg -n "stops after the fold|still a different pair of eyes|User seam|cheaper" skills/contractor/verbs/revise.md
    rg -n "No verb invokes the next, except" skills/contractor/SKILL.md
    rg -n "No verb invokes the next\\.?$" skills/contractor/SKILL.md
    rg -n "how we should revise" skills/contractor/SKILL.md
    ```
    Expected: first `rg` hits; second `rg` **no** hits; third `rg`
    hits; fourth `rg` **no** hits (bare pipeline line gone);
    description contains the revise-how trigger. Python length of
    `description:` ≤ 1024.

- [x] **Slice 2: blueprint `revise` seam** <requires: —>

  Same machine, blueprint artifact set. Parallel-eligible with
  slice 1 (no file overlap); sequence after 1 if you want one
  lint of the pair.

  - Files:
    - modify `skills/blueprint/verbs/revise.md`
    - modify `skills/blueprint/SKILL.md`
    - do **not** add `skills/blueprint/verbs/review.md`
    - do **not** turn inline `review` into a fold procedure
  - Change:
    1. **`revise.md`.** Same opening / Why-re-review / step-3
       `ask` expansion / steps 5–9 as slice 1, with blueprint
       deltas from the spec: grill-park (not spec-aimed park);
       job-aimed `push-back`; Apply kind bullets for feature
       spec / ADR / founding-shaped (mapped H2 only, no new
       H2); founding-legal proposals (illegal edit is
       park/`ask`, never a `keep` row). Named re-review
       follows the inline `review` section of
       `skills/blueprint/SKILL.md`.
    2. **`SKILL.md` description.** Current length 572. Insert
       `, or to ask how we should revise a spec` after the
       amend-a-needs-rework-spec clause. Draft whole line is
       611 characters. No sibling `/name`.
    3. **Verb table.** `revise` Does: `classify findings, propose amendments, fold on confirm`.
       Consumes → Produces: `findings baton + spec → proposed amendments, then amended spec on confirm`.
    4. **Pipeline.** Same qualification as contractor: “No verb
       invokes the next” except a `revise` confirmation that
       asks for `review` after apply.
    5. **Brief the human** (line 26). Two possible stops before
       confirm (questions, then proposal); after apply without
       named re-review, the offer is a further stop. Do not
       collapse questions and proposal into one ask.
    6. **State between verbs** (line 336). `revise` amends the
       named artifact in place **after confirm**, not in the
       invoke turn.
    7. Inline `review` (heading through After the verdict):
       unchanged as dump + stamp + stop + pointer at
       `verbs/revise.md` for the fold.
  - Verify:
    ```
    skills/skill-builder/scripts/skills-lint.sh
    ```
    `fails=0`. Then:
    ```
    test ! -e skills/blueprint/verbs/review.md
    rg -n "Propose\\. Do not amend|mapped H2" skills/blueprint/verbs/revise.md
    rg -n "stops after the fold|still a different pair of eyes|User seam|cheaper" skills/blueprint/verbs/revise.md
    rg -n "No verb invokes the next, except" skills/blueprint/SKILL.md
    rg -n "No verb invokes the next\\.?$" skills/blueprint/SKILL.md
    rg -n "how we should revise" skills/blueprint/SKILL.md
    rg -n "This verb does not amend" skills/blueprint/SKILL.md
    ```
    Expected: no `verbs/review.md`; first `rg` hits; second `rg`
    **no** hits; third `rg` hits; fourth `rg` **no** hits (bare
    pipeline line gone); description trigger present; inline
    `review` still “does not amend.” Description length ≤ 1024.

## Done when

Both packages follow the spec Mechanism: `revise` proposes before
any write; confirm parse Applies once; named re-review invokes the
existing `review` procedure; `review` itself is still dump+stop.
Lint `fails=0`. Descriptions route “how should we revise” to
`revise`. A reader of each SKILL.md sees the qualified pipeline
without opening the spec.

_On completion (before landing), run the host's close-the-books sweep._

## Review history

### 2026-08-21 — approve-with-changes

Must-fix: none.

Nice-to-have:

- **N1** Slice 1 / Slice 2 Verify absence-`rg` — greps
  `stops after the fold|different pair of eyes` but not leftover
  live `User seam` or Why-re-review's `delta` / `pass` (split across
  lines 13–14 on contractor today). An implementer who patches only
  the grepped phrases can ship a chimera: live step 5's extra ask on
  product-class `keep`s still there, named re-review still billed as
  a cheaper delta pass — the contradiction F2 already killed.
  **Fix:** add those leftovers to the second `rg` (expect no hits).
  Judgment read-back in Done when still owns the rest of the
  Mechanism.
  - resolved — second absence-`rg` includes `User seam` and
    `cheaper` (the live Why-re-review tell); expect no hits.

- **N2** Slice 1 Change item 8 (Brief the human) — does not name
  the live sentence it has to qualify:
  `After \`plan\`, \`review\`, or \`revise\`, stop and wait.`
  Adding the three-stop list beside that line leaves the router
  saying `revise` always stops, which is the named-re-review hole.
  **Fix:** cite that sentence; qualify it the same way item 7
  qualifies “No verb invokes the next.”
  - resolved — item 8 cites the live sentence and forbids leaving
    it intact beside the new list.

- **N3** Slice 1 / 2 Verify `rg "No verb invokes the next"` —
  that pattern matches the current unqualified line, so the
  “pipeline line is qualified, not the old bare sentence” expected
  is judgment on stdout, not a fail. **Fix:** require the
  exception on the same line (or that a bare-only line is gone).
  - resolved — must-hit `No verb invokes the next, except`;
    must-not-hit bare `No verb invokes the next.?$`.

- **N4** Global Constraints “Do not touch `docs/ideal-use.md`” —
  written as a repo-root path (`docs/` is a top-level dir).
  Ground-check: `unresolved_count=2` —
  `docs/ideal-use.md` (missing) and
  `skills/blueprint/verbs/review.md` (missing, intentional
  do-not-add). The real file is
  `skills/blueprint/docs/ideal-use.md`. **Fix:** write the
  skill-relative path so “do not touch” points at a file that
  exists.
  - resolved — constraint path is
    `skills/blueprint/docs/ideal-use.md`.

- **N5** Slice 1 Change item 3 — “Keep the existing Review
  history dispositions section; do not duplicate a second table
  if Apply already pasted it — one table, after Apply.” Spec
  step 8 pastes the table under Apply; live files keep it in
  `## Review history — dispositions` after the procedure.
  Two legal layouts. **Fix:** one sentence: Apply points at the
  existing section (write dispositions below); do not paste the
  spec’s table into the procedure.
  - resolved — Apply points at the existing section; do not paste
    the spec’s table into the procedure.
