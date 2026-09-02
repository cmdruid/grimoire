---
doctype: plans
status: published
stage: implemented
schema: contractor/plan@1
tags: [plan]
---

# Grimoire Phase 5 complete CLI adapter — Implementation Plan

Build the first production command path through the real binary, one ambient environment boundary,
typed scope resolution, the core planner, the transactional executor, and deterministic output.
The first slice proves that path with `grimoire init`; later slices widen the same adapter across
source review and trust, desired-state operations, read-only reporting, prune, and the complete
grammar/exit matrix. Where the completed core does not expose enough domain data for a thin
adapter, the owning core seam is extended and tested before the CLI consumes it; the app never
reimplements package-manager decisions.

Spec: `.records/specs/2026-08-31-grimoire-symlink-package-manager.md` and Phase 5 of
`.records/plans/2026-09-01-grimoire-hard-cut-rewrite-roadmap.md`

## Task 0 — Re-ground before editing

This task is read-only and produces no commit.

- Run `git -C /Users/cscott/Repos/grimoire/.workstreams/app status --short --branch`,
  `git -C /Users/cscott/Repos/grimoire/.workstreams/app log stream/app..main --oneline`, and
  `git -C /Users/cscott/Repos/grimoire/.workstreams/app worktree list --porcelain`. Stop for staged
  state, movement on `main`, or another worktree that owns the CLI, source-query, update, or
  environment boundary.
- Run
  `/Users/cscott/Repos/grimoire/skills/contractor/scripts/ground-check.sh /Users/cscott/Repos/grimoire/.workstreams/app /Users/cscott/Repos/grimoire/.workstreams/app/.records/specs/2026-08-31-grimoire-symlink-package-manager.md`
  and the same command for
  `.records/plans/2026-09-01-grimoire-hard-cut-rewrite-roadmap.md`. Confirm both records remain
  `published`, then re-read Product boundary; Scope and paths; Source identities, fetching, and
  snapshots; Trust and capability review; Command surface; Plans, confirmation, and frozen mode;
  Planner/executor API; Output and exit classes; and CLI and TUI verification. Re-read Phase 5's
  scope, gate, risks, and strict dependency on Phase 4.
- Re-read `crates/grimoire/Cargo.toml`, `crates/grimoire/src/lib.rs`,
  `crates/grimoire/src/runtime.rs`, `crates/grimoire/src/ui.rs`,
  `crates/grimoire/src/worker.rs`, `crates/grimoire-core/src/lib.rs`,
  `crates/grimoire-core/src/error.rs`, `crates/grimoire-core/src/model.rs`,
  `crates/grimoire-core/src/plan.rs`, `crates/grimoire-core/src/world.rs`,
  `crates/grimoire-core/src/check.rs`, `crates/grimoire-core/src/prune.rs`,
  `crates/grimoire-core/src/trust.rs`, and every file below
  `crates/grimoire-core/src/source/` against `HEAD`. At plan time `skill-grimoire` has no binary,
  Clap parser, environment/scope resolver, dispatcher, renderer, or CLI tests; it has six tests for
  its production Git/runtime and generic worker/terminal shells. Core owns plans and execution but
  lacks an operandless atomic update request, a unified refresh entry point across remote,
  pinned-local, and live sources, cached source/trust query values, complete historical source-diff
  evidence, inherited-global attachment, and a transport error class the CLI can map without
  parsing messages.
- Search compiled source and tests for `clap`, `main`, `Args`, `GRIMOIRE_HOME`, `HOME`,
  `current_dir`, `is_terminal`, `UpdateAll`, `SourceInfo`, `SourceDiff`, `TrustStore`,
  `ExitClass`, `Approval`, `dry-run`, `frozen`, `force`, `adopt`, `LibraryConfig`, and
  `AgentTarget`. Search history only to test a specific reuse claim. The deleted alpha parser and
  immediate/TUI-only command model are incompatibility evidence; do not restore, rename, or wrap
  them.
- Re-measure with
  `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p skill-grimoire -- --list`
  and
  `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo check --workspace`.
  The planning baseline has six app tests, no binary test target, no Clap entry in the lockfile,
  and a green workspace check. Amend this plan instead of coding around a moved API or already
  completed capability.

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Published hard cut.** The published product spec and roadmap remain authoritative. Implement
  exactly the canonical v1 grammar and `remove` alias; do not restore alpha library/agent flags,
  old state readers, immediate install/remove APIs, hidden migration/fetch, background update,
  `--force`, `--adopt`, registries, nested/cross-source packs, Windows behavior, or a second CLI
  grammar for pack exclusions.
