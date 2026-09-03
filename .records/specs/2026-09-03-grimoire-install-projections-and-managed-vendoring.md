---
doctype: specs
status: published
schema: architect/spec@1
tags: []
---

# Grimoire install projections and managed vendoring — Spec

## Problem

Grimoire already separates source acquisition from installation. It fetches and reviews source
content in user-local caches, materializes a verified immutable snapshot beneath
`<grimoire-home>/store/checkouts/<source-key>/<snapshot-key>/`, and activates each selected skill
with a symlink under the scope's `.agents/skills/` directory. That is the right default for a
managed dependency: the project commits desired state and an exact lock while the installed bytes
remain deduplicated and locally replaceable.

The model has no corresponding way to make selected skill bytes part of the project. A developer
who wants a code-reviewed, immediately available copy must copy files manually into an activation
directory that Grimoire otherwise treats as link-only. Grimoire then cannot distinguish a managed
copy from foreign content, verify it against the lock, update it transactionally, or protect local
edits. Mixing committed directories and generated links directly under `.agents/skills/` also
makes ignore rules fragile and lets installation layout leak into source discovery when one
repository is both a Grimoire source and a consuming project.

The underlying need is therefore not a copy flag. Grimoire needs an explicit projection model:
one resolved, locked skill may be activated from the immutable install store or from a managed,
committed vendor tree, without changing how sources are acquired, reviewed, trusted, or resolved.

## Goal

Add a project-only `vendor` projection alongside the existing `link` projection. Both projections
resolve the same request roots to the same locked source snapshot and expose the selected skill
through `.agents/skills/<name>`; they differ only in whether the activation link targets the
user-local install store or a verified copy at
`<project>/vendor/grimoire/<source-alias>/<skill-name>`.

The completed feature has these properties:

- `link` remains the default and preserves today's immutable-store behavior.
- a vendored skill is safe to commit and, after local approval of its exact locked bytes, can
  recreate its activation link on a fresh offline clone;
- initial vendoring and vendor updates copy only reviewed, locked bytes from the install store;
- local changes to managed vendor content are protected drift, never implicit update input;
- packs and direct requests use one deterministic projection rule per resolved skill;
- Global scope stays link-only;
- project state moves to strict `grimoire/manifest@2` and `grimoire/lock@2` formats.

Editable forks, merging local modifications with upstream changes, registries, aliases, automatic
`.gitignore` edits, and an eject command are outside this feature.

## Approach

Treat acquisition, storage, and projection as separate layers:

```text
declared source
    -> candidate and review caches
    -> verified immutable install store
    -> project projection
         link:   .agents/skills/<name> -> install store
         vendor: vendor/grimoire/<source>/<name> <- verified copy
                 .agents/skills/<name>           -> vendor tree
```

`.agents/skills/` remains a generated, symlink-only activation layer in both modes. A project that
wants committed bytes stores them under the fixed `vendor/grimoire/` boundary, which source
discovery already treats as non-source content. The activation path therefore remains uniform for
agent harnesses, linked and vendored skills may coexist, and a project can ignore all generated
activation links without also ignoring vendored content.

Projection mode belongs to request roots. A direct skill request or pack request declares `link`
or `vendor`; pack members inherit their pack root's mode. Every request root contributing a
resolved skill must agree. Disagreement is a blocker rather than an implicit precedence rule.

Projection does not weaken the activation trust boundary. A committed manifest, lock, and matching
vendor tree prove project intent and byte identity, not user-local approval. Existing source trust
or an explicit approval scoped to the exact vendored skill bytes is still required before Grimoire
creates or repairs their activation link.

Vendoring is managed, not ejected. The incumbent lock is the ownership receipt and the locked
skill content digest is the unchanged-content proof. Grimoire may replace or remove a vendor tree
only when both facts hold. A mismatch is protected drift and requires the developer to restore,
commit elsewhere, or explicitly eject the content in a future feature.

These load-bearing choices were confirmed by the project owner on 2026-09-03:

- introduce strict manifest and lock schema 2 with a hard cut from schema 1;
- allow a locally approved current vendored tree to restore its activation link in frozen mode
  without the install store;
- resolve mode from all request roots and block any disagreement.

### Alternatives rejected

**Copy directly into `.agents/skills/`.** This conflates content with activation, prevents a stable
ignore rule for mixed projections, and makes a consuming source repository rediscover committed
copies as additional skills.

**Hard-link files out of the install store.** A project edit could mutate the immutable store and
silently affect every scope sharing that snapshot. Implementations may use a filesystem clone that
has copy-on-write semantics, but never a mutable hard link.

