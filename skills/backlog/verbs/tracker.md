# `tracker` — add, remove, or list living trackers

Resolve roots and require the staged engine per `SKILL.md`.

- `list [<stem>]`: invoke `list` (with `--tracker` when named) and summarize its output. Do not
  open TSV files.
- `add <stem>`: preflight registration, invoke `tracker-add <stem>`, then ensure the owned route
  block. If a custom stub was created, author only that H2's routing body before committing.
- `remove <stem>`: preflight registration, invoke `tracker-remove <stem>`, then remove the owned
  route block only when `list` reports no trackers. Open rows refuse without changing the cookbook.
  If neither component exists but a stale owned block does, remove that block as repair.

Add/remove commits every reported path once through the scoped helper; list is read-only.
