# `tracker` — add, remove, or list queues

Resolve all roots per `SKILL.md`.

- `list [<stem>]`: run package-local `scripts/tracker-runtime-check.sh` with the resolved roots, then
  invoke `catalog` on its returned installed provider. When named, report that queue's counts or
  refuse if absent.
- `add <stem>`: run package-local `scripts/backlog-setup.sh` with the resolved root arguments and
  `tracker-add <stem>`. It creates exactly `.trackers/tables/<stem>.tsv`, adds the absent prompt
  section, and refreshes the installed provider. Incumbent stems refuse. In a preserved older
  installation, `/backlog tracker add failures` explicitly installs the packaged failure-routing
  section without changing any incumbent prompt bytes.
- `remove <stem>`: run the same helper with `tracker-remove <stem>`. It deletes the named queue even
  when rows remain, removes only its prompt section, and preserves history. Git is the recovery
  mechanism.

Add/remove makes one scoped commit over reported paths; list is read-only.

Done when API catalog reflects the requested population, the prompt agrees, no front door changed,
and any mutation was committed once with exact paths.
