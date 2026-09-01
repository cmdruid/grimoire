---
doctype: plans
status: published
stage: implemented
schema: contractor/plan@1
tags: [plan]
---

# Grimoire Phase 1 format and inventory foundation — Implementation Plan

Build the new pre-trust format authority as a backend-neutral source-tree scan, prove one complete
inventory first, then widen every hostile-input boundary. The final slice cuts consumers over by
removing the alpha model rather than adapting it. Every slice is independently committable; only
the phase gate permits the temporary coexistence used while the replacement is being built.

Spec: `.records/specs/2026-08-31-grimoire-symlink-package-manager.md` and Phase 1 of
`.records/plans/2026-09-01-grimoire-hard-cut-rewrite-roadmap.md`

## Task 0 — Re-ground before editing

This task is read-only and produces no commit.

- Re-run `git -C /Users/cscott/Repos/grimoire/.workstreams/app status --short --branch`,
  `git -C /Users/cscott/Repos/grimoire/.workstreams/app log stream/app..main --oneline`, and
  `git -C /Users/cscott/Repos/grimoire/.workstreams/app worktree list --porcelain`. Stop for a
  staged change, a moved `main`, or a newly overlapping stream before editing.
- Re-run Contractor's ground check, then read Phase 1 of the approved roadmap and the spec's
  Discovery and names, canonical skill-content/source-inventory/review-tree grammars, `PACK.md`,
  and Format and discovery verification sections. Confirm the spec remains published.
- Narrow with `rg` across `crates/`, `install.sh`, `scripts/tests/`, `PACK.md`, `README.md`,
  `AGENTS.md`, and `skills/skill-builder/` for `grimoire_pack::`, `PackShape`, `faced`, `faceless`,
  `member_hash`, `pack-format`, and `install.sh`; then let `cargo check --workspace` determine
  which candidates are compiled production consumers. The current narrow pass finds the old API in
  `grimoire-core`, `skill-grimoire`, the shell installer, its repository integration test, and the
  root pack/documentation surfaces.
- Search capability-wide for existing source-inventory, raw-path, capability, shebang,
  canonical-digest, and Unicode 17 collision-table/generator implementations. At plan time,
  neither `source-inventory@1` nor a pinned Unicode 17 implementation exists; the only relevant
  prior art is the incompatible filesystem walker/hash in `grimoire-pack` and the shell hash.
  Slice 3 owns acquiring and pinning the Unicode inputs; changing them later is a format decision.
- Reconfirm the selected `yaml-rust2` event API before adding it. The plan relies on events exposing
  aliases, nonzero anchor ids, optional tags, mapping/sequence boundaries, and scalar style so the
  parser can reject forbidden constructs before building a value tree. If that API has changed,
  stop and amend this plan rather than silently choosing a different parser model.
- Re-measure the test surface with `cargo test -p grimoire-pack -- --list` and list the root-layout
  tests.

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Published contract only.** The new spec and approved roadmap govern. Old design documents,
  `docs/spec/pack-format.md`, `install.sh`, and current APIs are evidence to delete, not
  compatibility requirements.
- **No execution.** Inventory opens and streams bytes only. The scanner never asks a reader to
  descend through a symlink, invokes no discovered file, runs no Git, reads no process environment,
  and does not interpret a Markdown body. `TreeReader` requires stable no-follow custody; Phase 1's
  filesystem reader is test-only over controlled fixtures, while Phase 3 owns the production local
  adapter and its descriptor-relative path-swap defenses.
- **One bounded authority.** Parsing is capped at the spec's 64-KiB frontmatter, 4,096-node, and
  depth-16 populations. Traversal uses the fixed ignore set and fails—never partially succeeds—at
  32 directory levels or 100,000 total outer-plus-skill entries, counted once. Reviewed regular
  files are capped at 1 GiB. Production limits are not configurable; limit findings report the
  first rejected value.
- **Raw bytes first.** Tree order, findings, digests, symlink targets, and path collision evidence
  retain Unix path bytes. UTF-8 conversion is an explicit validation/projection step; lossy path
  conversion never contributes to identity or a receipt.
