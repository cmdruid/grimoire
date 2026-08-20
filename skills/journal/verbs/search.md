# `search` — find records by content or metadata

Look up what is already recorded. Read-only. Do not mint. Do not commit.
Do not copy or refresh `records.sh` from here.

1. Resolve the agent-records home (SKILL.md discipline).
2. Deployed `<agent-records>/scripts/records.sh` missing → say so, point
   at `/journal setup`, stop. Do not file-mode-search (that duplicates
   the discriminator).
3. Usage lacks `grep` (`records.sh` with no args; the usage list has no
   `grep` line) → stop and name `/journal setup` (a later visit refreshes
   the tool). Do not copy the bundled `records.sh` from here.
4. Parse the query into a pattern and optional `list`-shaped filters
   (`--type` / `--status` / `--tag` / `--since` / `--until` when the user
   named them). Run `records.sh grep`.
5. Zero hits → say none. One hit → `show` it (or list the row and offer
   show). Many hits → print the TSV rows (path + title at least); do not
   rank; do not open every file.

## Done when

- Hits printed or shown from `records.sh grep`.
- Zero hits: said none; did not mint.
- Tool missing or usage lacks `grep`: named `/journal setup`; did not
  copy the bundled script; did not commit.