- **Thin adapter.** `skill-grimoire` owns Clap parsing, one ambient environment/path boundary,
  human and JSON rendering, TTY detection/prompting, and process exit selection. Core continues to
  own source identity and refresh custody, trust interpretation, manifests/locks, dependency
  resolution, checking, requests, plans, destructiveness, preconditions, transactions, recovery,
  project reachability, and prune. Every mutation except the documented inert source
  refresh/inspection workflow must be a typed `Request` -> `Plan` -> `apply`; app code never writes
  a managed state file, link, candidate, review export, trust record, project index, or store path.
- **Close missing core seams, not semantics in the app.** Add one atomic `Request::UpdateAll` that
  selects every declared non-live source's exact current candidate in one plan; never loop over
  `UpdateSource` applies. Add a core-owned constructor that classifies and validates one raw CLI
  source location plus ref/live options into `ManifestSource`; the app must not guess whether a
  spelling is a URL, SCP transport, pinned local Git root, or live path. Add core-owned
  query/refresh APIs and factual public values sufficient for source list/info/diff,
  identity-wide trust list/revoke previews, inherited-global context, and affected request roots.
  Persist and validate enough content-addressed review evidence to compare historical skills,
  packs, files, hashes, modes/capabilities, symlinks, submodules, and findings. The app may select
  and render values but may not reconstruct source identity, trust, diff, dependency, or
  reachability facts. New public shared values pin `Debug`, `Clone`, `PartialEq`, and `Eq`; keys and
  enums also pin `Hash`, `Ord`, and `PartialOrd` where used in sets/maps.
- **One environment read.** Production constructs an immutable app environment once: argument
  vector, resolved current directory, `HOME`, optional absolute `GRIMOIRE_HOME`, optional validated
  SSH-agent/owned-askpass inputs, stdin/stdout/stderr, and whether stdin is a terminal. Core sees
  only absolute `Paths` and structured runner inputs. `--help`, `--version`, and contextual help
  return before any home, cwd, project, source, Git, or managed-state resolution. Tests inject an
  environment/console seam; they do not mutate process-global cwd or environment concurrently.
- **Scope is exact.** `--global` and `--project <path>` are mutually exclusive. Explicit project
  selects that exact existing directory; implicit scope uses the nearest manifest; absence is
  usage exit 2 with an init/`--global` remedy. `init` defaults to the current directory and is the
  sole silent-creation path. Bare invocation is parsed as the Phase 6 TUI entry and remains a
  typed dispatch seam; Phase 5 does not invent a temporary alternate UI.
- **Plans are the output contract.** Every mutating command prints the complete core `Plan` before
  any apply attempt. Blockers return the plan's class without applying. An additive-only unblocked
  plan applies without a prompt. A destructive plan prompts exactly `Apply? [y/N]` on a TTY;
  outside a TTY it exits 3 unless `--yes` is present. A decline prints
  `Cancelled; no changes applied.`, returns 0, and passes `Approval::Declined` so the executor
  remains the final guard. `--dry-run` plans and never applies. `--yes` controls only destructive
  confirmation; Clap rejects it for trust grants and it never bypasses blockers or stale checks.
- **Frozen and source movement.** Only operand-free `install` accepts `--frozen`; it performs no
  source refresh and passes `PlanningMode::Frozen`. Operand installs, uninstall, and update reject
  `--frozen`. `update [source]` never fetches; the all-source form is one atomic plan and rejects
  no scope merely because it also declares live sources: operandless update skips live sources,
  while explicitly naming a live source is an input error. `source fetch` is explicit, inert,
  unconfirmed custody work and may refresh one or every declared source in stable alias order.
- **Output and exits.** Plans and primary results go to stdout; diagnostics go to stderr. Only
  `source info --json` is stable machine output and writes `SourceInfo::to_bytes()` unchanged.
  Human output renders typed core fields deterministically and never infers safety or
  destructiveness. Pin exit precedence and all mappings: 0 success/no-op/applicable dry-run/cancel,
  1 read-only findings or degraded list/info, 2 usage/scope/name/malformed state, 3 policy/safety,
  4 transport/auth/offline/Git, and 5 local I/O/transaction/recovery/invariant. Split transport
  failures into a typed core error rather than matching error strings.