- **Backend-neutral inventory.** Phase 1 owns a `TreeReader` boundary over raw entries and streamed
  file reads. The included filesystem adapter proves local sources; Phase 3 must be able to add a
  Git-tree adapter without duplicating parsing, hashing, capability, or inventory-digest logic.
- **Public type floor.** New shared value types pin `Debug`, `Clone`, `PartialEq`, and `Eq`; digest,
  path, severity, entry-kind, boundary, and safety enums/newtypes also pin `Hash`, `Ord`, and
  `PartialOrd` where their values are map/set keys. Do not derive serialization onto the domain
  model in this phase; the Phase 3 schema adapter owns JSON field names.
- **Validation is data.** Malformed source content becomes stable-code `Finding` values so an
  untrusted source remains inspectable. Transport or local I/O failure remains a typed operation
  error. Human messages and absolute paths never contribute to `source-inventory@1`.
- **Phase boundary.** Phase 1 owns raw capability/review facts plus
  `skill-content@1`, `source-inventory@1`, and `review-tree@1` bytes. It does not serialize
  `source-info@1` or `review-index@1`, canonicalize source URLs, produce source/snapshot/review
  keys, publish cache entries, or materialize the store; those remain Phase 3 custody work.
- **Red proofs.** Internal production rules use one strict policy. Test-only entry points may
  disable one named guard; each absence/security test runs the same invariant with that guard off
  and proves the invariant becomes false. No configurable guard surface enters the public API.
- **Hard-cut seam.** New code may coexist temporarily under `grimoire_pack::inventory` during this
  phase, but no compatibility adapter maps old pack/lock types into it. The final slice deletes the
  alpha parser, face model, lock, live-library core, immediate-action TUI state, and shell installer.
- **Platform and tree custody.** v1 targets macOS and Linux symlinks; Unix byte/mode APIs may be
  explicit. Every command runs from `/Users/cscott/Repos/grimoire/.workstreams/app`; every Git
  command uses `git -C` with that path. Root-checkout probes are read-only and must preserve
  unrelated root files.
- **Root-checkout trap.** Before this branch lands, the root checkout still has the alpha
  `PACK.md`. Its pre-land test must assert layout facts (no discovered content beneath nested
  `.workstreams`) without requiring the root pack to validate. The worktree dogfood test is the
  format-validity authority; Phase 7 owns cross-machine product reproduction.
- **Gate.** Each slice runs its targeted tests and `cargo check --workspace`. The phase gate also
  runs formatting, the full workspace tests, clippy with `-D warnings`, the skills lint,
  repository integrations, and the read-only root-layout probe.

## Slices

