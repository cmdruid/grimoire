---
doctype: plans
status: published
stage: implemented
schema: contractor/plan@1
tags: [plan]
---

# Global skill feedback capture and guided tuning — Implementation Plan

The first slice proves the riskiest path end to end: one agent-authored observation becomes one
validated row in the global store through the sole writer, survives concurrent captures, and can be
read back without touching a project or installed package. Later slices add lifecycle-guided tuning,
the optional global anchor, and finally the project/global feedback boundary and public inventory.
Each slice is independently testable and committable.

Spec: `.records/specs/2026-09-02-global-skill-feedback-capture-and-guided-tuning.md`

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Published contract:** implement the published spec exactly. The related skilldata ADR and broader
  skilldata hard-cut work may move concurrently, but they do not authorize changing this feature's
  fixed global path, TSV schema, command grammar, Backlog classifier, or opt-in anchor semantics.
- **Standalone package:** `skill-feedback` stays outside `clankshop`, works when installed alone, and
  names no sibling skill in its frontmatter or operating prose. Its typed edge is the coarse
  `skill-observation` artifact type. Backlog and the pack describe only the generic home feedback
  channel; neither calls this package or writes its TSV.
- **Global custody:** all durable feedback lives at exactly
  `~/.agents/skilldata/skill-feedback/feedback.tsv`. Production accepts no root override, project
  fallback, legacy probe, or alternate filename. Tests isolate the process home and never touch the
  developer's real `~/.agents`, Grimoire's authored `AGENTS.md`, a consuming project, or installed
  skill bytes.
- **One writer and one row per capture:** `scripts/feedback.sh` is the sole TSV writer. The public
  capture path asks no follow-up question, emits at most one coherent row, and may return one explicit
  skip reason. Agents never edit the TSV directly. Setup reconciles only the data home; anchor is the
  singular global-front-door writer.
- **Path and transaction safety:** physically resolve the user home once; reject symlinked descendant
  components and incompatible entries; preserve existing shared-parent modes and contents; use
  `0700` for newly created parents/owned directory and `0600` for the TSV. Every mutation validates
  after acquiring the bounded-retry lock, writes and validates a same-directory replacement, and
  atomically renames it. Only provider-mediated concurrency is supported.
- **Schema and privacy:** keep the exact `skill-feedback@1` header and field limits from the spec.
  Escape text reversibly, reject control characters, de-identify content before the provider call,
  expose `project_ref` only through the explicit TSV query flag pair, and make resolved-row rationale
  durable. Modes `0700`/`0600` and local-only behavior reduce exposure but are not a secrecy claim.
- **Canonical identity:** compute `content-sha256:` only with the exact
  `grimoire/skill-content@1` grammar. A package-local read-only Python helper may implement that
  grammar so the skill remains independent of the Grimoire executable; when Python or safe package
  traversal is unavailable, capture records `unknown` rather than inventing another digest. Prove
  its byte output against the existing Rust inventory goldens and include executable modes and
  symlink-target bytes.
- **Tuning custody:** installed packages are analysis-only. Apply requires a physically resolved,
  explicitly selected, Git-tracked source package that is not an immutable store entry, followed by
  human acceptance of both dispositions and target. A late target change invalidates the proposal
  and forces complete re-grounding. No tune path commits, publishes, opens issues, or pushes.
- **Anchor boundary:** only `/skill-feedback anchor` and `anchor --remove` may inspect or mutate
  `~/.agents/AGENTS.md`; both preview and confirmation-gate a compare-against-base update. Setup and
  every data verb ignore the front door. Installation/update detects competing routes; removal
  ignores them and deletes only one well-formed owned block. The route is useful only to harnesses
  that load that global file and is never required for capture.
- **Project/global classifier:** preserve Backlog's `feedback` stem, table, IDs, provider API, history,
  and incumbent `.trackers/DEBRIEF.md`. Change only its default title, default prompt, and hard runtime
  subject boundary: remedies owned by a reusable skill return as a skill-tagged byproduct; remedies
  owned by the repository may enter project feedback. Project defects and work keep their existing
  issue/task/routine routes.
