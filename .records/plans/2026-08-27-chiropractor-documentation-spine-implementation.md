---
doctype: plans
status: published
stage: implemented
schema: contractor/plan@1
tags: [plan]
---

# Chiropractor documentation spine — Implementation Plan

Tracer-bullet: Slice 1 proves the complete user-visible path in one small repository: enter through
`AGENTS.md`, inventory one important document and one operation, return a read-only audit, then build
an exact documentation-only adjustment preview without changing the tree before confirmation. Slice
2 widens the deterministic scanner beneath that path. Slice 3 hardens the complete-ledger judgment
and confirmation protocol. Slice 4 integrates the finished standalone skill into the library and
`clankshop` pack, then dogfoods both verbs in a dirty throwaway repository. Each slice is independently
testable and committable.

Spec: `.records/specs/2026-08-27-chiropractor-documentation-spine.md`

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Published contract:** Implement only the published specification above. Chiropractor stewards an
  existing project's documentation spine in place; it does not create a project home, setup verb,
  template deployment, route block, record, tracker, taxonomy, or parallel documentation system.
- **Scanner facts, agent judgment:** `scripts/spine-scan.sh` owns deterministic repository facts and
  candidate enumeration. The agent owns importance, authority, altitude, grouping, semantic-surface
  extraction, routing quality, and recommendations. Do not encode subjective verdicts in shell.
- **One candidate population:** Default output and `--candidates` must derive from the same normalized,
  repository-relative inventory. Every complete audit reconciles its physical-source ledger exactly
  to the scanner's `candidate_count`; every important candidate and semantic surface receives an
  individual disposition and route.
- **Finite reference grammar:** Parse only the published Markdown/MDX inline-link, `@` import,
  fenced-aware inline-code path, and Markdown fragment forms. Inventory all other candidate formats
  for direct agent reading; do not grow an opportunistic RST/AsciiDoc/manifest parser.
- **Front-door safety:** A usable root door is a readable regular non-symlink `AGENTS.md`. Missing,
  `CLAUDE.md`-only, divergent dual-door, and incompatible-path states follow the published matrix.
  Poor content does not make an otherwise usable door path-incompatible. No established `AGENTS.md`
  means no full reach score. Never follow a symlinked directory, cross the repository root, or descend
  into a nested Git root.
- **Read-only by default:** Bare invocation and `audit` never edit. `adjust` may construct an exact
  unified diff in a temporary directory, but it must wait for explicit confirmation before applying
  any hunk. A stale digest, rebase, new target, move, deletion, expanded authority change, or any
  content change invalidates the preview and requires a fresh preview plus confirmation. A named,
  byte-identical subset is the only partial approval.
- **Documentation-only mutation:** Even after approval, Chiropractor may edit only documentation and
  front-door files named in the preview. It never changes scripts, code, manifests, permissions,
  staging, commits, stashes, branches, or unrelated dirty content. A broken helper script is reported,
  not repaired.
- **Dirty-tree discipline:** Capture target-path preimages and the complete Git baseline before the
  preview. Apply only the approved hunks, preserve all pre-existing changes, and show the incremental
  post-apply diff. Do not require a clean repository and do not mistake untracked documentation for
  disposable content.
- **Portable package:** The implementation must run with Bash 3.2 and common POSIX utilities, locate
  bundled files relative to the skill, remain useful outside this repository and outside the pack,
  and expose only the stable scanner entry point `scripts/spine-scan.sh <root> [--candidates]`.
- **Patient zero:** Never add a deployed Chiropractor block or generated project layout to this
  repository's real `AGENTS.md`. Exercise all front-door creation, `CLAUDE.md` migration, adjustment,
  and dirty-tree behavior in throwaway fixtures. The real `AGENTS.md` may receive only its authored
  library-inventory mention in Slice 4.
- **Selective prior art:** Commit `e7d06d8` contains the retired Chiropractor. Reuse proven
  normalization, fenced-code, historical-path, nested-root, and capped-output techniques only after
  re-verifying them. Do not restore its monolithic skill, `calibrate` mode, broad entry-door model,
  token/glossary/frontmatter scoring, or old twelve-dimension rubric.
- **Red-first:** Before implementing each new mechanical assertion, demonstrate that its focused test
  fails on the missing behavior or on exactly one planted defect in a disposable copy. Restore with
  `cmp`, then require green. Do not sabotage live package or project files.