- [x] **Slice 1: One source tree becomes one canonical inventory** <requires: —>
  - Files: create `crates/grimoire-pack/src/inventory/mod.rs`,
    `crates/grimoire-pack/src/inventory/model.rs`, `crates/grimoire-pack/src/inventory/tree.rs`,
    `crates/grimoire-pack/src/inventory/yaml.rs`,
    `crates/grimoire-pack/src/inventory/digest.rs`,
    `crates/grimoire-pack/src/inventory/scan.rs`,
    `crates/grimoire-pack/src/inventory/tests/mod.rs`,
    `crates/grimoire-pack/src/inventory/tests/tracer.rs`,
    `crates/grimoire-pack/tests/fixtures/inventory-tracer/PACK.md`,
    `crates/grimoire-pack/tests/fixtures/inventory-tracer/skills/root/SKILL.md`, and
    `crates/grimoire-pack/tests/fixtures/inventory-tracer/skills/helper/SKILL.md`; modify
    `crates/grimoire-pack/Cargo.toml`, `Cargo.lock`, and `crates/grimoire-pack/src/lib.rs`.
  - Change: add `yaml-rust2` through its event API and build a new, crate-private
    `grimoire_pack::inventory::scan(&dyn TreeReader) -> Result<SourceInventory, InventoryError>`
    path without changing old APIs; `lib.rs` uses `mod inventory` until Slice 4 completes and
    exports the contract. `TreeReader` lists stable raw source-relative `TreeEntry` values and
    returns streamed readers for regular files under a no-follow adapter contract. The tracer uses
    an in-memory reader rather than a production filesystem adapter. Define `SourcePath`, `Digest`,
    `Severity`, `Finding`, `Skill`, `Pack`, `FileFact`, `SymlinkFact`, `SubmoduleFact`,
    `SourceInventory`, `TreeEntry`, and `TreeEntryKind` (including a distinct submodule kind) with
    the trait floor above. The tracer implements only the strict happy path needed to scan a root
    pure pack, two nested skills, regular files, and one internal symlink; it parses the three
    identities, streams file content, resolves the pack roster, sorts every collection, and emits
    deterministic skill-content, inventory, and review-tree digests. Each entry retains its
    snapshot/skill owning boundary even though the tracer uses only one internal link. Keeping the
    root pack outside both discovered skill directories proves the rule that discovery stops beneath
    a skill. The tracer pins the complete minimal preimage bytes and resulting digests; repeatability
    alone is not acceptance.
  - Verify: first make `cargo test -p grimoire-pack inventory::tests::tracer` fail because the new
    private path is absent, then make it pass against the exact byte/digest goldens; run
    `cargo check --workspace`. Expected: the new path is real end to end while alpha consumers still
    compile unchanged and no adapter connects the two models.

- [x] **Slice 2: Bounded YAML and the exact pure-pack grammar** <requires: 1>
  - Files: modify `crates/grimoire-pack/src/inventory/yaml.rs`,
    `crates/grimoire-pack/src/inventory/model.rs`, and
    `crates/grimoire-pack/src/inventory/scan.rs`; create
    `crates/grimoire-pack/src/inventory/tests/frontmatter.rs`,
    `crates/grimoire-pack/src/inventory/tests/pack_format.rs`,
    `crates/grimoire-pack/src/inventory/tests/finding_contract.rs`, and
    `crates/grimoire-pack/src/inventory/tests/red_proofs.rs`.
  - Change: finish the fence reader so it streams only the opening-through-closing frontmatter into
    the YAML parser and never loads the Markdown body. Build mappings/sequences from marked parser
    events while counting nodes and nesting; reject multiple documents, duplicate keys, aliases,
    nonzero anchors, explicit tags, `<<` merge keys, non-string mapping keys, unsupported scalar
    forms, non-finite numbers, and all three fixed parser ceilings. `SKILL.md` accepts a top-level
    mapping with one valid slug `name` and ignores other bounded ordinary fields. `PACK.md` accepts
    exactly `schema`, `name`, `description`, `required`, and `optional`; require
    `grimoire/pack@1`, a nonempty description, two unique slug sequences, no overlap, and at least
    one total member. Reject comma scalars, unknown keys, `format`, `version`, and every face-era
    shape. Map every envelope, event, root-type, missing-field, wrong-type, non-string-member, and
    semantic branch to the spec's exhaustive code and exact detail set. Apply its deterministic
    envelope/event stop rules and owned-field/semantic order; messages remain display-only. Add
    named red-proof arms for the size, node, depth, duplicate, alias/anchor/tag, merge,
    mapping-key, scalar-form, schema, unknown-key, and slug guards. Boundary fixtures accept
    exactly 65,536 frontmatter bytes, 4,096 nodes, and 16 levels, then reject the next unit.
  - Verify: `cargo test -p grimoire-pack inventory::tests::`
    passes; the finding test exhausts every parser-owned code, exact detail set, precedence, and
    first-rejected limit value. Each red-proof test names the disabled guard and demonstrates the
    strict invariant would fail without it; `cargo check --workspace` remains green.

