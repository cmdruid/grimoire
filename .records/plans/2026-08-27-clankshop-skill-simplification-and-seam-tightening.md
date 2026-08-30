---
doctype: plans
status: published
stage: implemented
schema: contractor/plan@1
tags: [plan]
---

# Clankshop skill simplification and seam tightening — Implementation Plan

Tracer-bullet: Slice 1 proves one bounded delegated task can travel through a capability-based
Delegate decision and mechanism-neutral Mailbox transport without a named-harness assumption. Slice
2 widens that public procedure into Workstream and the pack seam without copying foreign protocol.
Slice 3 closes the remaining Workspace, typed-edge, warning-disposition, inventory, and prose-cleanup
requirements. Each slice is independently testable and committable.

Spec: `.records/specs/2026-08-27-clankshop-skill-simplification-and-seam-tightening.md`

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Published contract:** Implement only the governing published spec. It changes dispatch selection,
  composition prose, edge truth, and focused tests; it does not redesign Delegate's return contract,
  Mailbox's slot protocol, Workstream's loop, or Workspace's checker.
- **Capability is not policy:** Detect native dispatch, model override, cwd control, and isolation as
  observable capabilities. A capability does not authorize an unconfirmed provider or different-model
  route. Same-harness/same-model context isolation remains ungated.
- **Single writer:** Mailbox delegates remain read-only on the target tree and write only their slot.
  Workstream's main session remains the sole writer of its held target regardless of the selected
  dispatch mechanism.
- **Pack/leaf ownership:** `PACK.md` owns Workstream → Delegate → Mailbox composition. Delegate owns
  dispatch and may point to Mailbox transport. Mailbox owns transport. Workstream keeps only its mode,
  stored route, sole-writer rule, inline fallback, and the operational invocation pointer.
- **Standalone completeness:** Delegate, Mailbox, Workstream, and Notepad must remain truthful and
  usable when installed without the pack or optional siblings. Missing Delegate or Mailbox degrades a
  Workstream unit to inline execution rather than becoming an installation floor.
- **No broad word bans:** Workstream owns legitimate manual-mode model mapping, isolated-worktree
  custody, and blocker behavior. Foreign-protocol checks must target the spawn, return, model-routing,
  and provider-fallback classes specifically; do not ban generic words such as `model`, `fallback`,
  `blocked`, or `isolated worktree`.
- **Red-proof every absence guard:** Use fixture copies or synthetic input. Count the planted defect,
  require the focused guard to fail, restore the fixture byte-for-byte with `cmp`, and then require the
  clean case to pass. Never mutate a live package file for a red-proof.
- **Description stability:** No frontmatter `description:` change is expected. If Task 0 or
  implementation proves one necessary, run a fresh descriptions-only cold-routing probe for every
  changed description and append its prompts/results to `docs/boundary-audit.md`.
- **Retained substrate:** Do not change migration procedures, recognized legacy paths, Mailbox's
  runtime scripts, or the four package-local `scoped-commit.sh` helpers. Recheck the helper population
  and byte equality at completion.
- **Pack format:** The member set, manifest format, and `version: 4.0.0` remain unchanged. This is a
  seam/runbook correction, not a membership or format change.
- **Coexisting work:** At plan authoring, Auditor and Inspector package paths and the control-flow
  complexity spec contain unrelated work. Preserve them byte-for-byte; never stage, format, or rewrite
  them. Use exact pathspecs for this job. The implementation owns only the files named by a slice.
- **Snapshot warning:** The paths and signatures below were verified while drafting, but Task 0 must
  repeat in the implementation checkout before any edit.

## Task 0 — Re-ground every seam before editing

Read-only; produce no commit.

1. Verify checkout custody, the published input, and unrelated work:

   ```sh
   git rev-parse --show-toplevel
   git branch --show-current
   git status --short
   sed -n '1,8p' .records/specs/2026-08-27-clankshop-skill-simplification-and-seam-tightening.md
   skills/contractor/scripts/ground-check.sh \
     "$(git rev-parse --show-toplevel)" \
     .records/specs/2026-08-27-clankshop-skill-simplification-and-seam-tightening.md
   ```

   Expected at plan authoring: top level is `/Users/cscott/Repos/grimoire`, branch is `main`, the
   governing spec is `status: published`, and `unresolved_count=0`. Record the complete dirty-path
   baseline. Do not open `.workstreams/app/WORKSTREAM.md`; it belongs to another session.
