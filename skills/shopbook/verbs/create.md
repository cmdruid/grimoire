# `create` — mint a host-procedure stub

Mint crawl keys + H1 at `$DST/<stem>.md`. The **calling** agent then
authors the procedure body in that file. This skill does not fill the
walk, does not overwrite incumbents, and does not mint records.

0. This file runs **only** after dispatch chose `create`. If opened for
   `/shopbook query` / `list` / `search` / `find`, STOP and run the
   query walk; do not call `flows-create.sh`. If opened for
   `/shopbook new` / `add` / `author` or another unknown slash token,
   STOP and **ask**; do not mint.
1. Resolve project root and `<agent-workspace>` the same way as query.
2. Stem from the argument; if missing and a human is present, **ask**.
   If missing and no human, stop; do not call the script. If the
   argument is not already kebab and a human is present, **propose**
   one (lowercase; non `[a-z0-9]` → `-`; collapse repeats; trim edge
   hyphens; strip a trailing `.md`) and **confirm**; then the script
   validates. If the argument is not kebab and no human, stop; do not
   slugify; do not call the script.
3. Optional `--title` / `--use-when`; if omitted and a human is
   present, ask; else script defaults.
4. Run this skill's `scripts/flows-create.sh`
   `--root --workspace --stem [--title] [--use-when]`.
5. Decision:
   - `reason=bad-stem` / `no-home` / `bad-value` → report; stop.
   - `reason=incumbent` → report the existing path; stop. Do not
     overwrite. Missing crawl keys on that file are `/shopbook upkeep`,
     not `create`.
   - `created=true` → print `path=`. The **calling** agent then authors
     the procedure body **in that file** (calling context). Shopbook
     does not fill the walk. Do not list other stems. Do not run
     `sync` (adding a file does not drift the pointer).

## Done when

- `created=true`: printed `path=`; caller is authoring the body in that
  file; did not invent steps; did not dump the catalog.
- Refused (`bad-stem` / `no-home` / `bad-value` / `incumbent`): reported
  the reason; wrote nothing (incumbent: left the existing file).
- Opened for query aliases: ran the query walk; did not mint.
- Opened for an unknown slash token: asked; did not mint.