- **Red proofs:** every new absence, refusal, privacy, path, transaction, registration, and ownership
  guard must first fail against one deliberately broken fixture whose mutation count is asserted,
  then pass after byte-identical restoration. Never plant a mutation in live package or user data.
- **Coexisting work:** re-establish status before every slice and preserve all unrelated tracked and
  untracked changes. If concurrent work changes a path or doctrine assumption used here, stop and
  reconcile the published contracts rather than choosing a winner during implementation. Do not
  patch another owner's surface or weaken a gate to absorb an unrelated failure.

## Task 0 — Re-ground before editing

- [x] Re-read the published spec, root `AGENTS.md`, current
  `skills/skill-builder/docs/DOCTRINE.md`, `README.md`, `PACK.md`, the complete Backlog package, and
  the root integration tests. Run Contractor's ground check and record `HEAD`, branch, and complete
  status before touching a file. The planned future `skills/skill-feedback/scripts/feedback.sh`
  reference is expected to be unresolved before Slice 1; any other unresolved live reference is a
  blocker.
- [x] Search capability-wide before creating code. Re-read canonical skill-content hashing in
  `crates/grimoire-pack/src/inventory/digest.rs` and its tracer/content-digest tests; global and
  project anchor classifiers/helpers; TSV escaping and lifecycle patterns in Backlog; and current
  permission/atomic-write helpers. Reuse algorithms and test shapes, not sibling runtime code.
- [x] Repeat the live feedback census over `README.md`, `PACK.md`, Backlog's suggestion, catalog,
  debrief prose, and root tests. Classify every hit as project feedback, reusable-skill feedback,
  historical evidence, or a negative fixture. Re-measure the outside-pack count and record the
  pre-change Backlog assertion total as the Slice 4 baseline rather than copying this plan's
  snapshot.
- [x] Run the current gates. Any Backlog, repository-integration, or skill-lint failure is a blocker:
  diagnose it before sizing edits and leave failures owned by another surface with that owner. Record
  existing warnings so each slice can distinguish an introduced warning from the live baseline.

Verification:

```sh
skills/contractor/scripts/ground-check.sh <root> \
  .records/specs/2026-09-02-global-skill-feedback-capture-and-guided-tuning.md
git status --short
bash skills/backlog/scripts/tests/run.sh
bash scripts/tests/run.sh
bash skills/skill-builder/scripts/skills-lint.sh .
```

Expected: only the planned new provider path is unresolved before Slice 1; Backlog and repository
integration are green; the complete coexisting path set is recorded; and lint reports `fails=0`
with its current warnings recorded.

## Slices

