---
doctype: plans
status: archived
stage: approved
schema: contractor/plan@1
tags: [plan]
---

# Workstream shared-resource coordination — Implementation Plan

Tracer-bullet: Slice 1 establishes one repository-local claim through the complete agent path —
routing, acquire, hand-off custody, load validation, release, and close — over an atomic Git ref.
Later slices widen that safe path into contention/fault handling, multi-resource lifecycle behavior,
and cold-context teaching. Each slice is independently testable and committable.

Spec: `→ specs/2026-08-26-workstream-resource-coordination.md`

## Task 0 — Re-ground before editing

This read-only gate runs immediately before Slice 1. If any result differs materially, update the
affected slice before writing code; do not force an aged plan onto a changed tree.

1. Verify the worktree and published input:

   ```sh
   git -C /Users/cscott/Repos/grimoire/.workstreams/skill rev-parse --show-toplevel
   git -C /Users/cscott/Repos/grimoire/.workstreams/skill branch --show-current
   sed -n '1,8p' /Users/cscott/Repos/grimoire/.workstreams/skill/.records/specs/2026-08-26-workstream-resource-coordination.md
   skills/contractor/scripts/ground-check.sh /Users/cscott/Repos/grimoire/.workstreams/skill /Users/cscott/Repos/grimoire/.workstreams/skill/.records/specs/2026-08-26-workstream-resource-coordination.md
   ```

   Expected: top level is the recorded worktree, branch is `stream/skill`, the spec is
   `status: published`, and `unresolved_count=0`.
2. Repeat the capability-wide prior-art and edit-surface sweep:

   ```sh
   rg -n "workstream-resource|workstream-resources|resource-lock|update-ref|resource lock|exclusive environment" /Users/cscott/Repos/grimoire/.workstreams/skill --glob '!target/**' --glob '!.git/**' --glob '!.workstreams/**'
   rg --files /Users/cscott/Repos/grimoire/.workstreams/skill/skills/workstream | sort
   git -C /Users/cscott/Repos/grimoire/.workstreams/skill worktree list
   git -C /Users/cscott/Repos/grimoire/.workstreams/skill log stream/skill..main --oneline
   ```

   Expected at plan authoring: no resource-claim implementation exists outside the published spec and
   this plan; the current Workstream package paths below exist; `main` has not moved.
   A sibling worktree may exist, but its hand-off belongs to its own session and is not opened. The
   plan ground-check reports exactly three unresolved create targets — `workstream-resource.sh`,
   `resource-test.sh`, and `verbs/resource.md` — until Slice 1 creates them; every incumbent path
   resolves.
3. Re-read the complete governing signatures at HEAD: `skills/workstream/SKILL.md`,
   `skills/workstream/flow.md`, `skills/workstream/templates/workstream-handoff.md`,
   `skills/workstream/verbs/create.md`, `skills/workstream/verbs/load.md`,
   `skills/workstream/verbs/save.md`, `skills/workstream/verbs/recycle.md`,
   `skills/workstream/verbs/close.md`, `skills/workstream/scripts/worktree-teardown.sh`, and
   `skills/workstream/scripts/tests/{run.sh,artifact-contract-test.sh,lib.sh}`. Confirm that the router is thin,
   save/recycle regenerate the hand-off, load owns the entry guard, and close has distinct worktree
   and in-place teardown paths.
4. Establish the green baseline:

   ```sh
   bash skills/workstream/scripts/tests/run.sh
   skills/skill-builder/scripts/skills-lint.sh
   bash scripts/tests/run.sh
   shellcheck skills/workstream/scripts/*.sh skills/workstream/scripts/tests/*.sh
   ```

   Expected: Workstream and repository integration suites are green, skills lint reports
   `fails=0 warns=0`, and ShellCheck has no error/warning-severity findings. Existing informational
   or style notices are baseline evidence, not permission to add new warnings.

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Safety model:** claims never expire. Age is diagnostic only. A held, malformed, or inconsistent
  claim halts and reports facts; no polling, waiting, automatic repair, or unattended takeover is
  introduced. Only the attended `break` procedure may displace another owner.
- **Atomic authority:** `refs/workstream-resources/<resource>` is the registry; the immutable blob OID
  is the token. Every create/delete uses `git update-ref` compare-and-swap, and `release-all` uses one
  `git update-ref --stdin` transaction. The hand-off is the exact token snapshot, never the atomic
  lock itself.
