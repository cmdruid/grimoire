---
doctype: specs
status: published
schema: architect/spec@1
tags: [activation]
---

# Grimoire skill activation as copies, local `--link` as symlink — Spec

Harnesses already look at `.agents/skills/<name>/` (project) and `~/.agents/skills/<name>/`
(global). The clone-and-go convention is that those directories contain skill trees. This spec
replaces the published projection split in
→ specs/2026-09-03-grimoire-install-projections-and-managed-vendoring.md.

## Problem

Grimoire activates every skill through a symlink under the scope's `.agents/skills/` directory.
Linked targets are machine-local store or `--live` paths. Vendored bytes live under
`vendor/grimoire/<source>/<skill>`, with a second relative symlink back into `.agents/skills/`.
Documentation then recommends ignoring the path harnesses actually read.

That fights the convention of committing `.agents/skills`. A clone is not skills-ready until
`install --frozen` recreates links. Project symlinks are also a poor Git citizen (Windows,
`core.symlinks`). Global `~/.agents/skills` as a pile of links is equally unlike a skills library.

The need is one activation path that is a real skill directory by default, with a single explicit
hatch for a local working tree.

## Goal

Pinned sources install by copying the locked skill tree into the scope's `.agents/skills/<name>/`.
`--link` exists only for a local filesystem source and installs a symlink to that tree. Remotes
never symlink. `vendor/grimoire/` and projection `mode` go away. The source flag is `--link`, not
`--live`: it names the activation.

## Approach

Activation style is implied by the source, not chosen per request:

```text
pinned git (remote or local path without --link)
    -> immutable store snapshot
    -> copy into <scope>/.agents/skills/<name>/

local path with --link
    -> no snapshot
    -> symlink <scope>/.agents/skills/<name> -> <source>/skills/<name>
```

`<scope>/.agents/skills` is project `.agents/skills` or `$HOME/.agents/skills`. The copy is the
committed (project) or user-local (global) skill tree. Pinned copies are lock-owned install
trees, not an edit surface; local edits are drift. There is no second byte home.

Rejected here, from the conversation:

- **Keep `vendor/grimoire/` and also copy into `.agents/skills/`.** Two committed trees of the
  same skill.
- **`--link` on a remote meaning "symlink to the store."** Remotes are pinned and always copy.
  Disk duplication of skill-sized trees is accepted.
- **Project copies, global still always-symlink.** Global harnesses want real directories too.
  `--link` is the symlink hatch in both scopes.
- **Keep the flag name `--live`.** The user-visible fact is a symlink, not "this source is
  unpinned." `--live` is retired.

The predecessor spec's rejection of "copy into `.agents/skills/`" was about mixing generated
links with committed trees and about source rediscovery. Those are solved by making the copy the
only pinned layout and by ignoring `.agents` during source discovery, as `vendor` is ignored
today.

## Mechanism

### Source kinds

`grimoire source add <alias> <location> [--link] [--trust|--trust-all]`.
`--link` is illegal on a remote (`github:`, URL, scp-shaped) and illegal with `--ref`. A local
path without `--link` is a pinned Git worktree (clean, commit-addressed).

A link source has no store snapshot and is not copyable. A pinned source always copies; it has
no symlink activation.

Install flags `--link` and `--vendor` are removed; `--link` exists only on `source add`. The TUI
`v` mode toggle is removed. Manifest and lock no longer carry `mode`. Manifest sources use
`link = true` in place of today's `live = true`. Lock source kind is `link` in place of `live`.
Because schema 2 requires `mode` and `live`, this is a hard cut to `grimoire/manifest@3` and
`grimoire/lock@3`. Schema 2 is unsupported; the diagnostic tells the developer to bump the
manifest schema, delete the generated lock, and reinstall. No silent migration. `--live` is a
usage error that names `--link`.

### Copy (pinned)

For each resolved skill from a pinned source, Grimoire copies the verified stored skill root to
`<scope>/.agents/skills/<name>/`. The copy uses the existing vendor copy-and-verify rules: from
the immutable store only (never from a candidate, review export, Git worktree, link source, or
incumbent copy); preserve the reviewed entry set; normalize file modes to `0644`/`0755`; require
the locked skill `content` digest after copy.

The incumbent lock is the ownership receipt. Grimoire may replace or remove a copy only when that
receipt still names this skill and the tree's digest still matches. Drift (`content` mismatch or
structural failure) blocks update and uninstall. Foreign trees at that path (no lock receipt) are
left untouched and reported.

