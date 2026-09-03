---
doctype: plans
status: published
stage: implemented
schema: contractor/plan@1
tags: [plan]
---

# Skilldata hard cut and Foreman first-use upgrade — Implementation Plan

The tracer is a read-only global-template catalog and one explicitly selected template flowing into Foreman's existing candidate validator. The second slice performs the indivisible repository-wide storage hard cut. The final slice adds the accepted first-use publication and post-run promotion transactions. Each slice ends green and is independently committable; Slice 2 must not be split into revisions that leave live readers and writers on different roots.

Specs:

- `.records/specs/2026-09-02-foreman-first-use-and-global-operation-templates.md`
- `.records/specs/2026-09-02-skilldata-hard-cut-and-workspace-retirement.md`
- `.records/adr/2026-09-02-reserve-skilldata-for-project-and-global-skill-owned-data.md`

## Global Constraints (verify vs HEAD before editing — the plan gate)

- The three governing records above are published. Treat them as the authority when this plan and the tree differ; revise the plan rather than silently changing an accepted decision.
- Project-owned skill data lives at `.agents/skilldata/<owner>/<kind>/...`. Owners match `[a-z0-9-]+`; the shared project kinds are `doctrine`, `drafts`, `hooks`, `operations`, `scripts`, and `templates`.
- Optional user-global data lives at `~/.agents/skilldata/<owner>/...`; each owner defines its internal shape. `.agents/skills` remains package installation space, never mutable skill data.
- There is no replacement whole-tree Workspace validator. Each skill validates the paths it owns. A deliberate cross-owner reader validates only the kind and contracts it consumes.
- This is a hard cut: add no `.spaces` probes, migration, alias, fallback, warning, compatibility reader, or cleanup. Existing `.spaces` trees are inert and remain the user's responsibility.
- The only permitted live `.spaces` literals after Slice 2 are: historical `.records/**`; historical `.scratch/**`; one bounded retirement paragraph in `skills/skill-builder/docs/DOCTRINE.md`; the rejecting token in `skills/skill-builder/scripts/skills-lint.sh`; and a negative-test line carrying the exact annotation `# lint: allow retired-skilldata-rejection`. None may resolve, read, write, or emit the retired path.
- Grimoire is patient zero for the mechanisms, not a consuming project. Tests use throwaway fixtures and isolated home directories. Do not deploy `.agents/skilldata` into this repository and do not add generated door blocks to its authored `AGENTS.md`.
- Foreman may read global operation templates, but has no global setup, write, sync, or mutation command. A selected template is copied into a fully resolved project candidate; no global path is persisted and later Foreman phases never reread the template.
- Checkpoint and Workstream remain the only runtime-state owners. Foreman adds no process supervisor, runtime ledger, transaction receipt, or new schema status.
- Preserve shell portability and the existing TSV/fact-style helper interfaces. Production scripts must reject unsafe symlinks and malformed paths before reading content.
- Preserve unrelated and concurrent work. At plan time, Journal implementation/tests and Skill-builder lint/tests were changing concurrently; Task 0 must recheck them, and implementation must not overwrite or stage unrelated hunks.
- At plan time the bounded live-root census (`README.md`, `PACK.md`, `AGENTS.md`, `scripts`, and `skills`) found 114 files containing `.spaces`: 69 non-test files and 45 test files. Recompute this population before editing; do not treat the snapshot as exhaustive if HEAD has moved.
- The Foreman, Skill-builder, and Workspace suites were green at plan time (273, 71, and 42 assertions respectively). The root integration suite had not produced a reliable final exit while concurrent work was active, so Task 0 must establish its actual baseline.
- Implementation may produce reviewable commits, but must not stage unrelated files or land/ship on the user's behalf.

## Task 0: Re-ground the accepted design and live tree

