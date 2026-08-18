# `migrate` — brownfield onramp

Bring an existing project with **organic** structure — ad-hoc doc trees, hand-rolled trackers
and notes, possibly a legacy records root (e.g. `dev/`) — into the workshop layout. The spine
of the procedure: inventory by script, one confirmed mapping table, mechanical moves by
script, judgment merges by hand, done means `check` green.

**Guard:** resolve the project root first (conversation → cwd → ask). If `<root>/.handbook`
exists, stop and point at `setup` — resume when `check` would be red; upgrade-as-diff
when the human asked and `check` is green. On a genuinely bare repo prefer `setup`
(nothing to migrate).
The resolved root may legitimately be a **workstream worktree** (a stream whose queue owns the
migration): everything below then writes and commits on the stream's branch and rides its ship
— never hop to the trunk checkout to commit a stream-owned migration directly.

## The walk

1. **Preflight (script).** `scripts/migrate-scan.sh <root>` inventories candidate artifacts —
   markdown docs with their git dates and first headings, tracker-shaped files, doc-tree
   roots, CI configs, the door files present. Facts only; classification is yours.
2. **One confirmed mapping table.** Propose a destination for **every** inventoried artifact —
   a station chapter (doctrine folds into `core/` or a station `POLICY.md`), a record store,
   or *leave in place* — and show the human the whole table at once. **Nothing moves before
   the table is confirmed.** A legacy records root the project wants to keep (e.g. `dev/`) is
   declared in place via the door's `agent-records:` (or legacy `records-root:`)
   line, never bulk `git mv`'d.

   The destination menu is the eight stores; classify by what the doc *is*:

   | legacy artifact | store |
   |---|---|
   | decision records, "why we chose X" docs | `adr` |
   | bug reports, repro writeups | `bugs` |
   | design docs, specs, RFCs, ideation | `design` (the living spec, if one emerges, gets `status: current`) |
   | durable how-it-works notes, shared memory | `notes` |
   | feature/implementation plans, roadmaps | `plans` |
   | investigation writeups, postmortems, audits | `reports` |
   | open asks awaiting a human | `tickets` |
   | hand-rolled TODO/backlog/issues lists | `trackers` |

   **A legacy tracker file** maps to a `trackers/` record: its actionable entries become the
   body's line-items (`- [ ] YYYY-MM-DD — <item>`); an entry too detailed for one line splits
   into its own dated record in the right store, linked from the line. Name it by what it
   tracks — a general TODO list becomes the canonical **Backlog**; friction/concern lists map
   to **Issues**/**Feedback**. **A legacy done-log or changelog** stays a historical document
   (*leave in place*, or adopt into `notes/`): the `history.tsv` ledger records live closure
   events only — `records.sh done` is its sole writer, and a hand-backfilled ledger would be
   fiction. A doc that fits no store is a legitimate *leave in place*, not a forced fit.
3. **Execute the mechanical rows.**
   - Seed the doctrine: `scripts/seed.sh <root> --gate '<gate>' --trunk '<trunk>'` (the two
     facts confirmed alongside the table).
   - Stand up the records tool layer via `/journal setup` (it owns `records.sh` +
     the ledger + README; it creates no store directories and no templates) —
     pointed at the declared agent-records home (`agent-records:` preferred,
     `records-root:` accepted, else `.records`). Do not inline journal's walk.
   - Move adopted records into their stores with `git mv` (history survives); keep original
     filenames — the path is the ID either way. Store directories must not collide with the
     records root's reserved paths (`templates/`, `scripts/`, `history.tsv`).
   - Backfill front-matter on every adopted record — the full five-key contract
     (`doctype`/`status`/`created`/`updated`/`tags`): `doctype` from the destination store
     (`check` enforces the match), `created`/`updated` from `git log`, `status` flagged for
     judgment where ambiguous. **Backfill only the non-closing statuses** (`open`, or
     `current` for a living spec): a hand-written closing status would fail `check`'s
     status↔ledger coherence (closed record, no ledger line). A record that is genuinely
     finished closes through `records.sh done <path> --note "closed at migration"` **after**
     standup — the ledger line is written by its one writer, dated honestly at adoption.
4. **Perform the judgment merges.** Organic policy and convention docs fold into `core/` or
   the station `POLICY.md`s **below** the seeded preambles — integrated, deduplicated, linked
   (the precedence rule holds from day one). The door is written **into** the existing
   `AGENTS.md` to setup's minimum (pointer naming `.handbook/README.md`, thin dispatch
   table, `agent-records:` only when not `.records/`); existing content preserved.
5. **Done means `check` is green.** Run the `check` verb; fix what it reports. One conformance
   regime, no grandfathering: after migration, `records.sh` sees everything.

## Notes

- The install stamp is written by `seed.sh` in step 3; the migration is not "installed" until
  step 5 is green — say so honestly if you stop early.
- Batch the mechanical moves into scoped commits per store, so the history reads as the
  migration it is.
