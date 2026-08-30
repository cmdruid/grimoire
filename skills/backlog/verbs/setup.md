# `setup` — deploy Backlog explicitly

1. Resolve `<root>`, `<agent-records>`, `<agent-workspace>`, and `<agent-trackers>` per `SKILL.md`.
   A caller-supplied `--trackers-root <repo-relative-path>` is legal only for first setup. Pass it to
   the helper; an incumbent declaration must match and existing tracker state prevents relocation.
2. First setup always creates `tasks`, `issues`, `feedback`, and `routines`; it accepts no queue
   selection. After initialization, queue population changes only through `tracker add|remove`.
3. Run package-local `scripts/backlog-setup.sh <root> --workspace <W> --records-root <R>
   [--trackers-root <T>] --apply`.
4. Parse unique `wrote=` / `reconciled=` paths. Standalone and nonempty → one
   `scripts/scoped-commit.sh <root> "Backlog: setup" <paths...>`; inside an announced configuration
   sweep, return the paths without committing; empty → no commit.

Done when the public layer has its README, executable adjacent `trackers.sh`, receipt ledger, incumbent queues, preserved editable
prompt, and one exact package-owned `debrief-anchor@1` root route whenever a queue exists; a rerun
preserves the initialized queue population and changes only drifted package-owned surfaces.