- [x] Read all three governing records in full and rerun Contractor's grounding checks:

  ```sh
  skills/contractor/scripts/ground-check.sh . .records/specs/2026-09-02-foreman-first-use-and-global-operation-templates.md
  skills/contractor/scripts/ground-check.sh . .records/specs/2026-09-02-skilldata-hard-cut-and-workspace-retirement.md
  ```

  Both checks must report zero unresolved references before implementation begins.

- [x] Capture `git status --short` and the current HEAD. Identify overlapping user or concurrent edits, especially under `skills/journal/` and in `skills/skill-builder/scripts/skills-lint.sh` plus its tests, and either preserve them hunk-by-hunk or stop for coordination before touching the same lines.
- [x] Recompute and save the bounded live-root `.spaces` carrier list:

  ```sh
  rg -l -F '.spaces' README.md PACK.md AGENTS.md scripts skills
  ```

  Classify every result as a production reference, test fixture/assertion, or one of the exact allowed retirement literals. Also search for Workspace-skill routes and package references independently because some contain no `.spaces` literal:

  ```sh
  rg -n '(/workspace|skills/workspace|workspace-check|`workspace`|Workspace skill)' README.md PACK.md AGENTS.md scripts skills
  ```

- [x] Re-read the live interfaces before editing: `skills/foreman/scripts/operation-check.sh`, `operation-write.sh`, `goal-compile.sh`, `operations-index.sh`, `foreman-door.sh`, `migration-census.sh`, `skills/foreman/templates/goal.md`, `skills/skill-builder/scripts/skills-lint.sh`, `skills/skill-builder/SKILL.md`, `skills/skill-builder/docs/DOCTRINE.md`, `skills/skill-builder/verbs/new.md`, `skills/skill-builder/verbs/check.md`, `skills/skill-builder/verbs/review.md`, and the complete Workspace package.
- [x] Establish a clean behavioral baseline:

  ```sh
  bash skills/foreman/scripts/tests/run.sh
  bash skills/skill-builder/scripts/tests/run.sh
  bash skills/workspace/scripts/tests/run.sh
  bash scripts/tests/run.sh
  ```

  Record any pre-existing failure. Do not reinterpret a failure caused by concurrent edits as part of this implementation.

## Slices