Transaction, rollback, and recovery stay the existing scope journal: prepare a private tree,
revalidate, rename into place. The destination is `.agents/skills/<name>` instead of
`vendor/grimoire/<source>/<name>`. After this cut, Grimoire never creates `vendor/grimoire/`.

Project copies are the git convention. Grimoire does not edit `.gitignore`.

### Symlink (local `--link` only)

For each resolved skill from a `--link` source, Grimoire creates
`<scope>/.agents/skills/<name>` as a symlink to the skill directory inside that source tree
(the locked `path`, typically `skills/<name>`). The target is absolute, as link identity is an
absolute local path.

Link activations are local dirt. They must not be committed. A project that wants clone-and-go
does not use `--link`. Mixing a link source with pinned copies in one scope is legal; the
operator owns not committing the link names. `check` reports a link activation that is not a
symlink to the link source skill path.

### Discovery

Source inventory skips the `.agents` directory the same way it skips `vendor`, `.git`, and
`target`. Installed copies and link symlinks are never extra source skills. A repository may be
both a pinned source (its `skills/` tree) and a consuming project (its `.agents/skills/` copies).

### Trust and frozen

Creating or replacing a copy from the store is activation of source content and keeps the
existing exact-snapshot or all-snapshots trust requirement.

A link source has no snapshot, so exact trust is illegal. Activating it requires identity-wide
all-snapshots trust (`--trust-all`). `--trust` on a link source is a usage error.

A present copy whose structural inventory matches the locked `content` digest is current. It
does not require the install store. `check` is happy; harnesses work with no Grimoire on a clone
that committed those trees.

`install --frozen` never changes the manifest, lock, copies, or trust store. It may create a
missing link symlink when the link source path still exists. It must not create a missing copy
(that would introduce uncommitted bytes). Reconstructing a missing copy is a non-frozen, trusted
install from the store.

Vendor receipts and `source trust --vendor` go away. They existed to authorize activation
symlinks to already-committed vendor trees. Copies *are* the trees; there is no extra link to
repair.

Trust hard-cuts to `grimoire/trust@3`: same identity, exact receipts, `all_snapshots`, and
baseline as v2, without `vendor_receipts`. Schema 2 is unsupported on read.

### Observation and check

Expected activation comes from the source kind (`copy` or `link`). Observation of
`.agents/skills/<name>` is then one of:

Pinned source:

- `absent`
- `copy_current` — regular directory, lock-owned, digest matches
- `copy_drift` — lock-owned directory that fails structure or digest
- `foreign` — any other occupant (including a symlink)

Link source:

- `absent`
- `link_current` — symlink to the link source skill path
- `link_stale` — a symlink whose target is not that path
- `foreign` — any other occupant (including a regular directory)

A lock-owned directory on a link source is `foreign`, not `copy_current`.

`list` reports `copy` or `link` from the source kind, plus that observation. `check` names
missing, drift, stale link, and foreign occupants. A missing store snapshot is not an error when
every selected skill from that snapshot is `copy_current`.

### CLI shape

```sh
grimoire source add grove github:cmdruid/grove --trust
grimoire install journal --source grove          # copy
grimoire install clankshop --pack --source grove # copy each member

grimoire source add grove ~/Repos/grove --link --trust-all
grimoire install clankshop --pack --source grove # symlink each member into that tree
```

Uninstall removes an owned copy or an owned link symlink. It does not touch foreign occupants.

Global scope uses the same rules under `$HOME/.agents/skills`. Global copies are not a git
convention; they are still real directories.

## Verification

- Schema-3 goldens: no `mode`, no `live`, v2 rejection, `--live` usage error names `--link`,
  hard-cut diagnostic, deterministic bytes.
- Pinned install in Project and Global creates a regular directory at
  `.agents/skills/<name>/` whose digest equals the lock, with no symlink and no
  `vendor/grimoire/` path.
- `--link` on a local path creates a symlink to that tree's skill directory; `--link` on a
  remote is a usage error.
- A committed Project copy clone: `grimoire check` passes without a store, cache, or candidate.
  `install --frozen` does not recreate a deleted copy.
- Drift (edit a file in an owned copy) blocks `update` and uninstall; restoring the digest
  unblocks.
- Source scan of a tree that contains both `skills/visible` and `.agents/skills/installed`
  reports only `visible`.
- Existing live-root dogfood can keep `--link` against sibling `../grove` and must not require
  committing those symlinks.

