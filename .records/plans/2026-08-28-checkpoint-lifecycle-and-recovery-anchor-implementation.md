---
doctype: plans
status: published
stage: implemented
schema: contractor/plan@1
tags: [plan]
---

# Checkpoint lifecycle and recovery anchor — Implementation Plan

The tracer starts with the only new destructive path: a body-free foreign-occupancy probe followed
by a fingerprint-gated atomic replacement. The second slice reconciles the complete runtime contract
and hard-cuts `done` to `close`. The final slice projects that settled contract through the version-2
anchor with v2-only classification, generic bounded-conflict replacement, and unsafe-collision
refusal. Each slice is independently testable and committable.

Spec: → specs/2026-08-28-checkpoint-lifecycle-and-recovery-anchor.md

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Design authority:** implement the published spec above. The published
  `.records/specs/2026-08-27-single-root-checkpoint.md` remains authoritative only for the
  single-root, ignore, identity, transaction, Workstream-exclusion, and unchanged hard-cut rules
  that the new spec retains.
- **Meaning of automatic:** lifecycle refresh is agent instruction after explicit enrollment. Do
  not add a daemon, hook, watcher, automatic first save, or presence-driven runtime.
- **Patient zero:** never create grimoire's root `CHECKPOINT.md`, install an anchor into its real
  `AGENTS.md`, edit committed ignore rules, or exercise mutations outside throwaway fixtures.
- **Custody and disclosure:** path presence is never ownership. Foreign probing emits no body or
  token. Refresh, overwrite, claim, Recovery, and Close keep their respective handle/fingerprint
  gates and revalidate inside the mutation transaction.
- **Closure neutrality:** Checkpoint never infers completion, describes a checkpoint as ready to
  close, suggests closure, or synthesizes a closure-oriented next action. Enrollment ends only on
  explicit `/checkpoint close`; `/checkpoint done` has no alias or compatibility route.
- **Anchor hard cut:** only the exact version-2 block is current. A safely marker-bounded non-v2
  unit is an opaque `conflict`, never a recognized version or migration source. Unmarked headings
  and ambiguous boundaries refuse without an automated replacement offer.
- **Portable skill doctrine:** scripts compute facts and agents decide; keep package references
  relative to the Checkpoint skill; remain Bash 3.2 compatible; avoid GNU-only regular expressions
  such as `\b`; prove every new guard or absence assertion red on a controlled copy before trusting
  its green result.
- **Workstream boundary:** Workstream keeps its own file, custody, save seams, and read-only Recovery
  overlay. It must not acquire Checkpoint's token, root file, overwrite, Close, or anchor semantics.
- **Coexisting work:** the worktree contains broad unrelated user-owned changes, including overlaps
  in `README.md` and Workstream surfaces. Patch only the named Checkpoint roster line in `README.md`;
  treat Workstream production prose as verify-only. Preserve every pre-existing unrelated hunk. If
  Task 0 finds load-bearing drift or an overlap that this plan cannot isolate exactly, stop and
  revise the plan before editing; never absorb the drift by silently widening a slice.
- **Baseline snapshot:** at `main` / `b76aa11`, Checkpoint has 181 passing assertions, Workstream has
  216, skill lint reports `fails=0 warns=4`, both Contractor and Inspector ground checks resolve all
  13 spec references, and scoped `git diff --check` is clean. This is orientation, not authority;
  re-run it before editing.

## Slices

