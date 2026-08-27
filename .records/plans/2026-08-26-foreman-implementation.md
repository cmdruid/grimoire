---
doctype: plans
status: published
stage: implemented
schema: contractor/plan@1
tags: [plan, foreman]
---

# Foreman project operations and goal runbooks — Implementation Plan

The tracer is a real project operation that remains directly usable by its publisher, is found and
followed through Foreman, and replaces the legacy procedure finder in one atomic hard cut. Later
slices add brownfield ingestion, curation, learning, composition, goal compilation, and finally the
optional Workstream launch seam. Each slice leaves the repository green and can land independently.

Spec: `→ specs/2026-08-26-foreman-autonomous-workflow-control-plane.md`

## Global Constraints

- **Fresh implementation:** build from the published contract and current library conventions. Do
  not resurrect any architecture or package layout from an earlier Foreman. Historical code is
  archaeology only. In particular, do not inherit the manifest-backed move/delete transactions used
  by schema-upgrade verbs elsewhere in the library: Foreman migration leaves its sources untouched
  and resumes by deterministic re-census.
- **Hard cut:** `operations` is the sole direct-Markdown project-operation kind when Slice 1 lands.
  Remove the retired finder package and vocabulary in that same slice; do not ship aliases, dual
  readers, migration shims, or two catalogs.
- **Knowledge, not runtime:** Foreman owns operations, doctrine, projection, and immutable goal
  runbooks. It never creates mutable run state. Root pursuit uses Checkpoint; stream pursuit uses
  Workstream; one goal never uses both.
- **Publisher independence:** a publisher owns and can directly follow its own operations without
  Foreman. Foreman may index foreign operations, but only writes
  `<agent-workspace>/foreman/{operations,doctrine}/` and its own front-door span. Foreign lifecycle
  changes are returned as bounded requests.
- **Small contract:** keep `foreman/operation@1` at the seven required fields and the standard body
  sections in the spec. Do not add environment, permission, executor, graph-runtime, state, receipt,
  registry, or lock abstractions.
- **Scripts compute facts:** shell helpers validate paths, parse operation structure, compute
  digests, index files, and perform bounded atomic rewrites. The skill prose owns candidate choice,
  session interpretation, recommendations, acceptance, and harness invocation.
- **Brownfield custody:** import keeps the selected native source authoritative. Migrate scans only
  the explicitly named file or directory and makes accepted Foreman-owned drafts authoritative
  within Foreman's catalog. Preview writes nothing; apply never deletes, relocates, or rewrites the
  source, creates no migration record or state file, and emits foreign-owner and host-reference work
  as follow-up rather than performing it.
- **Optional seams:** Journal's staged tool, Checkpoint, Workstream, and the harness goal feature are
  enhancements, never installation floors. Missing capabilities degrade exactly as the spec says.
- **Patient zero:** all project setup, front-door projection, debrief, goal, and Workstream launch
  behavior runs against disposable fixtures. Never deploy a Foreman block or workspace content into
  grimoire's own `AGENTS.md` or `.spaces`.
- **Portability and custody:** shell remains Bash 3.2 compatible. Project-editable files are
  absent-only unless the user explicitly accepts a bounded Foreman-owned update. Preserve unrelated
  worktree and index changes; use explicit pathspecs.
- **Plan gate:** paths and signatures are a snapshot. Re-run Task 0 against the implementation
  worktree's `HEAD` before editing and re-ground any drift before sizing or walking a slice.

## Slices