**Let `vendor` silently win mode conflicts.** The same skill can be owned by a direct request and
several packs. Precedence would make layout depend on unrelated request ordering and could turn a
committed tree into local state without an explicit project edit.

**Treat every copy as immediately project-owned.** A one-shot copy is an eject operation, not a
managed installation. Combining the two lifecycles would make update and removal destructive by
default. Ejection can be specified separately when there is a concrete workflow for it.

**Extend schema 1 in place.** Both v1 formats reject unknown fields, and projection mode changes
lock meaning and frozen behavior. Reusing the identifier would make the same schema version mean
different things to different binaries.

## Mechanism

### Terms and invariants

- The **acquisition cache** is the existing Git mirror, candidate, temporary, and review-export
  state beneath `<grimoire-home>/cache/` and `<grimoire-home>/candidates/`. It never activates a
  skill.
- The **install store** is the existing immutable, verified snapshot tree beneath
  `<grimoire-home>/store/checkouts/`. A store snapshot is content-addressed and shared across
  scopes.
- A **projection** is the scope-owned realization of one resolved lock skill.
- A **vendor tree** is the regular directory at
  `<project>/vendor/grimoire/<source-alias>/<skill-name>` whose complete normalized content digest
  equals that lock skill's `content` digest.
- An **activation link** is the symlink at `<scope>/.agents/skills/<skill-name>`. Activation paths
  contain no copied skill directories in either mode.
- `link` supports pinned and live sources. `vendor` supports pinned Git snapshots only.
- Global scope supports `link` only.
- Grimoire never edits `.gitignore`. Documentation recommends ignoring `.agents/skills/`; the
  committed manifest, lock, and vendor trees remain visible to Git.

Names in vendor paths are already validated source-alias and skill-name slugs. Every filesystem
operation holds the project or activation parent directory by descriptor, rejects symlinked parent
components, and proves containment beneath the canonical project root. A vendor operation never
follows an incumbent symlink in place of a vendor directory.

### Manifest schema 2

`grimoire/manifest@2` retains the v1 source grammar and adds optional `mode` to direct skill and
pack request values:

```toml
schema = "grimoire/manifest@2"

[sources.grimoire]
url = "github:cmdruid/grimoire"
ref = "main"

[skills]
developer-writing = { source = "grimoire", mode = "vendor" }

[packs]
clankshop = { source = "grimoire", mode = "link", exclude = ["scheduler"] }
```

`mode` is exactly `"link"` or `"vendor"`; omission means `"link"`. It is not valid on a source
because source mutability and projection are independent decisions. All other v1 strictness,
comment preservation, sorting, and unknown-field rejection remain.

`grimoire install <name> [--pack] [--source <alias>]` accepts mutually exclusive `--link` and
`--vendor` flags. For a new request, an omitted flag selects `link`. For an existing request, an
omitted flag preserves its declared mode, so repeating `install` cannot accidentally convert a
vendor tree. Passing a flag explicitly changes that request root's mode. `--vendor --global` is a
usage error. Uninstall needs no mode flag.

The Project TUI displays `linked` or `vendored` on every direct and pack request root. Pressing `v`
toggles the selected Project request root's staged mode. Pack members show the inherited mode but
cannot change it independently. The key is unavailable on Global and on inherited read-only rows.

### Lock schema 2

`grimoire/lock@2` retains the v1 source snapshot, pack membership, skill path, skill content, and
request-root fields. It adds:

- `mode` to every pack, recording the pack request root's declared mode;
- `mode` to every skill, recording the unanimously resolved projection mode.

Direct-root modes need no second lock table: a direct root is named in `requested_by`, and the
resolved skill's mode records the only accepted outcome. Lock validation re-resolves every pack
member's mode contribution and rejects a lock whose pack roots disagree with the resolved skill.
The manifest remains the authority for direct-root intent.

Vendor paths are derived from the validated source alias and skill name and do not enter the lock.
The existing `content` digest is the canonical vendor-tree digest; no second digest is introduced.
Serialization remains deterministic JSON with lexically sorted maps and arrays.

Schema 1 is unsupported after this feature. `init` writes schema 2. A schema-1 diagnostic tells the
developer to change the manifest schema to `grimoire/manifest@2`, remove the generated v1 lock, and
run a non-frozen install. Grimoire does not silently migrate or maintain a compatibility reader.

### Resolution

Each manifest request root contributes `(skill, mode)` after pack expansion. Resolution groups
contributions by skill:

1. Zero contributions omit the skill.
2. One distinct mode becomes the lock skill's mode.
3. More than one distinct mode emits `materialization-conflict`, naming the skill and the sorted
   contributing request roots with their modes. No lock or filesystem action is applicable.