- **Description boundary:** Chiropractor's frontmatter description must route on documentation-spine
  discoverability and confirmed link/front-door adjustment alone. It must not steal general document
  critique, developer-prose authoring, code-quality audit, or project-operation curation prompts.
- **Coexisting work:** At plan authoring, unrelated accepted work already modifies `PACK.md`,
  `README.md`, `docs/boundary-audit.md`, and `scripts/tests/run.sh`, and has an untracked
  `scripts/tests/clankshop-contract-test.sh`. Preserve those changes byte-for-byte outside the exact
  Chiropractor additions. Re-read each overlap immediately before editing; if its meaning or ownership
  has changed, pause that slice and reconcile instead of overwriting it.
- **Pack release:** Adding an optional default-installed member is a new compatible feature. From the
  plan-authoring baseline, bump `clankshop` from `4.0.0` to `4.1.0`. If Task 0 finds a different live
  version, recalculate the next compatible minor version and update the slice before editing.
- **Snapshot warning:** Paths, baselines, and prior-art claims below were verified while drafting.
  Task 0 must repeat them in the implementation checkout before any edit.

## Task 0 — Re-ground the documentation spine before editing

Read-only; produce no commit.

1. Verify custody, the published input, and the complete dirty baseline:

   ```sh
   git rev-parse --show-toplevel
   git branch --show-current
   git status --short
   sed -n '1,8p' .records/specs/2026-08-27-chiropractor-documentation-spine.md
   skills/contractor/scripts/ground-check.sh \
     "$(git rev-parse --show-toplevel)" \
     .records/specs/2026-08-27-chiropractor-documentation-spine.md
   ```

   Expected at plan authoring: top level `/Users/cscott/Repos/grimoire`, branch `main`, published
   spec, and `unresolved_count=0`. Record all dirty paths. Do not read another session's
   `.workstreams/*/WORKSTREAM.md`.
2. Re-read the complete governing spec and current integration/authoring surfaces:

   ```text
   AGENTS.md
   README.md
   PACK.md
   docs/spec/pack-format.md
   docs/boundary-audit.md
   scripts/tests/run.sh
   scripts/tests/install-pack-test.sh
   scripts/tests/clankshop-contract-test.sh
   skills/skill-builder/docs/DOCTRINE.md
   skills/skill-builder/docs/BOUNDARY-AUDIT.md
   skills/skill-builder/scripts/skills-lint.sh
   ```

   Confirm that `skills/chiropractor/` does not exist in the live tree and that this plan's `Create:`
   targets remain absent. Treat the currently untracked root contract test as coexisting work, not a
   file to replace.
3. Re-ground capability-wide prior art without restoring it wholesale:

   ```sh
   git ls-tree -r --name-only e7d06d8 -- skills/chiropractor
   git show e7d06d8:skills/chiropractor/scripts/spine-scan.sh
   git show e7d06d8:skills/chiropractor/scripts/tests/run.sh
   rg -n "AGENTS\.md|CLAUDE\.md|candidate_count|anchor_unverified|spine-scan" \
     skills scripts docs README.md PACK.md AGENTS.md
   ```

   Record which old algorithms still satisfy Bash 3.2 and the new finite grammar. Reject old behavior
   that treats README/CLAUDE as interchangeable root doors or scores token economy, glossary,
   frontmatter, style, or taxonomy.
4. Establish the implementation baseline:

   ```sh
   bash scripts/tests/run.sh
   for harness in skills/*/scripts/tests/run.sh; do bash "$harness" || exit 1; done
   bash skills/skill-builder/scripts/skills-lint.sh .
   ```

   At plan authoring, the root suite passes and lint reports `fails=0 warns=4` (`goal`,
   `goal-pursuit`, `resource-claim`, and `session-evidence`). Reconcile any new failure or warning
   before sizing or editing. The all-skill-harness sweep is deliberately repeated here because the
   current checkout contains unrelated package work.

## Slices

