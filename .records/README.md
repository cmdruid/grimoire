# Records

Records accumulated during development.

<!-- journal:records-tool BEGIN -->
## Use the records tool

The executable `records.sh` beside this README is the query and lifecycle engine. A
record is a Markdown file named `YYYY-MM-DD-<slug>.md` with front matter declaring
`doctype`, `status`, `schema`, and `tags`. The filename date is the creation
authority; Git is the durable modification history.

Record paths are relative to this records root. The tool discovers records by a live crawl at
any depth; directories belong to their writers, not to a stored roster. `history.tsv` is the
closure ledger and is never a substitute for the live record set.

Run the adjacent tool from the project root. It locates the project from its fixed
`.records` home:

    .records/records.sh list

Start with these read-only commands:

- `list [filters]` lists live records (`draft` and `published`) as TSV.
- `grep [filters] <pattern>` searches record bodies; metadata belongs in filters.
- `show <path>` prints one record; paths may be relative to `.records`.
- `history [filters]` reads the closure ledger.
- `check` validates record metadata, links, and ledger coherence.

Lifecycle commands write records:

- `new <doctype> --schema <writer/artifact@N> --title "..." [--dir <rel>] [--tag t]...`
  mints a record with the shared metadata. Use the schema owned by the record writer.
- `touch <path> [--status draft|published]` updates a live record.
- `done <path> [--as done|dropped|superseded|consumed] [--note "..."]` archives a
  record in place and appends its closure to `history.tsv`.
- `relocate <source> --to <destination-relative>` moves a record while updating
  internal links and ledger paths.

Every command uses the adjacent self-locating provider. Run `records.sh` without a command
to see the complete usage. Never edit `history.tsv` by hand; `records.sh done` is
its sole writer.

If the adjacent `records.sh` is missing, non-executable, byte-stale, or lacks the current
usage surface, do not hand-repair it and do not run a bundled Journal copy against project
records. Run `/journal repair`; missing initialization is handled by `/journal setup`.
<!-- journal:records-tool END -->

The directory layout under this root belongs to record writers. The engine
crawls records at any depth and knows no store roster. Project templates live
at `.spaces/<skill>/templates/` (for example, `.spaces/notepad/templates/`);
project doctrine lives at `.spaces/<skill>/doctrine/`. Journal setup deploys
the engine, ledger, and this README only.

Stood up by journal on 2026-08-29.
