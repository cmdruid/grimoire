---
doctype: plans
status: published
schema: contractor/plan@1
tags: [plan]
stage: approved
---

# Grimoire skill activation as copies — Implementation Plan

Governing spec: → specs/2026-09-04-grimoire-skill-activation-as-copies-live-local-as-symlink.md
(replaces → specs/2026-09-03-grimoire-install-projections-and-managed-vendoring.md).

This is a public compatibility migration (schema 2 → 3) and a custody change (activation copies
replace vendor trees and activation symlinks). Schema 2 is unsupported. Recovery is the existing
hard-cut diagnostic: bump the manifest schema, delete the generated lock, and reinstall. There is
no silent migration. Clone-and-go recovery is the committed copy trees themselves; vendor receipts
and `source trust --vendor` go away.

## Scope

- Outcome: pinned sources copy locked skill trees into `<scope>/.agents/skills/<name>/`; `--link`
  is a local-source symlink hatch; `vendor/grimoire/`, projection `mode`, vendor receipts, and
  `source trust --vendor` are gone. Ordinary `scan()` does not pay vendor-strict checks. Live-root
  dogfood is off the default gate.
- Affected surface: `crates/grimoire-core` (manifest, lock, trust, plan, apply, vendor copy,
  resolve, world, check), `crates/grimoire` (CLI, TUI, tests, `README.md`, `AGENTS.md`),
  `crates/grimoire-pack/src/inventory/scan.rs`.
- Non-goals / constraints: no silent schema migration; no second committed tree (`vendor/grimoire/`
  plus copies); no `--link` on remotes; no `.gitignore` edits; no transaction-journal rewrite
  (reuse the existing journal; destination becomes `.agents/skills/<name>`). Do not implement the
  old GrantVendor prompt fix or extract vendor projection as a helper — both die in this cut.

## Implementation

- [ ] Fold strict skill-tree checks and ignore `.agents` in discovery
  - Where: `crates/grimoire-pack/src/inventory/scan.rs`. Add `.agents` to `IGNORED_DIRECTORIES`
    (it is not there today; `vendor` is). Internal strict path or private helper; no public API.
    Public `scan()` findings stay unchanged. Only the skill-tree path emits `unsupported-entry` /
    `git-metadata` when a path component is `.git`, and only that path applies directory `0o755`
    and file `0o644|0o755` mode checks. `scan_skill_tree()` does not call `visit_entries` a third
    time. Bound and no-follow stay. Do not reconstruct checks from `SourceInventory` after `scan()`
    returns.
  - Verify: `cargo test -p grimoire-pack bounded_skill` — two 100,001-entry walks, not three.
    `vendor_tracer` still rejects `invalid-entry-mode` and `unsupported-entry`. Ordinary `scan()` of
    a git source does not report those codes. A tree with `skills/visible` and
    `.agents/skills/installed` reports only `visible`.

- [ ] Hard-cut source kinds to schema 3
  - Where: manifest/lock/trust schemas and CLI/TUI. `grimoire/manifest@3`, `grimoire/lock@3`,
    `grimoire/trust@3`. Drop `mode` and `live`; sources use `link = true`; lock source kind is
    `link`. `--link` exists only on `source add`; illegal on a remote and with `--ref`. `--live` is
    a usage error that names `--link`. Remove install `--link`/`--vendor` and the TUI `v` toggle.
    Schema 2 is unsupported: diagnostic tells the developer to bump the manifest schema, delete the
    generated lock, and reinstall (same shape as today's `LockSchemaUnsupported` for v1). Trust@3
    keeps identity, exact receipts, `all_snapshots`, and baseline; drop `vendor_receipts`. `--trust`
    on a link source is a usage error; activating a link source requires `--trust-all`. Update
    `hard_cut.rs` current-schema needles to `@3`.
  - Verify: schema-3 goldens (no `mode`, no `live`, v2 rejection, `--live` names `--link`,
    deterministic bytes). `cargo test -p skill-grimoire --test hard_cut --test cli_grammar`. TUI has
    no projection toggle.

- [ ] Activate by copy or link; retire vendor projection
  - Where: after the schema-3 cut. Retarget the existing vendor copy-and-verify (`prepare_from_store`
    and friends in `crates/grimoire-core/src/vendor.rs`) to `<scope>/.agents/skills/<name>/`. Planner and resolve
    take activation from source kind, not per-request `ProjectionMode`. Pinned: copy from the
    immutable store only; lock is the ownership receipt; digest mismatch or structural failure is
    drift and blocks update/uninstall; foreign occupants are left untouched. Link: symlink to the
    source skill path (absolute). Never create `vendor/grimoire/`. Reuse the scope journal; do not
    rewrite it. Observation/check/list use the spec's `copy_*` / `link_*` / `foreign` states.
    `install --frozen` may create a missing link symlink and must not create a missing copy. A
    `copy_current` tree does not require the store. Remove `GrantVendor`, `source trust --vendor`,
    and vendor-trust receipts.
  - Verify: `cargo test -p grimoire-core --test vendor_tracer --test vendor_apply --test
    vendor_lifecycle --test trust` and `cargo test -p skill-grimoire --test mixed_projection --test
    vendor_offline --test vendor_plan_render --test tui_parity` (retargeted: copy in Project and
    Global is a regular directory with lock digest, no symlink, no `vendor/grimoire/`; `--link`
    local path is a symlink; `--link` on a remote is a usage error; committed copy clone `check`s
    without store; frozen does not recreate a deleted copy; drift blocks update/uninstall).

- [ ] Demote live-root dogfood and retarget it to `--link`
  - Where: `#[ignore]` on `root_clankshop_pack_installs_checks_and_uninstalls_through_the_cli`.
    Drive it with `source add … --link` against sibling `../dojo`; do not require committing those
    symlinks. `README.md` and `AGENTS.md` replace `--live` / vendor clone-and-go with copy +
    optional `--link`. Next to the existing gate, document
    `RUSTC_WRAPPER= cargo test -p skill-grimoire --test root_dogfood -- --ignored`. Leave
    `live_root_layout.rs` on the default path.
  - Verify: `cargo test -p skill-grimoire --test root_dogfood` does not run the ignored test. The
    ignored command still selects it. The ignored test's `source add` uses `--link` against
    sibling `../dojo` and does not commit those symlinks.

## Done when

- Pinned install in Project and Global creates `.agents/skills/<name>/` as a regular directory
  whose digest matches the lock, with no activation symlink and no `vendor/grimoire/`.
- Local `--link` installs a symlink to that tree's skill directory; remotes cannot `--link`.
- A committed Project copy clone: `grimoire check` passes with no store, cache, or candidate;
  `install --frozen` does not recreate a deleted copy.
- Drift blocks update and uninstall; restoring the digest unblocks.
- Source scan of `skills/visible` plus `.agents/skills/installed` reports only `visible`.
- Strict skill verification walks twice, not three times, and still rejects `.git` and
  non-normalized modes; public `scan()` does not.
- Schema 2 is rejected with the bump-and-reinstall diagnostic. `cargo test --all` does not run
  the live clankshop dogfood.