- [x] **Slice 1: One repository from audit to confirmed-adjustment preview** <requires: Task 0>
  - Files:
    - Create: `skills/chiropractor/SKILL.md`
    - Create: `skills/chiropractor/docs/RUBRIC.md`
    - Create: `skills/chiropractor/verbs/audit.md`
    - Create: `skills/chiropractor/verbs/adjust.md`
    - Create: `skills/chiropractor/scripts/spine-scan.sh`
    - Create: `skills/chiropractor/scripts/tests/run.sh`
    - Create: `skills/chiropractor/scripts/tests/tracer-test.sh`
    - Create files under: `skills/chiropractor/scripts/tests/fixtures/tracer/`
  - Change:
    1. Add a strict-YAML `SKILL.md` with a self-scoping description, bare invocation routed to
       `verbs/audit.md`, explicit `audit` and `adjust` modes, natural-language fix requests routed to
       `adjust`, the patient-zero caveat, and a delimited edge block whose `produces`, `handoff`, and
       `consumes` values are all `—`. Add no setup, project-template, registration, or durable-home
       surface.
    2. Define the seven-dimension rubric in `docs/RUBRIC.md`: Door, Routing, Reach, Currency,
       Authority, Altitude, and Scope, each scored exactly `solid`, `drift`, or `gap`. Make scores
       evidence-backed and explicitly reject forced glossaries, indexes, frontmatter, house style, or
       taxonomies. State the direct-route expectation for project-wide tasks, the one-scoped-router
       allowance for subsystem work, and the presumed drift beyond two hops unless justified.
    3. Implement the scanner's safe shell skeleton and stable CLI. Resolve an explicit root, reject
       invalid options, create only a trapped temporary directory, emit deterministic `key=value`
       facts in default mode, and emit sorted TSV `candidate` rows plus `candidate_count` in
       `--candidates` mode. In this tracer, support root-door state/digests, tracked versus untracked
       nonignored origin, conventional Markdown documents, executable scripts, and one local
       Markdown-link edge. Never execute a discovered file or mutate the fixture.
    4. Write the complete audit procedure around the scanner even though later slices widen its facts:
       validate the root door, obtain the full candidate inventory, build physical-source and
       semantic-surface ledgers, score only after reconciling them, and return the five-section report:
       scope/worktree/front-door state; both reconciled ledgers; task-route matrix; seven-check
       scorecard; and severity-ranked findings with proposed adjustments. End with an offer to run
       `adjust`. A missing root `AGENTS.md` receives a census and proposed minimal door but no full
       reach score.
    5. Write the complete adjustment control flow: rerun the audit, select only documentation/front-door
       targets, capture content digests, construct an exact unified patch in temporary storage, list
       target paths and hunk intent, show the preview, and stop for explicit confirmation. Define
       byte-identical named-subset approval and every reconfirmation trigger. Applying an approved
       patch is part of the procedure, never a second production helper.
    6. Encode all four `CLAUDE.md` states in the verbs: AGENTS-only leaves CLAUDE absent; healthy dual
       doors keep `@AGENTS.md` plus a genuinely Claude-specific remainder; CLAUDE-only proposes moving
       portable content to a new AGENTS and leaves the import skeleton; divergent dual doors propose
       reconciliation without silently choosing an authority.
    7. Build a tracer fixture containing `AGENTS.md`, `README.md`, `docs/setup.md`, and
       `scripts/release.sh`. The door links to setup; setup names the release operation. The test
       red-proves the absent candidate/edge assertions, then verifies stable counts, tracked/untracked
       origins, a capped default fact surface, a complete sorted candidate stream, and byte-identical
       fixture state before and after both modes.
    8. Perform one manual tracer walkthrough against a temporary copy: produce the five-section audit;
       request the missing release route; produce its exact patch preview; verify no tree write before
       confirmation; confirm that single hunk; and show only that incremental documentation diff.
  - Verify:

    ```sh
    bash skills/chiropractor/scripts/tests/run.sh
    shellcheck skills/chiropractor/scripts/spine-scan.sh \
      skills/chiropractor/scripts/tests/run.sh \
      skills/chiropractor/scripts/tests/tracer-test.sh
    bash skills/skill-builder/scripts/skills-lint.sh .
    ```

    Expected: the tracer finds the door, important document, and operation without executing or
    modifying them; default and candidate counts agree; the audit is read-only; the preview is exact;
    only the explicitly confirmed documentation hunk applies; lint remains `fails=0` with only the
    pre-existing warning population.

