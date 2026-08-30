---
doctype: plans
status: published
stage: implemented
schema: contractor/plan@1
tags: [plan]
---

# Backlog debrief-anchor reliability — Implementation Plan

Replace Backlog's commit-stamped cadence sentence with one exact package-owned
`debrief-anchor@1` block, then prove the block is safely reconciled and actually dispatches under
the current Grok and Codex harnesses. The tracer slice exercises the riskiest path end to
end: fresh setup installs the exact anchor in a throwaway project, a rerun is byte-stable, and final
queue removal removes only Backlog's bounded extent.

Spec: → `specs/2026-08-28-backlog-debrief-anchor-reliability.md` (published addendum).
Base contract: → `specs/2026-08-27-backlog-routines-and-universal-debrief.md` (published).

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **One exact public anchor:** package the spec's exact
  `<!-- skill:backlog BEGIN built-against:debrief-anchor@1 -->` through
  `<!-- skill:backlog END -->` bytes. Preserve the required H3, `Route:`, and `Edges:` registration
  shape. The anchor is locally complete trigger policy, while `verbs/debrief.md` and the editable
  routing hook remain authoritative for the sweep and queue judgment.
- **Bounded ownership:** accept only `current`, `drifted-current`, `replaceable-managed`, and
  `absent`. Duplicate, nested, reversed, unmatched, overlapping reserved markers and the exact
  unmarked reserved H3 refuse before any setup write and expose no replacement extent. Replace or
  remove only the bounded Backlog block; preserve every byte before and after it.
- **Stable behavior version:** remove Git-derived route stamping and all `--stamp` plumbing. Byte
  identity against the package template detects drift; `debrief-anchor@1` versions behavior. Do not
  parse or translate an older bounded block before wholesale replacement.
- **One setup owner:** `backlog-setup.sh` remains the only setup/tracker-administration caller of
  route reconciliation. Runtime Backlog verbs do not install project instructions, and no new
  `/backlog anchor` verb or second mutator is added. A positive queue count ensures the current
  block; zero queues removes it.
- **No durable trigger state:** the anchor may rely only on the current agent context for once-only
  memory. Do not add a cursor, event ledger, candidate buffer, setup intent, session enrollment, or
  save-state field.
- **Boundary independence:** do not add Backlog dispatch to Checkpoint, Workstream, delegates, or
  harness hooks. Child/delegate sessions return byproducts; the custodial main agent owns debrief.
  Involuntary context emergencies preserve primary work first; a deliberate healthy reset remains
  gated by successful debrief or its reported terminal refusal.
- **Patient zero:** every registration, mutation, refusal, and hosted-harness proof uses a throwaway
  repository. Never install a Backlog route or tracker layer in grimoire's real `AGENTS.md`.
- **Coexisting provider work:**
  `.records/specs/2026-08-28-backlog-tracker-provider-discoverability.md` and its plan remain draft
  and overlap `skills/backlog/scripts/backlog-setup.sh`,
  `skills/backlog/scripts/tests/deploy-test.sh`, and
  `scripts/tests/configure-clankshop-test.sh`. Complete this anchor implementation before provider
  implementation begins; do not walk the two plans concurrently. Landing remains the host lane's
  decision. The provider plan's Task 0 must then re-ground and preserve the anchor. If
  provider/setup work lands first, stop and revise/re-review this plan against its new setup state
  rather than silently translating these slices.
- **Current hard cut stays current:** this plan does not rename `tracker-api.sh`, change initial
  queue selection, add repair, or redesign setup transactions. Preserve the live provider and data
  contract while implementing only the published anchor addendum.
- **Shell and test discipline:** remain Bash 3.2/BSD-macOS compatible, refuse unsafe symlinks and
  incompatible entries, revalidate the destination immediately before atomic rename, report exact
  `wrote=` paths, and prove every new absence/guard assertion red through a counted mutation and
  byte-identical restoration.

## Slices

