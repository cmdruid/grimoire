# Clankshop v2 — Phase 3 plan: helper upgrades

Companion to `2026-08-12-clankshop-v2.md` (§ The pack, § Records) and the roadmap's Phase 3.
Requires phases 1–2 (helpers probe the install stamp and call `records.sh`). Also carries the
Phase-2 follow-ups agreed 2026-08-13 (recorded in the phase-2 plan's decisions and below).

## Tasks (dependency-weight order, per the roadmap)

1. **`auditor`** (36 v1 refs): strip registration/seat machinery; enrichment via the
   install-stamp probe; findings drain through `records.sh` (bugs/reports stores + tracker
   lines — no counters, no projections).
2. **`workstream`** (29 v1 refs): `.handbook` paths → v2; build-station context summon.
   **Semantic rewiring, not textual** (agreed follow-up a): the `/backlog done` seam,
   `.records/done/` records, and `.records/tasks.md` wire formats no longer exist — re-express
   ship's shipping-records step in journal terms: shipped units land as `history.tsv` ledger
   entries plus an optional `reports/` record tagged `debrief` when the unit warrants
   narrative (spec § Records). `delegate`/`feature` stale `/backlog` mentions rewire here too.
3. **`blueprint`** (27 v1 refs + the new design): rename from `feature`; the six verbs
   (`brainstorm` / `grill` / `spec` / `roadmap` / `plan` / `review`); dual-mode entry
   (install-stamp probe, bundled templates, confirmed output home standalone). v1 design
   templates + DOC-RUBRIC recoverable from git history pre-9ce8a93 if wanted.
4. **Audit `clankshop` `verbs/migrate.md` against the eight-store schema** (agreed follow-up
   b): the brownfield mapping table must map legacy trackers/done-logs onto the v2 stores —
   v1-records conversion was scoped OUT of Phase 2 because migrate owns it; close the gap
   before Phase 6 tests brownfield live.
5. **`records.sh` small upgrades** (agreed follow-ups c–e, tracker-line-sized):
   - `check` validates `→ <store>/<file>.md` record links (link-rot detection);
   - a prune-candidates fact query for `curate` (`history --until` × file existence);
   - open-ticket visibility: `check` counts open tickets so the workshop check surfaces them.
6. **Tests**: every touched helper's checks proven by breaking; delegation suites updated
   where seams changed.

## Exit (roadmap)

Each member lints green and passes the boundary audit; summons and records seams exercised
against fixtures. Non-task: never dogfood journal into grimoire — patient zero holds.

## Decisions settled (human, 2026-08-13)

- **`feature`→`blueprint` lands as ONE commit** (rename + six verbs together) — matches the
  stream's phase-commit pattern; the rename without the new verbs isn't independently valuable.
- **Task 5's records.sh upgrades SHIP WITH Phase 3** — tracker-line-sized, task 4's migrate
  audit pairs naturally, and Phase 6's brownfield test benefits from `check` validating links
  and surfacing open tickets.
