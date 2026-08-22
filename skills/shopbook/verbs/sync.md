# `sync` — repair the procedures pointer in AGENTS.md

Rewrite only the delimited flows pointer span. New flow files do not
require `sync`. `--check` is facts-only (write nothing). Missing
`AGENTS.md` is a no-op write. Shopbook never creates a door.

1. Resolve project root and `<agent-workspace>` the same way as query.
2. Run this skill's `scripts/flows-door.sh`
   `check|apply --root --workspace`.
   - `--check` / facts-only: print the facts (`workspace=` `flows_dir=`
     `door=` `door_class=` `block=` `drift=`); write nothing.
   - `apply`: same decision table as the bundled script. `door_class`
     other than `agents` → no-op 0; never create `AGENTS.md`; never
     write `CLAUDE.md`. `block=malformed` → stop, touch nothing.
     `block=missing` on an existing `AGENTS.md` → append the pointer.
     `block=ok` → rewrite only the delimited span (idempotent).
3. Report the facts. Adding or deleting a `flows/*.md` file does not
   drift the pointer — do not `sync` for that.

## Done when

- `--check`: facts printed; nothing written.
- `apply`: pointer span matches the resolved `<agent-workspace>/flows/`
  literal, or a no-op / stop was reported; `CLAUDE.md` untouched;
  `AGENTS.md` not created.