- **Testable I/O and red proofs.** Grammar tests exercise the real Clap parser and real binary
  where environment short-circuiting matters. An injected console proves TTY yes/no/default,
  non-TTY refusal, stdout/stderr custody, and cancellation without pseudo-terminal flakiness.
  Negative/absence tests include a controlled red arm: re-enable a forbidden alpha option,
  perform the forbidden ambient lookup before help, bypass the non-TTY guard, grant trust from
  `--yes`, or fetch during update and show the named test fails.
- **Dependencies and portability.** Add Clap with derive support and no async runtime. Reuse core's
  serde adapters, `SystemGitRunner`, `SystemRuntime`, synchronous Unix support, and std I/O. Keep
  test helpers under dev-dependencies; do not add a shell parser, terminal framework for the CLI,
  second serializer, database, daemon, network client, or command runner.
- **Tree custody and gate.** Every non-Git command runs with
  `cd /Users/cscott/Repos/grimoire/.workstreams/app && ...`; every Git command uses
  `git -C /Users/cscott/Repos/grimoire/.workstreams/app`; the main session is the sole writer.
  Every slice begins red, ends with its targeted test and
  `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo check --workspace`
  green, and commits coherently. The shared workspace check applies after each slice without being
  repeated below. Do not ship or rebase this accumulating stream between phases.

## Slices

