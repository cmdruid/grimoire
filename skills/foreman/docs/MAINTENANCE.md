# Maintenance -- keeping the .agents/foreman/ system healthy

The `.agents/foreman/` system's living docs **drift** as the code and filesystem change, and **accumulate** as
work ships. Maintenance keeps both in check, in three modes:

- **The front-door contract** -- the *per-change* discipline that keeps `AGENTS.md` in step with
  `.agents/foreman/` as you work.
- **Audits** -- the *periodic* pass that catches drift the contract missed.
- **Prune & archive** -- draining shipped/stale material so what's live is what's *active*.

All three share a shape: run after a structural change or periodically, go **item by item**, do it
**when the tree is quiet** (these files are concurrently edited -- a sweep mid-churn fights other
agents), and **worktree it if the sweep is big** (it earns a branch). Record whatever you remove in
`.records/archive/`.

**If the host has a `/foreman` skill**, its `check` verb validates the deployed glue (spine coverage,
stale refs, glue-vs-skills drift) and its `calibrate` verb folds accumulated system signal back into this
doctrine and promotes durable notes; otherwise run those by hand from this doc.
**If the host has a `/backlog` skill**, `/backlog curate` automates the TASKS sharpen/reorder and
tidies the tracker lists; removal of shipped items is part of the backlog audit (no separate prune step).

Three mechanisms, one job each -- keep them distinct: the **front-door contract** (per-change, by
hand), the **spine audit** (periodic enforcement), and the **doc-linter** (`<stack: doc-linter
command in the gate>` -- the mechanical check: links resolve, enumerable series indexed, no
skill-default output paths in source, and backtick'd `.agents/foreman/<path>` file refs in the stable
reference docs resolve). Don't expect the linter to catch a *missing* pointer -- it checks the
series it can enumerate, not whether a how-to is actually surfaced.

## The front-door contract -- keep `AGENTS.md` in step

`AGENTS.md` is the shared onboarding entry point and the most volatile doc -- every agent and
harness touches it. The contract keeps it honest as `.agents/foreman/` grows.

- **Index, not copy.** `AGENTS.md` gives one named pointer to the canonical doc for each thing and
  stops. One source of truth per fact; duplication is what rots.
- **Change `.agents/foreman/` -> reflect it in `AGENTS.md` in the same commit.** A tracker, a how-to, a tool, or
  a top-level dir -- its pointer lands *then*, not "later."
- **Tier the pointers.** Name directly only what an agent reaches for first (`ROUTING.md`,
  `.agents/foreman/MEMORY.md`, the bug docs, the trackers, the core commands); everything else hangs off
  `.agents/foreman/README.md` (the one index). When unsure, default to the
  index -- keeping `AGENTS.md` lean matters more than saving a hop.

| You... | ...in the same commit |
|---|---|
| add a **tracker** | name it in `AGENTS.md`'s capture section (the taxonomy lives in `ROUTING.md` -> *Capture follow-ups*) |
| add a **how-to / process doc** | give the payload one owning doc; add a front-door routing-table row (or `AGENTS.md` pointer) only if it's first-reach |
| add a **tool / command** | add it to *Build / test / run* |
| add a **top-level dir** | add a one-line *Repo map* entry |
| **rename / move / remove** an artifact | repoint (or drop) every `AGENTS.md` pointer, and fix `.agents/foreman/README.md` too |

## Audits -- catch drift

Audits keep the **.agents/foreman/ docs** honest. (To audit the **project code** quality, see whatever
audit rubric the project defines -- that is separate from the docs-system health sweep here.)

