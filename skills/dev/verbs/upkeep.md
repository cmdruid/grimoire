# `/dev upkeep` — periodic dev/ docs-system health pass

Drive the periodic **dev/ docs-system health pass**: the living docs **drift** as code and the
filesystem change, and **accumulate** as work ships — `upkeep` catches both. It is a **thin driver**:
the methodology is `dev/docs/MAINTENANCE.md` (the single source of truth) — **re-read it each pass**;
this verb orchestrates and surfaces the routine, it does not restate the per-audit checklists. It
dovetails with the host's doc-linter (named in its `AGENTS.md`, wired into the gate), which does the
mechanical half (links resolve, enumerable series indexed, store-dir frontmatter valid).

**Scope boundary (read this):** `upkeep` maintains the **dev/ docs system** (spine, memory,
trackers, archives — `MAINTENANCE.md`). It is **not** the **project-code** quality audit — that's
`/audit`. Different domain, different files.

## When to use

- The user runs **`/dev upkeep`**, or asks to "tidy/maintain `dev/`", "drain the trackers", "archive
  what's shipped", "run a maintenance pass", or notes a tracker is **piling up** (e.g. `FEEDBACK.md`
  is accumulating, the backlog is stale).
- **Periodically, when the tree is quiet** — and after a structural change to `dev/`.

**Do NOT use** mid-task, for game-code quality (`/audit`), or **while the tree is churning**:
`MAINTENANCE.md` is explicit that these files are concurrently edited, so a sweep mid-churn fights
other agents. Confirm quiet first (see step 1).

## Modes (selected by argument)

- **(no arg) — full pass.** Spine + memory + backlog + issues + feedback audits, then prune &
  archive. Item by item.
- **`spine`** — the front-door / onboarding audit (`AGENTS.md`, `dev/README.md`, `docs/README.md`,
  `tests/README.md`, + `PROJECT.md` / `dev/MEMORY.md`): coverage, currency, consistency, onboarding.
- **`memory`** — the highest-stakes audit of `dev/MEMORY.md` (a wrong "fact" is actively harmful).
- **`backlog`** — the deep done/relevance pass over `dev/BACKLOG.md` (removes shipped/dead items).
- **`issues`** — the `dev/ISSUES.md` pass (resolved → `dev/done/`; promote durable gotchas).
- **`feedback`** — drain `dev/FEEDBACK.md` (route actionable items home; clear absorbed ones).
- **`prune`** — just the prune & archive pass (no audits).

## The pass (full)

Follow `dev/docs/MAINTENANCE.md`; in brief, go **item by item**, **when the tree is quiet**, and
**worktree it if the sweep is big** (it earns a branch):

1. **Confirm quiet + take the inventory.** `scripts/dev-health.sh inventory <root>` emits
   `tree_quiet`, `linked_worktrees`, and per-tracker sizes/last-change in one read — a sweep during
   churn (`tree_quiet=false` or live worktrees) fights concurrent edits, so confirm quiet first; the
   tracker sizes tell you which trackers are accumulating and earn a deep pass. If it'll be large, do
   it in a worktree.
2. **Spine audit** (`MAINTENANCE.md` → *The docs spine*). Linter already did links + indexing (run
   the gate); `scripts/dev-health.sh coverage <root>` lists top-level dirs not reachable from the
   spine (**coverage** candidates) and `dev-health.sh stale-refs <root>` lists rooted
   path/`file:line` references across the spine + trackers that no longer resolve (**currency**
   candidates) — judge each (a deliberate negative example is not drift). You still add
   **consistency** (no spine doc contradicts another or the code) and **onboarding** (the "Read
   first" path reaches vision/invariants/work/how-tos) by reading. Fix drift in place; file bigger
   gaps to `BACKLOG.md` (or `ISSUES.md` if it's doc-tooling).
3. **Memory audit** — per fact: still-true? still-load-bearing (keystone only)? redundant (trim to a
   pointer)? missing? pointers resolve? Hand-prune; no auto-prune.
4. **Backlog audit** — done (cross-ref `git log` → **remove** it; the commit + any stream digest is
   the record)? still-relevant? accurate `file:line`? right scope/classification? `/dev backlog
   groom` automates the sharpen/reorder; this audit adds the done/relevance judgment + the removal
   drain. (`dev-health.sh stale-refs <root> dev/BACKLOG.md` flags items whose `file:line` no longer
   resolves — strong weed/sharpen candidates, since the referenced code usually shipped or moved.)
5. **Issues audit** — resolved (fixed or now documented) → prune to `dev/done/`; still a real
   constraint? fix superseded (rewrite to current reality)? rank right? promote durable gotchas to
   `GOTCHAS.md`.
6. **Feedback audit** — per entry: actionable (route to its real home — `BACKLOG`/`bugs/`/`ISSUES`)?
   acted-on/absorbed (record outcome, clear)? still an open observation (keep — but don't let it sit
   unrouted across two passes)? Goal: a live signal, never a graveyard.
7. **Prune & archive** (`MAINTENANCE.md` → *Prune & archive*) — shipped one-shot plans/spikes →
   `plans/archive/`; spent reports → `reports/archive/`; fixed bugs → `bugs/archive/`; tracker items
   → dated `dev/done/<YYYY-MM-DD>-<slug>.md`; obsolete memory facts only. A `notes/` file goes when
   the entry that linked it goes.
8. **Record & commit.** Record what was removed in `dev/done/`. Commit atomically with **explicit
   paths** via `scripts/scoped-commit.sh` (never `git add -A` on the shared root — see
   `WORKTREES.md`). As a sweep, `upkeep` makes the commit; the capture verbs it touches only write.

## Relationship to neighboring verbs

- **`/dev backlog`** (`groom`) sharpens the BACKLOG list; it no longer prunes — `upkeep` owns the
  drain (removing shipped/dead items in the done/relevance pass).
- **`/dev debrief`**, **`/dev bug`**, **`/dev issue`**, **`/dev feedback`** *feed* the trackers
  `upkeep` drains — capture is their job, draining is this one's.
- **`/audit`** is the game-code analogue: same surface-then-drain shape, different domain. Keep them
  distinct — `/audit` scores code; `upkeep` keeps the dev/ docs system healthy and lean.
- The **doc-linter** (in the gate) is the mechanical backstop; `upkeep` covers the semantic drift it
  can't see (a missing pointer, a convention stated as fact that has since changed).

## Done when

The spine is current and consistent, `MEMORY.md` holds only true load-bearing facts, the trackers
carry only live items (shipped/stale ones drained to `dev/done/` and the `*/archive/` dirs with their
provenance), `FEEDBACK.md` is a live signal not a graveyard, and what was removed is recorded in
`dev/done/` — committed atomically with explicit paths. Gate green.

Any `dev/done/` record you write must open with the `type: task-record` frontmatter block
(`type`/`status: shipped`/`updated`), from `dev/templates/task-record.md` — the doc-linter gate
rejects a store-dir file without it. Schema: `dev/docs/TAXONOMY.md`.
