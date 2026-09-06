# Development

This checkout is the living project. Product docs stay in `README.md` so they remain valid on
`main`. This file is the human map of how we develop here. Agent-facing gate, grove wiring, and
workstream recovery stay in `AGENTS.md`.

## Branches

`dev` is the project: source, records, trackers, streams, and this file. `main` is a sequence of
production snapshots, not a merge of `dev`. Never merge `dev` into `main`. Preview releases tag
`dev`. Production releases tag `main`.

GitHub’s default branch is `main`. Clone it for the product tree. Check out `dev` to work.

## Stay on `dev`

Do day-to-day work on `dev` in this tree. Checking out `main` here removes `.records/`,
`.trackers/`, `.streams/`, and `.spaces/` from disk.

`scripts/publish-main.sh` updates `main` with git plumbing. It does not switch this worktree.

## Local grove

The installable catalog is the sibling **grove** checkout. This repo is a Grimoire client of that
catalog. `--link` installs a symlink to the working tree you are editing:

```sh
grimoire source add grove /Users/cscott/Repos/grove --link --trust-all
grimoire install clankshop --pack --source grove
```

A filesystem path without `--link` is a Git snapshot (clean worktree, pinned commit), not the tree
you are editing. Remotes never symlink. Do not author skills into this repository.

## This checkout's client

`grimoire.toml` and `grimoire.lock` are this working tree’s grove client. They point at sibling
`../grove` with `link = true`. They stay on `dev`. They are not the product.

## Extra gate

`AGENTS.md` has the cargo gate. On `dev`, also run the records and tracker provider parity check
(it needs the providers deployed in this tree):

```sh
bash scripts/tests/canonical-provider-parity-test.sh
```

## Publish a production snapshot

From `dev`, with the paths you want on `main` already committed:

```sh
bash scripts/publish-main.sh
# optional: bash scripts/publish-main.sh --message "Release v0.1.0"
```

The snapshot allowlist is `crates/`, `Cargo.toml`, `Cargo.lock`, `README.md`, and `LICENSE`.
Everything else on `dev` stays here, including this file, `AGENTS.md`, `grimoire.toml`,
`grimoire.lock`, `docs/`, `scripts/`, and the workshop directories.

Then push `dev` and fast-forward `main`. `main` only needs `--force` when its history is rewritten.