- [x] **Slice 1: Capture one safe global feedback row — tracer** <requires: Task 0>
  - Files:
    - Create `skills/skill-feedback/SKILL.md`, `skills/skill-feedback/verbs/capture.md`,
      `skills/skill-feedback/verbs/setup.md`, and `skills/skill-feedback/verbs/query.md`.
    - Create `skills/skill-feedback/scripts/feedback.sh` and
      `skills/skill-feedback/scripts/skill-content-ref.py`.
    - Create `skills/skill-feedback/scripts/tests/lib.sh`,
      `skills/skill-feedback/scripts/tests/provider-test.sh`,
      `skills/skill-feedback/scripts/tests/concurrency-test.sh`,
      `skills/skill-feedback/scripts/tests/skill-content-ref-test.sh`,
      `skills/skill-feedback/scripts/tests/capture-contract-test.sh`,
      `skills/skill-feedback/scripts/tests/boundary-test.sh`, and
      `skills/skill-feedback/scripts/tests/run.sh`.
    - Create `skills/skill-feedback/scripts/tests/fixtures/capture-cases.tsv` for the grounded
      friction, gap, preservation-win, new-skill, skip, and de-identification matrix.
  - Change:
    - Start with a failing tracer fixture: set a temporary physical home, invoke the capture procedure
      for one concrete observation, make one `feedback.sh capture` call, then query the result and
      prove the exact header, modes, ID shape, timestamps, escaped fields, open lifecycle fields,
      silent project boundary, and terse `captured=<id>` / `count=1` response. The product scripts
      must never accept a test-only root argument; tests isolate `HOME` at the process boundary.
    - Implement a thin self-contained router whose bare form and named-skill form dispatch to
      capture. Its description routes only its own job. Capture applies the five-part change,
      incident, consequence, candidate-response, and privacy rubric; chooses exactly one coherent
      observation; returns the two specified skip reasons without questions; and never stores raw
      caller text before structuring and de-identifying it. Inside a project, hash the physically
      resolved project root to the specified 16-hex local reference without storing its path; outside
      a project, pass an empty reference. Setup invokes provider `init`; query uses only provider
      output and applies the documented newest-open defaults.
    - Implement the capture-side `feedback.sh` data API—`describe`, `init`, `capture`, and `query`—
      against the final TSV schema, including empty open lifecycle columns. Enforce exact arguments
      and output, whole-file validation, limits, enums, escaping, and row-size bounds. Unknown usage
      must not initialize the store. Slice 2 adds the resolution command without changing the file
      schema or these commands.
    - Implement physical-home and descendant checks before every creation or replacement. Create
      absent shared parents without claiming existing-parent modes, own only `skill-feedback/`, use a
      restrictive umask, and reject symlink or incompatible components. Lock with atomic directory
      creation and a five-second bounded retry; generate/collision-check IDs under lock; validate the
      incumbent after acquisition; write, validate, close, and atomically rename one same-directory
      replacement; and clean up only the operation's own lock/temp paths. Setup removes a stranded
      lock only after parsing its PID and conclusively proving that process absent; a live,
      malformed, permission-denied, or otherwise ambiguous owner remains untouched.
    - Implement `skill-content-ref.py` as a read-only fact helper over one safe skill directory. Hash
      the exact schema prefix, entry kind, raw relative path bytes, normalized mode, and file or
      symlink-target bytes with unsigned 64-bit big-endian lengths. Never follow links or read outside
      the package. Emit a canonical reference or one explicit unavailable fact; capture maps
      unavailable to `unknown`. Cross-check byte goldens with
      `crates/grimoire-pack/src/inventory/tests/tracer.rs` and prove unrelated repository commits do
      not alter a skill reference.
    - Exercise at least 20 real concurrent provider writers, a deliberately live five-second lock,
      stale and ambiguous locks, delayed acquisition preserving an earlier row, ID collision reroll,
      interruption before rename, malformed incumbents, unsafe paths, permission tightening, every
      encoding/control/length boundary, both query formats, and project-ref suppression. Red-prove
      each guard in copied fixtures.
    - Treat the capture-case table as a prompt contract: every row names input context, expected
      capture/skip, kind, and required privacy outcome. The implementing agent walks the cases against
      `verbs/capture.md`; the deterministic test asserts that each decision arm and example remains
      represented and red-proves removal of one rubric clause. No product or test script calls a
      networked model.
    - In `boundary-test.sh`, run every data command with temporary-home canaries and fake network
      executables on `PATH`; prove writes stay below the owned global directory, no network program
      is invoked, installed-package and project canaries remain byte-identical, and
      `~/.agents/FEEDBACK.md` is neither read nor migrated. Red-prove both the network and escaped-write
      detectors with one counted fixture mutation apiece.
  - Verify:

    ```sh
    bash skills/skill-feedback/scripts/tests/run.sh
    shellcheck -S warning skills/skill-feedback/scripts/feedback.sh \
      skills/skill-feedback/scripts/tests/*.sh
    bash skills/skill-builder/scripts/skills-lint.sh .
    git diff --check
    ```

    Expected: the isolated-home tracer captures and queries one valid row; provider, concurrency,
    identity, and prompt-contract suites pass; all red proofs have been observed and restored; no
    project, installed package, real home, or front door changes; lint adds no failure or warning.
    Commit this standalone capture surface independently.

