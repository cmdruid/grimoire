# `setup [<root>]` — install the optional control surface

Resolve the canonical primary and run the package helper with `setup`. It installs or reconciles
exactly `.streams/.gitignore`, `CONFIG.md`, `README.md`, and executable `workstream.sh`, then makes
one exact pathspec-scoped commit for bytes it changed. It preserves project-authored config and
README prose. A no-op rerun makes no commit. It does not create `history.tsv`. An incumbent
`.streams/history.tsv` is left in place.

Setup doesn't edit a project front door, migrate streams, create a runtime worktree, or enable a
hook. It is optional; ordinary zero-setup creation uses package defaults.

Done when the helper reports `committed` or `current` and exactly those four control files are
tracked.
