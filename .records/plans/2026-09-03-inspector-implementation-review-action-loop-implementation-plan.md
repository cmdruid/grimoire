---
doctype: plans
status: published
stage: approved
schema: contractor/plan@1
tags: [plan]
---

# Inspector implementation review action loop — Implementation Plan

The first slice proves the riskiest default path end to end: a failing implementation review,
confirmed isolated remediation, safe integration, and a complete re-review. Later slices widen the
interaction and failure matrices, then align the public responsibility surfaces.

Spec: `.records/specs/2026-09-03-inspector-implementation-review-action-loop.md`

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Published contract:** Implement the governing spec exactly. The checklist is verdict-sensitive;
  recommended changes are first, focused, and off, while must-fix remediation, complete re-review,
  and eligible isolated execution are on for `needs-rework`.
- **Review/write boundary:** The review phase remains source-mutation-free through verdict reporting.
  Only a later confirmed action authorizes remediation. A verdict alone never writes source, status,
  stage, records, setup state, or project doctrine.
- **Continuation custody:** Keep implementation `revision-after-review: unavailable`. It continues to
  forbid document `revise`/`refine` for code; it does not suppress the separate confirmed
  implementation action loop. Document review behavior and status custody remain unchanged.
- **Destination safety:** Resolve one writable destination before offering fixes. Never infer it from
  cwd or detached history. Before either route writes, compare HEAD, staged bytes, unstaged bytes,
  and reviewed untracked paths and contents with the verdict evidence. Drift stops without mutation.
- **Isolation safety:** Offer isolation only for a clean committed reviewed endpoint and an available
  isolated executor. Start from that exact endpoint, confine the writer to the isolated checkout,
  independently inspect and verify its result, and recheck the destination immediately before
  integration. Never reproduce a dirty worktree with an invented snapshot/copy protocol.
- **Full re-review:** After a successfully applied selected package, review from the original base
  through the complete remediated result. Never reduce the pass to the fix delta or accept the
  implementation agent's self-report. A new verdict gets a fresh action close.
- **Portable package:** Keep Inspector self-contained, its router thin, and its prose generic. Add no
  sibling-skill, provider, model, or harness API names; no runtime store, setup behavior, hook,
  project doctrine kind, public verb, parser, or helper script is justified for this instruction-led
  state machine.
- **Behavioral evidence:** Extend the existing shell state-machine fixtures, not only prose-presence
  checks. Every new guard or absence assertion gets a deliberate failing plant, an occurrence-count
  check, restoration, and byte-identity proof. Keep the fixtures portable to macOS `/bin/bash` and
  avoid GNU-only regular-expression behavior.
- **Patient-zero boundary:** Do not add deployed Inspector layout or project door blocks to root
  `AGENTS.md`. Historical specifications and reports remain unchanged.
- **Coexisting work:** This stream was synchronized to `main` at `72ae94c` before planning. Re-run the
  divergence check before editing and sync if the target moved. Preserve unrelated work and stage
  only paths owned by the active slice.
- **Snapshot warning:** The paths and baseline below were verified while drafting this plan; Task 0
  must repeat the checks against the implementation worktree before any edit.

## Task 0 — Re-ground before editing

Read-only; produce no commit.

1. Run:

   ```sh
   git status --short
   git log stream/inspector..main --oneline
   skills/contractor/scripts/ground-check.sh \
     "$(git rev-parse --show-toplevel)" \
     .records/specs/2026-09-03-inspector-implementation-review-action-loop.md
   ```

   Confirm the spec is tracked with `status: published`, the stream owns the worktree, every rooted
   reference resolves, and no dirty Inspector path belongs to another session. If `main` moved,
   follow the Workstream sync procedure before sizing or editing.
2. Re-read the complete governing spec and these live seams:

   ```text
   AGENTS.md
   skills/skill-builder/docs/DOCTRINE.md
   skills/inspector/SKILL.md
   skills/inspector/verbs/review.md
   skills/inspector/verbs/revise.md
   skills/inspector/verbs/refine.md
   skills/inspector/kinds/implementation.md
   skills/inspector/scripts/tests/run.sh
   skills/inspector/scripts/tests/review-close-test.sh
   skills/inspector/scripts/tests/implementation-test.sh
   skills/inspector/scripts/tests/revise-test.sh
   skills/inspector/scripts/tests/refine-test.sh
   docs/design/2026-08-21-architect-contractor-inspector.md
   README.md
   PACK.md
   ```