- **Mutation boundary:** `skills/workstream/scripts/workstream-resource.sh` is the only supported ref
  writer. The agent verb owns user judgment and hand-off edits; the helper owns parsing, validation,
  facts, and atomic ref mutation. Other Workstream helpers remain read-only with respect to this
  namespace.
- **Cwd independence:** every helper call receives an absolute root; every verb resolves paths from
  Coordinates and invokes bundled scripts by absolute package path. The helper verifies the supplied
  root resolves to itself and never derives correctness from the caller's cwd.
- **Portability:** new shell is Bash 3.2 and BSD/macOS safe: no associative arrays, GNU-only flags,
  SHA-1-length constants, `mktemp -u`, or `/proc` assumptions. Intent is one bounded, non-secret,
  control-free argument. Test fixtures use `mktemp` repositories only.
- **Hand-off custody:** `resource-lock: <resource> <oid>` lines are strictly parsed inside the one
  `## Resource locks` section. Create starts empty; save and recycle preserve exact lines; load
  validates both directions. No operation silently edits another stream's hand-off.
- **Close ordering:** close settles ship/discard first, atomically releases the exact claim set,
  removes those exact hand-off lines, and only then tears down. The post-release hand-off cleanup is
  the multi-resource form of the spec's successful-release rule; without it, the direct teardown
  guard would correctly see stale declarations and refuse. A cleanup or later teardown failure halts
  and reports that refs were already released. `--force` never bypasses this gate.
- **Patient zero:** tests never touch this repository's real custom refs, live hand-offs, or sibling
  worktrees. The library's authored `AGENTS.md` receives no deployed door block or DUCAT-specific
  procedure. DUCAT remains an example only; shipped skill guidance is generic.
- **Progressive disclosure:** frontmatter routes; `SKILL.md` dispatches and declares the helper/edge;
  `verbs/resource.md` owns procedure; `flow.md` owns when-to-use behavior; the hand-off keeps only the
  durable reminder and token inventory. Do not duplicate the full procedure across those surfaces.
- **Scope:** Git shipping, ordinary worktree files, independently addressable environments, remote
  registries, queues, leases, daemons, Docker integration, and multi-resource atomic acquisition stay
  unchanged/out of scope. `PACK.md` membership/version and README inventory do not change for an
  internal capability of the existing Workstream member.
- **Coexisting work:** re-run Task 0's worktree/main checks before each slice. Do not inspect or edit a
  sibling stream's hand-off. If `main` moves or an overlapping path lands, sync before continuing and
  re-ground the affected signatures.

## Slices

