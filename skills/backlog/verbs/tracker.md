# `tracker` — add, remove, or list queues

Resolve all roots per `SKILL.md`.

- `list [<stem>]`: run package-local `scripts/tracker-runtime-check.sh` with the resolved roots, then
  invoke `catalog` on its returned installed provider; exclude reserved `receipts` from the configurable
  population. When named, report that queue's counts or refuse if absent.
- `add <stem>`: run package-local `scripts/backlog-setup.sh` with the resolved root arguments and
  `tracker-add <stem>`. It creates exactly `<agent-trackers>/<stem>.tsv`, adds the absent prompt
  section, and reconciles the route. `receipts` and incumbent stems refuse.
- `remove <stem>`: run the same helper with `tracker-remove <stem>`. It deletes the named queue even
  when rows remain, removes only its prompt section, preserves receipts, and removes the route block
  when no configurable queues remain. Git is the recovery mechanism.

Add/remove makes one scoped commit over reported paths; list is read-only.

Done when API catalog reflects the requested population, prompt and route agree, and any mutation
was committed once with exact paths.