- [x] **Task 0: re-ground the live migration and integration surface** <requires: —>
  - Files: read-only; no file changes.
  - Change: inspect `git status --short` and the done trail for `skills/shopbook/`,
    `skills/debugger/`, `skills/workspace/`, `skills/workstream/`, and
    `skills/skill-builder/`. Re-run `skills/contractor/scripts/ground-check.sh` against the
    published spec. Inventory the current retired-package references and closed workspace-kind
    vocabulary across `AGENTS.md`, `README.md`, `PACK.md`, `skills/`, `scripts/`, and `crates/`.
    Confirm capability-wide that no current `skills/foreman/` package implements this design.
    Confirm no live helper already provides unknown-schema, zero/one/many operation ingestion; the
    current owner-specific migration verbs move known artifacts with durable manifests and are
    deliberately not the implementation model for Foreman.
    Recheck available SHA-256 tooling, byte-exact incumbent conventions, bounded regular-file
    traversal, binary/generated/vendor/unreadable skip handling, and partial-write fixture hooks
    against `HEAD`; record the portable choice before Slice 2.
    Re-read the exact Workstream `create --seed-only`, `load`, hand-off Queue state, TL;DR, and
    What's next contracts. Record any changed path or signature in the slice notes before editing.
  - Verify: run
    `for suite in skills/shopbook/scripts/tests/run.sh skills/debugger/scripts/tests/run.sh skills/workspace/scripts/tests/run.sh skills/workstream/scripts/tests/run.sh skills/skill-builder/scripts/tests/run.sh scripts/tests/run.sh; do "$suite" || exit 1; done`
    → every baseline suite is green; ground-check reports
    `unresolved_count=0`; `git status --short` is unchanged by Task 0.

  Grounding result (2026-08-26): all six baseline suites passed and the ground check reported
  `unresolved_count=0`. The live tree has no current Foreman implementation or generic unknown-schema
  ingester. Use `/usr/bin/shasum -a 256`; stable newline-safe-enough path ordering over validated
  project-relative names; regular non-symlink traversal with explicit skip facts; `mktemp` + `mv` for
  atomic files; `cmp -s` for byte-identical incumbents; and an environment-injected post-write hook
  for partial-apply fixtures. Existing durable migration manifests are not an implementation model.

- [x] **Slice 1: operation tracer and atomic hard cut** <requires: Task 0>
  - Create `skills/foreman/SKILL.md`, `skills/foreman/verbs/{inventory,run,setup}.md`,
    `skills/foreman/templates/operation.md`, and
    `skills/foreman/scripts/{operation-check,operations-index,foreman-door}.sh`.
    `operation-check.sh` validates the complete `foreman/operation@1` front matter, procedure versus
    workflow body shape, standard sections, imported-source fields, identity references, and cycles.
    It owns the one canonical recursive digest over instruction-bearing front matter and standard
    sections, ordered child identities and operation digests, and imported-source digest while
    excluding `verified-against` and Verification evidence. `operations-index.sh` lists/searches valid direct operation files by
    identity, title, use-when, areas, and tags; reports malformed/stale operations and bounded native
    candidates without treating them as operations. `foreman-door.sh` checks/applies only Foreman's
    pointer-heavy delimited route, including the explicitly authorized minimal-front-door case.
  - Create `skills/foreman/scripts/tests/{lib,operation-check-test,operations-index-test,setup-test,skill-doc-test,run}.sh`.
    The fixtures prove direct lookup, ambiguous and absent results, malformed shape, local procedure
    digest, nested child-digest propagation, imported-source drift, evidence exclusion, no eager body
    loading, native-candidate reporting, incumbent-safe setup, and a bounded route. Include the
    owner-write sentinel here so removing Foreman's namespace guard makes the suite fail.
  - Keep the bundled operation template package-only and declare no deployable Project templates in
    `skills/foreman/SKILL.md`; setup registers the route but never copies the template into a
    consuming project.
  - Move and expand the bundled Debugger diagnostics operation to
    `skills/debugger/operations/diagnostics.md`; modify `skills/debugger/{SKILL.md,verbs/setup.md}`,
    `skills/debugger/scripts/{debugger-setup.sh,tests/setup-test.sh}` so setup deploys the conforming
    active operation and its publisher-owned route, preserves incumbents, and Debugger follows it
    directly without calling Foreman. Pin current verification evidence to the bundled instruction
    digest and test that the deployed copy remains directly readable.
  - Modify `skills/workspace/{SKILL.md,scripts/workspace-check.sh,scripts/tests/workspace-check-test.sh}`
    so `operations` replaces the retired direct-Markdown kind. Modify
    `skills/skill-builder/{docs/DOCTRINE.md,scripts/skills-lint.sh,scripts/tests/lint-workspace-path-test.sh}`
    so portable doctrine, the closed-kind lint, publisher examples, and red-proofs use the same
    contract. Modify `skills/workstream/flow.md` to point its optional project-owned build operation
    at the current kind.
  - Delete the complete `skills/shopbook/` package. Modify `AGENTS.md`, `README.md`, and `PACK.md` to
    list Foreman, describe operations and publisher ownership, remove the retired package and
    vocabulary, and preserve the patient-zero rule. Do not add a deployed Foreman block to the
    library front door.
  - Modify `scripts/tests/install-pack-test.sh` so a fresh pack install contains Foreman, a simulated
    old lock/link is removed on reinstall, and install/check/remove remain free of project setup
    side effects. No `install.sh` or Rust crate change is expected unless Task 0 proves that live
    behavior has moved.
  - Verify: run
    `for suite in skills/foreman/scripts/tests/run.sh skills/debugger/scripts/tests/run.sh skills/workspace/scripts/tests/run.sh skills/workstream/scripts/tests/run.sh skills/skill-builder/scripts/tests/run.sh scripts/tests/run.sh; do "$suite" || exit 1; done`,
    then `skills/skill-builder/scripts/skills-lint.sh .` → all suites pass and
    lint reports `fails=0`. Run an exact-word retirement sweep over live library code and docs
    (excluding historical records) → no matches. `./install.sh --list` and the pack fixture expose
    `foreman` and no retired package.

