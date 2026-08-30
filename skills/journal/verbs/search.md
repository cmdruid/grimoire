# `search` — find records by content or metadata

Look up what is already recorded. Read-only. Do not mint. Do not commit.
Do not copy or refresh `records.sh` from here.

1. Resolve the project root, `.spaces`, and `.records` (SKILL.md discipline).
2. Run SKILL.md's ordered runtime preflight. Emit its one exact setup-required or repair-required
   diagnostic and stop on the first failure. Do not file-mode-search (that duplicates the
   discriminator), copy the bundled provider, or execute it against project records.
3. Prefix every invocation with `.records/records.sh`, then parse the query into optional `list`-shaped filters (`--type` /
   `--status` / `--tag` / `--since` / `--until` / `--stage` when the user named them)
   and an optional **body** pattern. Metadata lives only in those
   filters, never in the pattern (`grep` skips front-matter). Map a
   metadata-shaped query onto filters before concluding "none".
   `list` without `--status` hides `archived`; `grep` without `--status`
   does not.
   - No body pattern (filters only, or a metadata-only ask) →
     `.records/records.sh list` with those filters.
   - Body pattern → `.records/records.sh grep` with those filters.
4. Zero hits → say none. One hit → `show` it (or list the row and offer
   show). Many hits → print the TSV rows (path + title at least); do not
   rank; do not open every file.

## Done when

- Hits printed or shown from `.records/records.sh list` or `grep`.
- Zero hits: said none after mapping metadata onto filters; did not mint.
- Runtime preflight failed: emitted exactly one ordered recovery diagnostic; did not invoke or copy
  the bundled script; did not commit.