- [x] **Slice 1: Read-only global operation-template tracer** — requires: Task 0

  Files to create:

  - `skills/foreman/scripts/operation-template-index.sh`
  - `skills/foreman/scripts/tests/operation-template-index-test.sh`
  - `skills/skill-builder/scripts/tests/lint-global-skilldata-test.sh`

  Files to modify:

  - `skills/foreman/SKILL.md`
  - `skills/foreman/verbs/create.md`
  - `skills/foreman/scripts/tests/run.sh`
  - `skills/foreman/scripts/tests/skill-doc-test.sh`
  - `skills/skill-builder/SKILL.md`
  - `skills/skill-builder/docs/DOCTRINE.md`
  - `skills/skill-builder/verbs/new.md`
  - `skills/skill-builder/verbs/check.md`
  - `skills/skill-builder/verbs/review.md`
  - `skills/skill-builder/scripts/skills-lint.sh`
  - `skills/skill-builder/scripts/tests/run.sh`

  Change:

  - Add `operation-template-index.sh catalog` and `operation-template-index.sh read --stem <stem>`. Production resolves the current user's home directory once and uses only `~/.agents/skilldata/foreman/templates/operations`; tests isolate it by setting `HOME` for the test process. Do not add a production root override.
  - `catalog` validates every regular, non-symlink template as `foreman/operation-template@1` before returning metadata and emits valid templates in ascending bytewise stem order. Its stdout protocol is TSV facts:
    - `state<TAB>absent|present|unsafe`
    - `template<TAB>stem<TAB>title<TAB>use-when<TAB>shape<TAB>areas<TAB>tags`
    - `invalid<TAB>stem<TAB>reason`
    - `count<TAB>N`
  - Percent-encode `%`, horizontal tab, carriage return, and line feed as `%25`, `%09`, `%0D`, and `%0A` in scalar TSV fields; decode exactly once at the Foreman consumer and reject malformed escapes. Slug-list fields remain in their validated array form. Add round-trip fixtures so legal metadata cannot inject or split fact rows.
  - Require the exact accepted metadata keys and single-line values. Validate the template body against the pre-materialization grammar, including rejection of concrete backticked workflow identities. `catalog` must never emit body text.
  - A missing global root is a successful empty catalog. An unsafe root disables global suggestions without breaking project-local creation. An explicitly selected invalid template is a refusal, not a fallback.
  - `read --stem` validates the chosen file again and emits exactly its body only after explicit selection. Reject traversal, nested stems, symlinks, malformed metadata/body, and files outside the fixed root.
  - Before consulting global metadata, teach Foreman to offer an existing same-purpose project operation through its normal inventory/use path. Otherwise inspect catalog metadata, use agent judgment to suggest at most three genuinely relevant templates with a short reason, and require explicit human selection. Do not add a scoring or auto-selection algorithm.
  - Trace one isolated template from metadata-only discovery through explicit body read into a complete temporary `foreman/operation@1` candidate, then validate it with `operation-check.sh --candidate`. Plant a credential-like value, absolute project path, imported-source declaration, and instruction-looking canary in the selected body; the curation fixture must remove or replace every plant before candidate validation, and its bypass arm must make the test fail. The tracer must make no project or global write.
  - Add the exact `## Global skilldata` declaration convention to Skill-builder. A skill using global data must declare scope, path, access mode, safety behavior, and justification; Foreman declares its single read-only template root. Add scaffold, check, review, and lint guidance. At this slice, add only the global declaration checks; the project-root hard cut lands atomically in Slice 2.
  - Tests must prove stable stem ordering and reversible metadata encoding; metadata-only catalog output does not leak body secrets; symlinked roots/files, lifecycle fields, invalid section shapes, and malformed templates are rejected; concrete workflow identities are rejected; project operations take precedence; silence or rejection uses the bundled scaffold; and missing or contradictory `## Global skilldata` declarations fail lint. Mutation arms must count the changed guard occurrence, make the affected test red, restore the temporary copy, and prove byte identity.

  Verify:

  ```sh
  bash skills/foreman/scripts/tests/run.sh
  bash skills/skill-builder/scripts/tests/run.sh
  bash skills/skill-builder/scripts/skills-lint.sh .
  bash -n skills/foreman/scripts/operation-template-index.sh
  shellcheck skills/foreman/scripts/operation-template-index.sh
  git diff --check
  ```

  Expected: both suites green; each new lint guard has a witnessed mutation red-proof; the isolated tracer exposes metadata before selection, body only after selection, removes every planted project-specific or instruction-like token during curation, and creates no repository or global files.

