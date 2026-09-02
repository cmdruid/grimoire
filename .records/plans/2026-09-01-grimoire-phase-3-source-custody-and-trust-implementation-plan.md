---
doctype: plans
status: published
stage: implemented
schema: contractor/plan@1
tags: [plan]
---

# Grimoire Phase 3 source custody and trust — Implementation Plan

Make an untrusted source inspectable without making it active, then make one explicitly trusted
pinned snapshot immutable. The first slice traces a single synthetic HTTPS remote through the real
bare-cache command plan, Git-object inventory, lossless review export, candidate publication, and
`source-info@1` facts while proving that no desired state, lock, link, trust, or source content is
changed or executed. Later slices widen that tracer across the complete transport grammar, hostile
local/Git trees, immutable store and repair custody, concurrent candidate publication, and the
exact/all-snapshots trust model. Phase 4 will apply scope transactions; this phase supplies the
source workflows, persisted authorities, observations, preconditions, and planned actions it needs.

Spec: `.records/specs/2026-08-31-grimoire-symlink-package-manager.md` and Phase 3 of
`.records/plans/2026-09-01-grimoire-hard-cut-rewrite-roadmap.md`

## Task 0 — Re-ground before editing

This task is read-only and produces no commit.

- Re-run `git -C /Users/cscott/Repos/grimoire/.workstreams/app status --short --branch`,
  `git -C /Users/cscott/Repos/grimoire/.workstreams/app log stream/app..main --oneline`, and
  `git -C /Users/cscott/Repos/grimoire/.workstreams/app worktree list --porcelain`. Stop for staged
  state, movement on `main`, or a sibling stream that now owns source, store, trust, candidate, or
  shared-lock work.
- Re-run
  `/Users/cscott/Repos/grimoire/skills/contractor/scripts/ground-check.sh /Users/cscott/Repos/grimoire/.workstreams/app /Users/cscott/Repos/grimoire/.workstreams/app/.records/specs/2026-08-31-grimoire-symlink-package-manager.md`,
  confirm that the governing spec and roadmap remain published, and re-read the spec's Scope and
  paths; Lock; Source identities, fetching, and snapshots; Trust and capability review;
  Plans/confirmation/frozen; Planner/executor API; Transactions and recovery; and Sources, store,
  and trust verification sections. Re-read the roadmap's Phase 3 boundary and gate.
- Re-read `crates/grimoire-core/src/lib.rs`, `crates/grimoire-core/src/model.rs`,
  `crates/grimoire-core/src/plan.rs`, `crates/grimoire-core/src/scope.rs`,
  `crates/grimoire-core/src/lockfile.rs`,
  `crates/grimoire-pack/src/inventory/mod.rs`,
  `crates/grimoire-pack/src/inventory/model.rs`,
  `crates/grimoire-pack/src/inventory/tree.rs`, and
  `crates/grimoire-pack/src/inventory/scan.rs` against `HEAD`. At plan time Phase 2 exposes a pure
  `WorldState` whose source snapshots are caller-supplied roots plus inventories,
  `Request::UpdateSource` incorrectly receives its proposed snapshot directly, and
  `Preconditions` pin only manifest, lock, and links. There is no live source identity, Git backend,
  cache, candidate, review-export writer, store, trust, shared lock, or repair implementation.
- Confirm that `grimoire-pack` already owns the canonical `TreeReader`, `TreeEntry`, raw
  `SourcePath`, `ReviewedEntry`, `SourceInventory`, inventory digest, and review-tree digest
  contracts. Phase 3 consumes and persists those facts; it does not add a second discovery walk,
  digest grammar, symlink-boundary decision, capability scan, or message-ordering authority in
  `grimoire-core`.
- Search all compiled crates and active tests for `SourceIdentity`, `SourceKey`, `SnapshotKey`,
  `ReviewKey`, `Candidate`, `SourceInfo`, `TrustStore`, `all_snapshots`, `review-index`,
  `store-repair`, `Command::new`, `openat`, and `flock`. Search Git history only to test a specific
  reuse claim. At plan time the deleted alpha core contains immediate links into a live library,
  not v1 source custody; it is incompatibility evidence and must not be restored, renamed, or
  wrapped.
- Reconfirm the installed APIs before selecting dependencies: `base64` is already direct in
  `grimoire-pack`; `rustix 1.1` is already locked transitively and exposes `openat`, `flock`,
  `fsync`, and `renameat` on the supported Unix targets. Add them directly only where the
  implementation uses them. Do not substitute a checkout-oriented Git library, shell command,
  async runtime, network client, or whole-tree copy helper for the injected command and
  directory-relative custody boundaries.
- Re-measure with
  `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core -- --list && RUSTC_WRAPPER= cargo check --workspace`.
  The planning baseline has 24 listed core integration tests, zero core unit/doc tests, and a green
  workspace check. Amend the plan instead of coding around a changed API or test baseline.

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Published hard cut only.** The published spec and approved roadmap are the sole product,
  format, and sequencing authority. No source catalog, alpha library, agent target, live-link
  default, install log, compatibility reader, force/adopt path, migration, registry, hidden update,
  or per-skill revision may return.
- **Phase boundary.** Phase 3 owns source identity and transport policy, local pinned/live and
  remote Git observation, bare cache, safe review exports, scope/alias candidates, immutable store
  materialization and verification, the separate store-repair journal, source/trust facts and
  diffs, exact/all-snapshots trust persistence authority, and the shared locks those workflows
  require. It enriches `WorldState`, `Plan`, and `Preconditions`. It does not reconcile desired
  links, execute general scope plans, write the scope operation journal, maintain the project
  index, prune snapshots, parse commands, render output, or build the final CLI/TUI adapters.
- **Fetch and inspection are inert.** `fetch_source` and `inspect_source` are the only mutation
  workflows outside `Plan`: they may update a bare mirror, verified review export, and one
  scope/alias candidate, but never manifest or lock bytes, installed links, trust, an accepted
  baseline, or the immutable store. Store materialization is a separate executor preparation from
  an already planned candidate. `update` consumes a cached candidate already present in one
  immutable world and never fetches.