4. A vendor contribution from a live source emits `vendor-live-unsupported`.
5. Any vendor contribution in Global scope emits `vendor-global-unsupported`.

Source collisions, missing required members, exclusions, shadowing, trust, and same-snapshot
resolution otherwise retain their existing behavior. Projection mode never changes which source
snapshot or skill content wins.

### Observed projection state

World observation records activation and vendor state separately.

An activation path remains `absent`, `symlink(target)`, `file`, or `directory`. A desired vendor
activation target is the exact relative path from `.agents/skills/<name>` to
`vendor/grimoire/<source>/<name>`. Relative targets keep a committed project movable across clones.

A vendor path is classified as:

- `absent`;
- `owned_unchanged`, when the incumbent lock declares that exact skill as `vendor`, bounded,
  no-follow structural validation succeeds, and its inventory equals the incumbent locked content
  digest;
- `drifted`, when the incumbent lock declares it as vendor but its entry set, modes, link targets,
  content, or structural validity do not match;
- `foreign`, when no incumbent vendor lock owns the path or the path is not a regular directory.

Coincidental digest equality does not adopt a foreign directory. Ownership requires the incumbent
lock receipt. Vendor observation runs a dedicated verifier rooted at the exact vendor directory. It
performs bounded, no-follow traversal; requires the root `SKILL.md` to declare the locked skill
name; accepts only directories, regular files with normalized `0644` or `0755` modes, and symlinks
whose byte-preserving targets remain within that vendor root; and rejects special files, malformed
or escaping link targets, excess entries, excess depth, or excess reviewed bytes. Only after those
structural checks succeed does it compute the existing normalized skill-content digest from entry
paths, modes, file hashes, and internal symlink target bytes. Digest equality never overrides a
structural failure.

### Planning

The plan model adds explicit vendor actions carrying scope, source alias, skill name, expected
content digest, and old/new ownership facts:

- `prepare_vendor` builds and verifies a transaction-private tree from a stored snapshot;
- `create_vendor` publishes a prepared tree into an absent vendor path;
- `replace_vendor` atomically replaces an `owned_unchanged` tree when its desired locked content
  digest differs from the incumbent digest;
- `retain_vendor` records an already-current tree without mutation;
- `remove_vendor` removes an unchanged, lock-owned tree.

Human rendering shows the vendor path, before/after digest, and added, removed, and changed source
entries from the two reviewed inventories. It does not dump file bytes. Vendor replacement,
removal, and conversion from `vendor` to `link` are destructive and follow existing confirmation
rules.

For desired `link` mode, the planner prepares the immutable snapshot when required, creates or
repoints the activation link to its stored skill path, and removes an unchanged incumbent vendor
tree during an explicit mode conversion. A drifted or foreign vendor path blocks that conversion.

For desired `vendor` mode, the planner behaves as follows:

- An `owned_unchanged` vendor tree whose incumbent and desired content digests agree needs neither
  source access nor a store snapshot. The planner retains it and repairs only a missing or stale
  owned activation link.
- An `owned_unchanged` vendor tree whose desired digest differs is replaced from the newly locked
  store snapshot, then activated.
- An absent tree is prepared from the exact locked store snapshot, published, and activated.
- A drifted tree emits `vendor-drift`; a foreign path emits `foreign-vendor-path`. Neither `--yes`
  nor ordinary update weakens those blockers.
- Converting from `link` creates the vendor tree before repointing activation.

For an unrequested skill, the planner removes an unchanged owned activation link and, when the
incumbent mode is vendor, its unchanged owned vendor tree. Missing owned state is idempotent.
Foreign activation or vendor paths are preserved and reported.

Store preparation is required only for a desired linked skill whose snapshot is absent, or for a
vendor create/replace whose source bytes are not already available in a valid store snapshot. A
current vendor tree is not copied back into the store.

### Copy and verification rules

A prepared vendor tree is copied from the verified stored skill root, never from a candidate,
review export, Git worktree, live source, or incumbent vendor tree. Implementations may use an
ordinary recursive copy or copy-on-write filesystem clone. They must not create mutable hard
links.

The copy preserves the reviewed entry set and internal symlink target bytes. Regular files are
normalized to `0644` or `0755` from the source executable bit; directories are `0755`; special
files and submodules remain invalid. After copying, Grimoire inventories the prepared tree and
requires the exact locked content digest before publication.

### Apply, rollback, and recovery

