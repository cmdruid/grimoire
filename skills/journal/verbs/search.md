# `search` — find records by content or metadata

Read-only. Do not mint, commit, or refresh provider bytes.

1. Resolve `<root>` and run `scripts/records-runtime-check.sh --root <root>`. Emit its one exact
   setup-required or repair-required diagnostic and stop on failure. On success, use its sole output
   line as the absolute staged-provider path. Do not resolve `.agents/skilldata`, file-mode search, or execute
   the bundled provider against project records.
2. Parse the query into optional `list` filters (`--type`, `--status`, `--tag`, `--since`, `--until`,
   `--stage`) and an optional body pattern. Metadata belongs in filters; `grep` skips front matter.
   Map metadata-shaped requests before concluding there are no hits. `list` without status hides
   archived records; `grep` without status does not.
3. With filters only, invoke the staged provider's `list`; with a body pattern, invoke its `grep`.
   Zero hits → say none. One hit → `show` it or report the row. Many hits → report TSV path and title
   without ranking or opening every file.

## Done when

Hits came only from the staged provider, zero hits were reported after filter mapping, or one exact
runtime recovery diagnostic stopped the operation.