- [x] **Slice 1: `grimoire init` crosses the real CLI boundary** <requires: —>
  - Files: modify `Cargo.lock`, `crates/grimoire/Cargo.toml`, and
    `crates/grimoire/src/lib.rs`; create `crates/grimoire/src/main.rs`,
    `crates/grimoire/src/args.rs`, `crates/grimoire/src/env.rs`,
    `crates/grimoire/src/command.rs`, `crates/grimoire/src/render.rs`,
    `crates/grimoire/tests/support/mod.rs`, and `crates/grimoire/tests/cli_tracer.rs`.
  - Change: declare the `grimoire` binary and add the smallest production Clap parser and
    testable app runner that carry `init`, global help/version, contextual help, and the typed bare
    TUI dispatch seam. Build an immutable environment/console boundary with validated absolute
    home/cwd/Grimoire-home resolution, exact explicit/implicit/init scope rules, structured
    `SystemGitRunner`/`SystemRuntime` construction, buffered stdout/stderr, terminal detection, and
    numeric exit results. Route `init` through `load_world` (absent state),
    `plan(Request::Initialize, Normal)`, deterministic plan rendering, and `apply`; do not create
    files in the app. Preserve `ui` and `worker` as Phase 6 infrastructure without routing the old
    application model back into the binary.
  - Verify: first add failing tests that invoke the built binary in an empty temporary home and
    prove project-default, explicit-project, and global init create the canonical manifest and lock
    only through core (while permitting core-owned lock, transaction, and project-index
    bookkeeping); repeat init is a typed usage failure; and help/version succeed with missing or
    invalid home/cwd inputs and no managed-state access. Then run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p skill-grimoire --test cli_tracer`;
    expected: the new tracer and help-before-environment red proof pass.

- [x] **Slice 2: Source add and info use complete core review values** <requires: 1>
  - Files: create `crates/grimoire-core/src/source/query.rs`,
    `crates/grimoire-core/tests/adapter_source.rs`, and
    `crates/grimoire/tests/cli_source_tracer.rs`; modify
    `crates/grimoire-core/src/lib.rs`, `crates/grimoire-core/src/error.rs`,
    `crates/grimoire-core/src/model.rs`, `crates/grimoire-core/src/world.rs`,
    `crates/grimoire-core/src/source/mod.rs`,
    `crates/grimoire-core/src/source/workflow.rs`,
    `crates/grimoire-core/src/source/review.rs`,
    `crates/grimoire-core/src/source/info.rs`,
    `crates/grimoire-core/src/source/diff.rs`, their source/review/info/diff tests, and
    `crates/grimoire/src/args.rs`, `crates/grimoire/src/command.rs`, and
    `crates/grimoire/src/render.rs`.
  - Change: add a core-owned source observation seam that requires and reconstructs the exact
    current candidate, review export, trust mode/baseline, and source summary from a `WorldState`;
    absence or stale candidate returns a typed instruction to run `source fetch`, rather than
    guessing an unrecorded review-tree identity from the lock. Add the single core constructor for
    raw CLI location/ref/live inputs, using the existing canonical remote grammar and resolved
    absolute local roots while rejecting URL-live, live-ref, and invalid combinations before any
    runner call. Unify explicit refresh dispatch for remote Git, pinned local Git, and live
    directories behind one core function. Extend the content-addressed review index and
    `SourceDiff` factual model so a historical trust baseline can be loaded and compared across
    commit/tree, skills, packs, entries, hashes, modes, executable/shebang/binary facts, links,
    submodules, validation findings, and affected desired/request roots. Validate all keys/digests
    while loading and update private-format goldens; do not make human wording stable wire data.
    Add a distinct `CoreError::Transport` path for runner/auth/offline/Git failures while source
    grammar and state validation remain typed non-transport errors. Then implement
    `source add <alias> <location> [--ref] [--live] [--trust|--trust-all] [scope]` through
    `prepare_source_add` and one planned apply, plus `source info <alias> [--json] [scope]` through
    the new observation value. JSON writes `SourceInfo::to_bytes()` byte-for-byte; human info is a
    deterministic factual projection and marks findings without claiming safety.
  - Verify: start with failing core fixtures for historical diff/review reconstruction and error
    classification and source-location construction, including a recorder proving rejected
    combinations never reach Git, plus a failing temp-home CLI workflow that adds an untrusted
    local pinned source and compares exact `--json` bytes with the core value. Run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test adapter_source --test review_export --test source_info --test source_diff --test source_backends --test source_boundary`
    and
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p skill-grimoire --test cli_source_tracer`;
    expected: source add/info cross only the core custody/plan seams, stable JSON is exact, and the
    runner is untouched for rejected locations.

- [x] **Slice 3: Complete source and identity-wide trust ceremonies** <requires: 2>
  - Files: create `crates/grimoire-core/tests/adapter_trust.rs` and
    `crates/grimoire/tests/cli_sources.rs`; modify
    `crates/grimoire-core/src/model.rs`, `crates/grimoire-core/src/plan.rs`,
    `crates/grimoire-core/src/projects.rs`, `crates/grimoire-core/src/trust.rs`,
    `crates/grimoire-core/src/source/query.rs`, relevant source/trust/planner tests, and
    `crates/grimoire/src/args.rs`, `crates/grimoire/src/command.rs`, and
    `crates/grimoire/src/render.rs`.
  - Change: expose core factual summaries for declared source candidate/locked/live/trust state and
    for every identity trust record with its receipts, baseline, and known global/indexed-project
    alias uses. Bound and validate project-index manifest reads in core; missing/unreadable projects
    produce factual degradation instead of adapter-side scanning. Add preview facts for
    alias-based and source-key revocation without changing trust mutation authority. Implement
    `source list`, one/all `source fetch`, `source diff`, exact/all/revoke `source trust`,
    `source remove`, scope-independent `trust list`, and `trust revoke`. Fetch remains inert and
    stable-ordered; source remove and both revoke forms print plans and use the shared destructive
    confirmation path; exact/all grants reject `--yes`, live exact trust, and ambiguous flag
    combinations in Clap. Render every ceremony directly from the core source/diff/trust/plan
    values.
  - Verify: add failing grammar and temp-home tests for remote/pinned/live refresh dispatch,
    no-fetch info/diff, exact/all/revoke behavior, shared-identity aliases, removal blockers,
    all-source stable order, destructive cancellation/non-TTY refusal, and `--yes` granting no
    trust. Run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test adapter_source --test adapter_trust --test planner_source --test trust`
    and
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p skill-grimoire --test cli_sources`;
    expected: all source/trust commands use typed core facts and mutation plans, and inert fetch is
    the only managed-cache exception.

- [x] **Slice 4: Desired-state commands share one plan/apply harness** <requires: 2, 3>
  - Files: create `crates/grimoire-core/tests/update_all.rs` and
    `crates/grimoire/tests/cli_mutations.rs`; modify
    `crates/grimoire-core/src/model.rs`, `crates/grimoire-core/src/plan.rs`,
    `crates/grimoire-core/src/lib.rs`, relevant planner/apply tests, and
    `crates/grimoire/src/args.rs`, `crates/grimoire/src/command.rs`, and
    `crates/grimoire/src/render.rs`.
  - Change: add `Request::UpdateAll` as one pure atomic plan over every declared non-live source,
    selecting only exact current candidates and preserving per-alias candidate preconditions; a
    missing/stale non-live candidate blocks with `source fetch`, declared live sources are skipped,
    explicitly named live sources remain an input error through `Request::UpdateSource`, and no
    update path invokes a runner. Route operand-free install/reconcile, direct skill and pack
    installs, skill and pack uninstall (including the documented `remove` alias), and one/all
    source update through one adapter harness that prints the complete plan, respects blockers,
    dry-run, frozen-only reconciliation, destructiveness, approval, stale-plan outcomes, and
    deterministic results. Parse names into core types before planning; install pack requests use
    an empty exclusion set and require an already-declared source.
  - Verify: begin with failing core tests for two-source atomic update, partial candidate failure,
    live rejection, stale concurrent refresh, and no runner capability, plus CLI tests for every
    desired-state production and invalid flag combination. Run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test update_all --test planner --test planner_source --test apply_matrix --test transaction_tracer`
    and
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p skill-grimoire --test cli_mutations`;
    expected: all mutations share one plan/apply path, all-source update is atomic, and update never
    fetches.

- [x] **Slice 5: List, check, inherited globals, and prune are direct projections** <requires: 2, 4>
  - Files: create `crates/grimoire-core/tests/adapter_context.rs` and
    `crates/grimoire/tests/cli_reports.rs`; modify
    `crates/grimoire-core/src/lib.rs`, `crates/grimoire-core/src/model.rs`,
    `crates/grimoire-core/src/world.rs`, `crates/grimoire-core/src/check.rs`,
    `crates/grimoire-core/src/prune.rs`, relevant world/check/project/prune tests, and
    `crates/grimoire/src/args.rs`, `crates/grimoire/src/command.rs`, and
    `crates/grimoire/src/render.rs`.
  - Change: add a core-owned project-context composition function that attaches the independently
    loaded global resolution as inherited read-only context while preserving scope ownership. Add a
    deterministic core report value for desired roots, resolved skills, every request root,
    source/snapshot, installed/drift state, unavailable optionals, inherited globals, and
    shadowing; the app renders it without resolving dependencies. Implement `list`, `check`, and
    `store prune [--project <path>]... [--dry-run] [--yes]`. Prune always constructs global paths,
    passes explicit projects to `observe_reachability`, attaches the observation to the world,
    prints the resulting core plan/findings, and applies only through the shared destructive
    harness. Read-only warnings/findings return 1; operational failures retain their higher class.
  - Verify: start with failing core and CLI fixtures for project/global independence, inherited
    read-only entries, shadowing, request roots, missing optionals, drift, check findings, uncertain
    project retention, explicit-project prune, dry-run, TTY cancel, and non-TTY refusal. Run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test adapter_context --test world --test check --test project_index --test prune`
    and
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p skill-grimoire --test cli_reports`;
    expected: reports are stable core projections and prune cannot delete an uncertain or
    unconfirmed snapshot.

- [x] **Slice 6: Exhaust the grammar, confirmation, exit, and temp-home workflows** <requires: 1, 3, 4, 5>
  - Files: create `crates/grimoire/tests/cli_grammar.rs`,
    `crates/grimoire/tests/cli_confirmation.rs`,
    `crates/grimoire/tests/cli_exit.rs`, and `crates/grimoire/tests/cli_workflows.rs`; modify
    `crates/grimoire/tests/support/mod.rs`, all app CLI modules as needed, and focused core tests
    only when a failing adapter scenario exposes a core-owned contract gap.
  - Change: enumerate every canonical grammar production, scope position, mutual exclusion, alias,
    command-specific flag, missing operand, surplus operand, and forbidden combination through the
    real parser. Pin deterministic human plan/outcome renderings and exit precedence. Exercise the
    injected console across additive no-prompt, TTY yes/no/default/EOF, non-TTY with/without
    `--yes`, blocked plan, dry-run, cancelled, stale, transport, malformed state, local I/O, and
    read-only findings. Build complete isolated workflows from init through source add,
    fetch/info/diff/trust, skill and pack install, cached multi-skill explicit update, check, shared
    member uninstall, drift, frozen offline restore, source removal, trust revoke, and prune; use
    local bare remotes/fake runner controls, no external network or user home. Prove update performs
    no fetch and help/version perform no environment resolution with controlled red arms.
  - Verify: run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p skill-grimoire --test cli_grammar --test cli_confirmation --test cli_exit --test cli_workflows`;
    expected: every grammar/flag/exit/confirmation production and complete temp-home workflow is
    covered without ambient state or network access.

