# grimoire 🜃 — a package manager for agent skills

Grimoire installs agent skills into a project or global scope. You declare sources and requested
skills in a schema-3 manifest; a lockfile pins the resolved trees. Install copies each locked skill
into `.agents/skills/`.

The skills catalog is a separate library, [grove](https://github.com/cmdruid/grove). This repository
is the manager, not the book.

## Install the CLI

Rust and Cargo are required. From a clone of this repository:

```sh
cargo install --path crates/grimoire
```

The binary is `grimoire`, from crate `skill-grimoire`.

## Install a skill

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

Commit `grimoire.toml`, `grimoire.lock`, and the copied skill trees under `.agents/skills/`. A clone
of those trees is skills-ready: `grimoire check` passes with no store, cache, or candidate.
`install --frozen` does not recreate a missing copy. Do not commit `--link` symlinks; they are
machine-local dirt.

## Use the tree interface

Run `grimoire` without a subcommand in an interactive terminal. It opens the nearest Project scope
when one exists and otherwise opens Global.

- Press Tab to switch scopes.
- Press Up and Down or `j` and `k` to move, and press Space to toggle a skill, pack, or optional
  member.
- Press Enter or `a` to apply the displayed plan. Destructive plans default to no.
- Press `c` or Escape to discard staged changes.
- On a source row, press `f` to fetch, `u` to update from the cached candidate, or `t` to open the
  separate trust-all confirmation. Update never fetches.
- Press `q` to quit and discard unapplied changes.

## Commands

| Command | What it does |
|---|---|
| `grimoire` | Opens the tree interface in an interactive terminal |
| `grimoire init` | Creates a project or global scope |
| `grimoire source add` | Registers a source and reviews its candidate |
| `grimoire install` | Reconciles desired state, or adds one skill or pack |
| `grimoire uninstall` | Removes one direct skill or pack request |
| `grimoire update` | Advances sources from cached candidates |
| `grimoire list` | Shows desired, resolved, installed, and inherited skills |
| `grimoire check` | Reports state, trust, store, and link findings |
| `grimoire trust` | Inspects and revokes identity-wide trust |
| `grimoire store prune` | Deletes immutable snapshots that are proven unreachable |

`grimoire --help` and `grimoire <command> --help` list flags for each command.

## License

MIT. See [LICENSE](LICENSE).

See [CONTRIBUTING.md](CONTRIBUTING.md) to build from source and send changes, and
[SECURITY.md](SECURITY.md) to report a vulnerability.