- [x] **Slice 2: Atomic project skilldata hard cut and Workspace retirement** — requires: Slice 1

  Files to modify are every live carrier found by Task 0, including this plan-time manifest:

  - Root and integration: `AGENTS.md`, `PACK.md`, `README.md`, `scripts/tests/configure-clankshop-test.sh`, `scripts/tests/clankshop-contract-test.sh`.
  - Agent Council: `skills/agent-council/briefs/skill-review.md`.
  - Analyst: `skills/analyst/SKILL.md`, `skills/analyst/scripts/analyst-deploy.sh`, `skills/analyst/scripts/analyst-facts.sh`, `skills/analyst/scripts/tests/deploy-test.sh`, `skills/analyst/scripts/tests/facts-test.sh`, `skills/analyst/verbs/migrate.md`.
  - Architect: `skills/architect/SKILL.md`, `skills/architect/docs/ideal-use.md`, `skills/architect/scripts/architect-artifacts.sh`, `skills/architect/scripts/architect-setup.sh`, `skills/architect/scripts/tests/artifacts-test.sh`, `skills/architect/scripts/tests/migrate-contract-test.sh`, `skills/architect/scripts/tests/setup-test.sh`, `skills/architect/scripts/tests/skill-doc-test.sh`, `skills/architect/verbs/brainstorm.md`, `skills/architect/verbs/migrate.md`, `skills/architect/verbs/setup.md`, `skills/architect/verbs/spec.md`.
  - Auditor: `skills/auditor/BOOTSTRAP.md`, `skills/auditor/SKILL.md`, `skills/auditor/scripts/auditor-seed.sh`, `skills/auditor/scripts/tests/setup-test.sh`, `skills/auditor/verbs/migrate.md`, `skills/auditor/verbs/setup.md`.
  - Backlog: `skills/backlog/SKILL.md`, `skills/backlog/scripts/tests/deploy-test.sh`, `skills/backlog/scripts/tests/hard-cut-test.sh`, `skills/backlog/scripts/tests/repair-test.sh`, `skills/backlog/scripts/tests/skill-doc-test.sh`, `skills/backlog/scripts/tests/trackers-test.sh`.
  - Code Humanizer: `skills/code-humanizer/scripts/scope.sh`.
  - Contractor: `skills/contractor/SKILL.md`, `skills/contractor/scripts/contractor-setup.sh`, `skills/contractor/scripts/tests/setup-test.sh`, `skills/contractor/verbs/migrate.md`, `skills/contractor/verbs/setup.md`.
  - Debugger: `skills/debugger/SKILL.md`, `skills/debugger/scripts/bug-mint.sh`, `skills/debugger/scripts/debugger-setup.sh`, `skills/debugger/scripts/tests/bug-mint-test.sh`, `skills/debugger/scripts/tests/setup-test.sh`, `skills/debugger/verbs/migrate.md`.
  - Delegate: `skills/delegate/SKILL.md`, `skills/delegate/scripts/delegate-setup.sh`, `skills/delegate/scripts/tests/contract-test.sh`, `skills/delegate/scripts/tests/setup-test.sh`, `skills/delegate/verbs/setup.md`.
  - Foreman: `skills/foreman/SKILL.md`, `skills/foreman/scripts/foreman-door.sh`, `skills/foreman/scripts/migration-census.sh`, `skills/foreman/scripts/operation-check.sh`, `skills/foreman/scripts/operation-write.sh`, `skills/foreman/scripts/operations-index.sh`, `skills/foreman/scripts/tests/composition-test.sh`, `skills/foreman/scripts/tests/debrief-contract-test.sh`, `skills/foreman/scripts/tests/goal-compile-test.sh`, `skills/foreman/scripts/tests/goal-routing-test.sh`, `skills/foreman/scripts/tests/lifecycle-test.sh`, `skills/foreman/scripts/tests/migration-redaction-test.sh`, `skills/foreman/scripts/tests/migration-test.sh`, `skills/foreman/scripts/tests/operation-check-test.sh`, `skills/foreman/scripts/tests/operation-template-index-test.sh`, `skills/foreman/scripts/tests/operation-write-test.sh`, `skills/foreman/scripts/tests/operations-index-test.sh`, `skills/foreman/scripts/tests/projection-test.sh`, `skills/foreman/scripts/tests/setup-test.sh`, `skills/foreman/scripts/tests/skill-doc-test.sh`, `skills/foreman/scripts/tests/tracker-tune-test.sh`, `skills/foreman/scripts/tests/verification-test.sh`, `skills/foreman/verbs/create.md`, `skills/foreman/verbs/inventory.md`, `skills/foreman/verbs/project.md`, `skills/foreman/verbs/setup.md`.
  - Inspector: `skills/inspector/SKILL.md`, `skills/inspector/scripts/kinds-deploy.sh`, `skills/inspector/scripts/tests/setup-test.sh`, `skills/inspector/verbs/setup.md`.
  - Journal: `skills/journal/SKILL.md`, `skills/journal/scripts/tests/layer-status-test.sh`, `skills/journal/scripts/tests/repair-test.sh`, `skills/journal/scripts/tests/runtime-recovery-test.sh`, `skills/journal/scripts/tests/setup-resume-test.sh`, `skills/journal/scripts/tests/standup-test.sh`, `skills/journal/verbs/anchor.md`, `skills/journal/verbs/curate.md`, `skills/journal/verbs/done.md`, `skills/journal/verbs/repair.md`, `skills/journal/verbs/search.md`, `skills/journal/verbs/setup.md`.
  - Notepad: `skills/notepad/SKILL.md`, `skills/notepad/scripts/note-mint.sh`, `skills/notepad/scripts/notepad-setup.sh`, `skills/notepad/scripts/tests/note-mint-test.sh`, `skills/notepad/scripts/tests/setup-test.sh`, `skills/notepad/verbs/migrate.md`, `skills/notepad/verbs/setup.md`.
  - Skill-builder: `skills/skill-builder/SKILL.md`, `skills/skill-builder/docs/DOCTRINE.md`, `skills/skill-builder/scripts/skills-lint.sh`, `skills/skill-builder/scripts/tests/lint-doctrine-consumer-test.sh`, `skills/skill-builder/scripts/tests/lint-global-skilldata-test.sh`, `skills/skill-builder/scripts/tests/run.sh`, `skills/skill-builder/verbs/check.md`, `skills/skill-builder/verbs/new.md`, `skills/skill-builder/verbs/review.md`.
  - Workstream: `skills/workstream/SKILL.md`, `skills/workstream/flow.md`, `skills/workstream/scripts/tests/hooks-test.sh`, `skills/workstream/scripts/tests/setup-test.sh`, `skills/workstream/scripts/workstream-setup.sh`, `skills/workstream/verbs/create.md`, `skills/workstream/verbs/migrate.md`, `skills/workstream/verbs/recycle.md`.

  File to rename:

  - `skills/skill-builder/scripts/tests/lint-workspace-path-test.sh` to `skills/skill-builder/scripts/tests/lint-skilldata-path-test.sh`.

  Workspace package files to delete completely:

  - `skills/workspace/SKILL.md`
  - `skills/workspace/scripts/workspace-check.sh`
  - `skills/workspace/scripts/tests/lib.sh`
  - `skills/workspace/scripts/tests/run.sh`
  - `skills/workspace/scripts/tests/workspace-check-test.sh`

  Change:

  - Replace every project reader, writer, setup path, generated path, assertion, and example with `.agents/skilldata/<owner>/<kind>/...`. Rename variables and messages such as `workspace`, `workspace_root`, and `WS_REL` when they mean the retired support root; retain ordinary Git workspace/worktree language where it is semantically correct.
  - Keep each skill's current ownership boundaries and artifact behavior. Setup and migration verbs may establish the new owner-local tree, but may not inspect, migrate, warn about, or remove the old tree.
  - Update Foreman's cross-owner operation inventory to scan `.agents/skilldata/*/operations` and validate only operation-kind contracts. Its tests must prove malformed unrelated sibling kinds remain inert. Do not recreate Workspace's general validator.
  - Update Skill-builder doctrine, scaffold guidance, review rules, and lint to enforce the project grammar and closed kind vocabulary. In `lint-skilldata-path-test.sh` and `lint-global-skilldata-test.sh`, cover every one of the six valid project kinds, invalid owners, kind-first paths, unknown kinds, obvious owner-mismatched writes, mutable writes beneath `.agents/skills`, a project-only package, a global-only package, a project-plus-global package with precedence/materialization, and proof that durable-home classification alone does not grant global storage. Make Skill-builder's self-hosting exceptions exact and content-bounded. A retired-path negative fixture is ignored only on the same line as `# lint: allow retired-skilldata-rejection`; no directory-wide or file-wide exemption is allowed.
  - Retain one concise retirement paragraph in `skills/skill-builder/docs/DOCTRINE.md`; it explains the hard cut but provides no compatibility procedure. Keep the rejecting `.spaces` pattern in the lint implementation.
  - Remove Workspace from root inventory, pack membership, route documentation, cross-skill references, and tests. Do not leave a tombstone package, alias, replacement command, or successor skill.
  - Change Architect's “Workspace drafts” wording to project/Architect drafts and update its contract test. Do not change unrelated uses such as Delegate's generic “workspace-writing.”
  - Update `configure-clankshop-test.sh` to exercise the new concrete paths and staging behavior and to prove rerun convergence. Remove its Workspace-check invocation.
  - Replace the root pack contract's Workspace public-procedure proof with an absence guard: Workspace is not a pack member, public route, or package. Its red proof plants `- workspace` in a disposable `PACK.md` and requires the contract to fail.
  - Update Code Humanizer's scope exclusions for `.agents/skilldata`.
  - In Journal tests, preserve concurrent hunks. Negative fixtures that intentionally contain the retired literal must use the exact annotation; ordinary live prose must not retain it.
  - Run the final census against the bounded live roots. Every remaining match must be one of the four accepted classes and must be inspected to prove it does not resolve or emit the retired path.

  Verify the hard cut first with focused red/green proofs:

  ```sh
  bash skills/skill-builder/scripts/tests/run.sh
  bash scripts/tests/configure-clankshop-test.sh
  bash scripts/tests/clankshop-contract-test.sh
  rg -n -F '.spaces' README.md PACK.md AGENTS.md scripts skills
  rg -n '(/workspace|skills/workspace|workspace-check|`workspace`|Workspace skill)' README.md PACK.md AGENTS.md scripts skills
  test ! -e skills/workspace
  test ! -e .agents/skilldata
  if rg -n '<!-- skill:[a-z0-9-]+ BEGIN -->' AGENTS.md; then exit 1; fi
  ```

  Expected: every new skilldata lint arm has a witnessed mutation red-proof before green, with a nonzero replacement count and byte-identical restoration; the root Workspace absence guard has its planted-membership red proof; the only `.spaces` matches are the exact bounded exceptions; no live Workspace route/package reference remains; no generated door block or real project skilldata was deployed into Grimoire.

  Then run every affected skill suite:

  ```sh
  bash skills/agent-council/scripts/tests/run.sh
  bash skills/analyst/scripts/tests/run.sh
  bash skills/architect/scripts/tests/run.sh
  bash skills/auditor/scripts/tests/run.sh
  bash skills/backlog/scripts/tests/run.sh
  bash skills/code-humanizer/scripts/tests/run.sh
  bash skills/contractor/scripts/tests/run.sh
  bash skills/debugger/scripts/tests/run.sh
  bash skills/delegate/scripts/tests/run.sh
  bash skills/foreman/scripts/tests/run.sh
  bash skills/inspector/scripts/tests/run.sh
  bash skills/journal/scripts/tests/run.sh
  bash skills/notepad/scripts/tests/run.sh
  bash skills/skill-builder/scripts/tests/run.sh
  bash skills/workstream/scripts/tests/run.sh
  bash scripts/tests/run.sh
  bash skills/skill-builder/scripts/skills-lint.sh .
  .records/records.sh check
  ```

  Expected: all suites green. Run `bash -n` and `shellcheck` on every changed production shell script, then `git diff --check`. Inspect `git status --short` to ensure only planned files and preserved pre-existing changes are present.