- **One identity, one snapshot unit.** Canonical remote or raw local identity determines
  `source-key@1`; commit, repository tree, and inventory determine `snapshot-key@1`; commit/tree,
  inventory, and review tree determine `review-key@1`. Use the spec's null/present framing and
  lowercase SHA-256 byte grammar exactly. A scope may not bind one canonical identity to two
  aliases. Committed state retains the declared portable value, never a canonical local, cache,
  review, store, temporary, or materialization path. Each pinned Git lock source carries the
  canonical inventory digest alongside commit/tree so frozen mode derives its snapshot key without
  candidate, cache, or trust state.
- **Data only, never execution.** Git content is read from objects, not checked out through filters.
  Source hooks, recursive submodules, remote helpers selected by rejected schemes, LFS/smudge
  filters, and source executables never run. Review objects clear execute/write modes and never
  create links or submodule directories. Store materialization preserves only the normalized
  executable bit and safe internal links from the already verified reviewed-entry set.
- **Hostile input is bounded before custody.** `git fetch --keep --depth=1 --stdin` requests exactly
  one forced refspec into a fixed app-private ref and one received pack; omitted refs first use
  bounded `git ls-remote --symref`. Both commands share one 600-second deadline and a dedicated
  process group with a 256-MiB per-file ceiling. Linux adds a hard 512-MiB address-space ceiling;
  macOS supervision samples aggregate process-group resident footprint at least every 5 ms and
  kills at 384 MiB, preserving 128 MiB headroom. Missing enforcement fails closed. One indexing
  thread plus 16-MiB delta-base/large-blob thresholds bound Git's normal memory use. Reverse
  indexes/maintenance are disabled, metadata is capped, and the complete cache must be at most 256
  MiB before publication.
  Control/diagnostic output buffers stop at 1 MiB per stream, while tree/blob payloads stream
  directly into `grimoire-pack`; enumeration, frontmatter, and 128-MiB cumulative reviewed bytes
  use counting/streaming boundaries that stop before their limits. There is no separate
  regular-file limit. A finding without a stopped read is not enforcement.
- **Held local roots.** Resolve local identity once to an absolute root, open every component with
  no-follow directory semantics, retain directory handles, and perform directory-relative no-follow
  reads. Revalidate device, inode, type, applicable size, mtime, and ctime for every traversed
  directory and entry plus pinned Git directory/commondir custody and cleanliness before
  publication. Frozen pinned-local reuse requires the original root to exist with the same
  canonical identity. A swap, dirty pinned checkout, changed read, outside canary, or symlinked
  component is stale or blocked; it never becomes live implicitly.
- **Lossless review, stricter activation.** A review export remains available for invalid UTF-8,
  collision, host-unrepresentable, escaping-link, invalid-link, and inert submodule facts. An
  installable pinned snapshot exists only when the complete canonical inventory is valid. The
  reviewed-entry set, review-tree digest, index order, raw-byte fallbacks, boundary owner, and
  safety/reason facts come from `grimoire-pack` and remain identical across review, source info,
  diff, candidate, and materialization decisions.
- **Immutable store and repair.** New snapshots are assembled in a transaction-private sibling,
  verified, made read-only, and renamed once to their derived key. Existing valid entries are
  reused; corrupt entries are never edited in place. Repair uses only the dedicated
  `transactions/store-repair/<source-key>/<snapshot-key>.json` quarantine-swap protocol, rederives
  and contains every path, is idempotent after every fault point, and never exposes mixed content.
  Project/scope transaction recovery remains Phase 4.
- **Ordered custody.** Shared locks have one typed acquisition order: `store`, `trust`, `projects`,
  then scope. Phase 3 exercises store, trust, and scope; it reserves rather than bypasses the
  projects position. A later lock cannot acquire an earlier one. Candidate preparation occurs
  outside the scope lock; publication takes only the required earlier shared locks and then the
  scope lock, revalidates declaration bytes and canonical identity, and atomically replaces that
  alias's record. A scope/alias candidate mutex is acquired before any other lock and held across
  fetch preparation and publication, preventing an older observation of the same declaration from
  overwriting a newer candidate. A source-key cache mutex, acquired after the candidate mutex and
  released before shared-state locks, serializes fixed bare-cache mutation across scopes. Candidate
  publication takes shared `store.lock` before the scope lock and holds both through rename/fsync so
  prune cannot miss a new reference. Lock files and state are under resolved
  `Paths::grimoire_home`; core never reads environment variables or cwd.
- **Trust is identity-wide and local.** The exact authority is `grimoire/trust@1`, keyed by source
  key and carrying canonical identity, sorted exact receipts, required boolean `all_snapshots`, and one
  accepted/reviewed diff baseline. Exact trust binds full commit, tree, and inventory. Live sources
  require all-snapshots and never receive exact receipts. Fetch never advances a baseline;
  trust-all alone never advances desired or installed state; successful install/reconcile/update
  link creation or repointing advances its accepted baseline. Revocation clears authorization for every
  alias sharing the identity but retains the last baseline and never silently uninstalls it.
  Removing the final alias leaves trust listable and revocable.
- **Planner remains pure.** `WorldState` receives candidate bytes/identity, store existence and
  integrity, trust bytes/revision, and source observations from loaders. Planning only compares
  that immutable observation. Candidate identity/bytes, snapshot existence/integrity, and trust
  revision become serializable preconditions; missing trust or store integrity blocks activation,
  while removal of an already active untrusted request stays possible. Phase 4 alone re-observes
  and applies them.
- **Adapter boundary.** Core receives resolved paths, a structured `GitRunner`, and explicit
  filesystem/lock/fault boundaries. It never invokes a shell or reads process environment. The
  `skill-grimoire` crate owns the one production `std::process::Command` adapter and later owns
  environment resolution/rendering; Phase 3 may construct that narrow runtime without adding CLI
  grammar or UI decisions. Tests use recorders and temporary repositories.
- **Sanitized Git boundary.** Validate and fully qualify refs before command construction. Fetch
  passes the validated repository, which cannot begin with `-`, as its sole positional operand to
  `git fetch --stdin` and writes exactly one LF-terminated forced refspec from the validated source
  to fixed `refs/grimoire/candidate`; no refspec reaches fetch argv. Omitted-ref discovery uses
  bounded `git ls-remote --symref --exit-code <repository>` and selects only one exact-`HEAD`
  symref/OID pair, ignoring other valid refs including names ending in `/HEAD`. Use
  `--end-of-options` only for other Git commands whose supported interface provides it, and prevent
  ambient config/environment from rewriting transport, replacing objects, rebinding repository
  state, enabling another protocol, or installing hooks. Preserve only structured app inputs: a
  validated SSH-agent socket and/or app-owned askpass callback. The Git operation receives no
  arbitrary ambient credential-helper command.