- [ ] **Task 0: Re-ground the route owner, overlap, and harness baseline** <requires: —>
  - Files: read-only inspection of `AGENTS.md`;
    `.records/specs/2026-08-28-backlog-debrief-anchor-reliability.md`;
    `.records/specs/2026-08-27-backlog-routines-and-universal-debrief.md`;
    `.records/specs/2026-08-28-backlog-tracker-provider-discoverability.md`;
    `.records/plans/2026-08-28-backlog-trackers-sh-and-readme.md`;
    `skills/skill-builder/docs/DOCTRINE.md`; `skills/backlog/SKILL.md`;
    `skills/backlog/verbs/setup.md`; `skills/backlog/verbs/debrief.md`;
    `skills/backlog/scripts/backlog-setup.sh`; `skills/backlog/scripts/register-route.sh`;
    `skills/backlog/scripts/tests/`; `scripts/tests/configure-clankshop-test.sh`; and
    `scripts/tests/run.sh`.
  - Change: make no writes. Run Contractor's ground check and record `git status --short`. Search
    live source for `skill:backlog`, `built-against:`, `--stamp`, `git log`, `/backlog debrief`, and
    the self-registered-routes heading. Classify every hit as route ownership, setup wiring,
    deterministic fixture, lifecycle-owner source, or historical record. Re-read Checkpoint and
    Workstream live hits to confirm neither dispatches Backlog. Confirm that the draft provider plan
    has not started; if any of its provider/setup changes are present, stop for plan revision.
    Measure the focused deterministic baseline and record current harness versions; do not infer
    hosted behavior from green shell tests.
  - Verify:
    `skills/contractor/scripts/ground-check.sh "$PWD" "$PWD/.records/specs/2026-08-28-backlog-debrief-anchor-reliability.md"`
    reports `unresolved_count=0`; `bash skills/backlog/scripts/tests/run.sh` ends
    `backlog tests: ALL GREEN`; `bash skills/skill-builder/scripts/skills-lint.sh .` reports
    `fails=0`; and `grok --version` plus `codex --version` identify the harnesses that Slice 3
    must re-record. The 2026-08-29 replacement baseline is Grok 1.0.13 and codex-cli 0.150.1.

- [ ] **Slice 1: Install and reconcile the exact anchor end to end** <requires: 0>
  - Files: create `skills/backlog/templates/debrief-anchor.md` and
    `skills/backlog/scripts/route-status.sh`; modify
    `skills/backlog/scripts/register-route.sh`, `skills/backlog/scripts/backlog-setup.sh`,
    `skills/backlog/verbs/setup.md`, `skills/backlog/scripts/tests/deploy-test.sh`, and
    `skills/backlog/scripts/tests/run.sh`; create
    `skills/backlog/scripts/tests/route-test.sh`.
  - Change: copy the published spec's anchor block byte-for-byte into the package-only template.
    Implement `route-status.sh <template> <front-door>` as the read-only classifier. It validates
    the template itself, recognizes the complete reserved begin family and exact end marker,
    detects the exact structural H3 outside Markdown code fences, and emits only compact facts:
    `route_status=` plus begin/end lines for a safely bounded state. Malformed input emits a
    `route_error=invalid-template|invalid-target|marker-structure|marker-order|reserved-heading`
    and no extent. It distinguishes exact current bytes, changed current bytes, one opaque managed
    predecessor, and true absence without interpreting predecessor content.

    Rewrite `register-route.sh preflight|ensure|remove --root <root>` to consume those facts and the
    package template. `preflight` only classifies; `ensure` appends below the existing
    `## Skill routes (self-registered)` heading (or creates that heading), replaces a safe bounded
    predecessor wholesale, and no-ops on current; `remove` removes one safe bounded block and
    no-ops on absence. Reclassify and revalidate the front door immediately before atomic rename so
    a raced destination cannot be overwritten. Preserve surrounding bytes exactly and retain
    `wrote=AGENTS.md` for a real change. Add `BACKLOG_ROUTE_TEST_BEFORE_REPLACE` and
    `BACKLOG_ROUTE_TEST_BEFORE_RENAME` test-only hooks at those two boundaries so failure and race
    arms are observable without weakening production guards.

    Remove `--stamp`, the skill-repository `git log`, and date fallback from `backlog-setup.sh`;
    invoke route reconciliation with only the resolved project root. Keep complete setup preflight:
    a malformed route still refuses before tracker, prompt, or front-door writes. Update setup prose
    to name the exact versioned route postcondition without duplicating the anchor body.
  - Verify: write `route-test.sh` red-first around throwaway front doors. It must cover current,
    drifted-current, a realistic current commit-stamped predecessor and an arbitrary opaque
    reserved predecessor as `replaceable-managed`, absent, duplicate, nested, reversed, unmatched,
    overlapping, and exact unmarked-H3 states. The reserved-heading fixtures include both a wholly
    unmarked front door and an otherwise well-formed managed block with a second exact reserved H3
    outside its delimiters; both refuse without an extent. Include fenced and indented code examples
    that must not become structural headings. Assert safe replacement preserves byte-identical
    prefix/suffix content and imports none of the opaque block. Count and weaken each marker/H3
    guard in a copied classifier, require its refusal fixture to fail, then restore and `cmp` the
    source copy.
    Inject failure before replacement and race the target immediately before rename; both must
    refuse or fail without a partial anchor, and a clean rerun must converge.

    Extend `deploy-test.sh` so fresh setup extracts a block byte-identical to
    `templates/debrief-anchor.md`, a current rerun reports no `AGENTS.md` write, a drifted or
    commit-stamped route refreshes to exact current bytes, and removing the final queue removes only
    that block before re-adding a queue restores it. Then `bash skills/backlog/scripts/tests/route-test.sh`
    and `bash skills/backlog/scripts/tests/run.sh` both exit 0; and
    `shellcheck -S warning skills/backlog/scripts/route-status.sh skills/backlog/scripts/register-route.sh skills/backlog/scripts/tests/route-test.sh`
    emits no warning-or-higher diagnostics.