- [x] **Task 0: Re-ground the plan against the live tree** <requires: —>
  - Files (read-only):
    `.records/specs/2026-08-28-checkpoint-lifecycle-and-recovery-anchor.md`,
    `.records/specs/2026-08-27-single-root-checkpoint.md`, `README.md`, `skills/checkpoint/`,
    `skills/workstream/flow.md`, `skills/workstream/templates/workstream-handoff.md`,
    `skills/workstream/scripts/tests/artifact-contract-test.sh`,
    `skills/skill-builder/docs/DOCTRINE.md`.
  - Change: write nothing. Confirm the governing spec is still `status: published`; inspect scoped
    status and diffs; re-run capability-wide searches for foreign-checkpoint replacement, lifecycle
    enrollment, the version-2 marker family and obsolete classifier states, and `done`/`close`;
    re-read the helper command dispatch and test overrides rather than trusting this plan's line
    numbers. Attribute every overlap before editing. Expected pre-implementation behavior belongs
    to its named slice; any other load-bearing drift, changed target shape, or inseparable user hunk
    fails Task 0. Stop without production edits and revise this plan rather than expanding scope.
  - Verify:
    - `skills/contractor/scripts/ground-check.sh /Users/cscott/Repos/grimoire .records/specs/2026-08-28-checkpoint-lifecycle-and-recovery-anchor.md` → `unresolved_count=0`.
    - `skills/checkpoint/scripts/tests/run.sh` → all suites green.
    - `skills/workstream/scripts/tests/run.sh` → all suites green.
    - `skills/skill-builder/scripts/skills-lint.sh` → `fails=0`; record, but do not silently absorb,
      any warning drift from the four-warning baseline.
    - `git diff --check -- README.md skills/checkpoint skills/workstream` → no output.

- [x] **Slice 1: Guarded foreign-occupancy replacement — the tracer** <requires: Task 0>
  - Files:
    - Modify `skills/checkpoint/scripts/checkpoint-file.sh`.
    - Modify `skills/checkpoint/verbs/save.md`.
    - Modify `skills/checkpoint/scripts/tests/checkpoint-file-test.sh`.
    - Modify `skills/checkpoint/scripts/tests/skill-doc-test.sh`.
  - Change:
    - Add the internal helper command `occupancy <root>`. It runs the existing root, Workstream,
      Git-read, lock, target-shape, and identity validators without emitting the checkpoint token or
      body. A valid incumbent emits exactly `checkpoint_occupancy=valid` and one opaque
      `checkpoint_fingerprint=<64-lowercase-hex>` fact. Absence, malformed identity, tracked or
      unignored state, symlink/non-regular shape, stream custody, or helper failure emits no private
      checkpoint bytes and returns nonzero.
    - Add `overwrite <root> <expected-fingerprint>`, taking the complete replacement document on
      standard input. Under the mutation lock it re-runs the Workstream and Git mutation guards,
      requires the incumbent to remain a valid managed file with the expected fingerprint, renders
      to the fixed sibling temporary path, validates the candidate's exact title/token shape,
      requires its new token to differ from the incumbent token, then revalidates incumbent identity
      and fingerprint immediately before atomic publication. It leaves no backup, emits the same
      path/token/stable-handle facts as Save, and preserves the incumbent on every refusal.
    - Rewrite Save's ownership branch precisely: absent target creates normally; one exact current
      handle that matches refreshes normally; a presented exact-root handle that fails matching
      stops as an ownership mismatch; an explicit Save with no matching handle probes occupancy and,
      only for `valid`, stops to tell the user the singleton is occupied and offer overwrite.
      Rejection performs no mutation. Confirmation retains the probe fingerprint, synthesizes a
      complete body with a fresh token, and calls `overwrite`. Unsafe or malformed occupancy refuses
      without offering replacement.
    - Give `skill-doc-test.sh` an absolute `CHECKPOINT_SKILL_UNDER_TEST` override before the first
      behavioral prose change. Assert that explicit Save offers overwrite only after a valid
      body-free occupancy probe, rejection is non-mutating, confirmation synthesizes a fresh-token
      document and calls the guarded `overwrite` command, and unsafe or malformed occupancy refuses
      without an offer. The controlled-copy override must cover both positive and negative branches.
    - Extend fixtures for body/token-free valid probing, malformed/unsafe non-offers, byte-identical
      rejection, confirmed replacement with a distinct token, no backup/temp residue, and a target
      changed between probe and publication. Reuse the current FIFO race pattern for the final
      revalidation arm.
  - Verify:
    - Red first: add the helper fixtures and Save documentation assertions before the implementation;
      `bash skills/checkpoint/scripts/tests/checkpoint-file-test.sh` and
      `bash skills/checkpoint/scripts/tests/skill-doc-test.sh` → nonzero for their new behavior.
    - Guard red-proof: copy the completed helper to a temporary path, remove exactly the
      post-candidate fingerprint revalidation (assert one removal), run the race fixture with
      `FILE_SH=<temporary-helper>` → nonzero, then discard the copy and confirm the source helper is
      byte-identical to its pre-proof state.
    - Documentation red-proof: copy the completed Checkpoint skill to a temporary directory, remove
      exactly the valid-only overwrite-offer guard from the controlled Save copy (assert one
      removal), run `CHECKPOINT_SKILL_UNDER_TEST=<temporary-skill> bash
      skills/checkpoint/scripts/tests/skill-doc-test.sh` → nonzero, then discard the copy and rerun
      green.
    - `bash skills/checkpoint/scripts/tests/checkpoint-file-test.sh` → all assertions green.
    - `bash skills/checkpoint/scripts/tests/skill-doc-test.sh` → all assertions green.
    - `shellcheck -S warning skills/checkpoint/scripts/checkpoint-file.sh skills/checkpoint/scripts/tests/checkpoint-file-test.sh skills/checkpoint/scripts/tests/skill-doc-test.sh` → no warning-or-higher diagnostics.