- [x] **Slice 2: Deterministic candidate graph and finite reference grammar** <requires: Slice 1>
  - Files:
    - Modify: `skills/chiropractor/scripts/spine-scan.sh`
    - Modify: `skills/chiropractor/scripts/tests/run.sh`
    - Create: `skills/chiropractor/scripts/tests/lib.sh`
    - Create: `skills/chiropractor/scripts/tests/scanner-test.sh`
    - Create files under: `skills/chiropractor/scripts/tests/fixtures/door-states/`
    - Create files under: `skills/chiropractor/scripts/tests/fixtures/candidates/`
    - Create files under: `skills/chiropractor/scripts/tests/fixtures/grammar/`
    - Create files under: `skills/chiropractor/scripts/tests/fixtures/topology/`
    - Create files under: `skills/chiropractor/scripts/tests/fixtures/history/`
  - Change:
    1. Complete one normalized repository population using tracked files plus untracked nonignored
       files. Give each unique repo-relative candidate a comma-sorted kind set, `tracked` or
       `untracked` origin, and deterministic evidence. Include conventional documentation,
       `scripts/`/`bin/`, executable tracked or untracked files, Make/Just/Task files, build/package
       manifests, CI/release workflows, and named operations/runbooks. Inventory extensionless and
       non-Markdown sources even when their internals are unparsed.
    2. Exclude ignored content, symlinked directories, and nested Git roots from traversal. Keep
       tracked or untracked-nonignored historical, archive, generated, vendor, and internal sources in
       the candidate population with factual evidence so the audit can disposition them; do not make
       them silently disappear. Detect nested `AGENTS.md` files and nested repositories as facts.
       Treat historical/archive content as a visible disposition input, not live routing. Report
       escaping references without following them.
    3. Implement the exact candidate row contract:
       `candidate<TAB><path><TAB><comma-separated-kinds><TAB><origin><TAB><evidence>`. Emit the full
       lexically sorted stream only with `--candidates`; emit true totals and capped samples in default
       mode. Both modes must consume the same inventory artifact and report the same
       `candidate_count`.
    4. Implement only the finite reference grammar: Markdown/MDX inline local destinations with no
       unescaped whitespace/parentheses and an optional quoted title; angle-bracket destinations with
       spaces/parentheses; `@` imports limited to `[A-Za-z0-9._/-]+`; fenced-aware inline-code repo
       paths with optional `:line`/`#fragment` but no leading slash, URL, glob/template, or whitespace;
       and Markdown fragments using explicit IDs plus a tested GitHub ATX slugger with duplicate
       suffixes. Strip titles/fragments before path resolution. Record reference-style links and HTML
       links as inventory-only facts, and use `anchor_unverified` when an anchor cannot be proved.
    5. Add deterministic default facts for root-door presence, `CLAUDE.md` import state, root-door
       outline, imported byte counts, exact content digests, nested doors/roots, candidate-kind totals,
       broken/escaping/unverified edges, reach topology, capped samples with a truncation marker and
       uncapped total, and worktree state. Use the published repeated-fact line shapes. Facts report
       what was observed, not whether documentation is important or well designed.
    6. Make every fixture test run from a disposable copy. Cover AGENTS-only, CLAUDE-only, neither,
       healthy import, healthy import with a harness-specific remainder, duplicated pair, divergent
       pair, and directory/unreadable/symlink `AGENTS.md`; exact accepted/rejected grammar; duplicate
       headings and explicit IDs; each operation-candidate class; RST/AsciiDoc/extensionless sources;
       tracked, untracked, ignored, archived, generated, vendor, executable, nested-root, nested-door,
       symlink-directory, broken, document-relative, inward-superproject, and outward-escaping cases;
       candidate paths containing spaces; and a population larger than the sample cap.
    7. For each new matcher or exclusion, plant exactly one positive or negative counterexample,
       require the focused assertion to turn red, restore byte-for-byte, and require green. Assert a
       clean/dirty status snapshot before and after every scanner invocation to prove no mutation.
  - Verify:

    ```sh
    bash skills/chiropractor/scripts/tests/run.sh
    shellcheck skills/chiropractor/scripts/spine-scan.sh \
      skills/chiropractor/scripts/tests/lib.sh \
      skills/chiropractor/scripts/tests/scanner-test.sh
    bash -c 'for f in skills/chiropractor/scripts/tests/fixtures/*; do test -e "$f" || exit 1; done'
    bash skills/skill-builder/scripts/skills-lint.sh .
    ```

    Expected: every scanner fixture passes on Bash-3.2-compatible syntax; candidate rows are unique
    and sorted; both modes agree on true totals beyond the sample cap; nested/symlink/escaping content
    is never traversed; accepted and inventory-only grammar cases remain distinct; no fixture mutates.