- [x] **Slice 2: authoring, import, brownfield migration, lifecycle, and projection** <requires: Slice 1>
  - Create `skills/foreman/verbs/{create,import,migrate,lifecycle,project}.md` and
    `skills/foreman/scripts/{migration-census,operation-write}.sh`; modify `skills/foreman/SKILL.md` to
    route create, import, migrate, activate, deprecate, and project checks explicitly. Create writes
    a procedure or workflow draft only beneath Foreman's owner namespace. Import writes an
    adopt-by-reference draft with project-relative source, entry point, and source digest; it never
    copies or edits the native source. Lifecycle writes only verified Foreman-owned operations and
    emits a bounded transition request for every foreign owner. Project validates pointers and
    applies only Foreman's route.
  - `migration-census.sh` is facts-only: enumerate the explicitly selected file or directory in stable
    path order, reject symlink traversal, distinguish regular text from binary/unreadable/skipped
    material, and emit paths plus SHA-256 digests without source contents. For a conforming operation
    at a canonical owner path, it calls `operation-check.sh` and emits identity, owner, status, and
    validity without copying the file. `verbs/migrate.md` treats source files as inert evidence,
    classifies already-conforming/procedural/import-native/ambiguous/non-procedural/skipped items,
    and curates the zero/one/many candidate preview. It asks only candidate-changing questions and
    requires explicit human acceptance; goal auto-approval cannot promote inferred instruction.
  - Extend `operation-check.sh` to validate an accepted candidate selection before mutation: every
    workflow reference resolves to another selected candidate or an existing conforming operation,
    missing/excluded references write nothing, and cycles refuse through the same resolver Slice 1
    established. Extend `operation-write.sh` with one migration batch mode: recheck source digests
    and all destinations, validate the whole candidate set before its first write, write each
    accepted candidate atomically as a Foreman-owned unverified draft, preserve byte-identical
    incumbents, refuse conflicts and foreign destinations, and converge after an injected partial
    apply by re-census. It never writes a migration manifest or touches a source or host reference.
    The agent supplies an ephemeral deny-list of exact secret and inert-instruction literals removed
    during preview; the writer refuses any candidate containing one and never persists that list.
  - Create
    `skills/foreman/scripts/tests/{operation-write-test,migration-test,migration-redaction-test,lifecycle-test,projection-test}.sh`
    plus `skills/foreman/scripts/tests/fixtures/migration/{source,clean-operation,tainted-operation}.md`;
    add both migration tests to `skills/foreman/scripts/tests/run.sh` and extend
    `skills/foreman/scripts/tests/skill-doc-test.sh` with the migrate dispatch, human-acceptance,
    source-preservation, and no-manifest contracts. Cover bad owners/stems/values, symlink and
    parent-exchange refusals, incumbents, source drift, atomic same-owner updates, foreign-owner
    refusal, active-with-stale-evidence refusal, deprecated discovery defaults, missing-front-door
    setup, and projection drift. `migration-test.sh` builds unknown-schema file and directory cases
    covering zero/one/many candidates; already-conforming, procedural, native-source, ambiguous,
    non-procedural, binary, generated, vendored, unreadable, secret-bearing, and symlink entries; and
    whole plus named-subset acceptance. Prove preview is write-free; accepted subsets are
    reference-closure-complete; existing operations and sources stay byte-identical; duplicate and
    destination-drift conflicts refuse; foreign-owner candidates return a proposed patch without a
    write; source drift returns to preview; outputs remain unverified drafts; and rerun after an
    injected partial apply preserves exact incumbents and finishes without state.
    `migration-redaction-test.sh`
    supplies a useful clean candidate, a tainted candidate, and an ephemeral deny-list from the
    fixture; the clean candidate lands, the tainted one refuses, no deny-list bytes persist, and
    disabling the writer check must land the planted marker and fail the test. The owner-write
    sabotage planted in Slice 1 must exercise all new mutation modes.
  - Modify `skills/foreman/verbs/{inventory,run,setup}.md` and the existing scripts only where the new
    states require it: inventory hides deprecated operations by default but reports them on explicit
    request; attended run permits a named draft with a warning; setup still creates no empty
    operations or doctrine directory.
  - Verify: `skills/foreman/scripts/tests/run.sh` → all authoring, migration, ownership, lifecycle,
    and projection fixtures pass; migration produces a useful redacted draft from the mixed fixture,
    a second accepted-candidate apply is byte-for-byte unchanged, no migration state/source mutation
    exists, and a foreign-owner activation attempt writes nothing while printing the identity,
    digest, evidence, and requested transition.