- **Public type floor and schemas.** Shared public values derive `Debug`, `Clone`, `PartialEq`, and
  `Eq`; key/identity/enum values additionally derive `Hash`, `Ord`, and `PartialOrd` where maps or
  sets require them. Domain types do not derive wire formats merely for convenience. Private
  adapters own `candidate@1`, `review-index@1`, `trust@1`, repair-journal, and `source-info@1` field
  names, tagged variants, null/fallback rules, sorting, and byte-exact output. Persisted-state
  adapters reject unknown fields and cross-check derived keys; `source-info@1` remains an
  output-facing additive schema whose readers may ignore added fields.
- **Determinism and red proofs.** Use `BTreeMap`/`BTreeSet` and explicit raw-byte ordering. Every
  security/absence guard gets a controlled red proof: invalid transport before Git, hook/filter
  execution, source execution, no-follow containment, stale declaration, candidate race, unsafe
  review path, resource bound, store digest, lock inversion, exact-receipt identity, trust-all
  inertness, baseline movement, live frozen refusal, and repair fault recovery. Slice 7 maps every
  guard to its exact test, disabled mechanism, and forbidden observed outcome. A green negative
  assertion without the corresponding disabled-guard failure is insufficient.
- **Dependencies and portability.** Keep synchronous macOS/Linux support. Add `base64` and the
  narrow `rustix` filesystem features directly to `grimoire-core`, and add `libc` directly to
  `skill-grimoire` for process groups/resource limits plus narrow macOS `libproc` FFI; keep
  `tempfile` and fixture helpers test-only. Do not add `tokio`, `reqwest`, `git2`, `walkdir`, shell
  parsing, platform copy abstractions, presentation crates, or a second hashing/discovery
  implementation.
- **Tree custody.** Every non-Git command runs with
  `cd /Users/cscott/Repos/grimoire/.workstreams/app && ...` in the same tool call; every Git command
  uses `git -C /Users/cscott/Repos/grimoire/.workstreams/app`. The main session is the only writer.
  Root-checkout probes are read-only and preserve unrelated root files.
- **Gate.** Every slice starts with a failing targeted test, ends with that test green, and runs
  `RUSTC_WRAPPER= cargo check --workspace`. The phase gate additionally runs formatting, all
  workspace tests, clippy with warnings denied, Skill Builder lint/tests, repository integrations,
  pack dogfood/availability, both worktree/root layout probes, and hard-cut searches.

## Slices

