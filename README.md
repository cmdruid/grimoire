# grimoire 🜃 — a package manager for agent skills

Grimoire is a transactional package manager for agent skills. Strict schema-2 manifests and locks
can project each requested skill from the immutable user-local store or from a managed,
project-committed vendor tree. Both modes activate through `.agents/skills/` symlinks and share the
same source review, trust, planning, ownership, and recovery boundaries. The published projection
contract is
`.records/specs/2026-09-03-grimoire-install-projections-and-managed-vendoring.md`.

The skills catalog lives in a separate library, **dojo** (`~/Repos/dojo`, eventually
`github:cmdruid/dojo`). This repository is the manager, not the book.

### Install a skill

Initialize a project, approve a source, and choose its projection mode:

```sh
grimoire init
grimoire source add dojo /Users/cscott/Repos/dojo --live --trust
grimoire install journal --source dojo
grimoire install clankshop --pack --source dojo
```

`--live` is the local-source path: install links the working tree. Omit it and Grimoire
snapshots a clean Git commit instead. When the library is on GitHub, the source line is
`github:cmdruid/dojo` instead of the filesystem path. There is no `path:` scheme; a local
source is an ordinary path.

An omitted mode creates a new request in linked mode. Repeating `install` without a mode preserves
an existing request's mode. Pass `--link` or `--vendor` to convert it explicitly. Vendoring is
available only in Project scope; Grimoire copies verified immutable-store bytes to
`vendor/grimoire/SOURCE/SKILL` and uses a relative activation symlink so the project remains
movable.

Commit `grimoire.toml`, `grimoire.lock`, and managed vendor trees. You can ignore
`.agents/skills/`, which Grimoire regenerates. In a fresh offline clone, approve the exact committed
vendor bytes and restore activation without a source candidate, cache, or store snapshot:

```sh
grimoire source trust dojo --vendor
grimoire install --frozen
grimoire check
```

### Use the tree interface

Run `grimoire` without a subcommand in an interactive terminal. It opens the nearest Project scope
when one exists and otherwise opens Global.

- Press Tab to switch scopes.
- Press Up/Down or `j`/`k` to move, and press Space to toggle a skill, pack, or optional member.
- In Project scope, press `v` to switch the selected direct skill or pack root between linked and
  vendored mode. Pack members display their inherited mode and remain read-only.
- Press Enter or `a` to apply the displayed plan. Destructive plans default to no.
- Press `c` or Escape to discard staged changes.
- On a source row, press `f` to fetch, `u` to update from the cached candidate, or `t` to open the
  separate trust-all confirmation. Update never fetches.
- Press `q` to quit and discard unapplied changes.

### Verify the implementation

Run the repository gate from the checkout root. Live-root dogfood needs the skills catalog:

```sh
RUSTC_WRAPPER= cargo fmt --all -- --check
RUSTC_WRAPPER= cargo test --all
RUSTC_WRAPPER= cargo clippy --all --all-targets -- -D warnings
```

The root-layout dogfood tests use `GRIMOIRE_LIVE_ROOT` when set, otherwise sibling `../dojo` when
that tree contains `PACK.md`. Set `GRIMOIRE_LIVE_ROOT=/absolute/path/to/dojo` to point at another
catalog.

Library lint and skill-contract tests run in the dojo checkout, not here.

### Install the CLI

The binary is `grimoire`, from crate `skill-grimoire`:

```sh
cargo install --path crates/grimoire
```

## Repo layout

- **`crates/`** — Cargo workspace. `grimoire-pack` owns canonical source inventory, `grimoire-core`
  owns declarative state, resolution, and the pure planner, and `skill-grimoire` provides the
  command-line and staged tree adapters. Crates never read a skills catalog at build time — live
  content appears only as test fixtures via `GRIMOIRE_LIVE_ROOT`.
- **`.records/specs/`** — published product contracts.

## License

MIT — see `LICENSE`.
