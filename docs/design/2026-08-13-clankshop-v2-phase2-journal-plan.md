# Clankshop v2 — Phase 2 plan: `journal` (DRAFT — uncommitted; refine before build)

Companion to `2026-08-12-clankshop-v2.md` (§ Records, § The pack) and the roadmap's Phase 2.
`backlog` → `journal` is a **rewrite, not a rename** (168 v1-machinery references). Journal owns
the records layer: `records.sh`, templates, `.records/` scaffolding, the history ledger.

## Tasks

1. **`records.sh`** (journal's deployed asset, lands in `.records/scripts/`):
   `list` (TSV: path·doctype·status·updated·tags·title, sorted updated desc) · `show` · `new
   <doctype> --title` (from store template, real date, prints path; date-slug filename) ·
   `touch [--status]` · `done [--as done|dropped|superseded|consumed] [--note]` (closure in
   place; sole writer of `.records/history.tsv`) · `history [filters]` · `check` (front-matter
   contract + status↔ledger coherence). Plain deterministic output; exit codes.
2. **Templates + stores**: `.records/templates/` for the eight stores (adr, bugs, design,
   notes, plans, reports, tickets, trackers); front-matter contract (doctype/status/created/
   updated/tags). Reserved: `templates/`, `scripts/`, `history.tsv` — skipped by store scans.
3. **Standup both ways**: `journal setup` standalone on a bare repo (scaffold stores +
   templates + records.sh, honoring a declared `records-root:`); same entry callable as the
   delegated seam from `clankshop setup` step 3.
4. **Rename + rewrite the skill**: `git mv skills/backlog skills/journal`; SKILL.md reframed
   (capture by kind, curate, escalate/tickets, debrief — against the stores; no counters, no
   done log, no projections, no registration). v1 machinery torn down (done-entry.sh,
   records-projection.sh, mirror, escalation pause markers as implemented).
5. **Proxies**: `skills/bug`, `skills/task` re-pointed `/backlog` → `/journal`.
6. **Tests** (throwaway fixtures; every check proven by breaking): records lifecycle round-trip
   (new→touch→done→history; ledger line appended); `records.sh check` FAILs on broken
   front-matter and on closed-status-without-ledger-line; bare-repo standup; the Phase-1
   seed-test fixture extended to exercise setup → journal delegation end to end.
7. **Manifest**: PACK.md `required: backlog` → `journal`; transition note updated.

## Exit (roadmap)

`records.sh check` proven by breaking; standalone standup on a bare repo; the phase-1 fixture
exercises setup → journal delegation end to end. Lint green; keep `~/.agents/skills` symlink
implications in mind (rename changes the live skill name immediately on this machine).

## Decisions settled before build

- **Ticket mirror: DEFERRED** (human decision, 2026-08-13). v2 journal ships without the v1
  GitHub mirror: the in-repo `tickets/` store is canonical and complete on its own. Rationale:
  the spec's § Records defines the store, not a remote projection; Phase 2 is the heaviest
  phase already; the mirror was v1's most failure-prone machinery. Revisit after Phase 6's
  live-deployment feedback — if it returns, it returns as its own designed feature, not a
  carry-over.
- `bug`/`task` proxy rename timing: with `backlog` gone the proxies break until re-pointed —
  do the re-point in the same commit as the `git mv`.
- **Quick-capture shape** (human, 2026-08-13): trackers are long-lived records; quick captures
  (`/journal task|issue|feedback`) append a line to the open tracker's **body** and stamp via
  `records.sh touch`. Detailed bugs/notes still get their own dated record. No append verb on
  records.sh — the spec's surface stands.
- **v1 records migration: out of scope** (human, 2026-08-13): Phase 2 ships greenfield standup +
  the clankshop-setup seam only; brownfield conversion stays `clankshop migrate`'s
  mapping-table job, exercised in Phase 6.
- **Dangling `/backlog` refs in sibling skills: accept the window** (human, 2026-08-13):
  bug/task proxies keep common capture paths alive; workstream/feature/delegate keep stale
  `/backlog` mentions until Phase 3 rewires them with the real new semantics.
