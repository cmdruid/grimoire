# `setup` — deploy Backlog explicitly

1. Resolve `<root>` per `SKILL.md`. Backlog uses the fixed `.trackers` layer. In a Git checkout,
   `<root>` must be its top level; a nested directory refuses before any write.
2. First setup always creates `tasks`, `issues`, `feedback`, and `routines`; it accepts no queue
   selection. After initialization, queue population changes only through `tracker add|remove`.
3. Run package-local `scripts/backlog-setup.sh <root> --apply`.
4. Parse unique `wrote=` / `reconciled=` paths. Standalone and nonempty → one
   `scripts/scoped-commit.sh <root> "Backlog: setup" <paths...>`; inside an announced configuration
   sweep, return the paths without committing; empty → no commit.

Done when the public layer has its README, executable adjacent `trackers.sh`, lifecycle history,
incumbent tables, `.trackers/tables/.gitkeep`, and preserved editable prompt; no project front door
changed; and a rerun preserves the initialized queue population while changing only drifted
package-owned surfaces.

Setup intentionally does not read or move tracker@1 state. When it refuses a flat tracker@1 layout,
use `/backlog migrate`; migration remains the only legacy reader.