- [x] **Slice 1: one claim through the complete stream lifecycle (tracer)** <requires: Task 0>

  - Files:
    - Create: `skills/workstream/scripts/workstream-resource.sh`
    - Create: `skills/workstream/scripts/tests/resource-test.sh`
    - Create: `skills/workstream/verbs/resource.md`
    - Modify: `skills/workstream/scripts/tests/run.sh`
    - Modify: `skills/workstream/scripts/tests/artifact-contract-test.sh`
    - Modify: `skills/workstream/templates/workstream-handoff.md`
    - Modify: `skills/workstream/verbs/create.md`
    - Modify: `skills/workstream/verbs/load.md`
    - Modify: `skills/workstream/verbs/close.md`
    - Modify: `skills/workstream/scripts/worktree-teardown.sh`
    - Modify: `skills/workstream/SKILL.md`
  - Change:
    - Implement the Bash-3.2 helper skeleton and strict shared parser. It validates the absolute root,
      resource/stream/branch/handoff/intent inputs, exact ordered version-1 blob grammar, blob target,
      repository object format, and hand-off `resource-lock:` lines. Unknown/duplicate/reordered keys,
      unsafe intent, bad time/name/path fields, missing objects, non-blobs, and duplicate hand-off
      resources produce `state=malformed`, remain held, and exit 2.
    - Implement `acquire`, `status`, `validate`, `release`, `release-all`, and `rollback` with the exact
      argv and exit contract from the spec. `acquire` writes a metadata blob with a real-`mktemp`
      nonce, derives the all-zero OID at the repository's hash length, and creates the ref from zero.
      `release`/`rollback` delete only the supplied hand-off/expected OID. `release-all` validates an
      exact set and submits expected-OID deletes in one transaction, even though this tracer exercises
      only zero/one claim. Every result emits bounded `key=value` facts; no helper output recommends
      an action or infers takeover from age.
    - Define `verbs/resource.md` for the implemented `acquire`, `status`, and `release` paths. The verb
      runs START HERE for mutations, writes the hand-off line only after a winning acquire, invokes
      exact-OID rollback if that write fails, deletes the ref before removing a released line, and
      turns held/malformed/inconsistent facts into the Workstream blocker seam. Do not expose `break`
      until Slice 2 implements its attended confirmation path.
    - Add the router row and helper entry needed to discover this tracer without duplicating the
      procedure. Add `## Resource locks` to the bundled hand-off; make `create` instantiate it empty;
      make `load` call `validate` after START HERE and before Confident launch.
    - Make `close` run `release-all` after ship/discard and before either teardown path, then remove the
      exact released lines. Make `worktree-teardown.sh` call the helper read-only guard and refuse both
      a valid `held_count>0` and every mismatch/malformed result; after close's cleanup an empty,
      consistent set passes. Apply the equivalent guard explicitly to in-place close prose.
    - Register `resource-test.sh` in the existing runner. Its disposable repository plus linked
      worktree proves acquire → hand-off token → load validation → status from both checkouts → release
      and close-release; the active ref does not dirty either checkout; an old expected token cannot
      delete a reacquired claim; direct teardown refuses a live declaration. Add artifact assertions
      for the router, hand-off section, load ordering, close ordering, and `--force` non-bypass.
  - Verify:

    ```sh
    bash skills/workstream/scripts/tests/resource-test.sh
    bash skills/workstream/scripts/tests/artifact-contract-test.sh
    shellcheck skills/workstream/scripts/workstream-resource.sh skills/workstream/scripts/worktree-teardown.sh skills/workstream/scripts/tests/resource-test.sh
    ```

    Expected: every tracer/failure assertion passes, ShellCheck has no error/warning findings, and a
    deliberate wrong-token delete leaves the live ref unchanged. Commit the green slice.

- [x] **Slice 2: contention, malformed state, and attended break** <requires: 1>

  - Files:
    - Modify: `skills/workstream/scripts/workstream-resource.sh`
    - Modify: `skills/workstream/scripts/tests/resource-test.sh`
    - Modify: `skills/workstream/scripts/tests/git-helpers-test.sh`
    - Modify: `skills/workstream/verbs/resource.md`
    - Modify: `skills/workstream/SKILL.md`
  - Change:
    - Complete the helper's observable contract: all singular outcomes print `operation`, `resource`,
      `state`, relevant booleans, and readable holder evidence (`owner`, `branch`, `handoff`, `intent`,
      `acquired_at`, floor-at-zero `age_seconds`, `oid`). Exit 0 is established state, 1 an expected
      negative such as held/absent/CAS rejection, and 2 invalid or malformed input.
    - Make same-owner acquire idempotent only when the live OID exactly matches the canonical hand-off;
      an absent/different token halts. Cover distinct-resource independence, competing intents on one
      singleton, arbitrarily old claims, wrong owner/token, ref-changed races, and acquire-write
      compensation. Exercise SHA-agnostic handling in a disposable `git init --object-format=sha256`
      repository as well as the host default; the helper must derive each zero/OID length rather than
      branching on a 40-character constant. A failed rollback reports the surviving resource and OID
      as a hard blocker; a release hand-off-write failure remains a detectable declared-but-free
      mismatch.
    - Implement helper `break <root> <resource> <expected-oid>` as exact-OID deletion, including
      malformed refs whose metadata cannot be trusted. Extend `verbs/resource.md` with `break`: run
      status first, display the exact resource/evidence/OID (or explicit malformed notice), require a
      human confirmation naming that resource, forbid unattended use, and halt if CAS detects change.
      Add `break` to the grouped router invocation only now.
    - Add the concurrency red-proof. Run two simultaneous create-from-zero contenders and assert one
      success/one held result with winner evidence. Mutate a temporary copy of the helper so acquire
      performs an unguarded update, prove both contenders report success, then restore/compare the
      fixture bytes before running the production helper green. The mutation must replace exactly one
      guarded site or the test fails.
  - Verify:

    ```sh
    bash skills/workstream/scripts/tests/resource-test.sh
    shellcheck skills/workstream/scripts/workstream-resource.sh skills/workstream/scripts/tests/resource-test.sh
    ```

    Expected: exactly one production contender wins, the mutant red-proof observes two successes,
    malformed/old/stale cases stay held, break succeeds only for the displayed OID, fixture restoration
    is byte-identical, and the suite exits 0. Commit the green slice.

