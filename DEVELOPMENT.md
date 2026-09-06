# Development

This is the `dev` branch of Grimoire: the working tree for the package manager, its local grove
client, records, trackers, and the script that publishes production snapshots.

## Branches

`dev` is the living project. `main` is a sequence of production snapshots, not a merge of `dev`.
Never merge `dev` into `main`. Preview releases tag `dev`. Production releases tag `main`.

GitHub’s default branch is `main`. Clone it for the product tree. Check out `dev` to work.

## Stay on `dev`

Do day-to-day work on `dev` in this tree. Checking out `main` here removes `.records/`,
`.trackers/`, `.streams/`, and `.spaces/` from disk.

`scripts/publish-main.sh` updates `main` with git plumbing. It does not switch this worktree.

## Local grove

The installable catalog is the sibling **grove** checkout. This repository is a Grimoire client of
that catalog. `--link` installs a symlink to the working tree you are editing:

```sh
grimoire source add grove /Users/cscott/Repos/grove --link --trust-all
grimoire install clankshop --pack --source grove
```

A filesystem path without `--link` is a Git snapshot (clean worktree, pinned commit), not the tree
you are editing. Remotes never symlink. Do not author skills into this repository.

`grimoire.toml` and `grimoire.lock` are this working tree’s grove client. They point at sibling
`../grove` with `link = true`. They stay on `dev`.

## Gate

From the checkout root:

```sh
RUSTC_WRAPPER= cargo fmt --all -- --check
RUSTC_WRAPPER= cargo test --all
RUSTC_WRAPPER= cargo clippy --all --all-targets -- -D warnings
bash scripts/tests/canonical-provider-parity-test.sh
```

The parity script needs the records and tracker providers deployed in this tree. `cargo test --all`
does not run the live clankshop CLI dogfood. To run it against sibling `../grove` or
`GRIMOIRE_LIVE_ROOT`:

```sh
RUSTC_WRAPPER= cargo test -p skill-grimoire --test root_dogfood -- --ignored
```

## Publish a production snapshot

From `dev`, with the paths you want on `main` already committed:

```sh
bash scripts/publish-main.sh
# optional: bash scripts/publish-main.sh --message "Release v0.1.0"
```

The snapshot allowlist is `crates/`, `Cargo.toml`, `Cargo.lock`, `README.md`, `LICENSE`,
`CONTRIBUTING.md`, and `SECURITY.md`. Everything else on `dev` stays here.

Then push `dev` and fast-forward `main`. `main` only needs `--force` when its history is rewritten.