3. Search capability-wide before adding instructions or fixtures:

   ```sh
   rg -n "verdict.only|verdict only|remediat|implementation review|revision-after-review|close_review" \
     skills/inspector docs/design/2026-08-21-architect-contractor-inspector.md README.md PACK.md
   ```

   Expected baseline: `review.md`, the router, the implementation kind, the responsibility spine,
   and both focused test files still encode a verdict-only implementation close. No existing
   Inspector action adapter, destination resolver, or remediation runtime exists to reuse.
4. Run:

   ```sh
   skills/inspector/scripts/tests/run.sh
   skills/skill-builder/scripts/skills-lint.sh
   ```

   Expected planning baseline: Inspector reports `17/63/49/81/46/35` passing assertions across its
   six fixtures; skill lint reports `fails=0` with the three existing orphan-edge warnings. If the
   baseline differs, reconcile the plan with the live behavior before editing.

## Slices

- [x] **Slice 1: Default isolated remediation and full re-review tracer** — requires: —
  - Files:
    - `skills/inspector/SKILL.md`
    - `skills/inspector/verbs/review.md`
    - `skills/inspector/kinds/implementation.md`
    - `skills/inspector/scripts/tests/review-close-test.sh`
    - `skills/inspector/scripts/tests/implementation-test.sh`
  - Change:
    1. Red-first, replace the fixture assumption that every implementation closes `verdict-only`
       with one end-to-end `needs-rework` transition: both finding classes are present; the ordered
       selection leaves recommendations off and selects must-fix, full re-review, and eligible
       isolation; confirmation fixes only must-fix findings.
    2. Model the clean exact-endpoint route in `implementation-test.sh`: retain the reviewed base and
       after endpoint, prove the destination is clean and unchanged before isolated checkout
       creation, confine the implementation writer to that checkout, return a reviewable change plus
       verification evidence, and require the primary session to inspect and verify it before
       integration.
    3. Model the second drift guard immediately before integration. A changed HEAD or any staged,
       unstaged, or untracked destination state must leave the returned change unapplied. Red-prove
       both the pre-write and pre-integration guards, then restore the fixtures byte-for-byte.
    4. Update `review.md` so the existing kind detection, evidence collection, adequacy, materiality,
       verdict mapping, and conversation-only report complete before a distinct implementation
       action close begins. Preserve the no-write verdict turn.
    5. Add the exact default checklist ordering and confirmation boundary. A clear acceptance enters
       the selected remediation package; rejection or dismissal writes nothing. Re-review runs only
       after the whole package applies successfully.
    6. After integration, invoke the complete implementation-review procedure from the original base
       through the new destination result. Prior findings are evidence, not a reduced checklist; the
       fresh verdict receives a fresh action close rather than authorizing another write.
    7. Align the thin router and implementation kind with this separation. Keep
       `revision-after-review: unavailable`, `Revision legal locations: None`, and implementation's
       no-status/no-publish rules; replace only claims that suppress the confirmed post-verdict
       action loop.
  - Verify:

    ```sh
    skills/inspector/scripts/tests/review-close-test.sh
    skills/inspector/scripts/tests/implementation-test.sh
    ```

    Expected: the default failing-review tracer reaches isolated remediation only after confirmation,
    integrates only into the unchanged destination, and launches a complete same-base re-review;
    verdict reporting itself remains byte-identical and mutation-free.