- [x] **Slice 3: multi-resource custody across reset, recycle, and close** <requires: 2>

  - Files:
    - Modify: `skills/workstream/scripts/workstream-resource.sh`
    - Modify: `skills/workstream/scripts/tests/resource-test.sh`
    - Modify: `skills/workstream/scripts/tests/artifact-contract-test.sh`
    - Modify: `skills/workstream/templates/workstream-handoff.md`
    - Modify: `skills/workstream/verbs/save.md`
    - Modify: `skills/workstream/verbs/recycle.md`
    - Modify: `skills/workstream/verbs/load.md`
    - Modify: `skills/workstream/verbs/close.md`
    - Modify: `skills/workstream/scripts/worktree-teardown.sh`
  - Change:
    - Make `validate` bidirectional for an arbitrary set: every hand-off token must match a live ref and
      owner, and every valid registry claim naming this stream/canonical hand-off must be declared.
      Missing, extra, duplicate, wrong-owner, wrong-OID, malformed, and declared-but-free cases halt;
      success reports sorted held resources and intents without changing state.
    - Preserve the `Resource locks` section verbatim through `save` regeneration and `recycle` while
      blanking only per-unit content. Keep `park`, `sync`, `ship`, feature completion, and resets neutral:
      they neither release nor reacquire claims. After an attended break, the displaced owner's stale
      hand-off must make its next load halt.
    - Harden `release-all`: scan the full namespace, derive the stream's valid registry set, require
      exact equality with the hand-off set, and send sorted expected-OID deletes in one
      `git update-ref --stdin` transaction. A single stale expected OID rejects the whole batch and
      leaves every ref. Zero claims is a successful `released=0` result. Close removes hand-off lines
      only after the transaction commits; no teardown runs on validation, transaction, or cleanup
      failure. If refs are released and later teardown fails, report that ownership is gone and require
      reacquisition before protected work.
    - Expand fixtures to matching and mismatched multi-resource sets, all-or-nothing batch rejection,
      create-empty/save-preserve/recycle-preserve behavior, break-stale load refusal, close ordering,
      direct-teardown refusal, and both worktree/in-place prose contracts. Prove the ordinary
      `workstream-git.sh` commands used by sync/ship do not alter a planted resource ref. Let
      `artifact-contract-test.sh` accept an optional absolute `WORKSTREAM_SKILL_UNDER_TEST` package
      override (default: its real package root); copy the package to a fixture, inject a namespace
      mutation into the fixture's verb text, and prove the absence assertion fails while the real
      package remains byte-identical.
  - Verify:

    ```sh
    bash skills/workstream/scripts/tests/run.sh
    shellcheck skills/workstream/scripts/workstream-resource.sh skills/workstream/scripts/worktree-teardown.sh skills/workstream/scripts/tests/resource-test.sh skills/workstream/scripts/tests/artifact-contract-test.sh
    ```

    Expected: the complete Workstream runner is green; the rejected batch preserves every ref; exact
    zero/one/many sets release; lifecycle rewrites preserve exact token lines; no direct or forced
    teardown bypass is possible. Commit the green slice.

