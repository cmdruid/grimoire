---
doctype: specs
status: published
created: 2026-08-24
updated: 2026-08-24
tags: [spec]
---

# Grimoire faceless pack — remove clankshop — Spec

This library's design home is `docs/design/` (patient-zero). This
spec lives here. It doubles as the implementation plan.

External landing prerequisite: the TUI Phase 3 change currently carried by
`stream/app` must land before F1. It changes `install.sh` and adds the live
TUI dogfood test that installs and removes this repository's pack. If it has
not landed, do not start this feature; coordinate the ownership handoff
instead of editing the same surfaces concurrently.

Land first. Consumers:

- `docs/design/2026-08-23-workspace-kinds.md` — replaces the
  kind-first workspace with the skill-first layout after the assembler
  is gone.
- `docs/design/2026-08-23-backlog-living-trackers.md` — owns Backlog
  setup; no pack face applies tracker suggestions.
- `docs/design/2026-08-23-delegate-byproducts-hook.md` — owns Delegate
  setup; no pack face publishes its hook.
- `docs/design/2026-08-24-inspector-adequacy-and-review-close.md` — owns
  Inspector doctrine setup; no pack face participates.

## Problem

`clankshop` is simultaneously a skill, the faced `clankshop` pack, a
doctrine seed, a project assembler, a brownfield migrator, a hook
publisher, a flow publisher, a records-layer caller, a door writer, and
an assembly checker. Its setup therefore crosses nearly every member's
ownership boundary. Refining an independent skill repeatedly requires
changes to the pack face and its fixtures.

That behavior contradicts the portable skill contract: a durable-home
skill initializes its own project surface without depending on a
composer. It also duplicates an abstraction the repository already
specifies. Pack format 1 supports a root, faceless `PACK.md`; the local
installer is the component that still refuses that valid shape.

Moving the same assembler under another doctrine directory would cure
one path collision without curing the authority collision. Alpha is the
right time to remove the obsolete composition layer rather than give it
a new address.

## Goal

After this feature:

- `skills/clankshop/` does not exist.
- The installable bundle is a root faceless pack named `grimoire`.
  Root `PACK.md` is its manifest and runbook; it is not a skill and has
  no project lifecycle verb.
- `install.sh --pack grimoire` installs the required and selected
  optional members transactionally, records the faceless manifest in
  `grimoire.lock`, and installs no implicit face member.
- `install.sh --pack clankshop` is unknown. There is no alias, lock
  adoption, compatibility name, or migration.
- Every skill is independently usable. Skills with durable project
  surfaces expose and own their own explicit setup; the pack runbook
  may describe seams but never writes them.
- The clankshop doctrine seed, four stations, pack flows, stamp,
  `setup`, `migrate`, `check`, hook glue, flow copy, pack-owned door
  glue, and their tests are deleted with no replacement composer.
  Durable-home skills may maintain only their own delimited
  self-registration blocks.
- Live code and current documentation contain no `clankshop` policy
  probe, invocation, path, pack identity, or setup dependency.
  Historical closed design records may retain the name as history.
- Lint and installer tests are green.

## Approach

**Chosen: delete the face and use the already-specified faceless pack
shape.** Skills are the runtime atoms. The pack is distribution plus a
human-readable seam map, not a project assembler.

This is a hard cut:

- no `skills/clankshop/` tombstone;
- no root wrapper skill;
- no `clankshop` pack-name alias;
- no station-path fallback or `Seeded from clankshop` marker;
- no automatic cleanup of already-deployed project files;
- no migration verb or lock rewrite.

Existing alpha installations remove the old installed pack and install
`grimoire`. Existing deployed clankshop artifacts are ordinary
project-file cleanup; the new runtime never reads them. The skill-first
workspace check specified by the consumer spec reports the old
kind-first workspace layout.

**Rejected: isolate the assembler at
`<agent-workspace>/doctrine/clankshop/`.** Filesystem isolation is not
authority isolation. Keeping pack-scoped setup would preserve the
cross-skill writes; stripping those writes would leave only a manifest
and bundled prose, which is exactly the faceless-pack shape.

**Rejected: replace clankshop with another face name.** That renames the
same privileged composer and leaves the architectural problem intact.

**Rejected: retain the station doctrine as shared project policy.** The
independent skills already carry their own operating contracts and fall
back to project documentation. Skill-owned project doctrine moves under
that skill's workspace namespace in the workspace feature. There is no
unowned shared station tree.

## Mechanism

### Root faceless manifest