Vendor mutations join the existing scope transaction; they are not a second best-effort phase.
Snapshot and transaction-private vendor preparation occurs before the mutation lock set. Apply
then reacquires the existing ordered store, trust, projects, and scope locks, revalidates
manifest, lock, source, activation-link, and vendor-tree preconditions, and writes one recovery
journal containing state-file, vendor-directory, and link transitions.

Directory publication uses descriptor-relative sibling renames. Replacing or removing an owned
vendor tree first renames it to a transaction-specific capture. Creating or replacing a tree then
renames the verified prepared directory into the fixed vendor path. Activation links are mutated
only after every desired vendor target exists. Manifest and lock bytes reach their recorded final
hashes only after vendor and activation projections are correct.

Before that state-file commit point, any error or crash restores captured vendor trees and links
and removes only transaction-created paths. After the commit point, recovery preserves the new
state and completes capture cleanup. Recovery never deletes or moves a path whose revalidated
identity differs from the journal. Multi-skill plans roll back as a unit, and recovery is
idempotent.

### Trust and frozen operation

Initial vendor creation and vendor replacement activate newly obtained source content and retain
the existing exact-snapshot or all-snapshots trust requirement. An incumbent vendor tree that
matches its schema-2 lock supplies the exact bytes without a source candidate, acquisition cache,
or install store, but does not supply user-local approval. Before Grimoire creates or repairs its
activation link, the canonical source identity must satisfy existing exact-snapshot or
all-snapshots trust, or the exact skill must satisfy a vendor receipt defined below. Grimoire does
not inspect Git state or claim that the bytes are committed.

The local trust store moves to strict `grimoire/trust@2`. It retains each v1 record's canonical
identity, exact receipts, `all_snapshots` policy, and baseline, and adds a strictly sorted
`vendor_receipts` collection. The outer record binds every vendor receipt to the canonical source
identity. Each receipt contains exactly the pinned snapshot's `commit`, `tree`, and `inventory`,
plus the vendored skill's `skill`, source-relative `path`, and `content` digest. The logical
authority key is therefore `(canonical identity, commit, tree, inventory, skill, path, content)`.
Duplicate or unknown fields are rejected. A v1 trust store parses as the equivalent v2 state with
no vendor receipts; the next trust mutation writes deterministic schema 2 without losing existing
receipts, policy, or baseline.

Project scope adds `grimoire source trust <alias> --vendor`. The command requires a schema-2 lock,
selects every lock skill from that source whose resolved mode is `vendor`, and verifies each
corresponding vendor tree with the structural verifier above before comparing its locked content
digest, without consulting a candidate, cache, or store snapshot. Before mutation it displays the
canonical source identity, pinned snapshot, and sorted skill names, project-relative paths, and
content digests being approved. It requires the existing explicit trust confirmation; `--yes` is
invalid. `--vendor` is mutually exclusive with `--all` and `--revoke`, rejects Global or live
sources, and fails without at least one current vendored skill. The resulting receipts approve
those skills individually.

A vendor receipt authorizes only retaining or creating the activation link for the exact matching
vendor tree in `vendor` mode. It does not authorize another skill or snapshot, copying bytes into a
missing vendor path, activating the same source through the store in `link` mode, or replacing
vendor content during update. Those operations continue to require exact-snapshot or all-snapshots
source trust. Identity-wide `source trust <alias> --revoke` and `trust revoke <source-key>` remove
vendor receipts together with exact receipts and the all-snapshots policy while retaining the
existing audit baseline. Trust listings, source information, checks, and plans distinguish full
source trust from vendor-only approval. Existing receipts and matching digests never bypass vendor
structural validation during observation, planning, `check`, trust mutation, frozen reconciliation,
or apply-time precondition revalidation.

World loading can therefore construct current vendor projections from the lock and observed vendor
trees without opening the corresponding stored snapshot. Pack membership, skill paths, content
digests, request roots, and projection modes come from the lock. A linked projection still requires
its stored snapshot before it can become current.

`install --frozen` never changes the manifest, lock, vendor bytes, or trust store. It may:

- verify current vendored content and create or repair its owned relative activation link when the
  source has existing exact/all trust or the skill has an exact matching vendor receipt;
- activate linked skills only when their exact locked snapshots exist in the install store and
  satisfy the existing trust rules;
- fail with `vendor-untrusted`, `vendor-missing`, `vendor-drift`, `foreign-vendor-path`, or the
  existing linked-snapshot blocker when required state is unavailable.

A missing vendor tree cannot be reconstructed from another vendor tree. Reconstructing it from the
store is a non-frozen, trusted mutation because it introduces uncommitted bytes into the project.