- [x] **Slice 3: Complete audit ledgers and stale-safe confirmation** <requires: Slice 2>
  - Files:
    - Modify: `skills/chiropractor/SKILL.md`
    - Modify: `skills/chiropractor/docs/RUBRIC.md`
    - Modify: `skills/chiropractor/verbs/audit.md`
    - Modify: `skills/chiropractor/verbs/adjust.md`
    - Modify: `skills/chiropractor/scripts/tests/run.sh`
    - Create: `skills/chiropractor/scripts/tests/procedure-contract-test.sh`
    - Create: `skills/chiropractor/scripts/tests/fixtures/walkthroughs/cases.tsv`
    - Create: `skills/chiropractor/scripts/tests/fixtures/walkthroughs/physical-candidates.tsv`
    - Create: `skills/chiropractor/scripts/tests/fixtures/walkthroughs/semantic-source.md`
    - Create: `skills/chiropractor/scripts/tests/fixtures/walkthroughs/expected-audit.md`
  - Change:
    1. Tighten the physical-source ledger contract so its individual and homogeneous grouped rows sum
       exactly to scanner `candidate_count`. Each row records count/sample, evidence, inspection mode,
       discovered surface IDs or explicit `none`, one of `important`, `internal`,
       `historical/generated`, or `unresolved`, and rationale. Every important candidate is
       individual; every live nonhistorical source is read directly unless a supported homogeneous
       grouping rationale names the shared evidence. `unresolved` or unclassified rows block a solid
       result.
    2. Tighten the semantic-surface ledger contract so every task, procedure, workflow, or load-bearing
       knowledge item receives a report-local `<source>#<short-label>` ID, kind, source evidence, one
       of the same four dispositions, authoritative destination, and rationale. Every important
       surface is individual and routed; newly proposed surfaces are counted separately from observed
       ones. Finding one task in a source never licenses omitting its second task.
    3. Freeze the exact five report sections and evidence hierarchy: (1) scope, Git/worktree state,
       front-door state, and excluded nested roots/stores; (2) reconciled physical-source and
       semantic-surface ledgers with totals and unresolved rows; (3) task-route matrix; (4) the seven
       checks scored `solid`, `drift`, or `gap`; and (5) severity-ranked findings with location,
       measured fact, judgment, and proposed adjustment. The report contains no patch. Explain direct
       versus grouped inspection, authority conflicts, scoped-router justification,
       `historical/generated` disposition, and why missing AGENTS blocks a full reach result.
    4. Freeze adjustment preflight and application semantics. Verify every target is a regular
       non-symlink file inside the root, compare content digests immediately before apply, reject any
       unpreviewed path/hunk, and treat moves/deletions/new doors/authority changes as explicit preview
       items. After confirmation, apply only the approved byte-identical subset and rerun scanner plus
       the complete audit; report preserved dirty paths and the incremental diff.
    5. Populate `cases.tsv` with the exact fifteen published walkthroughs: neither door stops at a
       grounded minimal-door proposal; CLAUDE-only migration preserves its specific remainder and
       leaves the import skeleton after confirmation; divergent doors surface authority conflict;
       graph-reachable but ambiguous workflow fails Routing or Reach; public script is routed while
       its private helper is not independently required; archive store is reached by convention;
       audit stops after findings; direct adjust previews without writing; dirty surgical edit
       separates old/new diff; changed target invalidates approval; byte-identical named subset
       applies while a rebased subset reconfirms; broken script is reported but untouched; complete
       physical disposition rejects one missing candidate; two-task source rejects either omission or
       blank `surfaces`; and homogeneous grouping rejects missing population/sample/shared-rule
       evidence.
    6. Make the procedure contract test verify that every named case has fixture inputs and expected
       evidence, check the actual SKILL/verb/rubric text, reconcile `physical-candidates.tsv` to the
       scanner population, and reconcile both tasks in `semantic-source.md` to `expected-audit.md`.
       Red-prove an omitted physical row, omitted second semantic task, unsupported group, audit-time
       patch, broad confirmation, and stale-digest apply in disposable copies; each must fail its
       focused static contract before byte-identical restoration. These prose/fixture contracts are
       guardrails, not substitutes for executing the procedure.
    7. Execute all fifteen fixture-backed walkthroughs by following the actual package procedure
       against fresh throwaway copies and report per-case pass/fail evidence in the implementation
       handoff. Negative cases must visibly take their required stop/refusal branch. In particular,
       CLAUDE-only establishment uses one confirmed door patch, reruns the scanner from the new
       `AGENTS.md`, and requires a second preview/confirmation before any ordinary route repair; the
       initial natural-language “fix” request authorizes neither patch.
  - Verify:

    ```sh
    bash skills/chiropractor/scripts/tests/run.sh
    shellcheck skills/chiropractor/scripts/tests/procedure-contract-test.sh \
      skills/chiropractor/scripts/tests/run.sh
    bash skills/skill-builder/scripts/skills-lint.sh .
    ```

    Expected: all fifteen walkthroughs execute and report passing evidence; physical rows reconcile
    exactly; both semantic tasks survive; unsupported grouping and unresolved rows prevent a solid
    result; audit never previews or applies; stale or broadened adjustments require a fresh
    confirmation; all focused red-proofs and the package harness pass.