- [x] **Slice 4: cold discovery and operational teaching** <requires: 3>

  - Files:
    - Modify: `skills/workstream/SKILL.md`
    - Modify: `skills/workstream/flow.md`
    - Modify: `skills/workstream/verbs/resource.md`
    - Modify: `skills/workstream/templates/workstream-handoff.md`
    - Modify: `skills/workstream/scripts/tests/artifact-contract-test.sh`
  - Change:
    - Rewrite the frontmatter description as a generic trigger for shared development resources,
      exclusive environments, and resource locks while retaining lifecycle routing and staying under
      the 1024-character hard limit (aim near 700). Finalize the single grouped dispatch row, list the
      mutation helper distinctly from read-only facts helpers, and extend `produces:` with
      `resource-claim` without inventing a consumer or project setup.
    - Add `flow.md`'s `Shared resources` behavior: acquire a host-procedure-declared singleton before
      its first protected operation; validate before each later operation and after load/recovery;
      release early when finished; close releases the remainder. A held/inconsistent claim is a
      blocker seam with compact holder facts, never a polling loop or age-based takeover. Explicitly
      exclude Git landing, ordinary files, read-only work, and independently addressable environments.
    - Complete `verbs/resource.md` with exact acquire/status/release/break examples, the one-resource /
      multiple-intent configuration rule, output interpretation, rollback behavior, human-only break,
      and conflict-report language. Keep product prose generic; explain that a host procedure must name
      its literal resource and intent before protected commands because Workstream cannot infer them.
    - Add the compact durable reminder to the hand-off `Loop routine` without copying the procedure.
      Extend artifact-contract tests so each teaching responsibility has one authority and so a
      competing configuration example never encodes configurations as separate resources.
    - Run fresh-context routing/procedure probes with only installed skill metadata. Prompts:
      `coordinate access to a shared Docker environment between workstreams` and
      `acquire an exclusive development-resource lock` must select Workstream and recover when to
      acquire/validate/release/halt. Control prompt `two workstreams need to ship Git changes at the
      same time` must retain ship contention guidance and not prescribe a resource claim. Record the
      prompts, selected skill, and summarized responses beneath this slice before checking it off.
  - Verify:

    ```sh
    bash skills/workstream/scripts/tests/artifact-contract-test.sh
    skills/skill-builder/scripts/skills-lint.sh
    ```

    Expected: contract assertions and lint are green (`fails=0 warns=0`); both positive cold probes
    route to Workstream and recover the four operational moments; the control probe does not prescribe
    a resource lock. Commit the green slice.

  - Fresh-context evidence (2026-08-27; selection used only this branch's staged
    `skills/*/SKILL.md` frontmatter metadata):
    - Prompt: `coordinate access to a shared Docker environment between workstreams` → selected
      Workstream; acquire the named singleton/intent before first protected work, validate before each
      later operation and after load/recovery, release immediately when finished, halt with holder
      facts on held/malformed/inconsistent state; attended exact-OID break only.
    - Prompt: `acquire an exclusive development-resource lock` → selected Workstream; the grouped
      resource verb acquires from loaded Coordinates, records the exact OID only after success,
      validates the hand-off/ref pair, exact-token releases, and halts on stale/inconsistent state or
      failed compensation.
    - Control: `two workstreams need to ship Git changes at the same time` → selected Workstream and
      retained Git's ff-only contention path: the loser re-syncs/retries; no resource claim prescribed.

## Coverage

- Public operations, singleton/intent semantics, registry/blob grammar, atomic helper, and no-expiry
  safety: Slices 1–2.
- Hand-off custody, bidirectional load validation, save/recycle persistence, multi-resource close,
  direct-teardown guard, and neutral sync/ship behavior: Slices 1 and 3.
- Human-confirmed exact-OID break and stale-owner detection: Slices 2–3.
- Agent routing, typed edge, helper discovery, use/avoid rules, host-procedure declaration, durable
  recovery reminder, and cold/control probes: Slice 4.
- All 18 numbered verification requirements in the spec map to explicit assertions or probes above;
  no spec requirement is intentionally deferred.

## Done when

All four slices are committed; the spec's 18 verification requirements and required concurrency /
absence red-proofs have evidence; no open decision branch was introduced; and the final tree passes:

```sh
bash skills/workstream/scripts/tests/run.sh
shellcheck skills/workstream/scripts/workstream-resource.sh skills/workstream/scripts/worktree-teardown.sh skills/workstream/scripts/tests/resource-test.sh skills/workstream/scripts/tests/artifact-contract-test.sh
skills/skill-builder/scripts/skills-lint.sh
bash scripts/tests/run.sh
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings
```

Expected: both shell test runners report `ALL GREEN`, ShellCheck has no error/warning findings,
skills lint reports `fails=0 warns=0`, and all Cargo tests/clippy checks pass. Re-run Inspector over
the complete implementation diff against the published spec before Workstream's landing seam. On a
successful Contractor walk, retain `status: published` and set `stage: implemented`; Workstream, not
Contractor, owns any later ship to `main`.

_On completion (before landing), run the host's close-the-books sweep._
