# `setup` — deploy Backlog explicitly

1. Resolve `<root>`, `<agent-records>`, `<agent-workspace>`, and `<agent-trackers>` per `SKILL.md`.
   A caller-supplied `--trackers-root <repo-relative-path>` is legal only for first setup. Pass it to
   the helper; an incumbent declaration must match and existing tracker state prevents relocation.
2. Bare setup uses `tasks`, `issues`, `feedback`, and `routines`. If the invocation explicitly names
   builtin or custom stems, that selection replaces the defaults.
3. Run package-local `scripts/backlog-setup.sh <root> --workspace <W> --records-root <R>
   [--trackers-root <T>] --apply [<builtin-stems...>] [--custom <custom-stems...>]`.
4. Parse unique `wrote=` / `removed=` paths. Standalone and nonempty → one
   `scripts/scoped-commit.sh <root> "Backlog: setup" <paths...>`; inside an announced configuration
   sweep, return the paths without committing; empty → no commit.

Done when the public layer has its README, API, receipt ledger, selected queues, preserved editable
prompt, and bounded root route; a rerun changes only a drifted managed API.