- [x] **Slice 4: Library integration, routing proof, and dirty-repo dogfood** <requires: Slice 3>
  - Files:
    - Modify: `PACK.md`
    - Modify: `README.md`
    - Modify: `AGENTS.md`
    - Modify: `scripts/tests/install-pack-test.sh`
    - Modify: `scripts/tests/clankshop-contract-test.sh` (preserve its coexisting untracked content)
    - Modify: `scripts/tests/run.sh`
    - Modify: `docs/boundary-audit.md`
  - Change:
    1. Add `chiropractor` to the pack's optional default-installed members and bump the grounded
       `4.0.0` baseline to `4.1.0`. Add it to the human-readable member category and one seam entry:
       Chiropractor audits documentation/front-door routing and adjusts it only after confirmation;
       it has no project setup or home, and it does not curate operations or repair scripts.
    2. Add Chiropractor to README's helper roster and inventory table with a self-scoped description
       of documentation-spine discoverability, authority, routing, and confirmed documentation-only
       adjustment. Add only the authored helper-roster mention to `AGENTS.md`; do not add a generated
       route block or consuming-project layout.
    3. Extend `install-pack-test.sh` with installed-member canaries for executable
       `chiropractor/scripts/spine-scan.sh`, `verbs/audit.md`, and `verbs/adjust.md`, and assert its
       optional classification in the lock. Red-prove the membership assertion with a disposable
       manifest/target fixture rather than changing the live manifest.
    4. Extend the existing Clankshop contract test in place to require Chiropractor's optional
       membership, README/AGENTS inventory entries, and the pack seam. Preserve all current
       Workstream/Delegate/Mailbox, Workspace, Auditor, and warning-disposition assertions. Add focused
       planted-defect red-proofs for a missing member and a pack seam that falsely claims setup or
       script repair.
    5. Register `bash skills/chiropractor/scripts/tests/run.sh` in the root integration entry point in
       addition to its current repository tests. Keep failure aggregation so the package suite cannot
       be masked by a later passing integration test.
    6. Run a descriptions-only routing probe with positive prompts for discovering setup/release/docs
       from AGENTS, auditing doc reachability, and reconciling CLAUDE/AGENTS; and negative controls for
       reviewing one document, writing developer prose, auditing project code, and curating an
       operation. Append a dated result to `docs/boundary-audit.md`; sharpen only Chiropractor's own
       description if it steals or misses a route, then rerun the complete probe.
    7. Dogfood both verbs in a throwaway Git repository with at least five important tasks and both
       front-door files, where `CLAUDE.md` imports `AGENTS.md` and retains a genuine harness-specific
       remainder. Include unrelated staged, unstaged, and untracked changes; nested docs and a nested
       Git root; more candidates than the cap; one broken link; and a public helper-script route. The
       audit must report complete physical and semantic ledger populations and leave the tree
       byte-identical. The adjustment must preview minimal route/link corrections, wait, accept a
       named byte-identical subset, preserve unrelated dirt, and show only the approved incremental
       diff. CLAUDE-only establishment remains the separate Slice 3 walkthrough and is not substituted
       for this final acceptance population.
    8. Run the full package, repository, lint, and shell gates. Compare the final diff with the Task 0
       baseline and confirm the real repository received no deployed Chiropractor files outside
       `skills/chiropractor/`, no project route block, and no mutation produced by dogfooding.
  - Verify:

    ```sh
    bash skills/chiropractor/scripts/tests/run.sh
    bash scripts/tests/run.sh
    shellcheck skills/chiropractor/scripts/spine-scan.sh \
      skills/chiropractor/scripts/tests/*.sh \
      scripts/tests/install-pack-test.sh \
      scripts/tests/clankshop-contract-test.sh \
      scripts/tests/run.sh
    bash skills/skill-builder/scripts/skills-lint.sh .
    git diff --check
    ```

    Expected: the pack installs Chiropractor as an optional member at the new compatible release;
    package and root suites pass; all planted defects turn their focused guards red before restore;
    routing probes select Chiropractor only for its own domain; lint has `fails=0` and only documented
    warnings; dogfood proves full-ledger audit plus confirmed subset adjustment without collateral
    changes.