2. Re-read the complete governing spec and the live production/test seams:

   ```text
   PACK.md
   README.md
   docs/boundary-audit.md
   skills/skill-builder/docs/DOCTRINE.md
   skills/skill-builder/docs/BOUNDARY-AUDIT.md
   skills/delegate/SKILL.md
   skills/delegate/references/codex.md
   skills/delegate/scripts/tests/contract-test.sh
   skills/mailbox/SKILL.md
   skills/mailbox/scripts/tests/{run.sh,mailbox-test.sh}
   skills/workstream/SKILL.md
   skills/workstream/flow.md
   skills/workstream/verbs/{create,load}.md
   skills/workstream/templates/workstream-handoff.md
   skills/workstream/scripts/tests/{run.sh,artifact-contract-test.sh,lib.sh}
   skills/notepad/SKILL.md
   skills/notepad/scripts/tests/{run.sh,note-mint-test.sh,setup-test.sh}
   skills/workspace/SKILL.md
   scripts/tests/{run.sh,install-pack-test.sh,configure-clankshop-test.sh}
   ```

   The four slice-declared `Create:` targets do not exist before implementation:
   `scripts/tests/clankshop-contract-test.sh`, Mailbox and Notepad `contract-test.sh`, and Workstream
   `seam-contract-test.sh`. A ground-check of this plan may report exactly those four paths; any other
   unresolved path is drift to reconcile.
3. Repeat the capability-wide prior-art and scope sweeps:

   ```sh
   rg -n "Codex orchestrator|Codex agents|Claude orchestrator|Claude agents|native model-routed|Task tool|codex exec" \
     skills/delegate skills/mailbox skills/workstream
   rg -n "mailbox|model-routing table|return contract|Deliverable|Byproducts|Failure states|rate-limit|quota|provider" \
     skills/workstream/SKILL.md skills/workstream/flow.md skills/workstream/verbs skills/workstream/templates
   rg -n "workspace-check|/workspace check|handoff: note|resource-claim|goal-pursuit|session-evidence|findings.*trackers" \
     PACK.md README.md docs/boundary-audit.md skills/notepad skills/foreman scripts/tests
   find skills -name scoped-commit.sh -type f -exec cksum {} \;
   codex exec --help
   ```

   Expected: four `scoped-commit.sh` files with identical checksums; Codex advertises `read-only` and
   `workspace-write` sandbox modes plus model and cwd controls; Workstream's manual phase-model map is
   owner-local; the stale named-harness assertions and copied foreign protocols are confined to the
   locations named by this plan.
4. Establish the baseline:

   ```sh
   bash scripts/tests/run.sh
   for harness in skills/*/scripts/tests/run.sh; do bash "$harness" || exit 1; done
   bash skills/skill-builder/scripts/skills-lint.sh .
   ```

   Expected at plan authoring: the repository integration suite and every executable skill harness
   pass; lint reports `fails=0 warns=4`, exactly `goal`, `goal-pursuit`, `resource-claim`, and
   `session-evidence`. Any changed baseline must be reconciled before sizing or editing.

## Slices

- [x] **Slice 1: Capability-based Delegate → Mailbox tracer** <requires: Task 0>
  - Files:
    - Modify: `skills/delegate/SKILL.md`
    - Modify: `skills/delegate/references/codex.md`
    - Modify: `skills/delegate/scripts/tests/contract-test.sh`
    - Modify: `skills/mailbox/SKILL.md`
    - Create: `skills/mailbox/scripts/tests/contract-test.sh`
    - Modify: `skills/mailbox/scripts/tests/run.sh`
  - Change:
    1. Replace Delegate's harness-named spawn table with one capability inventory: native subagent
       dispatch, model override, cwd control, and isolated execution. Select native same-harness
       dispatch when its observed capabilities satisfy the unit's model and isolation needs.
    2. Keep Delegate's provider/model confirmation rule unchanged. A same-harness same-model native
       subagent remains a context-isolation mechanism with no route confirmation; a different model or
       provider still uses the existing one-time human gate.
    3. Make `codex exec` the selected headless executor only when no fitting native route exists, the
       confirmed route explicitly requires an external process, or its sandbox/cwd/output-capture
       semantics are material. Generalize `references/codex.md` from coding-only wording into two
       explicit executor modes: `--sandbox read-only` for analysis and `--sandbox workspace-write` for
       coding in an unheld target or owned isolated worktree. Preserve its preflight, held-tree refuse,
       whole-tree trust check, no-commit rule, and canonical return-contract pointer.
    4. Preserve Delegate's decision ownership, return headings/status vocabulary, byproducts snapshot,
       failure handling, and isolated-worktree procedure. Update the decision tree and quick reference
       to name selected capabilities rather than a fixed Codex/Claude mapping.
    5. Replace Mailbox's `Realizing the spawn` section with one mechanism-neutral instruction: the
       caller uses its already-selected dispatch capability and passes the absolute slot path,
       self-contained task, exact single-writer contract, and any cwd control that capability exposes.
       Mailbox does not select or reinterpret provider/model values.
    6. Leave Mailbox's mint, tree snapshot/drift check, apply/consume split, concurrency rule, and reap
       scripts unchanged. Remove only authoring commentary in these touched documents that merely says
       the empty typed-edge block is required or non-omitted; keep the edge block and its operational
       explanation.
    7. Extend Delegate's existing prose-contract test to require the capability/policy separation,
       both headless executor modes, and the unchanged canonical return contract. Add Mailbox's focused
       prose-contract test and register it in its harness.
    8. In fixture copies, plant categorical claims that a named harness always has or lacks a dispatch
       primitive. Count one plant, require the relevant contract guard to fail, restore byte-identically,
       and require the clean fixture to pass. The live package files remain untouched by sabotage.
  - Verify:

    ```sh
    bash skills/delegate/scripts/tests/run.sh
    bash skills/mailbox/scripts/tests/run.sh
    shellcheck skills/delegate/scripts/tests/contract-test.sh \
      skills/mailbox/scripts/tests/contract-test.sh skills/mailbox/scripts/tests/run.sh
    bash skills/skill-builder/scripts/skills-lint.sh .
    ```

    Expected: both package harnesses pass; the exact return/slot contracts remain protected; the planted
    named-harness claims fail their focused guards; lint remains `fails=0 warns=4`.

