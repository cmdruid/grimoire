# `search` — find records by content or metadata

Look up what is already recorded. Read-only. Do not mint. Do not commit.
Do not copy or refresh `records.sh` from here.

1. Resolve the agent-records home (SKILL.md discipline).
2. Deployed `<agent-records>/scripts/records.sh` missing **or not
   executable** → say so, point at `/journal setup`, stop. Do not
   file-mode-search (that duplicates the discriminator). Do not run the
   bundled copy.
3. Usage lacks `grep` (`records.sh` with no args; the usage list has no
   `grep` line) → stop and name `/journal setup` (a later visit refreshes
   the tool). Do not copy the bundled `records.sh` from here.
4. Parse the query into optional `list`-shaped filters (`--type` /
   `--status` / `--tag` / `--since` / `--until` / `--stage` when the user named them)
   and an optional **body** pattern. Metadata lives only in those
   filters, never in the pattern (`grep` skips front-matter). Map a
   metadata-shaped query onto filters before concluding "none".
   `list` without `--status` hides `archived`; `grep` without `--status`
   does not.
   - No body pattern (filters only, or a metadata-only ask) →
     `records.sh list` with those filters.
   - Body pattern → `records.sh grep` with those filters.
5. Zero hits → say none. One hit → `show` it (or list the row and offer
   show). Many hits → print the TSV rows (path + title at least); do not
   rank; do not open every file.

## Done when

- Hits printed or shown from `records.sh list` or `grep`.
- Zero hits: said none after mapping metadata onto filters; did not mint.
- Tool missing, not executable, or usage lacks `grep`: named
  `/journal setup`; did not copy the bundled script; did not commit.