Move the manifest role, not the face payload, to repository-root
`PACK.md`:

```yaml
---
name: grimoire
version: 1.0.0
description: "Independent agent skills with a faceless composition runbook"
required: journal
optional: analyst, auditor, backlog, architect, contractor, inspector, debugger, delegate, checkpoint, mailbox, notepad, scheduler, shopbook, workstream
---
```

The exact member set is the installed surviving set when this feature
lands; `clankshop` is absent. `workspace` does not join before its
package exists—the workspace feature adds that optional member and bumps
the pack version. `skill-builder` remains outside the pack. The body
keeps the roster and typed seam descriptions that are still true,
rewritten as recommendations rather than automatic setup behavior.

The runbook must not claim that the pack:

- seeds doctrine or project flows;
- writes a front door;
- initializes records, trackers, hooks, templates, or scripts;
- validates a deployed workshop;
- provides a project-presence stamp.

### Installer

`install.sh` already discovers root `PACK.md`. Replace its faced-only
branch with the two format-1 shapes:

1. Manifest beside `SKILL.md` → faced pack; validate matching names and
   include the face as the implicit required member.
2. Manifest at repository root with no sibling `SKILL.md` → faceless
   pack; include no implicit member.
3. Manifest anywhere else without a face → invalid per the existing
   pack-format contract.

For a faceless install, cache enough manifest data in the lock for
offline check/remove exactly as `docs/spec/pack-format.md` requires.
The installed member hashes remain authoritative. Do not invent a
project setup state.

The exact shell entrypoints are:

```text
./install.sh --list
./install.sh --pack grimoire
./install.sh --check --pack grimoire
./install.sh --remove --pack grimoire
```

Fresh install and reinstall use `--pack grimoire`. List, install,
reinstall, check, and remove must all render the faceless pack without
pretending a `grimoire` skill directory exists.

The transaction boundary is preflight every member, link, then commit one
lock entry. A lock that is unparseable, has a newer unsupported version,
cannot be merged without the required runtime, or cannot be written is a
transaction failure: return nonzero, remove links created by this run, and
preserve the prior lock byte-for-byte. Never report pack success when the
lock entry was not written.

### Package deletion and live consumers

Delete all of `skills/clankshop/`: `SKILL.md`, `PACK.md`, `seed/`,
`flows/`, `verbs/`, `scripts/`, and fixtures.

Hard-cut live consumers away from clankshop identity:

- remove stamp-based policy probes;
- remove `/clankshop setup|migrate|check` remedies;
- remove station-loader summons that depend on the deleted seed;
- remove clankshop-specific face assumptions and fixtures while retaining
  the generic faced-pack lint exemptions and mutation fixtures required by
  pack format 1;
- remove clankshop from the library inventory and local authoring
  front door;
- update pack-format examples to neutral or `grimoire` examples where
  they describe a current pack rather than historical rationale.

Rename `crates/grimoire-pack/tests/clankshop.rs` to `grimoire.rs` and change
the repository's live Rust conformance expectations to the root `grimoire`
faceless pack. After the app prerequisite
lands, update its dogfood scenario as well: select `grimoire`, expect no face
symlink and no face teardown warning, and continue to prove install, check,
and remove against both global and project scopes.

This feature removes the identity and composition layer. The following
workspace feature owns the new `<agent-workspace>/<skill>/<kind>` paths;
feature specs own their own setup and behavior. This spec must not
define those paths or edit another spec during implementation.

### Project artifacts

No teardown script is added. Automatic deletion of deployed doctrine,
hooks, flows, or door content would be destructive and would require
guessing whether a project edited the files. The hard cut is a runtime
contract, not an automatic filesystem eraser:

- new code never reads old clankshop artifacts;
- workspace check reports old kind-first workspace shapes;
- a human removes obsolete project files explicitly.

That is not a compatibility period: the old artifacts have no effect.

### Spec ownership

This spec exclusively owns:

- `skills/clankshop/**` deletion;
- root `PACK.md` identity, format, initial surviving member set, and
  faceless-pack runbook baseline;
- faceless support in `install.sh` and its pack tests;
- removal of live clankshop identity and policy probes.

It does not own the skill-first workspace grammar, Backlog behavior,
Delegate behavior, Inspector behavior, or their setup mechanics. Those
consumer specs are amended before implementation and are never edited
by this feature's slices.

### Shared integration files

Some composition files are intentionally shared, but their spans are
not:

| File | Exclusive span owner in this portfolio |
|---|---|
| root `PACK.md` identity, format, initial surviving member set | this spec |
| root `PACK.md` Workspace membership/roster span | workspace-kinds W5 |
| root `PACK.md` Backlog roster/seam spans | living-trackers B4 |
| root `PACK.md` Delegate seam span | delegate-byproducts D2 |
| root `PACK.md` Inspector roster span | Inspector I4 |
| `README.md` pack/install removal spans | this spec |
| `README.md` workspace/backlog inventory spans | the named owner spec |
| `README.md` Inspector inventory span | Inspector I4 |
| shared station summons and clankshop policy probes | this spec F3 |
| live Rust pack/core tests and the landed app dogfood pack identity | this spec F3 |
| Workstream hook paths/parser | workspace-kinds W3 |
| Workstream legacy Backlog invocations | living-trackers B4 |

The build order serializes those span edits: faceless pack → Workspace
→ Backlog → Delegate → Inspector. A slice must name its exact span, not
claim the whole shared file. No spec document is an implementation
path.

## Verification

**Mechanical**

- `test ! -e skills/clankshop`.
- Root `PACK.md` parses as a faceless format-1 pack named `grimoire`.
- Installer fixtures cover list, fresh install, reinstall, check, and
  remove of the faceless pack; prove-by-breaking the no-implicit-face
  assertion and lock-cached-manifest assertion.
- A failed member preflight leaves neither links nor a lock entry.
- An unparseable/newer/unmergeable/unwritable lock makes install fail,
  restores the prior lock byte-for-byte, and removes links created by that
  run.
- Required-member removal reports the faceless pack broken using only
  installed state.
- Library skill lint reports `fails=0`; all surviving affected skill
  harnesses are green.

**Absence**

Across live surfaces (`AGENTS.md`, `README.md`, `install.sh`, root
`PACK.md`, `docs/spec/`, `skills/`, and `crates/`):

- zero `skills/clankshop`;
- zero `/clankshop`;
- zero `Seeded from clankshop`;
- zero clankshop station-loader, setup, migrate, check, seed, or hook
  glue dependencies.

Historical `docs/design/` records outside the active portfolio are not
runtime surfaces and are exempt. Red-proof each population grep by
planting one forbidden reference in its target population and showing
the gate fails.

**Procedure**

- `./install.sh --pack grimoire` installs members and no `grimoire`
  skill.
- `./install.sh --pack clankshop` reports no matching pack and writes
  nothing.
- Installing one member directly still works without any pack state.
- Invoking a surviving independent skill on a project with no deployed
  workspace does not point at clankshop and follows its own fallback.

## Slices

| id | does | verify | paths |
|---|---|---|---|
| F1 | Add root faceless `grimoire` manifest/runbook; implement faceless install/list/check/remove, lock caching, and rollback on lock-write refusal | installer transaction fixtures | `PACK.md`, `install.sh`, `scripts/tests/install-pack-test.sh`, `crates/grimoire-pack/tests/conformance.rs`, `crates/grimoire-core/tests/parity.rs` |
| F2 | Delete the clankshop package and face fixtures | package absence + lint | `skills/clankshop/**` |
| F3 | Remove live clankshop identity, stamp probes, station summons, clankshop-specific lint assumptions, and current inventory claims; retarget live pack dogfood to faceless `grimoire` | affected harnesses + red-proof absence gates | `AGENTS.md`, `README.md`, `docs/spec/pack-format.md`, `crates/grimoire-pack/{src/discovery.rs,tests/clankshop.rs,tests/grimoire.rs}`, `crates/grimoire-core/tests/live_repo.rs`, `crates/grimoire/tests/dogfood.rs`, `skills/{architect,auditor,contractor,debugger,inspector,workstream}/**`, `skills/shopbook/scripts/tests/{flows-door-test.sh,skill-doc-test.sh}`, `skills/skill-builder/{docs/BOUNDARY-AUDIT.md,docs/DOCTRINE.md,scripts/skills-lint.sh,scripts/tests/lint-doctrine-consumer-test.sh,scripts/tests/lint-edges-test.sh}` (owned identity/station spans only; generic faced-pack support remains) |

Land order F1 → F2 → F3. One landing after F3. The next feature is
workspace-kinds; it owns the skill-first path migration.

## Out of scope

- The skill-first workspace path grammar (workspace-kinds spec).
- Backlog tracker schema or setup behavior.
- Delegate return semantics or setup behavior.
- Inspector review semantics or setup behavior.
- Automatic cleanup or migration of deployed alpha project files.
- A replacement workshop face, station system, or shared project
  doctrine tree.