- [ ] **Slice 2: Make the trigger contract executable and guard lifecycle independence**
  <requires: 1>
  - Files: create
    `skills/backlog/scripts/tests/fixtures/debrief-anchor-scenarios.tsv`,
    `skills/backlog/scripts/tests/debrief-anchor-contract-test.sh`, and
    `scripts/tests/backlog-anchor-contract-test.sh`; modify
    `skills/backlog/scripts/tests/skill-doc-test.sh`,
    `skills/backlog/scripts/tests/run.sh`, and `scripts/tests/run.sh`.
  - Change: store deterministic scenario expectations separately from model behavior. The scenario
    table must cover: one interactive completed unit; two autonomous consecutive units; healthy
    pre-reset; zero-result success; pure Q&A; routine status; child/delegate return; debrief plus
    setup/repair/retry closure without recursion; terminal refusal with the boundary still pending;
    and involuntary-compaction deferral to the next safe boundary. Give each row an applicability
    decision, earliest trigger, dispatch expectation, and whether the next unit/reset is permitted.

    Make `debrief-anchor-contract-test.sh` validate the exact package template and every scenario.
    Require applicability, all three trigger moments in order, automatic execution without a
    permission round trip, the coherent-unit definition, once-only current-context scope,
    zero-result success, exclusions, emergency deferral, and provider-recovery/one-retry behavior.
    For each requirement class, copy the template, count one intended target, remove or weaken it,
    require the matching assertion to fail, and confirm the original template is byte-identical
    afterward. This test is a prose/decision contract only and must not claim to execute a hosted
    model.

    Put the cross-owner absence gate at repository integration scope, not inside a portable leaf's
    runtime. `backlog-anchor-contract-test.sh` must reject a Backlog-specific invocation in live
    Checkpoint or Workstream source and reject current commit-derived Backlog marker construction in
    live setup/route code. Explicit historical records and the one generic predecessor fixture are
    outside or allowlisted from the live-source population. Red-prove each absence guard by copying
    its live-source population to a temporary tree, planting the prohibited line once, requiring
    the copied gate to fail, and restoring/confirming the source bytes.
  - Verify: `bash skills/backlog/scripts/tests/debrief-anchor-contract-test.sh`,
    `bash skills/backlog/scripts/tests/run.sh`, and
    `bash scripts/tests/backlog-anchor-contract-test.sh` exit 0;
    `bash skills/checkpoint/scripts/tests/skill-doc-test.sh` and
    `bash skills/workstream/scripts/tests/seam-contract-test.sh` exit 0;
    `bash scripts/tests/run.sh` ends `repository integration tests: ALL GREEN`; and
    `bash skills/skill-builder/scripts/skills-lint.sh .` reports `fails=0`.