### The docs spine -- the periodic enforcement of the front-door contract
The spine -- `AGENTS.md`, `.agents/foreman/README.md`, and any `README.md` files for major subdirs (plus the
root project doc and `.agents/foreman/MEMORY.md`) -- is the onboarding path; it drifts whenever the filesystem
changes. If the project's operations live as skills (e.g. a `/foreman` bundle), the spine audit should
also check that the skill bundles' blueprint still matches the system's structure (there is no
synced mirror to track -- the host repo's own `.agents/foreman/` is the live example).

1. **Linter does the mechanical half** (`<gate>`): internal links resolve; the doc series are
   indexed; no skill-default output paths appear in source.
2. **Coverage** -- every top-level dir and dev/testing tool is reachable from the spine.
3. **Currency** -- every path and command in the spine resolves/runs.
4. **Consistency** -- no spine doc contradicts another or the code; conventions match across
   `AGENTS.md` / `.agents/foreman/README.md` / `.agents/foreman/MEMORY.md`.
5. **Onboarding** -- following `AGENTS.md`'s "Read first" reaches the vision, the invariants, the
   current work, the tool how-tos, and the worktree workflow.

Fix drift in place; file bigger gaps to `tasks.md` (or `issues.md` if it's a doc-tooling gap).

### The memory (`.agents/foreman/MEMORY.md`) -- highest stakes
Agents *internalize* it, so a wrong "fact" is actively harmful. Per fact / invariant: **still
true?** (re-verify against the source -- the sharpest rot is a convention that changed but is still
stated as fact) · **still load-bearing?** (keystone only -- move lesser facts to their home doc and
drop them here) · **redundant?** (trim to a one-line pointer) · **missing?** (a new invariant not
yet here) · **pointers resolve?** No auto-prune -- MEMORY is rewritten by hand.

### The tasks tracker (`.records/tasks.md`)
A deep pass over **every** item: **done?** (cross-ref `git log` -> **remove** it; the commit + any
`.records/archive/` stream digest is the record) · **still relevant?** (obsolete/superseded -> remove,
rationale to `archive/`) · **accurate?** (repoint stale `file:line`) · **right scope?** (split or
merge) · **right classification?** (effort tag, group, order). If available, `/backlog curate`
automates the sharpen/re-order; this audit adds the done/relevance pass and the removal drain.
(Items are plain bullets, removed when shipped -- there is no checkbox/prune step.)

### The issues log (`.records/issues.md`)
Per entry: **resolved?** (fixed in code *or* now documented in a gotchas doc / `AGENTS.md` ->
prune to `.records/archive/`) · **still a real constraint?** · **fix superseded?** (rewrite to current
reality -- a stale recommendation is worse than none) · **rank still right?** (`HIGH`/`MEDIUM`/`LOW`)
· **promote** any durable gotcha into the project's gotchas doc, then prune the entry.

### The feedback (`.records/feedback.md`)
A qualitative catch-all -- drain it or it rots. Per entry: **actionable?** (route to its real
home) · **acted on / absorbed?** (record the outcome, clear it) · **still an open observation?**
(keep -- but don't let it sit unrouted across two audits). Goal: a live signal the owner skims,
never a graveyard.

## Prune & archive -- keep it lean

Move finished or stale material out of the live docs into archives and dated records. **Git history
is the source of truth; `.records/archive/` is the human-readable index into it.**

- **`.records/plans/`** -- a one-shot plan or spike *ships* -> `git mv` to `plans/archive/`. Roadmaps and
  ongoing design docs stay live until the track ships.
- **`.records/adr/`** -- an ADR must stand on its own: decision rationale lives *in* the ADR, which cites
  the roadmap track in `.records/plans/` (or another ADR), **never** a plan path -- a durable doc must not depend
  on a volatile one. Before archiving a plan an ADR references, confirm no rationale lives only in
  that plan (lift it into the ADR if so), then drop/repoint the pointer.
- **`.records/reports/`** -- conclusions acted on or superseded -> `reports/archive/`.
- **`.records/bugs/`** -- fixed -> note the commit in the report, `git mv` to `bugs/archive/`.
- **`.records/notes/`** -- a note is subordinate to the entry that links it (a `MEMORY`/tracker/report
  line); when that entry is pruned or archived, archive the note with it (or drop it if spent).
  Never drained on its own -- it's a store, reached only via its link (but `/foreman calibrate` may promote a
  durable note into `MEMORY.md`/`GOTCHAS.md` before clearing it).
- **The capture trackers** (the five capture kinds -- `task`/`bug`/`issue`/`feedback`/`note`) drain
  per their taxonomy (`ROUTING.md` -> *Capture follow-ups*): `TASKS`/`ISSUES` items to a dated
  `.records/archive/<YYYY-MM-DD>-<slug>.md`, `bugs/` to its archive. `/backlog` itself never drains --
  `/backlog curate` only keeps the lists tidy (dedupe/rank/sharpen/weed); `/foreman calibrate` is what
  drains and promotes durable signal into doctrine. (No checkbox/prune step -- an item is removed
  when its work ships; the audit drains the stragglers.)
- **`.agents/foreman/MEMORY.md`** -- prune a durable fact only when it goes obsolete (a reversed convention, a
  retired invariant). Rare -- keep it true; a stale "fact" is worse than none.