- [x] **Slice 2: Workstream invokes the public route; the pack owns composition** <requires: Slice 1>
  - Files:
    - Modify: `PACK.md`
    - Modify: `skills/workstream/SKILL.md`
    - Modify: `skills/workstream/flow.md`
    - Modify: `skills/workstream/verbs/create.md`
    - Modify: `skills/workstream/templates/workstream-handoff.md`
    - Create: `skills/workstream/scripts/tests/seam-contract-test.sh`
    - Modify: `skills/workstream/scripts/tests/run.sh`
    - Create: `scripts/tests/clankshop-contract-test.sh`
    - Modify: `scripts/tests/run.sh`
  - Change:
    1. Expand the pack's existing Delegate/Mailbox composition entry into the complete seam:
       Workstream may submit a bounded unit to Delegate; Delegate selects dispatch and, when needed,
       Mailbox transport; Workstream's main session alone writes the held target; absence of either
       optional skill falls back to inline execution.
    2. In Workstream's sole-writer discipline, execution-mode flow, and create route confirmation,
       replace copied transport/model/failure mechanics with an operational call to Delegate's public
       procedure followed by resumption of the Workstream loop from the returned result.
    3. Preserve Workstream-owned state: `manual` versus `delegate`, the confirmed route or
       `inline-only`/`unconfirmed` value in the handoff, the main-session writer invariant, the manual
       PLAN/BUILD/SHIP phase-model map, delegation tallies, single-location gates, and the rule that a
       failed/unavailable route eventually executes inline.
    4. Thin `workstream-handoff.md` to store the selected route state and point to Delegate for its
       meaning. Remove Mailbox slot mechanics, Delegate's phase-to-tier table, exact return headings,
       and the transient/persistent provider-failure ladder. Keep the package-only template's section
       names consumed by `workstream-prime.sh` unchanged.
    5. Leave `verbs/load.md` unchanged. Its step 4 already delegates the attended `unconfirmed`
       interview to `create.md` step 6, so revising that step preserves the pointer while keeping
       load's owner-local inline behavior. Do not change migration because the package-only handoff
       template is never deployed as project configuration.
    6. Add a Workstream seam-contract harness over the exact production-doc population. It requires a
       usable Delegate pointer and rejects four foreign classes independently: spawn mechanism,
       three-part return protocol, model-routing table, and provider-failure ladder. Plant one
       representative of each class into a copied package, require red, restore with `cmp`, then green.
       Patterns must not reject the owner-local manual phase map or isolated-worktree safety text.
    7. Add and register a root Clankshop prose-contract test. In this slice it requires the complete
       Workstream → Delegate → Mailbox seam, inline degradation, and sole-writer custody in `PACK.md`.
  - Verify:

    ```sh
    bash skills/workstream/scripts/tests/run.sh
    bash scripts/tests/run.sh
    shellcheck skills/workstream/scripts/tests/seam-contract-test.sh \
      skills/workstream/scripts/tests/run.sh scripts/tests/clankshop-contract-test.sh scripts/tests/run.sh
    bash skills/skill-builder/scripts/skills-lint.sh .
    ```

    Expected: Workstream and root suites pass; each synthetic foreign-contract class fails before
    restoration; the pack carries the seam once; lint remains `fails=0 warns=4`.