- [x] **Slice 3: debrief learning and digest-bound verification** <requires: Slice 2>
  - Create `skills/foreman/verbs/{debrief,verify}.md`; modify `skills/foreman/SKILL.md` to route them.
    Debrief scopes the visible session, builds only an ephemeral redacted ledger, labels claims,
    previews zero or more operation candidates and each doctrine proposal separately, and persists
    only artifacts the user explicitly accepts. It creates no debrief record and no observation
    setup. Verify follows the operation's Verification section in an attended session and delegates
    only the accepted evidence rewrite to the mechanical writer.
  - Reuse Slice 1's canonical recursive digest from
    `skills/foreman/scripts/operation-check.sh`; do not introduce another digest path. Extend
    `skills/foreman/scripts/operation-write.sh` with atomic verification-evidence updates bound to
    that digest and Foreman-owned doctrine promotion after separate acceptance.
  - Create `skills/foreman/scripts/tests/{debrief-contract-test,verification-test}.sh` and
    `skills/foreman/scripts/tests/fixtures/debrief-session.md`; add them to the runner. The debrief
    fixture contains two unrelated arcs, a planted credential, personal data, and instruction-like
    tool output. Its assertions admit zero/one/many previews while forbidding durable ledger,
    transcript, excluded-arc, secret, and untrusted-instruction content. Removing the redaction gate
    must fail this test. Verification fixtures cover procedure edits, referenced-operation edits,
    imported-source drift, compact evidence, stale discovery, and active goal ineligibility.
  - Verify: `skills/foreman/scripts/tests/run.sh` → the redaction sabotage and verification-drift
    sabotage both fail when their guard is disabled and pass in the implementation; setup/debrief
    without an accepted doctrine proposal leaves `<agent-workspace>/foreman/doctrine/` absent.