- [x] **Slice 7: Enforce the CLI hard cut and close the phase gate** <requires: 6>
  - Files: modify `README.md`, this plan, and only the production/test files implicated by final
    gate failures; remove obsolete app CLI/TUI-only argument scaffolding if any remains.
  - Change: run a boundary audit proving `skill-grimoire` is the sole parser/environment/TTY owner,
    core owns every domain decision and managed mutation, plan and `SourceInfo` serialization remain
    core-owned, and the production binary contains no former argument model or bypass. Pin compile
    boundaries against core ambient reads, app state writes, string-based destructiveness/trust/exit
    inference, hidden update fetch, and alpha names. Run the Code Humanizer write-time standard over
    the durable CLI and maintained tests without broad unrelated cleanup. Update README status to
    state that the complete CLI is available and the tree TUI is Phase 6 next; do not claim the
    TUI or final hard-cut audit is complete. Mark every slice checked and set this record to
    `status: published`, `stage: implemented` only after the full gate is green.
  - Verify: first run the Phase 5 suites:
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p skill-grimoire --tests`
    and
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test adapter_source --test adapter_trust --test adapter_context --test update_all`.
    Prove the hard cut with
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && ! rg -n '(LibraryConfig|AgentTarget|LiveLibrary|InstallLog|ImmediateInstall|ImmediateRemove|\\bforce\\b|\\badopt\\b|struct +Args.*library|--library)' crates/grimoire/src crates/grimoire/tests`
    and a boundary test whose controlled forbidden-import arm fails. Then run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo fmt --all -- --check`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test --workspace`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo clippy --workspace --all-targets -- -D warnings`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && skills/skill-builder/scripts/skills-lint.sh`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && skills/skill-builder/scripts/tests/run.sh`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && scripts/tests/run.sh`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-pack --test clankshop --test pack_availability`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && GRIMOIRE_LIVE_ROOT=/Users/cscott/Repos/grimoire/.workstreams/app RUSTC_WRAPPER= cargo test -p grimoire-pack --test live_root_layout`, and
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && GRIMOIRE_LIVE_ROOT=/Users/cscott/Repos/grimoire RUSTC_WRAPPER= cargo test -p grimoire-pack --test live_root_layout`.
    Expected: every gate is green; the known unrelated archived-record ledger failure remains out
    of scope and is not permission to weaken a Phase 5 gate.