- [x] **Slice 3: Public validation, truthful edges, and documented residuals** <requires: Slice 2>
  - Files:
    - Modify: `PACK.md`
    - Modify: `README.md`
    - Modify: `docs/boundary-audit.md`
    - Modify: `skills/notepad/SKILL.md`
    - Create: `skills/notepad/scripts/tests/contract-test.sh`
    - Modify: `skills/notepad/scripts/tests/run.sh`
    - Modify: `scripts/tests/clankshop-contract-test.sh`
  - Change:
    1. In the pack configuration validation step, instruct the composer to invoke `/workspace check`.
       Remove the package-local Workspace script path from runbook prose. Keep
       `scripts/tests/configure-clankshop-test.sh`'s direct script execution as fixture mechanics: the
       prohibition applies to the human-readable composer procedure, not to Workspace's own behavior
       test.
    2. Condense pack setup prose that repeats member preflight, incumbent, migration, or collision
       mechanics. Retain only cross-member requirements: explicit profile/approval, member-owned setup,
       absent-only project-authored surfaces, write-only sweep custody, resolved public checks, complete
       approved diff review, and one optional aggregate commit.
    3. Change Notepad's edge block to `handoff: —` with a short explanation that write-only sweeps
       return `path=`/`rel=` inline to their caller. Keep `produces: note` and `consumes: note` exactly.
       Add and register a Notepad prose-contract test.
    4. Red-prove the old `handoff: note` guard in a copied Notepad document: plant exactly one old
       declaration, require failure, restore byte-identically, then pass.
    5. Append a new dated entry to `docs/boundary-audit.md` rather than rewriting its historical
       2026-08-27 three-warning entry. Name the current four-warning population and its disposition:
       Workstream `resource-claim` is legal repository-local leaf state; Foreman `goal`,
       `goal-pursuit`, and `session-evidence` are external-runtime edges. Record `fails=0 warns=4`.
    6. Rewrite README's Auditor inventory row so findings remain in the audit report and promote
       through the host capture lane; do not claim direct tracker writes and do not edit Auditor.
    7. Extend the root prose-contract test to require `/workspace check`, the four exact warning
       dispositions, and the corrected Auditor summary. Its absence guard rejects a direct
       `skills/workspace/scripts/workspace-check.sh` instruction in a copied `PACK.md`; plant, require
       red, restore with `cmp`, then require green.
    8. Task 0 found no authoring-only assertion in the Slice 2–3 surfaces beyond the Delegate and
       Mailbox edge commentary removed by Slice 1. Perform no additional authoring-commentary cleanup
       in this slice. If the implementation-time census differs, revise this slice's file list and
       concrete change before editing rather than widening opportunistically.
  - Verify:

    ```sh
    bash skills/notepad/scripts/tests/run.sh
    bash scripts/tests/run.sh
    shellcheck skills/notepad/scripts/tests/contract-test.sh \
      skills/notepad/scripts/tests/run.sh scripts/tests/clankshop-contract-test.sh
    bash skills/skill-builder/scripts/skills-lint.sh .
    for harness in skills/*/scripts/tests/run.sh; do bash "$harness" || exit 1; done
    find skills -name scoped-commit.sh -type f -exec cksum {} \;
    ```

    Expected: all integration and skill harnesses pass; lint reports the documented four warnings and
    no failures; the four scoped-commit helpers remain present and byte-identical; no migration/runtime
    helper changed.

## Done when

- Delegate selects from observed capabilities, preserves the route gate and return contract, and uses
  the Codex reference only for the selected headless-executor branch.
- Mailbox is dispatch-neutral while its absolute-slot, single-writer, drift, apply/consume, and reap
  contracts remain unchanged.
- Workstream invokes Delegate without copying Mailbox or Delegate protocol, retains sufficient
  owner-local execution state, and remains functional inline with optional skills absent.
- `PACK.md` contains the Workstream → Delegate → Mailbox seam and invokes Workspace only through
  `/workspace check`; its setup prose states composition invariants without duplicating leaf safety
  procedures.
- Notepad has `produces: note`, empty `handoff`, and `consumes: note`; `docs/boundary-audit.md` records
  all four residual warnings; README states Auditor's actual report/capture contract.
- Every new absence guard has a fixture red-proof with planted-cardinality and byte-identity checks.
- No frontmatter description changed, or every changed description has a fresh logged routing probe.
- `bash scripts/tests/run.sh`, every `skills/*/scripts/tests/run.sh`, relevant ShellCheck commands, and
  `bash skills/skill-builder/scripts/skills-lint.sh .` pass with `fails=0 warns=4`.
- A full `/skill-builder check` boundary pass finds no leaf protocol duplication or pack seam missing.
- The implementation diff contains only slice-owned production/test paths, preserves all unrelated
  Auditor/Inspector and record work, and leaves migration support plus all four `scoped-commit.sh`
  helpers unchanged.

_On completion (before landing), run the host's close-the-books sweep._