- [x] **Slice 3: Deterministic discovery over hostile paths** <requires: 2>
  - Files: modify `crates/grimoire-pack/src/inventory/tree.rs`,
    `crates/grimoire-pack/src/inventory/scan.rs`,
    `crates/grimoire-pack/src/inventory/model.rs`, and
    `crates/grimoire-pack/src/inventory/tests/red_proofs.rs`; create
    `crates/grimoire-pack/src/inventory/unicode17.rs`,
    `crates/grimoire-pack/tools/generate_unicode17.rs`,
    `crates/grimoire-pack/src/inventory/tests/discovery.rs`,
    `crates/grimoire-pack/src/inventory/tests/unicode_collision.rs`,
    `crates/grimoire-pack/src/inventory/tests/support.rs`, and pinned `UnicodeData.txt`,
    `CompositionExclusions.txt`, `DerivedNormalizationProps.txt`, `NormalizationTest.txt`, and
    `LICENSE.txt` under `crates/grimoire-pack/tests/data/unicode-17/`.
  - Change: complete one raw-byte-sorted recursive walk. Apply the spec's exact fixed directory
    ignore set at every descent, reject rather than truncate beyond depth 32 or 100,000 total
    outer-plus-skill entries, and carry one shared entry budget into Slice 4's skill walk. Skip child
    checkouts containing a `.git` file or directory, and never descend through
    a symlink or beneath a discovered skill. A skill requires a real directory plus a regular
    `SKILL.md` and a valid parsed name; there is no basename fallback. Consider `PACK.md` at every
    scanned directory outside a skill, with no root-only special case; a directory that qualifies
    as a skill cannot also contribute a pack. Put UTF-8, unsafe-component, entry-kind, and collision
    checks in one raw `EntryValidator` used by this outer walk and Slice 4's skill walk. Retain all
    duplicate candidates as facts while emitting stable error findings for duplicate skill or pack
    identities. Sort each duplicate/collision group by raw path, then emit exactly one finding for
    each later path referencing the first.

    Acquire the five inputs from exactly
    `https://www.unicode.org/Public/17.0.0/ucd/UnicodeData.txt`,
    `https://www.unicode.org/Public/17.0.0/ucd/CompositionExclusions.txt`,
    `https://www.unicode.org/Public/17.0.0/ucd/DerivedNormalizationProps.txt`,
    `https://www.unicode.org/Public/17.0.0/ucd/NormalizationTest.txt`, and
    `https://www.unicode.org/license.txt`; verify the hashes below before adding their bytes to the
    tree. Generate the complete Unicode 17.0.0 `toNFKC_Casefold` implementation into
    `unicode17.rs` from that checked-in data. The generator contains its own small SHA-256
    implementation, has no network access or third-party dependency, and refuses an input whose
    SHA-256 differs from:
    `UnicodeData.txt` `2e1efc1dcb59c575eedf5ccae60f95229f706ee6d031835247d843c11d96470c`,
    `CompositionExclusions.txt` `2f239196ef3b5b61db5cc476e9bd80f534d15aa1b74e1be1dea5d042a344c85f`,
    `DerivedNormalizationProps.txt` `71fd6a206a2c0cdd41feb6b7f656aa31091db45e9cedc926985d718397f9e488`,
    `NormalizationTest.txt` `5019ffd530751a741900c849c0e010332f142a3612234639bd200b82138a87db`,
    or `LICENSE.txt` `e7a93b009565cfce55919a381437ac4db883e9da2126fa28b91d12732bc53d96`.
    The generated code owns the NFKC_CF map, canonical decomposition/composition data, combining
    classes, and algorithmic Hangul handling needed for the required post-normalization. Use fake
    `TreeReader` records for NUL and
    absolute/traversal paths that a host filesystem cannot create; use Unix fixtures for invalid
    UTF-8. A test-only filesystem reader may use `symlink_metadata`/`read_link` only against
    controlled immutable fixtures; it is not exported or suitable for Phase 3 custody. Emit
    raw-path findings for those cases, unsupported entry kinds, and collision keys without lossy
    normalization. Add red-proof arms for every
    ignore, nested-checkout, no-follow, stop-at-skill, traversal-limit, duplicate, raw-path, and
    collision guard.
  - Verify: run
    `rustc crates/grimoire-pack/tools/generate_unicode17.rs -o target/grimoire-unicode17-gen`,
    `target/grimoire-unicode17-gen crates/grimoire-pack/tests/data/unicode-17 target/unicode17.generated.rs`,
    and `cmp target/unicode17.generated.rs crates/grimoire-pack/src/inventory/unicode17.rs`; then
    `cargo test -p grimoire-pack inventory::tests::` passes on
    generated shallow limits, fake hostile-path records, controlled filesystem
    symlink/nested-checkout fixtures, every scalar `NFKC_CF` mapping, every normalization vector,
    and explicit cross-scalar post-normalization cases. Production constants and collision-group
    cardinality are asserted to the spec values; `cargo check --workspace` remains green.