- [ ] **Slice 2: Complete action, presentation, and failure matrices** — requires: 1
  - Files:
    - `skills/inspector/SKILL.md`
    - `skills/inspector/verbs/review.md`
    - `skills/inspector/kinds/implementation.md`
    - `skills/inspector/scripts/tests/review-close-test.sh`
    - `skills/inspector/scripts/tests/implementation-test.sh`
  - Change:
    1. Complete the verdict matrix. `needs-rework` offers selected must-fix remediation;
       `approve-with-changes` leaves recommendations first/focused/off and accepts as-is on untouched
       defaults; `approve` returns directly without a meaningless remediation checklist. Omit absent
       finding classes and keep execution/re-review modifiers inert when no fix is selected.
    2. Specify the presentation adapter once. A native multi-select preserves row order, focus, and
       defaults. The textual fallback renders the same semantic selection, names the actual selected
       route, excludes recommendations by default, accepts clear confirmation, re-presents adjusted
       packages once, and treats cancellation as no-write.
    3. Complete route resolution. A resolved dirty destination or missing executor exposes inline
       before confirmation; deselecting eligible isolation also selects inline. An ambiguous or
       missing destination asks and stops. A post-confirm isolation failure stops and offers inline
       rather than silently weakening the chosen route.
    4. Make the shared pre-write identity comparison cover HEAD, staged bytes, unstaged bytes, and
       reviewed untracked paths and contents. Include a fixture where dirty contents change without
       changing the status-path population; it must block inline mutation. Separately, make a clean,
       isolation-eligible destination gain a new HEAD, staged, unstaged, or untracked state after
       confirmation; each change must block isolated-checkout creation. The identity is drift
       detection only and never reconstructs dirty state elsewhere.
    5. Complete package/re-review outcomes: blocked or partial remediation never reviews a knowingly
       incomplete package; explicitly deselected re-review reports the unreviewed result; a mutation
       outside the fix delta is still found by the full pass; another failing verdict offers a new
       action surface without an unattended loop.
    6. Preserve document close/continuation parsing, implementation refusal in `revise` and `refine`,
       kind resolution, setup, status custody, complexity evidence, and exact verdict mapping. Narrow
       the old anti-remediation red-proof to forbid mutation during the review phase rather than the
       now-valid confirmed action phase.
    7. Red-prove row ordering/defaults, absent-class suppression, native/textual agreement,
       destination resolution, dirty-state isolation exclusion, same-population inline drift,
       clean-endpoint isolation drift, post-confirm route failure, partial-package blocking,
       same-base re-review, and the fresh-close loop one at a time; count each plant, require failure,
       restore, and confirm byte identity.
  - Verify:

    ```sh
    skills/inspector/scripts/tests/run.sh
    skills/skill-builder/scripts/skills-lint.sh
    ```

    Expected: the complete action and route matrices pass, all existing document and setup behavior
    remains green, and skill lint reports `fails=0` without a new warning class.

- [ ] **Slice 3: Public responsibility alignment and release gate** — requires: 2
  - Files:
    - `skills/inspector/scripts/tests/review-close-test.sh`
    - `skills/inspector/scripts/tests/implementation-test.sh`
    - `docs/design/2026-08-21-architect-contractor-inspector.md`
    - `README.md`
    - `PACK.md`
  - Change:
    1. Replace the live responsibility spine's verdict-only claim with the final ownership boundary:
       implementation review reports without mutation, then may enter confirmed inline or isolated
       remediation and full re-review; document revision policy remains separate.
    2. Update the README inventory and pack composition wording just enough to advertise the
       actionable implementation close. Preserve their current skill inventory, pack membership,
       and invocation-only composition seams.
    3. Add focused stale-surface assertions that reject the retired live claims in the router,
       review verb, implementation kind, responsibility spine, README, and PACK while retaining the
       review-phase no-mutation rule. Scope the sweep to live surfaces; historical specs and reports
       stay untouched.
    4. Red-proof the stale-claim guard by planting one retired verdict-only sentence into a copied
       live surface, counting it, requiring failure, restoring, and confirming byte identity.
    5. Run the complete gates and manually re-read every changed file as one state machine. Confirm
       each slice touched only its declared paths and no live prose says either that implementation
       always stops at the verdict or that the review phase itself edits code.
  - Verify:

    ```sh
    skills/inspector/scripts/tests/run.sh
    skills/skill-builder/scripts/skills-lint.sh
    skills/architect/scripts/ground-check.sh \
      "$(git rev-parse --show-toplevel)" \
      .records/specs/2026-09-03-inspector-implementation-review-action-loop.md
    git diff --check
    ```

    Expected: all Inspector fixtures pass, skill lint reports `fails=0`, the published spec has zero
    unresolved references, the diff has no whitespace errors, and only plan-owned paths changed.

## Done when

- Every governing-spec requirement maps to one of the three slices with no open decision branch.
- Every implementation verdict has an actionable close, with the requested recommendation-first
  checklist and safe defaults on `needs-rework`.
- No remediation begins before confirmation or against destination state different from the review
  evidence; isolated work starts from the exact reviewed endpoint and cannot mutate the destination.
- Successful remediation triggers a full same-base review of the complete result; stopped, partial,
  or deselected paths accurately report that no such review passed.
- Implementation remains outside document `revise`/`refine`, and document review, setup, status,
  stage, kind-resolution, complexity, and verdict behavior remain unchanged.
- Live Inspector, responsibility, README, and pack prose agree on the post-verdict action loop without
  naming a sibling skill, provider, model, or harness-specific API.
- Every new guard is red-proven, all listed verification commands pass, and final scope contains only
  the declared paths.

_On completion (before landing), run the host's close-the-books sweep._
