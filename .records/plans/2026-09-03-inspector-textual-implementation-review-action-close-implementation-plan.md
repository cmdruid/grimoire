---
doctype: plans
status: published
stage: approved
schema: contractor/plan@1
tags: [plan]
---

# Inspector textual implementation review action close — Implementation Plan

Slice 1 replaces the shared broken presentation with all three verdict surfaces and proves the ordinary
`needs-rework` response through confirmed isolated remediation and full re-review. Slice 2 widens the
parser and pending-selection evidence, Slice 3 exercises destination and failure safety through real
Git state, and Slice 4 aligns every public surface and runs the release gate. Each slice is
independently testable and committable.

Spec: `.records/specs/2026-09-03-inspector-textual-implementation-review-action-close.md`

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Published contract:** Implement only the published textual action-close spec. The archived
  `.records/specs/2026-09-03-inspector-implementation-review-action-loop.md` is historical evidence;
  do not retain its native multi-select, checkbox, focus, or Enter-submission contract in live surfaces.
- **Instruction-led runtime:** Inspector remains an agent-instruction skill. Put the normative state
  machine in `verbs/review.md`; use Bash helpers only inside behavioral fixtures. Add no production
  parser, runtime store, harness API, public verb, setup behavior, hook, or project doctrine surface.
- **Review/write boundary:** Verdict reporting remains source-mutation-free. Only a confirmed complete
  selection can authorize remediation. A pending scope, invalid input, destination question, route
  failure, drift, rejection, or verdict alone cannot authorize a write.
- **Action state:** Keep pending scope distinct from pending normalized selection. Parse only the latest
  displayed surface, use verdict-local scope numbers, preserve gaps when classes are absent, and bind
  `yes` to the current displayed or pending target exactly as the spec defines.
- **Destination and isolation safety:** Always expose a non-mutating exit. Resolve destination ownership
  before route/re-review modifiers can authorize fixing. Offer isolation only for an eligible clean,
  committed exact endpoint. Inline fallback is legal only before the isolated writer begins and while
  destination identity remains unchanged.
- **Complete-package gate:** Destination drift requires a fresh review. Writer-started partial work,
  blocked remediation, failed primary inspection/verification, and incomplete returned packages stop
  unreviewed and never become an ordinary inline fallback.
- **Full re-review:** Re-review from the original base through the complete remediated population,
  including paths outside the selected fix. Independence means a fresh judgment from complete evidence,
  not a separate provider, model, or agent.
- **Portable fixtures:** Keep shell tests compatible with macOS `/bin/bash` 3.2. Avoid associative
  arrays, namerefs, `mapfile`, `${x^^}`, GNU `sed -i`, `\b`, and `\s`. Use `LC_ALL=C`, `tr`, explicit
  token scanning, and `|| true` where a deliberately absent `grep` match is expected under `set -e`.
- **Red-proof discipline:** Every new parser default, absence assertion, drift guard, and failure
  transition must fail on one counted plant, restore from saved bytes, and prove byte identity.
- **Behavioral evidence:** Drive the implementation tracer from raw reply text through normalized
  selection and real Git outcomes. Do not pass preselected scope, route, inspection, verification, or
  failure results around the behavior under test. Red-prove a contract check over the load-bearing
  `review.md` clauses, then forward-test the completed skill with a fresh agent in a disposable Git
  fixture so fixture logic cannot be the only evidence for the live instructions.
- **Plan lifecycle:** This plan is an owned path of every slice. After a slice's verification passes,
  mark only that slice complete and include the plan update in the same slice commit. Set
  `stage: implemented` only after Slice 4's complete gate passes.
- **Package boundaries:** Keep `skills/inspector/SKILL.md` thin and self-scoping. Update doctrine,
  responsibility spine, README, and PACK together. Do not add deployed layout or door blocks to root
  `AGENTS.md`; do not edit historical specs, plans, or reports beyond this plan's own lifecycle.
- **Coexisting work:** Task 0 found `main` unchanged, the stream clean at `5f3f21c`, and no overlapping
  Inspector worktree. Re-run divergence and custody checks before editing; preserve unrelated work and
  stage only each slice's declared paths.
- **Baseline:** Inspector currently reports `17/114/49/81/116/35` passing assertions across its six
  fixtures. Skill lint reports `fails=0 warns=3`; the three warnings are established orphan edge types
  owned by Foreman and are not part of this feature.

## Task 0 — Re-ground before editing

Read-only; produce no commit.