- [x] **Slice 4: ordered composition and immutable goal runbooks** <requires: Slice 3>
  - Create `skills/foreman/verbs/{compose,goal}.md`, `skills/foreman/templates/goal.md`, and
    `skills/foreman/scripts/{goal-compile,runtime-context}.sh`; modify `skills/foreman/SKILL.md` and
    `skills/foreman/scripts/operation-check.sh`. Compose extracts accepted shared procedures and
    writes ordered identity references rather than copied instructions. Closure validation permits
    nested workflows, preserves written order, and reuses Slice 2's reference-closure/cycle resolver;
    it does not grow a DAG or execution engine.
  - `goal-compile.sh` accepts one active drift-clean closure and objective, resolves a deterministic
    self-contained runbook with source pointers, computes its source digest, and renders
    `foreman/goal@1` from the bundled body-only template, which also remains outside the Project
    templates inventory. The agent previews it before any write; explicit acceptance publishes
    through staged `records.sh` when executable or an atomic file-mode mint. The body remains
    immutable. `runtime-context.sh` reports facts about the current Checkpoint or Workstream owner
    but never writes either surface.
  - Implement goal create/resume/status/close in `skills/foreman/verbs/goal.md`: invoke or return the
    harness goal objective; ask the calling root session to use ordinary Checkpoint save/resume/done;
    degrade with the specified recovery warning when Checkpoint is unavailable; read stream state
    when already inside Workstream; stop on source drift; archive only through ordinary Journal
    closure when available. Auto-accept only the runbook's bounded delegated decisions and always
    stop for the five excluded decision classes.
  - Create `skills/foreman/scripts/tests/{composition-test,goal-compile-test,goal-routing-test}.sh`
    and add them to the runner. Cover nested ordered closure, missing/cyclic references, duplicate
    extraction, deterministic compilation, immutable body, staged-tool and file modes, no Journal
    floor, source drift on resume, Checkpoint/no-Checkpoint roots, Workstream context, close routing,
    and absence of any Foreman runtime file. Add root-only and stream-only custody fixtures plus a
    simultaneous-state fixture: when the same pursuit exposes both `CHECKPOINT.md` and
    `WORKSTREAM.md`, `runtime-context.sh` refuses before pursuit or mutation. Cycle,
    decision-boundary, and single-runtime-state guards each get the one required sabotage proof;
    disabling the state-exclusivity guard must make the simultaneous-state fixture fail.
  - Modify `skills/skill-builder/docs/DOCTRINE.md` with the narrow optional-composer rule demonstrated
    here: an explicitly invoked composer may call another skill's public procedure, but may not
    reproduce it, write its state, require its installation, or bypass its guards. Modify `PACK.md`
    and `README.md` to document Foreman's Checkpoint and harness-goal seams at the runbook level.
  - Verify: `skills/foreman/scripts/tests/run.sh`,
    `skills/journal/scripts/tests/run.sh`, `skills/checkpoint/scripts/tests/run.sh`,
    `skills/skill-builder/scripts/tests/run.sh`, and
    `skills/skill-builder/scripts/skills-lint.sh .` → all fixtures pass and lint has
    `fails=0`; identical inputs compile byte-identical goal bodies and source digests; no fixture
    contains a Foreman-owned runtime-state file; and dual Checkpoint/Workstream custody refuses while
    either state owner alone succeeds.