- [x] **Slice 2: Explicit enrollment, one-command recovery, and the Close hard cut** <requires: 1>
  - Files:
    - Modify `skills/checkpoint/SKILL.md`.
    - Modify `skills/checkpoint/references/disciplines.md`.
    - Modify `skills/checkpoint/verbs/save.md`.
    - Modify `skills/checkpoint/verbs/resume.md`.
    - Move the former closure verb file to `skills/checkpoint/verbs/close.md` and rewrite its public
      verb wording without changing the guarded `delete` helper transaction.
    - Modify `skills/checkpoint/scripts/tests/skill-doc-test.sh`.
    - Modify only the Checkpoint roster row in `README.md`.
    - Modify `skills/workstream/scripts/tests/artifact-contract-test.sh`; treat
      `skills/workstream/flow.md` and `skills/workstream/templates/workstream-handoff.md` as
      verify-only inputs.
  - Change:
    - Make successful explicit Save, successful one-command Resume, and admitted exact-token
      Recovery the only enrollment events. Remove maintain-style activation and automatic first-save
      wording. After enrollment, refresh only before a healthy reset, after a human-visible work
      unit, and on a context-pressure warning; every successful refresh reports the stable handle
      and next action without asking. Missing current handle is inert; a presented root handle that
      no longer matches stops visibly; polluted context resets without saving.
    - Change explicit Resume to inspect, fully reconcile, fingerprint-claim, rotate the token, report
      the new handle/action, and continue in the same invocation. There is no second confirmation.
      If the continuation is genuinely ambiguous, ask only after custody is safe. Report stale or
      already-landed facts neutrally and remain enrolled.
    - Change automatic Recovery admission so no handle or a wrong-root handle causes no Checkpoint
      read, prompt, facts-gather, write, or user-visible semantics. One exact-root handle uses the
      existing single-read admission. A matching token reconciles read-only, preserves/reports the
      token and action, and continues when KNOWN. Once an exact-root handle affiliates the session,
      token or identity mismatch stops without body disclosure and reports Recovery failure.
    - Recast the exported disciplines: Save remains explicit; Lifecycle begins only after an
      owner-defined enrollment/creation event and retains the three numbered moments; Resume leaves
      claim authorization to the owner rather than mandating another confirmation; Recovery removes
      write-back and landed-to-close routing. Remove `forgotten close` and every completion heuristic.
    - Hard-cut the router, description, prose, and file from `done` to `close`. `close` remains
      argument-free, requires the exact current handle, checks the durable trail, confirms before
      abandoning dirty/unlanded work, calls `delete`, and reports the exact removed path. Delete the
      old verb file; add no alias, redirect, natural-language completion shortcut, or compatibility
      fixture. Update the README roster narrowly while preserving its unrelated edits.
    - Extend the `CHECKPOINT_SKILL_UNDER_TEST` contract established in Slice 1. Assert the three
      enrollment events, no automatic first save, one-command Resume, quiet no-handle Recovery,
      visible exact-root mismatch, read-only Recovery, closure neutrality, Close dispatch/file, and
      absence of every Done route. In Workstream's existing artifact contract, assert that its own
      explicit creation/save seams and no-Recovery-writeback text remain locally complete and that
      root token/Close semantics did not leak into the hand-off.
  - Verify:
    - Red first: run the expanded documentation contracts against the pre-change package → nonzero.
    - Absence red-proof: copy the completed Checkpoint skill to a temporary directory, plant exactly
      one `done` dispatch/file reference and one landed-to-close sentence (count both plants), run
      `CHECKPOINT_SKILL_UNDER_TEST=<temporary-skill> bash skills/checkpoint/scripts/tests/skill-doc-test.sh`
      → nonzero, then discard the copy and rerun green.
    - `bash skills/checkpoint/scripts/tests/skill-doc-test.sh` → green.
    - `bash skills/workstream/scripts/tests/artifact-contract-test.sh` → green.
    - `test -f skills/checkpoint/verbs/close.md` and a shell absence check for the former verb
      filename → both true.
    - `rg -n '/checkpoint done|verbs/done\.md|\| `done` \|' skills/checkpoint README.md` → no output.
    - `skills/checkpoint/scripts/tests/run.sh` and `skills/workstream/scripts/tests/run.sh` → green.

