# `repair` — restore the initialized tool surface

1. Resolve `<root>` per `SKILL.md` and run package-local
   `scripts/backlog-setup.sh <root> repair`.
2. Repair requires a valid lifecycle-history ledger and valid incumbent table schemas. It may write
   only `.trackers/trackers.sh`, that file's executable bit, and Backlog's managed
   `backlog:trackers-tool` README block. It never creates roots or changes declarations, table or
   history data, prompts, routes, or unrelated README prose.
3. Parse unique `wrote=` paths. Standalone and nonempty → one scoped commit with `Backlog: repair`;
   inside an announced configuration sweep, return the paths without committing; empty → no commit.

Done when the initialized layer has an executable canonical provider that describes exactly
`schema=tracker@2`, `catalog` succeeds, the managed README block is current, and no other project
surface changed.