- [ ] **Slice 3: Prove consuming-project installation and real harness dispatch** <requires: 2>
  - Files: modify `scripts/tests/configure-clankshop-test.sh`; create or resume
    `.spaces/architect/drafts/backlog-debrief-anchor-harness-acceptance.md`; read
    `skills/architect/verbs/spike.md`, `skills/architect/templates/draft.md`,
    `skills/architect/templates/spikes.md`, and
    `skills/architect/scripts/architect-artifacts.sh`; create one dated published spike at
    `.records/spikes/YYYY-MM-DD-backlog-debrief-anchor-harness-acceptance.md` through the returned
    publisher path without overwriting an incumbent record.
  - Change: strengthen the consuming-project fixture to extract the configured Backlog extent and
    compare it byte-for-byte with `skills/backlog/templates/debrief-anchor.md`. Prove the aggregate
    setup sweep remains commit-free, its committed configuration contains exactly one current
    anchor, and a second sweep is diff-free. Preserve every existing Journal, Workstream, Delegate,
    Workspace, and provider assertion; do not broaden this slice into the draft provider plan.

    After the deterministic gate is green, follow the package's spike procedure. Build the charter
    in a body based on `templates/draft.md`: the question is whether the implemented anchor dispatches
    at each claimed harness boundary; success requires all six cells below; the budget is those six
    fresh fixtures; and the stopping condition is the first failed or ambiguous cell. Present that
    charter and obtain explicit human confirmation before launching either harness. Save or resume
    it with package `architect-artifacts.sh draft-save --root "$PWD" --workspace .spaces --slug
    backlog-debrief-anchor-harness-acceptance --title "Backlog debrief anchor harness acceptance"
    --body <draft-body>`.

    Create three fresh temporary Git projects for Grok and three for Codex. In each, install the
    Backlog skill into `.agents/skills`, run package `backlog-setup.sh` to configure the project,
    verify that the harness discovers both the root `AGENTS.md` and project Backlog skill, and commit
    the configured baseline. Give the
    positive fixtures `UNIT-ONE.md`; give the transition fixture `UNIT-TWO.md`; and plant a unique
    `FOLLOWUP-CANARY-<harness>` in the completion fixture. Each unit file specifies one small file
    change and its exact commit message so Git order is independently observable. Do not alter
    grimoire's root front door.

    Run three independent attended cells per harness:

    1. **Completion response:** prompt, “Complete `UNIT-ONE.md`, commit that finished unit, leave the
       separate non-blocking `FOLLOWUP-CANARY-<harness>` work unimplemented, and report when the
       unit is complete.” Require the canary's tracker mutation and `Backlog: debrief` commit after
       the Unit 1 commit but before the harness's completion response.
    2. **Autonomous transition:** prompt, “Complete `UNIT-ONE.md` and `UNIT-TWO.md` in order without
       pausing or asking between them. Commit each unit with the message named in its file, then
       report after both are complete.” Require the transcript/rollout to show exactly one debrief
       boundary after Unit 1 and before the first Unit 2 action, then one final boundary before the
       response. A zero-row sweep remains a successful observed boundary and need not create a
       Backlog commit.
    3. **Pure Q&A:** prompt, “Read `UNIT-ONE.md` and summarize its requested outcome in one sentence.
       Do not change files.” Require no debrief dispatch, tracker change, or Backlog commit.

    Do not add any hosted command to a deterministic test runner. Record the exact
    `grok --version` and `codex --version`, fixture recipe, exact prompts, harness log locations or
    identifiers, relevant transcript/rollout excerpts, queue state, `git log --oneline` ordering,
    pass/fail per cell, limitations, and conclusion in a body based on `templates/spikes.md`. Publish
    it with package `architect-artifacts.sh spike-publish --root "$PWD" --records-root .records
    --title "Backlog debrief anchor harness acceptance" --body <spike-body>`, adding
    `--records-tool "$PWD/.records/records.sh"` only when that path is an executable regular file.
    Add the returned `path=` as `→ spikes/<dated-file>.md` under the draft's `## Related records`
    and save the updated draft again through `draft-save`. A missing harness, refused tool
    permission, ambiguous ordering, or failed cell leaves only the resumable draft: do not call
    `spike-publish`, keep the implementation unaccepted, and report the evidence gap.
  - Verify: `bash scripts/tests/configure-clankshop-test.sh` exits 0; all three attended Grok cells
    and all three attended Codex cells satisfy their independent criteria; the spike front
    matter declares `doctype: spikes`, `status: published`, `schema: architect/spike@1`, and
    `tags: [spike, feasibility]`; the draft's `## Related records` contains the returned spike link;
    and the spike contains a dated result for both harnesses before implementation review begins.

## Done when

Fresh setup installs one byte-exact `debrief-anchor@1` block, current reruns are no-ops, safe older
or drifted bounded blocks refresh wholesale, final-queue removal touches only Backlog's extent, and
every malformed or raced state refuses without partial front-door mutation. The deterministic
contract covers all trigger, exclusion, recursion, refusal, emergency, and once-only cases with
valid red proofs; repository integration proves Checkpoint and Workstream are not alternate
dispatchers. Backlog, consuming-project, lifecycle documentation, skill-lint, and repository suites
are green. Current Grok and Codex attended cells demonstrate real pre-completion and
between-unit dispatch plus pure-Q&A silence, with the dated result published as a spike.

Before handoff, run `git diff --check`, re-run the live-source absence search, inspect the complete
diff against the published anchor spec, and preserve every pre-existing unrelated change. Do not
start the draft provider/setup plan in the same implementation walk.

_On completion (before landing), run the host's close-the-books sweep._