- [x] **Slice 1: One untrusted remote becomes inspectable and nothing becomes active** <requires: —>
  - Files: modify `crates/grimoire-pack/src/inventory/tree.rs`,
    `crates/grimoire-pack/src/inventory/scan.rs`,
    `crates/grimoire-pack/src/inventory/tests/mod.rs`,
    `crates/grimoire-pack/src/inventory/tests/support.rs`,
    `crates/grimoire-pack/src/inventory/tests/red_proofs.rs`,
    `crates/grimoire-pack/src/inventory/tests/tracer.rs`,
    `crates/grimoire-pack/src/inventory/tests/finding_contract.rs`,
    `crates/grimoire-pack/tests/support/inventory.rs`,
    `crates/grimoire-core/Cargo.toml`, `Cargo.lock`,
    `crates/grimoire-core/src/lib.rs`, `crates/grimoire-core/src/error.rs`,
    `crates/grimoire-core/src/model.rs`, `crates/grimoire-core/src/scope.rs`,
    `crates/grimoire/Cargo.toml`, and `crates/grimoire/src/lib.rs`; create
    `crates/grimoire-core/src/source/mod.rs`,
    `crates/grimoire-core/src/source/identity.rs`,
    `crates/grimoire-core/src/source/git.rs`,
    `crates/grimoire-core/src/source/review.rs`,
    `crates/grimoire-core/src/source/candidate.rs`,
    `crates/grimoire-core/src/source/info.rs`,
    `crates/grimoire-core/src/locks.rs`,
    `crates/grimoire-core/tests/support/source.rs`,
    `crates/grimoire-core/tests/source_tracer.rs`,
    `crates/grimoire/src/runtime.rs`, and `crates/grimoire/tests/source_runtime.rs`.
  - Change: first harden the inventory substrate used by every untrusted backend. Replace unbounded
    entry collection and whole-file reads with bounded enumeration/counting readers, bounded
    frontmatter reads, streaming content hashing, and a 128-MiB cumulative reviewed-byte budget that
    stops before the configured entry or byte limit. Migrate every `impl TreeReader` found at Task
    0 to the bounded interface. Preserve the canonical inventory/finding grammar while making each
    existing limit enforce custody rather than merely report it.

    Extend `Paths` with exact trust, cache/git, cache/review, cache/tmp, candidate, per-alias and
    source-key cache mutexes, store, lock, and source-plus-snapshot store-repair locations derived only from resolved
    scope/home facts. Define validated
    `CanonicalIdentity`, `SourceKey`, `SnapshotKey`, `ReviewKey`, `CandidateRecord`, `ReviewExport`,
    and the minimal complete trait floor for `GitRunner` and source publication. Keep their wire
    adapters private. Implement the complete `candidate@1` wire shape for tracer-supported values,
    including source-key rederivation/cross-checking and exact declaration/scope-key framing; later
    slices widen accepted input variants without changing the schema. Implement the first
    HTTPS/GitHub identity path and exact key framing needed by the tracer. Build a bare mirror in a
    per-source temporary path through structured Git arguments,
    resolve one full commit and tree, enumerate/read blobs and links directly from Git objects
    through a `TreeReader`, and feed that one reader into `grimoire_pack::inventory::scan`.

    Write a content-addressed review export whose `index.json` and read-only regular-file objects
    correspond to the inventory's exact `reviewed_entries`; create no checkout, symlink, submodule
    directory, or executable review object. Add the minimal typed lock coordinator needed by the
    tracer, reserving the complete `store < trust < projects < scope` order. Acquire the
    scope/alias candidate mutex before reading the declaration and hold it through preparation and
    publication; it is never acquired while another Grimoire lock is held. The source-key cache
    mutex is acquired after it for fixed-mirror verification/mutation and released before
    shared-state locks. Preparation occurs in
    per-source temporary storage outside the scope lock. Before final review-index/candidate
    publication, acquire every applicable shared lock in order and then the scope lock, reread the
    matching manifest declaration's exact owned TOML key/value spans, length-frame their key names
    and raw value bytes in lexical key order, and match that hash plus canonical identity. Only then
    atomically publish one strict `grimoire/candidate@1` record. Pin this declaration-hash projection
    with byte goldens rather than hashing unrelated comments or whole-manifest bytes. Derive a
    minimal complete `SourceInfo` from the candidate, export, inventory, and an untrusted
    observation. The candidate stores declaration hash, canonical identity, nullable commit/tree,
    inventory, and review-tree digest only; snapshot/review keys and absolute paths are derived.

    Add the one production `SystemGitRunner` in `skill-grimoire`; it executes argv without a shell,
    rejects embedded NUL/LF, qualifies refs, and invokes
    `git fetch --keep --depth=1 --no-tags --no-recurse-submodules --no-write-fetch-head --no-write-commit-graph --no-auto-maintenance --no-progress --stdin <validated-repository>`.
    Bounded stdin contains only
    `+<validated-fully-qualified-ref-or-object-ID>:refs/grimoire/candidate\n`; the fixed private ref
    is cache-local evidence and never enters candidate, lock, snapshot, review, or trust identity.
    An omitted ref first runs bounded
    `git ls-remote --symref --exit-code <validated-repository>`, selects exactly one valid symref/OID
    pair whose reported ref is exactly `HEAD`, ignores other valid advertised refs including
    `*/HEAD`, and fetches the advertised fully qualified ref. Missing/conflicting/malformed HEAD
    records or control output above 1 MiB fail. Both commands share one 600-second deadline and the
    same sanitized Git config/environment, protocol, credential, output, and process controls. Use
    `--end-of-options` only on other Git commands that support it. It accepts only a validated
    SSH-agent socket and/or app-owned askpass callback.

    Put each local Git command tree in one dedicated process group with a 256-MiB OS per-file
    limit. On Linux every member inherits a hard 512-MiB OS address-space limit. On macOS a
    parent-owned supervisor samples and sums resident footprint for every process-group member at
    least every 5 ms and kills the whole group at 384 MiB, retaining 128 MiB headroom; it is
    supervised rather than kernel-hard. Use narrow `proc_listpgrppids` plus
    `proc_pid_rusage(RUSAGE_INFO_V4)` bindings and count the larger reported resident/physical
    footprint for each member. Failure to install the Linux limit, enumerate/read the macOS group,
    or retain supervision fails closed. Supply app-owned
    `pack.writeReverseIndex=false`, `pack.threads=1`, `core.deltaBaseCacheLimit=16m`, and
    `core.bigFileThreshold=16m`; kill the whole group on any limit or deadline. Enforce
    one-pack/one-index shape, 1-MiB aggregate repository metadata, and a 256-MiB complete-cache
    publication limit. Separate runner methods buffer control/diagnostic output up to 1 MiB per
    stream or stream tree/blob payloads directly into inventory entry/byte guards. The core tracer
    uses an injected runner backed by a temporary local bare repository, places a fail-if-run
    executable in the source, and proves the candidate and `SourceInfo` facts without any
    manifest/lock/link/trust/store change or canary execution. A production-command integration
    test invokes the host Git executable against a local fixture and proves the exact supported
    `fetch --stdin` argv/stdin/private-ref shape succeeds for a named ref and full OID; its recorder
    proves no refspec enters argv. A host-Git HTTPS smoke test proves the production command reaches
    HTTPS transport rather than a plumbing-only protocol path. Omitted-ref fixtures pin exact-HEAD
    selection amid distracting `*/HEAD` refs plus malformed/conflicting output and race behavior.
    Runtime tests seed ambient URL
    rewrite, replace/object-path, hook, and protocol canaries and prove none can affect submitted
    operations. A local bare repository is test transport only, never an accepted end-user source
    location. This thin tracer exercises one publisher, but it uses the production
    lock/revalidation path; later slices widen the validated grammars and add contention coverage
    without adding a second publication path.
  - Verify: first make
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-pack inventory::tests && RUSTC_WRAPPER= cargo test -p grimoire-core --test source_tracer && RUSTC_WRAPPER= cargo test -p skill-grimoire --test source_runtime`
    fail because no source workflow exists, then make both pass with byte-exact candidate/review
    goldens and value-exact `SourceInfo` assertions. Pause once between preparation and publication,
    change the declaration, and prove revalidation returns stale while preserving the prior
    candidate; disable that revalidation guard once and prove the red arm fails. Counting-reader
    fixtures hit each entry/frontmatter/128-MiB-cumulative-byte boundary, and disabling each bound
    proves its red arm consumes or enumerates past the limit. Runner fixtures cross each time,
    Linux address-space/macOS aggregate-RSS/file/shape/metadata/final-cache and control-output
    budget and prove whole-group termination plus zero publication; missing platform enforcement
    fails closed. Under a safe reduced test threshold, compact packs with exaggerated object counts
    and delta-result declarations hit the memory boundary; disabling only that guard lets a bounded
    canary allocation complete, proving the red arm without risking host exhaustion. A blob and tree
    listing each above 1 MiB but within inventory limits succeed only through payload streaming;
    disabled payload byte/entry guards hit their red canaries. Expected: one untrusted source is
    fully inspectable, the executable canary is untouched, and before/after manifest, lock, link,
    trust, and store bytes are identical. Run
    `RUSTC_WRAPPER= cargo check --workspace` in the same shell.

- [x] **Slice 2: Complete transport identities and held local-source custody** <requires: 1>
  - Files: create `crates/grimoire-core/src/source/local.rs`,
    `crates/grimoire-core/tests/source_identity.rs`,
    `crates/grimoire-core/tests/source_backends.rs`, and hostile transport/local fixtures under
    `crates/grimoire-core/tests/fixtures/source/`; modify
    `crates/grimoire-core/src/source/identity.rs`,
    `crates/grimoire-core/src/source/git.rs`,
    `crates/grimoire-core/src/source/mod.rs`,
    `crates/grimoire-core/src/error.rs`, `crates/grimoire-core/src/model.rs`,
    `crates/grimoire-core/src/manifest.rs`,
    `crates/grimoire-core/tests/boundary.rs`, and `crates/grimoire/src/runtime.rs`.
  - Change: complete source location validation and conservative canonicalization for GitHub
    shorthand, HTTPS, SSH URI, SCP home-relative SSH, pinned local Git worktrees,
    and explicit live directories. Reject `file://`, `git://`, `ext::`, unknown helpers,
    non-ASCII hosts, userinfo/password violations, whitespace/control/percent/query/fragment,
    malformed ports and IPv6, invalid/trailing-dot DNS labels, empty/repeated/trailing path
    components, absolute or leading-`-` SCP paths, an SCP username whose first byte is not ASCII
    alphanumeric, any submitted repository operand beginning with `-`, invalid GitHub owner/repo
    syntax or shorthand `.git` suffix, and `.`/`..` components before a Git command is submitted.
    Accept only validated branch, fully qualified head/tag, or full-object refs; qualify short refs as
    heads, reject option/ambiguous revision syntax, submit only one forced
    `+<source>:refs/grimoire/candidate` refspec through bounded `git fetch --stdin`, and resolve an
    omitted default branch once through the exact bounded `ls-remote --symref` parser to the
    candidate's actually fetched full commit. Preserve
    expanded HTTPS transport for GitHub shorthand and the original validated transport for other
    inputs while independently canonicalizing identity; raw `github:` never reaches the runner. Preserve
    explicit ports, SCP versus URI path semantics, username/path case, and RFC 5952 IPv6. Pin
    `source-key@1`, `snapshot-key@1`, and `review-key@1` complete preimages with byte goldens,
    including nullable live fields and raw non-UTF-8 local identities.

    Implement `HeldDirectoryReader` over directory file descriptors and `rustix` no-follow
    `openat` operations. Resolve the local root once component-by-component, reject symlinked/root
    swaps, read only directory-relative entries, and revalidate device/inode/type/applicable-size/
    mtime/ctime for every traversed directory and entry around reads and before publication. Bind
    pinned Git directory/commondir and object access to the same custody and reject a nested
    directory, `.git`, gitdir, or commondir swap. Pinned local mode additionally requires a clean
    Git index/worktree, resolves one commit/tree, and reads the committed objects; it never copies
    moving worktree bytes. Frozen pinned-local reuse requires that root to remain present with the
    same canonical identity. Live mode accepts a readable dirty directory, has null commit/tree, creates a new review
    identity when any reviewed entry changes, and stays explicitly non-reproducible. Widen the bare
    backend to all accepted remote transports, disable hooks and recursive submodules, avoid
    checkout/filter/LFS execution, and retain only structured SSH-agent/app-owned-askpass inputs
    without storing credentials. Keep backend observations private and disconnected from Phase 2 resolution and
    link actions until Slice 6 installs trust/store blockers in the same hard cut; do not add a
    compatibility constructor.
  - Verify: run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test source_identity --test source_backends`.
    Table tests exhaust accepted/distinct/rejected URL identities—including GitHub grammar/suffix,
    DNS labels/trailing dot, path components/trailing slash, SCP leading slash, SCP username
    `-git@example.com:repo`, SCP path `git@example.com:-repo`, and URI-only IPv6—before the recording
    runner sees argv; both option-shaped SCP cases prove Git is never invoked, and exact argv proves
    shorthand submits expanded HTTPS. Actual temporary Git tests cover remote, pinned-clean,
    pinned-dirty, and live.
    Race tests
    swap a path component, nested directory, root, regular file, `.git`, gitdir, and commondir around
    reads and prove an outside canary is never opened or published. Frozen tests remove/rebind the
    original root and fail identity validation. Red proofs disable transport, ref qualification,
    sanitized Git state, no-follow, clean-worktree, hooks/filters, and revalidation guards one at a
    time and demonstrate the forbidden outcome. Run
    `RUSTC_WRAPPER= cargo check --workspace` in the same shell.

- [x] **Slice 3: Lossless review exports, complete source information, and factual diffs** <requires: 1, 2>
  - Files: create `crates/grimoire-core/src/source/diff.rs`,
    `crates/grimoire-core/tests/review_export.rs`,
    `crates/grimoire-core/tests/source_info.rs`,
    `crates/grimoire-core/tests/source_diff.rs`, and review/source-info JSON fixtures under
    `crates/grimoire-core/tests/fixtures/source/`; modify
    `crates/grimoire-core/src/source/review.rs`,
    `crates/grimoire-core/src/source/info.rs`,
    `crates/grimoire-core/src/source/candidate.rs`,
    `crates/grimoire-core/src/source/mod.rs`, and `crates/grimoire-core/src/error.rs`.
  - Change: complete `grimoire/review-index@1`: exact reviewed-entry set and raw-byte order;
    boundary and owning-skill projection; normalized mode; file size/hash; exact symlink target and
    internal/escaping/invalid safety with empty/NUL reason; inert submodule commit; conditional
    UTF-8/base64 fields; strict variant-inapplicable-field rejection; object digest
    re-verification; and a best-effort UTF-8 collision-free `tree/` view that is never canonical.
    Index/export writing is temp-plus-fsync-plus-rename, reuses a verified existing export, clears
    write/execute bits on objects, and produces no unsafe filesystem representation even when the
    inventory is invalid. Export/materialization reopens the same stable `TreeReader`; it never
    pretends `SourceInventory` contains file bytes.

    Complete the stable `grimoire/source-info@1` domain and private JSON adapter without changing
    the wire shape introduced by the tracer: source identity,
    snapshot/review path, trust mode/baseline input, skills/files, top-level entries, packs,
    findings, executable/binary/shebang facts, raw paths/targets, and every specified sort/null/
    fallback rule. Serialization is exact and deterministic while downstream schema-1 readers may
    ignore additive fields; strict unknown-field rejection remains limited to persisted state. It
    renders messages as display facts but branches only on canonical finding
    codes/severity/details. Implement one factual `SourceDiff` over an optional prior baseline and
    its verified review export, covering commit, skill/pack/member, file/hash/mode/size/shebang/
    binary, link/submodule, validation, and affected requested/installed roots. Trust selection and
    baseline mutation arrive in Slice 6; this slice accepts an explicit immutable baseline and
    cannot advance it.
  - Verify: run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test review_export --test source_info --test source_diff`.
    Fixtures include invalid UTF-8, Unicode collision keys, host-unrepresentable names, executable
    files, binary/shebang variants, empty/NUL/internal/escaping links inside and outside skills,
    submodules, ignored and nested-checkout trees, byte/entry limits, missing pack members, and
    tampered index objects. Expected: inspection stays lossless where activation is invalid, no
    review export contains a symlink/executable, `source-info@1` goldens are exact, and changing any
    reviewed live entry changes the review identity/diff. Run `RUSTC_WRAPPER= cargo check --workspace`.