The existing trust baseline continues to describe a fully reviewed source snapshot, not a subset
of vendored skills. Granting vendor-only approval therefore does not establish or advance it. When
an all-snapshots-trusted install, reconcile, or update publishes a newly resolved vendor tree, that
snapshot becomes the accepted source baseline in the same transaction even if the stable
activation symlink is retained. Exact-snapshot approval has already established its baseline before
vendor creation, as it does for linked activation.

### Check, list, and pruning

`list` reports each resolved skill's `mode`, activation status, and either its store snapshot or
project-relative vendor path. `check` distinguishes missing activation, wrong activation target,
missing vendor content, vendor drift, foreign vendor paths, missing required linked snapshots, and
optional absent vendor-store state. A missing store snapshot is not an error when every selected
skill that uses it has a current vendor tree.

Project indexing continues to record every locked snapshot key, including snapshots whose selected
skills are all vendored. `store prune` therefore retains snapshots referenced by live project
locks; vendoring is not an implicit store-eviction policy. Explicit future cache compaction may
relax that rule only with a separate contract for reconstructability.

### Self-hosting

A repository may be both a pinned Grimoire source and a consuming project. Linked self-hosting
uses the committed Git snapshot, immutable store, and generated activation links; uncommitted
activation links do not alter the pinned source tree. Vendoring the repository's own source skills
is legal but redundant: the managed copies remain below the discovery-ignored `vendor/` boundary,
so they cannot become duplicate source skills.

## Verification

The feature is complete when all of the following hold:

- Manifest and lock goldens prove strict schema-2 parsing, deterministic serialization, default
  link mode, explicit vendor mode, v1 rejection, unknown-mode rejection, and the manual hard-cut
  diagnostic.
- Trust goldens prove strict schema-2 vendor receipts, deterministic ordering, lossless v1 loading
  and next-write conversion, unknown-field rejection, receipt revocation, and clear full-source
  versus vendor-only reporting.
- Resolution matrices cover direct roots, pack roots, exclusions, shared members, agreeing and
  conflicting modes, live-source rejection, and Global rejection.
- Planner matrices cover create, retain, update, remove, link-to-vendor, vendor-to-link, missing
  activation, missing store, vendor-only frozen restore, drift, and foreign paths without adapter
  inference.
- Copy-boundary tests reject escaping symlinks, special files, symlinked parent components,
  post-copy digest changes, hard-link shortcuts, and unbounded traversal. Controlled failing arms
  prove every negative guard observes the intended mechanism.
- Offline vendor-verifier tests present unsafe trees whose attacker-controlled lock digests match
  their bytes and prove malformed skill identity, invalid regular-file modes, invalid or escaping
  symlinks, special files, and entry, depth, and reviewed-byte limit violations block both receipt
  creation and activation.
- Fault injection at every vendor journal step proves pre-commit rollback, post-commit roll-forward,
  multi-skill atomicity, idempotent recovery, and preservation of late foreign replacements.
- Concurrency tests cover vendor update versus check, prune, another project, and another mutation
  in the same project without weakening the existing lock order.
- CLI tests cover `--link`/`--vendor` grammar, preservation of an incumbent mode when neither flag
  is passed, offline `source trust --vendor`, its conflicts and `--yes` rejection, dry-run
  rendering, destructive confirmation, and stable blocker exit classes.
- TUI tests prove mode labels and `v` staging, pack inheritance, Global/inherited disablement,
  cancellation, confirmation, and planner parity with the CLI.
- A clone fixture commits only `grimoire.toml`, `grimoire.lock`, and vendor trees, starts with empty
  user-local Grimoire state and no activation links, performs explicit offline vendor approval, and
  passes offline `install --frozen` plus `check` without modifying committed bytes. Negative arms
  prove that a vendor receipt cannot authorize changed bytes, another skill or snapshot, a linked
  projection, a vendor create/replace, or activation after revocation.
- Mixed-projection dogfood installs linked and vendored members together, verifies that every
  `.agents/skills` entry is a symlink, and confirms linked targets enter the store while vendored
  targets stay project-relative.
- Root self-hosting dogfood creates a disposable clone that is both source and project, installs the
  `clankshop` pack in linked mode, and proves subsequent fetch, diff, update, check, and frozen
  reconcile do not discover activation or vendor duplicates. Any companion source-discovery check
  against the developer's actual root checkout is read-only.
- Trust-all update tests prove that successful vendor creation or replacement advances the accepted
  source baseline even when the activation symlink target is retained, while vendor-only approval
  leaves a missing or existing full-source baseline unchanged.
- The complete workspace tests, formatting, warnings-denied clippy, repository integrations, pack
  inventory, source-security, transaction-recovery, and both CLI/TUI end-to-end gates pass without
  waiver.