1. Run:

   ```sh
   skills/workstream/scripts/workstream-git.sh stream-state \
     /Users/cscott/Repos/grimoire/.workstreams/inspector stream/inspector main
   git log stream/inspector..main --oneline
   skills/contractor/scripts/ground-check.sh \
     "$(git rev-parse --show-toplevel)" \
     .records/specs/2026-09-03-inspector-textual-implementation-review-action-close.md
   ```

   Require matching worktree/branch custody, no staged or unowned dirty state, and no incoming `main`
   commit. If `main` moved, follow the Workstream sync procedure before editing. Ground-check currently
   reports `checked=0`, so it is only an unresolved-reference signal; the manual symbol pass below is
   mandatory.
2. Re-read the complete governing spec, root `AGENTS.md`,
   `skills/skill-builder/docs/DOCTRINE.md`, and these live seams:

   ```text
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
3. Search capability-wide before adding behavior:

   ```sh
   rg -n "native multi-select|textual fallback|implementation_defaults|present_defaults|implementation_answer|route_for|isolation_failure|selection_result|checkbox|Enter" \
     skills/inspector README.md PACK.md docs/design/2026-08-21-architect-contractor-inspector.md
   rg -n "normalize|pending scope|pending.*selection|1-A-R|scope.*route" skills .records
   ```

   Expected: the obsolete presentation is concentrated in `review.md`, `review-close-test.sh`, and
   `implementation-test.sh`; no reusable action-code parser or pending-selection runtime exists.
   Preserve the existing real temporary-Git identity tracer rather than replacing it with labels.
4. Run:

   ```sh
   skills/inspector/scripts/tests/run.sh
   skills/skill-builder/scripts/skills-lint.sh
   ```

   Reconcile any change from the recorded baseline before editing.

## Slices

- [x] **Slice 1: Complete verdict renderer and needs-rework text tracer** <requires: —>
  - Files:
    - `.records/plans/2026-09-03-inspector-textual-implementation-review-action-close-implementation-plan.md`
    - `skills/inspector/verbs/review.md`
    - `skills/inspector/scripts/tests/review-close-test.sh`
    - `skills/inspector/scripts/tests/implementation-test.sh`
  - Change:
    1. Red-first, replace the shared native/textual adapter with all three verdict surfaces before
       removing its live contract. `needs-rework` exposes numbered scope plus `A/I` and `R/N` groups;
       `approve-with-changes` defaults to return-as-is and labels its modifiers **if fixing**; `approve`
       offers only direct return. No surface uses checkbox, focus, native-control, or Enter language.
    2. Implement the complete basic selection semantics in `review.md`: verdict-local scope numbers;
       eligible `A` or inline-only `I`; default `R` for fixing; inert modifiers for non-mutating scope;
       `yes` bound to the displayed default; direct valid code as confirmation; and rejection as
       no-write. Keep only the resolved `needs-rework` default route as this slice's end-to-end tracer.
    3. Model a Bash-3.2-safe fixture normalizer that trims outer ASCII whitespace, folds letters with
       `tr`, consumes the entire input, recognizes verdict-local scope/route/afterward tokens in order,
       and fills omitted groups from the displayed defaults. Keep it a test model of the prose contract,
       not a production parser.
    4. Prove `yes`, `1`, `1AR`, `1-A-R`, `1 A R`, `1,A,R`, and `1-A R` reach the same confirmed
       selection on the complete default surface. A direct valid code confirms once; the verdict itself
       and all pre-confirm states remain no-write.
    5. Feed raw reply `1-A-R` through normalization and selection into the existing real
       isolated-remediation tracer. Derive the route from the temporary repository, derive primary
       inspection and verification from the returned diff and commands, integrate only against
       unchanged destination identity, run the complete same-base review, and emit a fresh textual
       action close. Do not inject preselected fixes, route, inspection, or verification labels.
    6. Add a focused contract check for the exact three verdict surfaces, code meanings, confirmation
       boundary, and review-phase no-write clauses in `review.md`. Red-prove each clause against a
       mutated copy so the semantic fixture cannot stay green while the live instruction disappears.
    7. Preserve kind detection, adequacy, verdict mapping, document continuation, and status custody
       byte-for-byte outside the owned action-close prose. Red-prove the rendered defaults, one-confirm
       boundary, original-base re-review, and fresh-close event one at a time; count each plant and
       restore fixture bytes.
    8. After both verification commands pass, mark Slice 1 complete and include this plan in the slice
       commit.
  - Verify:

    ```sh
    /bin/bash skills/inspector/scripts/tests/review-close-test.sh
    /bin/bash skills/inspector/scripts/tests/implementation-test.sh
    ```

    Expected: the common `needs-rework` response reaches isolated remediation and full re-review only
    after one explicit text confirmation, with no live pseudo-control contract remaining in the changed
    surfaces.

- [x] **Slice 2: Complete parser and pending-selection matrix** <requires: 1>
  - Files:
    - `.records/plans/2026-09-03-inspector-textual-implementation-review-action-close-implementation-plan.md`
    - `skills/inspector/verbs/review.md`
    - `skills/inspector/scripts/tests/review-close-test.sh`
  - Change:
    1. Widen evidence for the already-complete renderer. Prove `needs-rework` exposes scopes `1` through
       `4`, omits `2` and `3` without renumbering when recommendations are absent, and defaults to `1`.
       Prove `approve-with-changes` returns unchanged on its default and `approve` has no modifiers.
    2. Widen evidence for route and afterward behavior already introduced in Slice 1. Eligible isolation
       uses `A`; ineligible isolation omits it and uses `I`. Fixing defaults to `R`; `N` reports the
       complete applied result as unreviewed. Non-mutating modifiers normalize away.
    3. Cover the full response grammar: compact, uniform, mixed, and optional separators; case folding;
       outer whitespace; number-only defaults; omitted route or afterward; and whole-input rejection of
       repeated punctuation, trailing punctuation, unknown tokens, unavailable codes, duplicate groups,
       and out-of-order groups.
    4. Add pending normalized selection for natural-language adjustments. Reflect its exact code and
       meaning once; bind the next acceptance to that pending code rather than the prior default. A new
       direct code replaces and confirms it; rejection clears it; invalid input writes nothing and does
       not alter it.
    5. Red-prove each verdict default, absent-class gap, inline-only surface, conditional label, pending
       confirmation target, and invalid-input guard independently with counted/restored mutations.
    6. Extend the `review.md` contract check for the full grammar and pending normalized selection;
       delete or alter each load-bearing clause in a copied verb and require the focused check to fail.
    7. After the full Inspector suite passes, mark Slice 2 complete and include this plan in the slice
       commit.
  - Verify:

    ```sh
    /bin/bash skills/inspector/scripts/tests/review-close-test.sh
    skills/inspector/scripts/tests/run.sh
    ```

    Expected: every verdict surface and supported textual form maps deterministically, invalid input is
    fail-closed, and all document review fixtures remain unchanged and green.

- [x] **Slice 3: Stateful destination and failure safety** <requires: 2>
  - Files:
    - `.records/plans/2026-09-03-inspector-textual-implementation-review-action-close-implementation-plan.md`
    - `skills/inspector/verbs/review.md`
    - `skills/inspector/scripts/tests/review-close-test.sh`
    - `skills/inspector/scripts/tests/implementation-test.sh`
  - Change:
    1. Replace boolean destination labels with a fixture driver that derives destination ownership,
       cleanliness, exact endpoint, and isolation eligibility from real temporary Git repositories.
    2. Implement the reduced destination-less surface. Prove `approve-with-changes` `yes` returns
       unchanged, while `needs-rework` `yes` records only pending scope `1`. Numeric no-change scopes and
       unambiguous natural-language non-mutating adjustments return without ownership; numeric and
       natural-language fixing scopes create only a pending scope and ask for destination. Route or
       afterward prose is not accepted on the reduced surface. After ownership resolves, atomically
       consume the scope into the exact `A/I` plus `R` complete pending code and require fresh
       confirmation before any write.
    3. Split post-confirm isolation failures. Missing executor or checkout-creation failure before writer
       start, with unchanged destination identity, renders a reconfirmed inline-only surface preserving
       scope and `R/N` while changing only `A` to `I`. Destination drift requires a fresh review.
       Writer-started partial work, incomplete return, and failed primary inspection or verification stop
       unreviewed without inline fallback.
    4. Inject changed HEAD, staged, unstaged, and untracked destination state separately both before
       isolated checkout creation and immediately before integration. Each case must block and leave the
       returned result unapplied. Preserve the dirty same-path/different-content inline identity case.
    5. Make the partial-package fixture attempt at least two findings and fail the second; assert that the
       incomplete package never re-reviews. Derive failed primary verification by returning a checkout
       whose content fails the actual primary verification command; do not pass a caller-supplied `no`
       result. Prove it independently blocks integration and fallback.
    6. Widen the full-review fixture to at least two changed paths. Put one material mutation outside the
       selected fix path and prove the original-base complete review finds it while fix-delta and
       path-limited mutants fail.
    7. Red-prove pending-scope no-write, scope-to-complete conversion, route-preserving fallback, every
       no-fallback failure class, all eight drift placements, second-finding failure, and multi-path
       population one at a time with occurrence counts and byte restoration.
    8. Extend the live `review.md` contract check across pending-scope conversion, destination drift,
       pre-writer fallback, and writer-started no-fallback clauses. Red-prove each against a mutated copy.
    9. After all three verification commands pass, mark Slice 3 complete and include this plan in the
       slice commit.
  - Verify:

    ```sh
    /bin/bash skills/inspector/scripts/tests/review-close-test.sh
    /bin/bash skills/inspector/scripts/tests/implementation-test.sh
    skills/inspector/scripts/tests/run.sh
    ```

    Expected: real Git state drives every destination and isolation decision; only a complete confirmed
    package reaches integration or re-review; every drift and incomplete-result path stops safely.

- [ ] **Slice 4: Public contract alignment and release gate** <requires: 3>
  - Files:
    - `.records/plans/2026-09-03-inspector-textual-implementation-review-action-close-implementation-plan.md`
    - `skills/inspector/SKILL.md`
    - `skills/inspector/verbs/review.md`
    - `skills/inspector/kinds/implementation.md`
    - `skills/inspector/scripts/tests/review-close-test.sh`
    - `skills/inspector/scripts/tests/implementation-test.sh`
    - `docs/design/2026-08-21-architect-contractor-inspector.md`
    - `README.md`
    - `PACK.md`
  - Change:
    1. Update Inspector's frontmatter routing description to advertise confirmed post-verdict
       implementation remediation while naming `revise` and `refine` specifically as document mutation
       verbs. Keep the description self-scoping, discriminating, and within its current size limits.
    2. Align the router flow, implementation kind, responsibility spine, README inventory, and PACK
       wording with the plain-text action close, pending-state boundary, eligible inline/isolated routes,
       and complete re-review. Preserve typed edges, inventory, pack membership, and document behavior.
    3. Replace old presence assertions with focused stale-surface guards over live files. Reject native
       multi-select, checkbox, focus, unchecked, and Enter-submission language while permitting
       historical records. Assert the router description and each public surface carry its owned part of
       the final contract without duplicating the parser.
    4. Re-read the complete changed package as one state machine. Confirm independence is full fresh
       judgment, no live prose sends source remediation through document `revise`/`refine`, and no setup,
       store, hook, helper, or harness-specific dependency was added.
    5. Red-prove the stale-surface sweep by planting each retired presentation class into a copied live
       surface, requiring failure, then restoring and comparing bytes.
    6. Forward-test the skill with a fresh read-only agent against a disposable temporary Git repository
       and only the installed Inspector instructions plus a realistic implementation-review request.
       Require the actual response to render the applicable numbered/lettered surface with no pseudo-
       controls. Continue that isolated scenario with one valid code and one invalid code in separate
       fixture runs; the valid reply must follow the selected state transition, while the invalid reply
       must remain no-write. Do not give the evaluator the intended answer or edit the shared worktree.
    7. Run the complete gate below. Only after it passes, mark Slice 4 complete, set this plan to
       `stage: implemented`, and include the final plan lifecycle update in the slice commit.
  - Verify:

    ```sh
    skills/inspector/scripts/tests/run.sh
    shellcheck skills/inspector/scripts/tests/review-close-test.sh \
      skills/inspector/scripts/tests/implementation-test.sh
    skills/skill-builder/scripts/skills-lint.sh
    skills/architect/scripts/ground-check.sh \
      "$(git rev-parse --show-toplevel)" \
      .records/specs/2026-09-03-inspector-textual-implementation-review-action-close.md
    .records/records.sh check
    git diff --check
    ```

    Expected: all Inspector fixtures and record checks pass; ShellCheck is clean; skill lint reports
    `fails=0` without a new warning class; the published spec has no unresolved reference; and the diff
    contains only declared plan-owned paths with no whitespace errors.

## Done when

- Every published-spec requirement maps to one slice with no open decision branch or stale dependency
  on the archived presentation contract.
- Every implementation verdict renders its applicable plain-text close; all supported codes normalize
  deterministically, and invalid, rejected, incomplete, or unavailable selections remain no-write.
- Ambiguous destination ownership leaves safe exits usable and cannot convert a pending scope into write
  authorization without destination resolution and fresh confirmation.
- Isolation fallback is limited to unchanged pre-writer capability failure; drift, partial work, and
  unverified results stop under their stricter rules.
- Integration requires the complete selected package plus primary inspection and verification; a full
  original-base review covers every changed path and emits a fresh action close.
- Inspector remains self-contained and instruction-led; document review/revise/refine, kind resolution,
  setup, status custody, typed edges, complexity evidence, README inventory, and pack seams remain green.
- Every new guard is red-proven, every slice verification passes, the complete gate is green, and only
  declared paths—including this plan's own lifecycle updates—changed.

_On completion (before landing), run the host's close-the-books sweep._