- [x] **Slice 2: Revalidate and disposition one bounded tuning batch** <requires: Slice 1>
  - Files:
    - Create `skills/skill-feedback/verbs/tune.md` and
      `skills/skill-feedback/scripts/source-custody.sh`.
    - Create `skills/skill-feedback/scripts/tests/source-custody-test.sh` and
      `skills/skill-feedback/scripts/tests/tune-contract-test.sh`.
    - Modify `skills/skill-feedback/SKILL.md`, `skills/skill-feedback/scripts/feedback.sh`,
      `skills/skill-feedback/scripts/tests/provider-test.sh`, and
      `skills/skill-feedback/scripts/tests/run.sh`.
  - Change:
    - Extend the router and typed edges so `tune` consumes the same `skill-observation` state that
      capture produces. Select one stable oldest-open page of at most 100 exact-skill rows and retain
      its IDs for the pass; never treat rows as accepted requirements or resolve unsupported evidence.
    - Add heterogeneous
      `feedback.sh resolve --entry ID DISPOSITION RESOLUTION RESULT_REF [--entry ...]` against the
      schema established in Slice 1. Every entry consumes exactly four arguments; dispositions that
      do not require a result reference pass an empty quoted fourth argument. Enforce result-reference
      rules, exact idempotent repeats, duplicate-ID refusal, conflicting re-resolution refusal, and
      all-or-nothing batch lifecycle updates while preserving every non-lifecycle field. Red-prove
      the resolution guards before tuning consumes the command.
    - Implement `source-custody.sh` as a read-only fact source for the named skill, installed package,
      and explicit candidate. Resolve paths physically; verify the candidate's matching `SKILL.md`,
      Git worktree, and tracked file; and compare it with the installed entry and real target. Resolve
      the Grimoire home from a nonempty absolute `GRIMOIRE_HOME`, otherwise from the physical user home
      plus `.grimoire`, following the published package-manager path contract. Classify a physically
      resolved candidate contained beneath that home's `store/checkouts/` component boundary as
      `immutable=yes` and refuse it; lexical lookalikes outside that boundary are `immutable=no`. An
      absent manager home or store is also `immutable=no`. If the relevant paths cannot be inspected
      safely or the containment result is inconclusive, report `immutable=unknown` rather than
      inferring custody from writability, symlink shape, Git ancestry, or a generic directory name.
      Emit facts only—the tune procedure owns the decision and human confirmation.
    - In `tune.md`, analyze the installed package only when no source candidate exists. For apply,
      require the gated explicit source with `immutable=no`; an `immutable=unknown` candidate remains
      analysis-only and returns an actionable custody refusal. Compare the candidate's canonical
      reference with every row; inspect relevant history; grep before generalizing; cluster repeated
      incidents; and classify current, already-addressed, stale, project-specific, false,
      preservation, and new-skill evidence. A candidate supplied or changed after preview forces the
      source gate, complete re-grounding, and a replacement proposal.
    - Present per-ID dispositions, rationale, result references, exact source target, and the smallest
      coherent package change before editing. Human acceptance authorizes only that package. Apply
      through the source library's doctrine and gates, never through an installation path. If editing
      or verification fails, leave every affected row open; after success, send one heterogeneous
      atomic `resolve` request for the accepted batch. Do not commit or publish.
    - Test all dispositions, repeated evidence, matching/changed/unknown references, unsupported rows,
      tracked and untracked candidates, direct installed paths, live symlink targets, writable and
      read-only copies, an explicit temporary Grimoire home, immutable descendants, symlinks into the
      immutable store, component-boundary lookalikes, absent manager/store roots, and unavailable or
      inconclusive metadata. Assert that `unknown` permits analysis but refuses apply without mutation.
      Also cover late target changes, rejected proposals, edit failure, gate failure, atomic lifecycle
      success, and exact preservation of non-lifecycle fields. Red-prove that removing re-grounding or
      source confirmation makes the contract suite fail.
  - Verify:

    ```sh
    bash skills/skill-feedback/scripts/tests/provider-test.sh
    bash skills/skill-feedback/scripts/tests/source-custody-test.sh
    bash skills/skill-feedback/scripts/tests/tune-contract-test.sh
    bash skills/skill-feedback/scripts/tests/run.sh
    shellcheck -S warning skills/skill-feedback/scripts/*.sh \
      skills/skill-feedback/scripts/tests/*.sh
    bash skills/skill-builder/scripts/skills-lint.sh .
    git diff --check
    ```

    Expected: analysis can proceed without a source but cannot offer apply; every accepted source is
    explicit and re-grounded; installations remain byte-identical; heterogeneous lifecycle updates
    are atomic and post-verification only; lint adds no failure or warning. Commit the tuning path
    independently.