- [x] **Slice 4: Canonical skill facts and `source-inventory@1` bytes** <requires: 3>
  - Files: modify `crates/grimoire-pack/src/inventory/digest.rs`,
    `crates/grimoire-pack/src/inventory/model.rs`,
    `crates/grimoire-pack/src/inventory/scan.rs`,
    `crates/grimoire-pack/src/inventory/tests/finding_contract.rs`,
    `crates/grimoire-pack/src/inventory/tests/red_proofs.rs`, and
    `crates/grimoire-pack/src/lib.rs`; create
    `crates/grimoire-pack/tests/content_digest.rs`,
    `crates/grimoire-pack/tests/capabilities.rs`,
    `crates/grimoire-pack/tests/inventory_digest.rs`, and
    `crates/grimoire-pack/tests/review_digest.rs`.
  - Change: stream every non-directory skill entry in raw relative-path order. Hash the
    exact `grimoire/skill-content@1` schema+NUL and `F`/`L` records with unsigned 64-bit big-endian
    path, normalized-mode, and content-or-target fields; normalize regular modes to `100644` or
    `100755` and links to `120000`. Every symlink target contributes, including an escaping or
    invalid one. Classify a link against its owning skill or snapshot boundary; emit exact
    `escaping-symlink` or `invalid-symlink-target` findings for skill-external, empty, and NUL target
    fixtures while retaining the raw target fact. Any such skill error makes the complete
    installable inventory invalid rather than omitting one entry. For regular files record exact
    size and SHA-256, NUL-in-first-8 KiB binary fact, executable fact, and first-line shebang capped
    at 512 bytes without assuming UTF-8. Reuse Slice 3's `EntryValidator` for every skill entry so
    invalid UTF-8, unsafe components, unsupported kinds, and collision groups behave identically in
    both walks. Ignore names and nested-checkout markers have no effect once a skill root is found:
    fixtures under `vendor`, `fixtures`, `target`, and a nested `.git` all contribute. Add inner-walk
    hostile-path/collision fixtures and red proofs. Finish the exact reviewed-entry set: outer
    non-directory entries outside ignored/nested-checkout subtrees plus every skill entry, sharing
    the 100,000-entry budget and enforcing the 1-GiB regular-file limit with its stable finding. A fake
    `TreeReader` fixture emits submodules both outside and inside a skill: the former is an inert
    snapshot-boundary fact, while the latter retains its commit and emits `unsupported-entry`.
    Neither enters the file/symlink-only skill digest; filesystem discovery still skips nested
    checkouts. Finish the `grimoire/source-inventory@1`
    byte encoder exactly as the spec defines: schema+NUL; record bytes `S` (`0x53`), `P` (`0x50`),
    and `F` (`0x46`) for skill, pack, and finding; unsigned 64-bit big-endian field lengths; raw
    finding paths with the none/present tag; sorted exact UTF-8 detail pairs; exact `PACK.md` digest;
    deterministic duplicate/collision cardinality; and no human message, absolute path, timestamp,
    or discovery-order input. Encode `grimoire/review-tree@1` over raw path, kind, mode, payload,
    boundary, safety, and reason for the same reviewed-entry set. Pin byte-for-byte goldens and add
    red proofs for schema domains, path presence, kind, mode, link target, boundary, ordering,
    detail extras, and message exclusion. Only after these tests are green, change `lib.rs` from
    private `mod inventory` to the final public module.
  - Verify: `cargo test -p grimoire-pack inventory::tests::` and
    `cargo test -p grimoire-pack --test content_digest --test capabilities --test inventory_digest --test review_digest`
    pass; controlled content, execute-bit, internal/escaping/invalid-link, boundary, and reviewed
    ordinary-file changes alter only the expected digests, while traversal order and human-message
    changes do not alter them. The limit fixtures stop at the first rejected entry/byte and every
    review-tree fact has the same boundary/safety as its inventory capability fact;
    `cargo check --workspace` remains green.

