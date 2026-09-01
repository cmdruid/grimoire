<!-- journal:records-tool BEGIN -->
## Use the records tool

The executable `records.sh` beside this README is the records query and lifecycle engine. You don't
need the Journal skill for ordinary record work: run the adjacent provider from the project root,
where it self-locates through the fixed `.records/` directory.

    .records/records.sh list

A record is a Markdown file named `YYYY-MM-DD-<slug>.md` with front matter declaring `doctype`, `status`, `schema`, and `tags`.
Both the filename and `doctype` are required. The filename date is
the creation authority, the path relative to `.records/` is the record ID, and Git is the durable
modification history. Directories belong to their writers; the provider discovers records with a
live crawl at any depth.

Use these read-only commands to discover and validate records:

- `list [--type TYPE] [--status STATUS] [--tag TAG] [--since DATE] [--until DATE] [--stage STAGE]`
  lists live `draft` and `published` records as TSV.
- `grep [filters] PATTERN` searches record bodies after applying the same metadata filters.
- `show PATH` prints one record. `PATH` can be relative to `.records/`.
- `history [--type TYPE] [--disposition DISPOSITION] [--since DATE] [--until DATE] [--grep PATTERN]`
  reads closure events from `history.tsv`, optionally narrowed by those filters.
- `prune-candidates [--until DATE]` lists archived records eligible for human pruning judgment.
- `check` validates record metadata, record links, and lifecycle-ledger coherence.

Use these commands to change record state:

- `new DOCTYPE --schema WRITER/ARTIFACT@N --title "TITLE" [--template BODY_PATH] [--dir DIR] [--tag TAG]...`
  creates a `draft` record and prints its absolute path. `BODY_PATH` names a readable body-template
  file, not inline prose; it may use the `<title>` and `<date>` slots and must not contain front
  matter. Use a schema owned by the workflow or record writer; don't invent a replacement for a
  missing package-owned schema.
- `touch PATH [--status draft|published]` optionally changes a live status and prints the record's
  relative path. Edit record body prose normally, then use `touch` when the status changes. Run
  `check` to validate record metadata, links, and lifecycle-ledger coherence after your edits.
- `done PATH [--as done|dropped|superseded|consumed] [--note "NOTE"]` archives a record in place and
  appends its closure event to `history.tsv`.
- `relocate SOURCE --to DESTINATION` moves a dated record, updates owned links and ledger paths, and
  prints the old and new relative paths. External references block the move until you resolve them.

Run `.records/records.sh` without a command to print the complete current usage.
Never edit `history.tsv` by hand, never hand-close a record by writing `status: archived`, and never substitute
provider bytes from another checkout. After a mutation, inspect the reported paths and Git diff,
then commit only the records and ledger paths that operation changed in the checkout that owns them.

Setup, repair, brownfield migration, schema migration, and records curation remain maintenance work.
If the adjacent provider or this managed guide is missing or stale, stop. Run `/journal repair`; if
initialization or a root migration is required, use the corresponding Journal procedure. When the
Journal skill isn't available, stop and report the maintenance requirement instead of improvising
tool bytes, ledger entries, schemas, or migration behavior.
<!-- journal:records-tool END -->