## Implementation result

- **Task 0 — passed.** Published-spec ground check reported `unresolved_count=0`; branch, dirty
  baseline, prior art, root integration tests, every existing skill harness, and the initial lint
  population were recorded before edits.
- **Slice 1 — passed.** The tracer reconciled five candidates and the setup/release surfaces, stayed
  read-only through preview, and applied only confirmed hunk T1. Its unrelated untracked note remained
  byte-identical; the release route rescanned at depth two with no broken reference.
- **Slice 2 — passed.** The Bash 3.2 scanner test finished with 79 assertions. Candidate/default
  populations agree; the finite grammar, code-literal boundaries, door states, anchors, nested roots,
  symlink boundaries, escaping paths, worktree facts, caps, and empty-graph topology are covered by
  focused red-proofs.
- **Slice 3 — passed.** The procedure contract finished with 34 assertions. CLAUDE-only item C1
  established `AGENTS.md`, preserved its harness-specific remainder behind `@AGENTS.md`, and rescanned
  before finding no ordinary follow-up repair. The fifteen walkthroughs all took their expected branch:

  | case | result evidence |
  |---|---|
  | 01 neither door | census only; no full Reach score |
  | 02 CLAUDE only | confirmed C1; import skeleton and remainder preserved |
  | 03 divergent doors | unequal digests surfaced; no authority chosen |
  | 04 ambiguous label | both leaves reachable; Routing still failed |
  | 05 public/private script | public caller routed; private helper internal |
  | 06 archive convention | archive guide routed; 25 records grouped historically |
  | 07 audit only | five sections and findings; no patch or write question |
  | 08 direct adjust | exact preview; no write before confirmation |
  | 09 dirty target | staged, unstaged, and untracked dirt preserved |
  | 10 stale proposal | digest change refused application |
  | 11 named subset | D1 applied byte-identically; D2 excluded and now requires reconfirmation |
  | 12 broken script | reported and left byte-identical |
  | 13 physical completeness | omitted row blocked completeness |
  | 14 two surfaces | omitted release or blank `surfaces` failed |
  | 15 homogeneous group | missing population/sample/shared rule failed |

- **Slice 4 — passed.** Clankshop 4.1.0 installs Chiropractor as an optional member; installed-file,
  lock, inventory, seam, and planted-defect guards pass. The descriptions-only routing battery was
  8/8. Dirty dogfood reconciled all 44 candidates and eight important surfaces; approved D1 removed
  the sole broken reference and routed API documentation while D2 remained untouched.
- **Final gates — passed.** Package and root suites, every skill harness, ShellCheck, skill validation,
  the skill-library lint (`fails=0 warns=4`, all four pre-existing documented edge exceptions), spec
  ground check, and `git diff --check` are green on Bash 3.2. The only Chiropractor route block is
  package-local; no deployed project surface, staging action, commit, or branch change was made.
- **Close the books — complete.** This checkout has no deployed `.trackers` provider. Grimoire's
  fallback feedback lane is tagged GitHub issues; the acceptance defects found during the walk were
  fixed and left no unresolved project follow-up, so no issue was filed.

## Done when

The standalone `skills/chiropractor/` package implements the published audit and adjustment
contracts; its single Bash-3.2 scanner produces one safe, deterministic candidate population and
finite reference graph; every complete audit reconciles physical and semantic ledgers before scoring;
no change occurs before exact confirmation; all CLAUDE/AGENTS and dirty-tree states behave as
specified; the optional pack member and library inventories are truthful; package, root, shellcheck,
lint, and diff gates pass; and dirty throwaway dogfood shows no mutation outside the approved
documentation subset.

Before landing, rerun Task 0's complete baseline sweep, compare the entire implementation diff to the
published spec requirement-by-requirement, and run the host's close-the-books sweep. No implementation
commit should include unrelated dirty work.