## Done when

- The `grimoire` binary implements every Phase 5 CLI production and command-specific flag with
  exact project/global scope behavior, help/version short-circuiting, deterministic output, stable
  `source-info@1` bytes, and the documented exit classes.
- Source refresh/inspection is the only inert cache mutation; every desired-state, lock, trust,
  link, candidate-registration/removal, and prune mutation is represented by a complete core plan
  and applied through the transactional executor without adapter replanning or direct state writes.
- Destructive TTY/non-TTY confirmation, cancellation, dry-run, frozen reconciliation, trust
  ceremony, cached one/all-source update, stale-plan refusal, read-only findings, inherited-global
  reporting, and conservative prune all match the published contract.
- Temp-home workflows and grammar/negative matrices cover init through complete source review,
  trust, install, update, check, uninstall, offline restore, and prune. Controlled red proofs show
  the forbidden alpha parser, ambient-before-help, `--yes` trust, confirmation bypass, and hidden
  update-fetch arms are observable failures.
- No TUI state/rendering or new package-manager semantics entered Phase 5; the Phase 6 bare-command
  seam remains typed, and all targeted, workspace, clippy, skills/repository integration, dogfood,
  hard-cut, and root/worktree layout gates are green.

_On completion (before landing), run the host's close-the-books sweep._
