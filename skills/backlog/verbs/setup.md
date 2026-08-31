# `setup` — deploy Backlog explicitly

1. Resolve `<root>` per `SKILL.md`. Backlog uses the fixed `.trackers` layer. In a Git checkout,
   `<root>` must be its top level; a nested directory refuses before any write.
2. First setup always creates `tasks`, `issues`, `feedback`, and `routines`; it accepts no queue
   selection. After initialization, queue population changes only through `tracker add|remove`.
3. Run package-local `scripts/backlog-setup.sh <root> --apply`.
4. Parse unique `wrote=` / `reconciled=` paths. Standalone and nonempty → one
   `scripts/scoped-commit.sh <root> "Backlog: setup" <paths...>`; inside an announced configuration
   sweep, return the paths without committing; empty → no commit.

Done when the public layer has its README, executable adjacent `trackers.sh`, receipt ledger, incumbent queues, preserved editable
prompt, and one exact package-owned `debrief-anchor@1` root route whenever a queue exists; a rerun
preserves the initialized queue population and changes only drifted package-owned surfaces. For an
existing pre-cut project, move a customized prompt before this first setup with
`git mv .spaces/backlog/hooks/debrief.md .trackers/DEBRIEF.md`; setup never probes the old path.