- [x] **Slice 5: Pack availability, root dogfood, and the alpha cutover** <requires: 4>
  - Files: modify `crates/grimoire-pack/src/inventory/model.rs`,
    `crates/grimoire-pack/src/inventory/scan.rs`, `crates/grimoire-pack/src/lib.rs`,
    `crates/grimoire-pack/tests/clankshop.rs`,
    `crates/grimoire-pack/Cargo.toml`, `crates/grimoire-core/Cargo.toml`,
    `crates/grimoire-core/src/lib.rs`, `crates/grimoire/Cargo.toml`,
    `crates/grimoire/src/lib.rs`, `PACK.md`, `AGENTS.md`, `README.md`,
    `scripts/tests/run.sh`, `scripts/tests/clankshop-contract-test.sh`,
    `skills/skill-builder/scripts/skills-lint.sh`, `skills/skill-builder/specs/README.md`,
    `skills/skill-builder/docs/DOCTRINE.md`,
    `skills/skill-builder/scripts/tests/lint-edges-test.sh`, and
    `skills/skill-builder/scripts/tests/lint-doctrine-consumer-test.sh`; create
    `crates/grimoire-pack/tests/pack_availability.rs`,
    `crates/grimoire-pack/tests/live_root_layout.rs`; delete
    `crates/grimoire-pack/src/discovery.rs`, `crates/grimoire-pack/src/frontmatter.rs`,
    `crates/grimoire-pack/src/hash.rs`,
    `crates/grimoire-pack/src/lock.rs`, `crates/grimoire-pack/src/manifest.rs`,
    `crates/grimoire-pack/src/pack.rs`, `crates/grimoire-pack/tests/conformance.rs`,
    `crates/grimoire-pack/tests/ignore.rs`, the former
    `crates/grimoire-pack/tests/fixtures/` cases other than `inventory-tracer`, every alpha module
    and test under `crates/grimoire-core/src/` and `crates/grimoire-core/tests/` except the rewritten
    `src/lib.rs`, `crates/grimoire/src/app.rs`, `crates/grimoire/src/args.rs`,
    `crates/grimoire/src/env.rs`, `crates/grimoire/src/job.rs`,
    `crates/grimoire/src/main.rs`, `crates/grimoire/src/render.rs`,
    `crates/grimoire/src/run.rs`, `crates/grimoire/examples/spike.rs`,
    `crates/grimoire/tests/boundary.rs`, `crates/grimoire/tests/dogfood.rs`,
    `crates/grimoire/tests/render.rs`, `crates/grimoire/tests/workflow.rs`,
    `crates/grimoire/tests/world/`, `install.sh`, `scripts/tests/install-pack-test.sh`, and
    `docs/spec/pack-format.md`.
  - Change: finish same-snapshot pack availability: populate sorted `missing_required` and
    `missing_optional` facts. A missing required member is a pack-local availability fact that makes
    that pack unresolvable without poisoning the source inventory; it emits no source-wide finding.
    A missing optional member emits the exact `missing-optional-member` availability warning and
    remains unavailable without invalidating the pack's other selected members. Keep nested packs and
    cross-source resolution impossible because the inventory accepts skill names only from this
    one tree. Convert the root `PACK.md` frontmatter to
    `grimoire/pack@1` sequence-valued pure-bundle form, remove face/version/install-script claims
    from its body and active root docs, and point active documentation at the published hard-cut
    spec. Rewrite `clankshop-contract-test.sh` to assert optional membership from the new YAML
    sequence rather than a comma scalar, including a list-item removal red proof. Rewrite the
    skill-builder doctrine's pack-face exception into one regime: every skill remains independent,
    while a pure bundle has no skill face to exempt. Remove `is_pack_face` and every corresponding
    lint exemption, invert the edge fixture to prove that placing `PACK.md` beside `SKILL.md` grants
    no exemption, and rename the doctrine-consumer fixture so it asserts the same one-regime rule
    without preserving face terminology. Cut the public crate surface to the new inventory modules
    and remove `semver`, `serde`, `serde_json`, and other alpha-lock-only
    dependencies. Reduce `grimoire-core` to an explicit Phase 2 library shell whose only dependency
    is `grimoire-pack`, with the alpha operations description and dependency-floor comment removed.
    Set `skill-grimoire` to `autobins = false`, remove its explicit `[[bin]]`, alpha description,
    and obsolete core dependency, and retain only the product-independent `worker` and
    terminal-custody modules plus their tests for Phase 6; remove every old app/domain path rather
    than translating it. Delete the shell installer and its parity/integration tests now because
    converting the root pack makes that alpha oracle incompatible; Phase 7 will verify that no
    residual reference survived. Adjust the repository test list and skill-builder prose so no
    active check or doctrine advertises the removed installer or face model.
  - Verify: red-first, make the worktree `clankshop` test reject the alpha root manifest, then make
    `cargo test -p grimoire-pack --test clankshop --test pack_availability` pass with exactly one
    valid root pack and no validation errors. Pack-availability fixtures prove a missing required
    member blocks only its pack and contributes no finding, while optional warnings affect the
    inventory digest. Run
    `GRIMOIRE_LIVE_ROOT=/Users/cscott/Repos/grimoire cargo test -p grimoire-pack --test live_root_layout`;
    expected: known root skills are found, no skill or pack path enters `.workstreams`, and the test
    does not require the pre-land root `PACK.md` to use the new schema. Prove the cut with `rg` over
    compiled crate and active integration surfaces for `PackShape`, `faced`, `faceless`,
    `grimoire_pack::discovery`, `pub mod discovery`, `Ignore`, `grimoire_pack::lock`, `member_hash`,
    `docs/spec/pack-format.md`, and `install.sh`; expected:
    no production/parser/active-test hit. Then run `cargo fmt --all -- --check`,
    `cargo test --workspace`, `cargo clippy --workspace --all-targets -- -D warnings`,
    `skills/skill-builder/scripts/skills-lint.sh`,
    `skills/skill-builder/scripts/tests/run.sh`, and `scripts/tests/run.sh`; expected: every gate
    green, with only pre-existing documented lint warnings.

## Done when

- `grimoire-pack` exposes one deterministic, backend-neutral inventory path for skills, pure packs,
  capability/review facts, exact finding occurrence, and `skill-content@1`,
  `source-inventory@1`, and `review-tree@1` digests.
- Parser, Unicode collision, traversal, hostile-path, duplicate, symlink, submodule, capability,
  and digest fixtures cover the published limits and each negative guard has a named red-proof arm.
- The root `clankshop` pack uses only `grimoire/pack@1`, scans successfully from this worktree, and
  the read-only root-checkout layout probe remains immune to nested worktrees.
- Alpha face/format/lock APIs, live-library core operations, immediate-action TUI state, the shell
  installer, its integration test, and the old active pack-format spec are absent rather than
  wrapped. Only generic worker and terminal-custody infrastructure remains for later reuse.
- Formatting, full workspace tests, clippy, skill lint, repository integrations, and root-layout
  verification are green. No Phase 2 manifest/lock, source transport/trust/store, installed-link
  operation, CLI, or TUI-domain behavior has been pulled into this phase.

_On completion (before landing), run the host's close-the-books sweep._