- [x] **Slice 3: One-acceptance first-use publication and atomic promotion** — requires: Slice 2

  Files to create:

  - `skills/foreman/scripts/goal-start.sh`
  - `skills/foreman/scripts/tests/goal-start-test.sh`
  - `skills/foreman/verbs/start.md`

  Files to modify:

  - `skills/foreman/SKILL.md`
  - `skills/foreman/verbs/create.md`
  - `skills/foreman/verbs/goal.md`
  - `skills/foreman/scripts/goal-compile.sh`
  - `skills/foreman/scripts/operation-write.sh`
  - `skills/foreman/scripts/tests/run.sh`
  - `skills/foreman/scripts/tests/goal-compile-test.sh`
  - `skills/foreman/scripts/tests/goal-routing-test.sh`
  - `skills/foreman/scripts/tests/operation-write-test.sh`
  - `skills/foreman/scripts/tests/lifecycle-test.sh`
  - `skills/foreman/scripts/tests/verification-test.sh`
  - `skills/foreman/scripts/tests/skill-doc-test.sh`
  - `skills/foreman/scripts/tests/composition-test.sh`

  Change:

  - Expose `/foreman start [--as <stem>] <objective>` as the first-use route. If `--as` is omitted, Foreman derives a safe stem from the objective and asks only when identity choice or an incumbent conflict would change the artifact; otherwise the derived identity is simply included in the joint publication preview.
  - Keep `goal-compile.sh render` and `publish` compatible for already-proven operations. Add:
    - `render-provisional --root <dir> --operation <identity> --candidate <file> --objective <text> --record-path <relative-record> --output <file>`
    - `check --root <dir> --input <goal-record>`
  - `render-provisional` accepts exactly one root candidate in `draft`/unverified state. Every child operation must pass existing `goal_eligible=true` validation. It emits the normal source row plus exactly one line in Sources: `Provisional root: \`foreman/<stem>@sha256:<64-lowercase-hex>\``. Proven goals contain no provisional marker.
  - `check` accepts a provisional goal only when that marker occurs exactly once, matches the root source row's identity and canonical digest, the marked Foreman root is `draft` or digest-stably promoted to `active`, its imported sources remain current, and every child remains goal-eligible. Reject missing, duplicate, misplaced, foreign, stale, status-outside-`draft|active`, or mismatched markers.
  - Wire both `goal resume <goal-record>` and `goal status <goal-record>` through `goal-compile.sh check` before either runtime-state access or status reporting. Goals without the marker retain ordinary all-sources eligibility; marked goals use only the accepted provisional-root exception. Cover both routes in `goal-routing-test.sh`.
  - Add `goal-start.sh` with two exact modes:
    - `render --root <dir> --identity foreman/<stem> --objective <text> --candidate <file> --goal-output <file> --manifest-output <file>`
    - `apply --root <dir> --candidate <file> --goal-input <file> --manifest-input <file> --expected-preview-digest sha256:<hex>`
  - `render` runs the candidate overlay check, chooses the dated goal destination once, invokes `render-provisional`, and writes a newline-terminated manifest with exactly these fields in this order: `operation`, `operation_sha256`, `goal_record`, `goal_sha256`. The two SHA fields are raw-file SHA-256 values of the candidate and draft goal. The preview digest is `sha256:` plus SHA-256 of the exact newline-terminated manifest.
  - The human-facing start preview shows the complete resolved operation, exact goal record destination and content, manifest, and preview digest. One acceptance passes only the expected preview digest to `apply`.
  - `apply` regenerates and compares the candidate validation, goal validation, record destination, both raw file hashes, exact manifest bytes, and bundle digest before writing. It preflights both destinations as absent or byte-identical accepted projections. It then writes the operation through `operation-write.sh` and publishes or preserves the exact goal record without recomputing its date.
  - Make `apply` convergent across interruption: neither destination written means write both; operation already exact means write only the goal; both exact means success with no history churn. Any non-identical incumbent or changed input is a refusal. Do not add rollback, a transaction ledger, or a receipt.
  - Extend goal publication so an exact rendered record path is authoritative, an exact published incumbent is preserved, and repeated apply cannot create a second dated goal or append duplicate lifecycle history.
  - Start the harness-managed goal only after both durable project artifacts are confirmed. When the harness exposes no goal feature, return the same exact ready-to-submit objective used by the proven lane without claiming pursuit began. Lazy Checkpoint behavior remains unchanged; Foreman does not create a runtime record before the harness does.
  - Add `operation-write.sh promote --root <dir> --identity foreman/<stem> --expected-digest sha256:<canonical-hex> --expected-file-sha256 <raw-hex> --evidence-file <file> --expected-evidence-sha256 <raw-hex>`. The preview shows the exact evidence, operation identity/digest, and `draft` to `active` transition. After acceptance, the writer re-hashes both the current operation and evidence file, validates the source and children again, and performs `verified-against`, evidence, and `status: active` as one atomic replacement. On success the operation is current and goal-eligible.
  - Promotion must leave the operation byte-for-byte unchanged on stale source, stale raw hash, invalid or changed evidence, failed child validation, interrupted staging, destination replacement failure, or a status other than `draft`. Once the operation is active, goal close does not offer promotion and a direct repeated `promote` invocation refuses without mutation; resume continues to accept that digest-stable active root through the goal marker.
  - Document the attended path: optional catalog suggestions, explicit selection or scratch creation, full candidate resolution, joint preview, one publication acceptance, harness goal run, evidence review, one promotion acceptance. `setup` remains optional.
  - Add sabotage tests for candidate drift after preview, goal drift after preview, manifest edits, identity/date/destination drift, different incumbents, partial publication recovery, duplicate apply, marker mismatch/duplication (including a marker planted on a proven goal), stale resume, initial-launch checkpoint absence, no-goal-feature fallback, promotion source/evidence drift, incomplete verification, child invalidation, foreign ownership, interrupted promotion, and active-root repeat refusal. After selected-template materialization, mutate or remove the global source and prove compilation, resume, verification, and promotion use only the project operation; assert the global bytes are unchanged and no origin path appears in the operation.
  - Red-proof the acceptance guards with temporary script copies. In `goal-start-test.sh`, count and disable exactly the expected-preview-digest guard and prove a planted preview mutation would land. In the promotion tests, separately disable the destination/evidence recheck and the combined atomic replacement and prove the corresponding race or partial-rewrite fixture fails. Every mutation must assert one changed occurrence, restore the copy, and confirm byte identity.

  Verify:

  ```sh
  bash skills/foreman/scripts/tests/run.sh
  bash skills/checkpoint/scripts/tests/run.sh
  bash skills/workstream/scripts/tests/run.sh
  bash scripts/tests/run.sh
  bash skills/skill-builder/scripts/skills-lint.sh .
  .records/records.sh check
  bash -n skills/foreman/scripts/goal-start.sh
  bash -n skills/foreman/scripts/goal-compile.sh
  bash -n skills/foreman/scripts/operation-write.sh
  shellcheck skills/foreman/scripts/goal-start.sh skills/foreman/scripts/goal-compile.sh skills/foreman/scripts/operation-write.sh
  git diff --check
  ```

  Expected: all production sabotage cases refuse before mutation; each temporary guard-disabled variant makes its red-proof test fail; interrupted publication converges; failed or repeated promotion preserves exact bytes; template removal cannot affect materialized operations; Checkpoint and Workstream contracts remain unchanged.

## Done when

- The global Foreman template catalog is metadata-only until explicit selection, safe under missing or hostile global state, and covered by red/green tests without writing to a real home directory.
- Every live project skill-data reader and writer uses `.agents/skilldata`; Workspace has no package, route, pack membership, or compatibility replacement; and the bounded retired-literal census contains only the accepted inert exceptions.
- Skill-builder scaffolding, doctrine, review, and lint teach both project and global `skilldata`, including the exact self-hosting retirement rules.
- `/foreman start` binds a resolved draft operation and provisional goal into one digest-backed acceptance, publishes them convergently, and resumes only when the exact provisional source remains valid.
- Post-run promotion binds evidence and verification into one atomic, digest-rechecked acceptance and leaves no partially promoted operation on failure.
- Grimoire itself contains no generated project skilldata or door blocks; all changed shell passes syntax and ShellCheck; all affected skill suites and root integration are green; `git diff --check` is clean; and unrelated worktree changes remain untouched.

_On completion, before landing, run the host's close-the-books sweep and inspect the final staged diff against all three published records._
