# grimoire 🜃 — a package manager for agent skills

Grimoire is a transactional package manager for agent skills. Schema-3 manifests and locks install
each requested skill into the scope's `.agents/skills/` directory. Pinned git sources copy the
locked skill tree there as a regular directory. `--link` is a local-source hatch that installs a
symlink to that tree instead. Remotes never symlink.

The skills catalog lives in a separate library, **grove** (`~/Repos/grove`, eventually
`github:cmdruid/grove`). This repository is the manager, not the book.

### Install a skill

Initialize a project, add a source, and install from it:

```sh
grimoire init
grimoire source add grove github:cmdruid/grove --trust
grimoire install journal --source grove
grimoire install clankshop --pack --source grove
```

Pinned sources — remotes, and local git paths without `--link` — copy verified store bytes into
`.agents/skills/<name>/`. A local path with `--link` installs a symlink to that working tree and
requires `--trust-all`. `--live` is a usage error that names `--link`. There is no `path:` scheme;
a local source is an ordinary path.

```sh
grimoire source add grove /Users/cscott/Repos/grove --link --trust-all
grimoire install clankshop --pack --source grove
```

Commit `grimoire.toml`, `grimoire.lock`, and the copied skill trees under `.agents/skills/`. A clone
of those trees is skills-ready: `grimoire check` passes with no store, cache, or candidate.
`install --frozen` does not recreate a missing copy. Do not commit `--link` symlinks; they are
machine-local dirt.

### Use the tree interface

Run `grimoire` without a subcommand in an interactive terminal. It opens the nearest Project scope
when one exists and otherwise opens Global.

- Press Tab to switch scopes.
- Press Up/Down or `j`/`k` to move, and press Space to toggle a skill, pack, or optional member.
- Press Enter or `a` to apply the displayed plan. Destructive plans default to no.
- Press `c` or Escape to discard staged changes.
- On a source row, press `f` to fetch, `u` to update from the cached candidate, or `t` to open the
  separate trust-all confirmation. Update never fetches.
- Press `q` to quit and discard unapplied changes.

### Verify the implementation

Run the repository gate from the checkout root:

```sh
RUSTC_WRAPPER= cargo fmt --all -- --check
RUSTC_WRAPPER= cargo test --all
RUSTC_WRAPPER= cargo clippy --all --all-targets -- -D warnings
```

`cargo test --all` does not run the live clankshop CLI dogfood. To run it against sibling `../grove`
or `GRIMOIRE_LIVE_ROOT`:

```sh
RUSTC_WRAPPER= cargo test -p skill-grimoire --test root_dogfood -- --ignored
```

The root-layout inventory tests stay on the default path. They use `GRIMOIRE_LIVE_ROOT` when set,
otherwise sibling `../grove` when that tree contains `packs/clankshop/PACK.md`. Set
`GRIMOIRE_LIVE_ROOT=/absolute/path/to/grove` to point at another catalog.

Library lint and skill-contract tests run in the grove checkout, not here.

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

## License

MIT — see `LICENSE`.