- [x] **Slice 3: Install and remove the optional global anchor** <requires: Slice 2>
  - Files:
    - Create `skills/skill-feedback/verbs/anchor.md`,
      `skills/skill-feedback/scripts/feedback-anchor.sh`,
      `skills/skill-feedback/templates/agents-route.md`, and
      `skills/skill-feedback/scripts/tests/anchor-test.sh`.
    - Modify `skills/skill-feedback/SKILL.md` and
      `skills/skill-feedback/scripts/tests/run.sh`.
  - Change:
    - Add only `anchor [--remove]`; setup must remain data-only. Validate the package template and
      current global file structurally, ignoring headings and marker-like text inside Markdown code
      fences. Physically resolve the home, reject symlinked/incompatible descendants, and create an
      absent `.agents/` parent only during confirmed apply.
    - Render the exact owned `skill:skill-feedback` block under
      `## Skill routes (self-registered)`. Derive `built-against` from the path-scoped Git log, then
      package version, then the fixed v0 date. Preview returns the full diff and base SHA; confirmed
      apply repeats preflight and refuses if the base identity changed. Absent appends, current is a
      no-op, and a valid drifted block replaces only owned bytes.
    - Before installation/update, have the agent inspect outside prose for an active competing
      reusable-skill feedback route and stop for a human cutover choice. `--remove` bypasses that
      semantic conflict scan, previews deletion, and removes only one well-formed owned block while
      retaining the shared heading and all surrounding bytes. Absent removal is a no-op; malformed
      ownership or concurrent edits refuse. Neither path touches feedback data.
    - Test missing/current/drifted/malformed/duplicate/inverted blocks, fenced examples, reserved
      section arrangement, unsafe targets, absent parent creation, path-scoped stamp changes,
      conflicting outside routes, removal in the presence of such a route, base-SHA races, exact
      surrounding-byte preservation, and no-op idempotence. A fixture containing both the untouched
      legacy `~/.agents/FEEDBACK.md` and a competing global route must prove no import or rewrite.
      Use temporary homes exclusively. Add a cold-route contract fixture proving all four qualifying
      kinds invoke capture once, ordinary success stays silent, and `skill-feedback` cannot recurse.
      Red-prove every absence and refusal guard.
  - Verify:

    ```sh
    bash skills/skill-feedback/scripts/tests/anchor-test.sh
    bash skills/skill-feedback/scripts/tests/run.sh
    shellcheck -S warning skills/skill-feedback/scripts/feedback-anchor.sh \
      skills/skill-feedback/scripts/tests/anchor-test.sh
    bash skills/skill-builder/scripts/skills-lint.sh .
    git diff --check
    ```

    Expected: add/update/remove previews are deterministic and confirmation-gated; a concurrent edit
    or unsafe target leaves the file unchanged; removal remains available beside a competing route;
    all real front doors and data remain untouched. Commit this anchor surface independently after
    the Slice 2 router and test-runner changes are present.

