# `migrate` — brownfield onramp

Bring an existing project with **organic** structure — ad-hoc doc trees, hand-rolled trackers
and notes, possibly a legacy records root (e.g. `dev/`) — into the workshop layout. The spine
of the procedure: inventory by script, one confirmed mapping table, mechanical moves by
script, judgment merges by hand, done means `check` green.

**Guard:** resolve the project root first (conversation → cwd → ask). If `<root>/.handbook`
exists, stop — already seeded. On a genuinely bare repo prefer `setup` (nothing to migrate).

## The walk

1. **Preflight (script).** `scripts/migrate-scan.sh <root>` inventories candidate artifacts —
   markdown docs with their git dates and first headings, tracker-shaped files, doc-tree
   roots, CI configs, the door files present. Facts only; classification is yours.
2. **One confirmed mapping table.** Propose a destination for **every** inventoried artifact —
   a station chapter (doctrine folds into `core/` or a station `POLICY.md`), a record store
   (`.records/<store>/`), or *leave in place* — and show the human the whole table at once.
   **Nothing moves before the table is confirmed.** A legacy records root the project wants to
   keep (e.g. `dev/`) is declared in place via the door's `records-root:` line, never bulk
   `git mv`'d.
3. **Execute the mechanical rows.**
   - Seed the doctrine: `scripts/seed.sh <root> --gate '<gate>' --trunk '<trunk>'` (the two
     facts confirmed alongside the table).
   - Stand up the records machinery via `journal` (its standup owns `.records/` scaffolding,
     templates, `records.sh`) — pointed at the declared records root.
   - Move adopted records into their stores with `git mv` (history survives); keep original
     filenames — the path is the ID either way.
   - Backfill front-matter on every adopted record: `doctype` from the destination store,
     `created`/`updated` from `git log`, `status` flagged for judgment where ambiguous.
4. **Perform the judgment merges.** Organic policy and convention docs fold into `core/` or
   the station `POLICY.md`s **below** the seeded preambles — integrated, deduplicated, linked
   (the precedence rule holds from day one). The door is written **into** the existing
   `AGENTS.md`: pointer + thin routing table, existing content preserved.
5. **Done means `check` is green.** Run the `check` verb; fix what it reports. One conformance
   regime, no grandfathering: after migration, `records.sh` sees everything.

## Notes

- The install stamp is written by `seed.sh` in step 3; the migration is not "installed" until
  step 5 is green — say so honestly if you stop early.
- Batch the mechanical moves into scoped commits per store, so the history reads as the
  migration it is.