- [x] **Slice 4: Immutable snapshot materialization and crash-safe store repair** <requires: 2, 3>
  - Files: create `crates/grimoire-core/src/store.rs`,
    `crates/grimoire-core/src/store/repair.rs`,
    `crates/grimoire-core/src/store/tests.rs`, and store/repair fixtures under
    `crates/grimoire-core/tests/fixtures/store/`; modify
    `crates/grimoire-core/src/locks.rs`,
    `crates/grimoire-core/src/lib.rs`, `crates/grimoire-core/src/error.rs`,
    `crates/grimoire-core/src/model.rs`, `crates/grimoire-core/src/scope.rs`,
    `crates/grimoire-core/src/source/review.rs`, and `crates/grimoire-core/Cargo.toml`.
  - Change: define crate-private `StoreObservation::{Absent, Valid, Corrupt}` plus assembly,
    materialization, repair, and verification entry points. They remain unreachable from adapters
    and accept no general candidate-to-store call; Slice 6 alone connects them to an opaque,
    plan-produced materialization intent. The verifier reconstructs
    canonical inventory/skill digests from a fixed snapshot root without following links or
    trusting writable metadata. Materialize a valid pinned candidate from its verified review
    export into a transaction-private sibling containing exactly the reviewed entries and parent
    directories: regular bytes are digest-verified, executable files retain execute but lose write,
    non-executables become read-only, and safe internal links preserve exact targets. An outer
    submodule remains an inert review fact and is omitted without invalidating the snapshot; a
    submodule inside a skill is already a source-wide validation error. Invalid/escaping links,
    special entries, traversal, collisions, and every other source-invalid inventory block the
    complete snapshot. Verify the result before one atomic rename to
    `store/checkouts/<source-key>/<snapshot-key>`; reuse only an already valid entry. Live sources
    never receive a snapshot key or store directory.

    Widen the tracer's typed shared-lock coordinator with the `rustix::flock` store modes and
    runtime/type-state order checks needed by materialization and repair, preserving
    `store < trust < projects < scope`. Implement strict create-new store-repair journal bytes keyed
    by both source and snapshot. The journal stores only derived relative locations; every recovery
    open/rename rederives keys and proves containment below the store or transaction root. Then run
    the quarantine-swap state machine: prepare/verify replacement,
    exclusively lock store, recover any incumbent journal for the pair, reverify corruption, fsync
    journal, rename fixed to private quarantine,
    rename replacement to fixed, restore immediately on ordinary second-rename failure, and recover
    idempotently after every crash point. Recovery keeps a verified fixed entry and deletes
    quarantine, otherwise restores quarantine and discards incomplete replacement, fsyncing the
    store parent before journal removal. It never reads or repairs a Phase 4 scope journal.
  - Verify: run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core store::tests`.
    Tests cover exact entry/mode/link materialization, origin mutation after materialization,
    offline reuse, missing/corrupt files, link escape, object tamper, and skill-digest verification.
    A fault injector stops before/after every journal/fsync/rename/removal and repeated recovery
    proves one valid fixed snapshot or the original quarantine, never mixed bytes. Fixtures give
    two source identities the same snapshot key and prove their journals cannot collide; tampered
    journal paths cannot reach an outside canary. Red proofs disable integrity, mode, boundary,
    journal containment, and store-lock/order guards. Run
    `RUSTC_WRAPPER= cargo check --workspace`.

- [x] **Slice 5: Race-safe candidate publication and ordered source workflows** <requires: 1, 2, 3, 4>
  - Files: create `crates/grimoire-core/tests/candidate.rs`,
    `crates/grimoire-core/tests/source_concurrency.rs`, and candidate fixtures under
    `crates/grimoire-core/tests/fixtures/source/`; modify
    `crates/grimoire-core/src/locks.rs`,
    `crates/grimoire-core/src/source/mod.rs`,
    `crates/grimoire-core/src/source/git.rs`,
    `crates/grimoire-core/src/source/local.rs`,
    `crates/grimoire-core/src/source/candidate.rs`,
    `crates/grimoire-core/src/source/review.rs`,
    `crates/grimoire-core/src/scope.rs`,
    `crates/grimoire-core/src/error.rs`, and `crates/grimoire/src/runtime.rs`.
  - Change: complete `fetch_source` and `inspect_source` as one re-entrant custody machine.
    Acquire the scope/alias candidate mutex before reading the declaration and hold it until the
    workflow publishes or aborts; never acquire it while holding another Grimoire lock. Preparation
    uses unique per-source temporary directories with no scope lock; different aliases may inspect
    independently. Acquire the source-key cache mutex after the candidate mutex to serialize every
    verification/mutation of `cache/git/<source-key>.git` across scopes, then release it before
    shared-state locks. Enforce the selected-ref single-pack `git fetch --stdin`, bounded omitted-
    HEAD discovery, shared 600-second deadline, Linux hard 512-MiB address-space or macOS supervised
    384-MiB aggregate-RSS process-group boundary, app-owned single-thread/16-MiB Git memory
    configuration, 256-MiB per-file limit, one-pack/one-index shape, 1-MiB aggregate repository
    metadata, 256-MiB final-cache, and 1-MiB
    buffered control-output budgets; payload listings/blobs stream into inventory bounds. Any
    breach discards temporary state and publishes nothing.
    Publish only a fully verified temporary bare repository: rename an incumbent to a unique
    sibling, rename/fsync the new fixed generation, then remove the incumbent. The next cache-lock
    holder recovers one verified fixed/incumbent generation or drops both and refetches; cache
    recovery never grants activation or trust.
    Review-export publication never materializes or repairs the immutable store. Candidate
    publication takes shared `store.lock` and then the scope lock, holding both through candidate
    rename and parent fsync, then rereads the exact source
    declaration, recomputes its declaration hash and canonical identity, and atomically replaces
    only `candidates/<scope-key>/<alias>.json`. A removed/changed/rebound declaration returns stale
    and leaves the prior record byte-identical. Cache/review leftovers are unreferenced data, never
    activation.

    Implement the exact `scope-key@1` grammar from canonical project-root raw bytes with literal
    `global`, and the exact `source-declaration@1` grammar from alias plus owned TOML field/value
    spans; pin both with byte goldens. Within one
    scope, reject a second alias whose canonical identity equals any existing alias's identity;
    different scopes may use independent aliases and refs for that identity without sharing
    candidate bytes. Complete candidate records contain only the normative schema, declaration
    hash, source key, kind, canonical identity projection, nullable commit/tree, inventory, and
    review tree. On read they rederive/cross-check the source key and outer scope/alias identity,
    derive every other key/path, reject unknown/duplicate/wrong-variant data, and verify review
    index/object digests before reuse. A
    fetch may update a candidate but never the existing lock, installed links,
    trust, baseline, or immutable snapshots; an update later pins candidate record bytes and fails
    stale on a concurrent fetch. Add contention tests proving no later lock waits while holding a
    later-order lock, and that rejected publication leaves no staged state behind.
  - Verify: run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test candidate --test source_concurrency && RUSTC_WRAPPER= cargo test -p skill-grimoire --test source_runtime`.
    Matrices cover same-scope rejection of two aliases for one canonical identity, cross-scope
    alias/ref independence, unchanged reuse, declaration removal/edit/identity swap, candidate
    tamper, review tamper, and held-lock permutations. Two scopes fetching different refs for one
    identity prove the source-cache mutex protects the shared mirror; a paused prune proves shared
    store custody prevents deletion across candidate publication. Cache fault points around both
    renames/fsync recover one verified generation or an empty refetchable cache. A paused first fetch plus a queued second
    fetch for the same unchanged declaration proves preparation/publication serialize and the
    second observation is the final candidate; disabling the candidate/cache mutex or shared store
    lease exposes the corresponding stale overwrite, cache race, or prune race.
    Expected: the newest still-valid observation alone remains published, every rejected result is inert, and fetch never
    changes active, desired, trust, baseline, or store state. Run
    `RUSTC_WRAPPER= cargo check --workspace`.