- [x] **Slice 4: Enforce the project/global feedback boundary and publish inventory** <requires: Slice 3>
  - Files:
    - Modify `skills/backlog/suggestions/feedback.md`,
      `skills/backlog/scripts/backlog-setup.sh`, `skills/backlog/verbs/debrief.md`, and
      `skills/backlog/SKILL.md`.
    - Modify `skills/backlog/scripts/tests/deploy-test.sh`,
      `skills/backlog/scripts/tests/setup-resume-test.sh`,
      `skills/backlog/scripts/tests/debrief-contract-test.sh`, and
      `skills/backlog/scripts/tests/skill-doc-test.sh`.
    - Modify `README.md`, `PACK.md`, `scripts/tests/configure-clankshop-test.sh`, and
      `scripts/tests/clankshop-contract-test.sh`.
    - Modify `skills/skill-feedback/scripts/tests/run.sh` only if its final package-inventory test is
      not already wired. Do not modify root `AGENTS.md`, Backlog's tracker provider/schema/history,
      existing project tracker files, or the `clankshop` manifest member lists.
  - Change:
    - Change the packaged suggestion and setup catalog to the exact title `Project Feedback` and exact
      use-when sentence `Development-experience observations whose remedy belongs in this project.`
      Keep the `feedback` stem. New setup prompts receive matching prose; initialized customized
      `.trackers/DEBRIEF.md` files remain byte-identical.
    - Put the remedy-owner cut in Backlog's non-overridable debrief procedure before the editable
      prompt: repository-owned development friction may file to project feedback; reusable installed
      skill feedback never enters `.trackers` and returns to the custodial caller as a skill-tagged
      byproduct; project defects/work/routines retain their current routes. Extend the deterministic
      debrief contract matrix and red-prove removal of this subject cut.
    - Update `PACK.md` composition and delegated-byproduct example to qualify feedback as
      project-owned and return reusable-skill observations separately for their home channel. The
      pack must not require, call, or list `skill-feedback`, name its global path, or write its state.
      Update the disposable configuration fixture to match that policy and prove there is still no
      direct Delegate-to-global-feedback writer.
    - Update `README.md` from four to five outside-pack skills, add the `skill-feedback` inventory row,
      keep it absent from `clankshop`, and update the contributing-feedback paragraph so GitHub issues
      remain the library default while the optional local skill is discoverable. Add root contract
      assertions for the count, row, pack exclusion, patient-zero `AGENTS.md` absence, and generic
      Backlog/pack wording; red-prove each new guard in a disposable copy.
    - Before these edits, require the complete Backlog suite to pass with the pre-change assertion
      total recorded in Task 0. After adding the focused guards, run the complete expanded suite and
      account for its assertion-total increase rather than expecting the old fixed count. Prove setup
      catalog, new prompt bytes, incumbent prompt preservation, installed-skill byproduct routing,
      equivalent project-owned filing, unchanged tracker IDs/history/schema, and no migration. Run
      the standalone skill, root integration, and lint gates after reconciling any concurrent Skill
      Builder hard-cut changes.
  - Verify:

    ```sh
    bash skills/backlog/scripts/tests/debrief-contract-test.sh
    bash skills/backlog/scripts/tests/deploy-test.sh
    bash skills/backlog/scripts/tests/skill-doc-test.sh
    bash skills/backlog/scripts/tests/run.sh
    bash skills/skill-feedback/scripts/tests/run.sh
    bash scripts/tests/run.sh
    bash skills/skill-builder/scripts/skills-lint.sh .
    git diff --check
    ```

    Expected: every focused and aggregate suite exits zero; lint reports `fails=0` with no new
    warning; README says five and lists the standalone skill; the pack manifest excludes it; Backlog
    files only project-owned feedback and returns reusable-skill observations; no real front door,
    project tracker data, global feedback data, or unrelated coexisting path changes.

## Done when

- `skills/skill-feedback/` is a self-contained, lint-clean package implementing one-call capture,
  guarded global storage, query, guided tuning, and reversible opt-in anchoring exactly as specified.
- All provider, identity, concurrency, prompt-contract, source-custody, tuning, and anchor suites pass
  against temporary homes, with every required safety guard red-proved and restored.
- Backlog's `feedback` queue is visibly and operationally project-owned without a stem/schema/history
  migration, and its full suite plus repository integration remain green.
- `README.md` inventories five outside-pack skills, `PACK.md` describes the generic boundary while
  excluding `skill-feedback`, root `AGENTS.md` remains authored library doctrine, and no test or setup
  touches the developer's actual global files.
- `bash skills/skill-builder/scripts/skills-lint.sh .` reports `fails=0`, all relevant shell scripts
  pass `shellcheck -S warning`, `git diff --check` is clean, and a final status/diff audit proves the
  implementation changed only the approved feature paths while preserving concurrent user work.

_On completion (before landing), run the host's close-the-books sweep._
