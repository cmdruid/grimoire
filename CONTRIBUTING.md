# Contributing

Thank you for contributing to Grimoire.

## Where to work

Day-to-day development is on the [`dev`](https://github.com/cmdruid/grimoire/tree/dev) branch.
`main` is a sequence of production snapshots. Open pull requests against `dev`. Do not merge `dev`
into `main`.

```sh
git clone https://github.com/cmdruid/grimoire.git
cd grimoire
git checkout dev
```

The skills catalog is [grove](https://github.com/cmdruid/grove). Do not author skills into this
repository.

## Build and test

Rust and Cargo are required. From the checkout root:

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

Root-layout inventory tests stay on the default path. They use `GRIMOIRE_LIVE_ROOT` when set,
otherwise sibling `../grove` when that tree contains `packs/clankshop/PACK.md`. Set
`GRIMOIRE_LIVE_ROOT=/absolute/path/to/grove` to point at another catalog.

Library lint and skill-contract tests run in the grove checkout, not here.

On `dev`, also run the records and tracker provider check:

```sh
bash scripts/tests/canonical-provider-parity-test.sh
```

That script is not on `main`.

## Pull requests

1. Branch from `dev`.
2. Keep the change scoped to one problem.
3. Run the cargo gate before you open the pull request.
4. Target `dev`. Maintainers publish production snapshots onto `main`.

## Security

Do not open a public issue or pull request for a vulnerability. See [SECURITY.md](SECURITY.md).

The snapshot workflow and this checkout's grove client are documented on `dev` in
[DEVELOPMENT.md](https://github.com/cmdruid/grimoire/blob/dev/DEVELOPMENT.md).