- [x] **Slice 3: Version-2 lifecycle and Recovery anchor** <requires: 2>
  - Files:
    - Modify `skills/checkpoint/templates/recovery-anchor.md`.
    - Modify `skills/checkpoint/scripts/anchor-status.sh`.
    - Modify `skills/checkpoint/verbs/anchor.md`.
    - Modify `skills/checkpoint/verbs/save.md`.
    - Modify `skills/checkpoint/scripts/tests/anchor-test.sh`.
    - Modify `skills/checkpoint/scripts/tests/skill-doc-test.sh`.
  - Change:
    - Replace the package-only template byte-for-byte with the published spec's exact
      `<!-- checkpoint:recovery-anchor@2 -->` block and
      `## Checkpoint lifecycle and recovery` heading. Keep it locally complete: explicit enrollment,
      the three refresh moments, stable-handle/action reporting, polluted-context rollback, no
      completion inference or closure suggestion, quiet no-handle sessions, exact-token Recovery,
      read-only reconciliation, and visible exact-root mismatch.
    - Replace the classifier with the published four-result grammar. The reserved begin family is
      one complete `<!-- checkpoint:recovery-anchor@<opaque-suffix> -->` line; only exact `@2` is
      current, the reserved end marker is exact, and any structural H2 whose text begins with
      `Checkpoint` is a reserved heading collision. Emit `current` for one byte-identical v2 block,
      `drifted-current` for one ordered `@2` pair whose block differs, `conflict` for one ordered
      non-v2 begin-family/end pair, and `absent` only when no reserved marker or heading exists.
      Never emit or interpret the opaque suffix or branch by its value.
    - Treat an unmarked Checkpoint H2, unmatched counterpart, duplicate, inverted, nested, mixed,
      overlapping, malformed template, symlink, or non-regular input as an unsafe error. Emit no
      extent and offer no replacement. Delete `obsolete-versioned`, `obsolete-unversioned`, legacy
      heading bounding, version-specific fixtures, and every migration branch rather than retaining
      compatibility routing.
    - Update Anchor's guarded edit procedure. For `drifted-current` and `conflict`, show the selected
      `AGENTS.md` path, exact bounded current bytes, and exact v2 replacement before offering the
      wholesale replacement. Immediately before editing, require those same bytes at the emitted
      extent; if they changed, reclassify and re-propose. Preserve surrounding bytes. For `absent`,
      show the exact target and appended block first. Never read a checkpoint, edit ignore rules,
      self-install, touch grimoire's real front door, or commit.
    - Update ordinary Save's anchor report in the same cut: report a missing anchor, drifted-v2
      anchor, or generic conflict and point to `/checkpoint anchor`; never edit project instructions
      or mention an obsolete version, compatibility route, or migration.
    - Rebuild anchor fixtures around the exact v2 template and an arbitrary opaque non-v2 marker
      pair. Cover current, drifted v2, generic conflict, missing/absent, unmarked Checkpoint H2,
      unmatched markers, nested, mixed, overlap, duplicate, inverted, invalid target, exact emitted
      extents, and changed-preview refusal. Extend `skill-doc-test.sh` to pin the path/old/new preview,
      approval, wholesale replacement, reclassify-on-change contract, Save's v2-only warning
      vocabulary, and absence of obsolete-status language.
  - Verify:
    - Red first: update the v2 classifier and Anchor documentation expectations before the
      classifier/template and run `bash skills/checkpoint/scripts/tests/anchor-test.sh` plus
      `bash skills/checkpoint/scripts/tests/skill-doc-test.sh` → nonzero.
    - Guard red-proof: use the existing `ANCHOR_SH` / `ANCHOR_TEMPLATE` overrides with a temporary
      classifier whose mixed-marker refusal is disabled (assert one controlled mutation); run the
      mixed/overlap fixture → nonzero, discard the copy, and rerun green. On a controlled Checkpoint
      skill copy, remove the reclassify-on-changed-preview instruction and restore obsolete Save
      warning vocabulary (assert one mutation of each), then prove `skill-doc-test.sh` fails before
      restoring the green source.
    - `bash skills/checkpoint/scripts/tests/anchor-test.sh` → green.
    - `bash skills/checkpoint/scripts/tests/skill-doc-test.sh` → green.
    - `rg -n 'obsolete-versioned|obsolete-unversioned|recovery-anchor@1' skills/checkpoint` → no output.
    - `shellcheck -S warning skills/checkpoint/scripts/anchor-status.sh skills/checkpoint/scripts/tests/anchor-test.sh skills/checkpoint/scripts/tests/skill-doc-test.sh` → no warning-or-higher diagnostics.
    - `skills/checkpoint/scripts/tests/run.sh` → all suites green.