- [x] **Slice 6: Identity-wide trust, candidate-based planning, and frozen/store blockers** <requires: 3, 4, 5>
  - Files: create `crates/grimoire-core/src/trust.rs`,
    `crates/grimoire-core/tests/trust.rs`,
    `crates/grimoire-core/tests/planner_source.rs`, and trust/plan fixtures under
    `crates/grimoire-core/tests/fixtures/trust/`; modify
    `crates/grimoire-core/src/lib.rs`, `crates/grimoire-core/src/error.rs`,
    `crates/grimoire-core/src/model.rs`, `crates/grimoire-core/src/lockfile.rs`,
    `crates/grimoire-core/src/plan.rs`, `crates/grimoire-core/tests/lockfile.rs`,
    `crates/grimoire-core/src/resolve.rs`, `crates/grimoire-core/src/locks.rs`,
    `crates/grimoire-core/src/source/candidate.rs`,
    `crates/grimoire-core/src/source/info.rs`,
    `crates/grimoire-core/src/source/diff.rs`, and all Phase 2 planner/resolution fixtures affected
    by the intentional `WorldState` hard cut.
  - Change: implement strict deterministic `grimoire/trust@1` parsing/writing keyed by source key.
    The root contains exactly schema plus records; each keyed record contains exactly kind,
    canonical identity projection, sorted exact receipts, required boolean all-snapshots policy, and nullable
    baseline. Receipts bind commit/tree/inventory; baselines bind nullable commit/tree plus
    inventory/review tree. Reject unknown/duplicate fields, rederive each source key, and emit
    canonical bytes. Produce pure byte-exact proposed mutations for grant-exact, grant-all, and
    identity-wide revoke; revoke clears receipts/policy but retains the baseline/identity record,
    reject exact trust for live, emit no exact receipt for live all-trust, retain trust after final
    alias removal, and expose aliases only as observed preview facts. Trust-file creation mode and
    atomic staging are executor primitives consumed by Phase 4's journal, not an adapter-facing
    write shortcut. Phase 3 records required creation-mode metadata and proposed bytes but performs
    no standalone trust rename. Fetch never calls them. Exact approval and a pinned `--all` approval set the
    reviewed baseline; later fetch does not. A future trust-all candidate is admissible but changes
    the baseline only in the eventual successful install/reconcile/update action that creates or
    repoints links. Live baseline changes only on another
    explicit `--all` approval.

    Only in this slice connect the previously private backend/store observations to resolution and
    plan actions, simultaneously installing trust, validation, and store blockers. Replace
    `Request::UpdateSource { snapshot }` with a candidate-selecting request that reads only
    the world's validated cached candidate. Extend immutable `WorldState` with candidate bytes and
    identity, trust bytes/revision, store observations, and review/source facts; update existing
    tests rather than preserving a caller-invented compatibility path. Extend `Request`, `Action`,
    `Blocker`, `PlanFact`, and `Preconditions` for candidate selection, an opaque plan-gated
    snapshot-materialization intent consumed only by the crate-private store path,
    exact/all trust, baseline update, identity-wide revocation, candidate/trust/store preconditions,
    and affected aliases/roots. Source update never fetches and moves every affected skill from one
    source snapshot together. Link create/repoint requires exact or all trust plus a valid or
    materializable pinned store entry; frozen mode requires the exact valid stored snapshot,
    refuses live, and performs no network access. Untrusted installed content is reported and
    cannot be created or repointed, but an owned request/link may still be removed. Trust-all alone
    never changes lock, links, or desired state; revocation is destructive but never uninstalls.
    Source info and diff derive their trust mode/baseline from this same authority.

    Hard-cut pinned Git `LockSource` to require the canonical inventory digest alongside declared
    location, ref, commit, and tree. Parse/write it deterministically, derive the snapshot key from
    lock commit/tree/inventory in frozen mode, and never consult candidate/cache/trust baselines to
    locate a locked store entry. Live lock entries reject the Git-only inventory field.
  - Verify: run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test trust --test planner_source --test source_info --test source_diff --test lockfile --test planner --test resolution`.
    Trust matrices cover exact reuse/change, commit/tree/inventory identity, all-trust inertness,
    live rules, identity URL change, alias sharing, final-alias removal, revoke-by-key, candidate
    races, required-boolean grant/revoke goldens, revocation with retained baseline, and baseline
    transitions including trust-all, fetch-newer, then first install. Trusting an exact or
    all-snapshots candidate whose inventory is validation-invalid still permits source info/diff
    but leaves create/repoint/update blocked; disabling the validation blocker proves the red arm.
    Candidate/cache-free frozen fixtures include multiple stored snapshots plus an identity-wide
    baseline pointing elsewhere and select only the lock-derived snapshot. Planner matrices cover missing/stale candidate, absent/valid/
    corrupt store, trust blockers, frozen offline success/failure, multi-skill source update,
    untrusted removal, and serialized preconditions. Controlled red proofs show that `--yes`/an
    approval value cannot broaden trust, fetch cannot advance baseline, update cannot fetch or
    substitute a newer candidate, and revocation cannot infer uninstall. Run
    `RUSTC_WRAPPER= cargo check --workspace`.

- [x] **Slice 7: Complete Phase 3 security matrices and hard-cut gate** <requires: 1, 2, 3, 4, 5, 6>
  - Files: create `crates/grimoire-core/tests/source_boundary.rs`; modify
    `crates/grimoire-core/tests/boundary.rs`, `crates/grimoire-core/src/lib.rs`,
    `crates/grimoire-core/Cargo.toml`, `crates/grimoire/src/lib.rs`,
    `crates/grimoire/Cargo.toml`, `Cargo.lock`, and `README.md`; update only Phase 3 fixtures/tests
    needed to close uncovered contract rows.
  - Change: run a spec-to-plan coverage sweep across every Source identities/fetching/snapshots,
    Trust/capability review, source/store/trust verification, and Phase 3 roadmap requirement. Add
    one executable security matrix mapping each guard to the exact test, the mechanism disabled for
    its red arm, and the forbidden observation that must then occur. Add the missing test or red
    proof for any uncovered row; do not widen into link application, scope
    journal, projects index/prune, CLI grammar/rendering, or TUI state. Tighten boundary tests so
    `grimoire-core` remains environment-, shell-, CLI-, UI-, and async-free; `plan` remains pure;
    Git process construction exists only in `skill-grimoire::runtime`; filesystem mutation is
    confined to named source/review/store/lock/repair modules; and no source content execution,
    checkout/filter path, alpha type, or second inventory authority is reachable. Pin all stable
    schema/key byte goldens and public exports, including candidate/trust outer-key cross-checks,
    declaration/scope framing, review boundary framing, and source-info additive-reader behavior.
    Update README status to say Phase 1 inventory,
    Phase 2 planner, and Phase 3 source custody/trust foundations are complete and transactional
    core operations are next; do not claim install/apply/CLI/TUI completion.
  - Verify: first run the targeted Phase 3 suite:
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-pack inventory::tests && RUSTC_WRAPPER= cargo test -p grimoire-core store::tests && RUSTC_WRAPPER= cargo test -p grimoire-core --test source_tracer --test source_identity --test source_backends --test review_export --test source_info --test source_diff --test candidate --test source_concurrency --test trust --test planner_source --test lockfile --test source_boundary && RUSTC_WRAPPER= cargo test -p skill-grimoire --test source_runtime`.
    Prove the hard cut with
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && ! rg -n '(LiveLibrary|LibraryConfig|InstallLog|AgentTarget|ImmediateInstall|ImmediateRemove|git2|reqwest|tokio)' crates/grimoire-core/src crates/grimoire/src`;
    expected: no forbidden production hit. Then run these exact gates:
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo fmt --all -- --check`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test --workspace`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo clippy --workspace --all-targets -- -D warnings`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && skills/skill-builder/scripts/skills-lint.sh`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && skills/skill-builder/scripts/tests/run.sh`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && scripts/tests/run.sh`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-pack --test clankshop --test pack_availability`, and
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && GRIMOIRE_LIVE_ROOT=/Users/cscott/Repos/grimoire RUSTC_WRAPPER= cargo test -p grimoire-pack --test live_root_layout`.
    Expected: every gate is green. The documented unrelated archived-record ledger failure remains
    outside this stream and is not permission to weaken a Phase 3 gate.

## Done when

- Every accepted source location has one conservative canonical identity and stable source,
  snapshot, and review keys; rejected transports reach no Git runner, and pinned/live local reads
  cannot escape or publish a mixed observation.
- Fetch and inspection produce verified bare-cache, review-export, candidate, source-info, and diff
  facts without executing source content or changing manifest, lock, links, trust, store, or
  accepted baseline state; the separate materialization path produces an immutable verified store
  entry only from a planned valid pinned candidate.
- Review exports preserve every required hostile/raw fact without unsafe materialization; valid
  pinned snapshots alone materialize immutably, verify before reuse, and recover idempotently from
  every quarantine-swap fault point.
- Candidate publication is atomic after declaration/identity revalidation under the documented
  lock order, stays scope/alias-specific, and cannot race a newer declaration into a stale update.
- `grimoire/trust@1` implements exact, all-snapshots, live, baseline, identity-wide revocation, and
  final-alias behavior; trust-all/fetch remain inert and no approval flag can grant trust.
- The pure planner consumes cached candidate, store, and trust observations, serializes their
  preconditions/actions/blockers, refuses untrusted/corrupt/live-frozen activation, permits owned
  removal, and never fetches, replans, or mutates.
- No desired-link executor, scope transaction/recovery, project index/prune, CLI/TUI policy,
  ambient core access, alpha compatibility, or second inventory/digest authority has entered the
  phase; formatting, full workspace tests, clippy, skill/repository integrations, dogfood, and both
  layout probes are green.

_On completion (before landing), run the host's close-the-books sweep._