- [x] **Slice 5: opt-in Workstream priming and completion audit** <requires: Slice 4>
  - Create `skills/workstream/scripts/workstream-prime.sh` and
    `skills/workstream/scripts/tests/workstream-prime-test.sh`; modify
    `skills/workstream/scripts/tests/{run.sh,artifact-contract-test.sh}` and the Helper scripts
    section of `skills/workstream/SKILL.md`. The generic helper accepts a validated hand-off path,
    source pointer, current-unit sentence, and literal next action; atomically changes only Queue
    state, TL;DR, and What's next; writes the same next-action sentence to the latter two; and never
    knows or invokes Foreman. Fixtures prove malformed/missing sections, wrong source, symlink,
    unrelated-byte preservation, preservation of Queue control lines such as `Parked:`, idempotence,
    and exact three-section mutation.
  - Modify `skills/workstream/{SKILL.md,verbs/create.md,verbs/load.md}` with the narrow root-coordinator
    exception: a coordinator not already driving a stream may seed, prime, and load only the same
    stream in one launch. An existing stream driver may still seed only for a separate session and
    may not use the exception. Ordinary create, load, save, ship, recycle, and close paths perform no
    Foreman checks.
  - Modify `skills/foreman/verbs/goal.md` and
    `skills/foreman/scripts/tests/goal-routing-test.sh` to preflight that the published goal and every
    project-local operation in its closure are committed and reachable from the intended target,
    call Workstream seed-only, invoke the generic prime helper, load that same stream, and then call
    Foreman from inside it. Treat the whole goal as one queue unit; inner operation steps never
    advance or ship the Workstream queue.
  - Modify `PACK.md` and `README.md` with the final optional seam and concise user-facing Foreman
    surface. Re-run a consequence-complete inventory over `AGENTS.md`, `README.md`, `PACK.md`,
    `skills/`, `scripts/`, and `crates/`; remove stale package, workspace-kind, and route references
    from live code and docs without rewriting historical records.
  - Verify: run
    `for suite in skills/foreman/scripts/tests/run.sh skills/debugger/scripts/tests/run.sh skills/workspace/scripts/tests/run.sh skills/workstream/scripts/tests/run.sh skills/skill-builder/scripts/tests/run.sh scripts/tests/run.sh; do "$suite" || exit 1; done`,
    `skills/journal/scripts/tests/run.sh`, `skills/checkpoint/scripts/tests/run.sh`,
    `skills/skill-builder/scripts/skills-lint.sh .`, `shellcheck` over changed
    shell scripts when available, and `git diff --check` → all green and lint `fails=0`. In a fresh
    Git fixture, an uncommitted goal refuses before stream creation; a committed closure seeds,
    primes, loads, and resumes from inside the stream; an already-driving stream cannot take the
    coordinator exception; ordinary Workstream fixtures remain byte-for-byte unchanged. The final
    live-tree retirement sweep and spec-to-plan coverage audit report no unresolved item.

## Coverage Audit

- Operation schema, ownership, direct publisher use, discovery, and hard cut → Slice 1.
- Create/import, unknown-schema file-or-directory migration, closure-complete candidate selection,
  lifecycle, projection, and bounded foreign-owner requests → Slice 2.
- Session debrief, redaction, doctrine acceptance, digest evidence, and drift → Slice 3.
- Reusable decomposition, ordered composition, goal records, delegated decisions, harness pursuit,
  Checkpoint state, resume/status/close, and no-runtime-state invariant → Slice 4.
- Committed-source preflight, generic Workstream priming, same-stream coordinator load, one queue
  unit, final convergence audit, and full gates → Slice 5.

No published-spec requirement is intentionally deferred. The implementation deliberately excludes
sandboxing, permission models, executor adapters, schedules, environment categories, mutable run
records, transcript records, graph execution, and Foreman-owned runtime state.

## Done when

All five slices are landed in order; Foreman is the only cross-owner operation curator; each
publisher's operation remains directly usable; accepted goal runbooks are deterministic and
immutable; brownfield migration converges without changing sources or conforming incumbents;
Checkpoint or Workstream exclusively owns mutable progress; all named package and repository gates
are green; the hard-cut sweep is empty over live code and docs; and the final diff contains no
unrelated project-workspace or front-door changes.

_On completion (before landing), run the host's close-the-books sweep._