## Done when

- Every requirement in the published spec maps to one of the three slices; no open design branch or
  compatibility alias remains.
- Explicit Save is the only first enrollment write; valid foreign occupancy offers one guarded
  overwrite; unsafe occupancy does not; confirmed replacement is atomic, fingerprint-gated,
  token-fresh, and backup-free.
- Resume claims in one command; matching-token Recovery is read-only; no-handle sessions are inert;
  exact-root mismatches stop without disclosure; all enrolled refreshes occur only at the three
  lifecycle moments.
- `/checkpoint close` is the only closure verb, and no lifecycle, Resume, Recovery, or anchor text
  infers or suggests it.
- The exact v2 anchor classifies `current`; bounded changed v2 classifies `drifted-current`; one
  opaque marker-family collision classifies `conflict` and offers wholesale replacement only after
  the exact `AGENTS.md` before/after preview; clean absence classifies `absent`; every ambiguous or
  unmarked collision refuses. No legacy-specific state, migration branch, or version alias remains,
  ordinary Save reports only the v2-era missing/drifted/conflict vocabulary, and all installation
  tests use throwaway front doors.
- Run, in order:
  - `skills/checkpoint/scripts/tests/run.sh` → all suites green.
  - `skills/workstream/scripts/tests/run.sh` → all suites green.
  - `shellcheck -S warning skills/checkpoint/scripts/checkpoint-file.sh skills/checkpoint/scripts/anchor-status.sh skills/checkpoint/scripts/tests/*.sh` → no warning-or-higher diagnostics.
  - `skills/skill-builder/scripts/skills-lint.sh` → `fails=0`, with every warning attributed.
  - `skills/architect/scripts/ground-check.sh /Users/cscott/Repos/grimoire .records/specs/2026-08-28-checkpoint-lifecycle-and-recovery-anchor.md` → `unresolved_count=0`.
  - `skills/inspector/scripts/ground-check.sh /Users/cscott/Repos/grimoire .records/specs/2026-08-28-checkpoint-lifecycle-and-recovery-anchor.md` → `unresolved_count=0`.
  - `skills/journal/scripts/records.sh --root /Users/cscott/Repos/grimoire --records-root .records check` → records check succeeds.
  - `git diff --check -- README.md skills/checkpoint skills/workstream` → no output.
- The final diff contains no root `CHECKPOINT.md`, real-`AGENTS.md` anchor, committed ignore rule,
  Done compatibility shim, legacy-anchor compatibility branch, backup checkpoint, or unrelated
  user-owned hunk.

_On completion (before landing), run the host's close-the-books sweep._
