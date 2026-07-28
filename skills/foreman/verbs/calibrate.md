# `/foreman calibrate` — tune the doctrine to its correct settings from its own signal

The **self-growing curation loop**. As work ships, `/backlog`'s trackers accumulate a **dev-experience
signal** *about the development system itself* — friction with a workflow, a routing rule that
misfired, a convention that has quietly changed, a `FEEDBACK` note that the docs are getting heavy.
`calibrate` **consumes that signal and adjusts foreman's own doctrine to its correct settings**:
`.records/feedback` (the primary instrument), plus the system-relevant slice of `.records/issues`
and `.records/notes`, folded into concrete edits of foreman's docs (`.agents/foreman/…`) and the
project's `AGENTS.md` wiring — and **durable `notes` promoted** into `.agents/foreman/MEMORY.md` /
`.agents/foreman/GOTCHAS.md` / the docs (the promotion `/backlog debrief` deliberately no longer
does). The living docs both **drift** (as code and the filesystem move) and **accumulate** a backlog
of "the system should work differently"; `calibrate` reads the signal like a gauge and turns the
knobs, so the factory re-tunes itself to reality instead of ossifying at last year's settings.

It is a **thin driver**: the maintenance methodology lives in `.agents/foreman/docs/MAINTENANCE.md` (the single
source of truth) — **re-read it each pass**; this verb orchestrates the drain and surfaces the
routine, it does not restate the per-audit checklists.

**Scope boundary (read this).** Three neighboring jobs are deliberately *not* here:

- **Curating the trackers as lists** — sharpening/reordering `tasks.md`, removing shipped items,
  archiving to `.records/archive/` — is **`/backlog curate`**, not `calibrate`. `calibrate` *consumes* the trackers'
  signal to adjust doctrine and promote durable notes; it does not curate the lists themselves.
- **Mechanically validating that the deployed glue still resolves** — spine coverage, stale
  `file:line` refs, runbook-vs-installed-skills drift — is **`/foreman check`** (the cheap
  validator). Run `check` first to *find* drift; `calibrate` is where you *act* on the semantic half.
- **Project-code quality** is **`/auditor`**. Different domain, different files.

## When to use

- The user runs **`/foreman calibrate`**, or asks to "calibrate the dev system", "fold this friction back into
  the docs", "the workflow keeps tripping me — fix the doctrine", or notes that the system-facing
  signal (`feedback.md`, `issues.md`) is **piling up** with recurring complaints about how development
  works here.
- **Periodically, when the tree is quiet** — and after a structural change to the `.agents/foreman/` system, or
  once a body of friction has accumulated enough to see a pattern.

**Do NOT use** mid-task, or **while the tree is churning**: `MAINTENANCE.md` is explicit that these
files are concurrently edited, so a sweep mid-churn fights other agents. Confirm quiet first (step 1).

## The pass

Go **item by item**, **when the tree is quiet**, and **worktree it if the pass is big** (it earns a
branch):

1. **Confirm quiet + take the inventory.** `scripts/foreman-health.sh inventory <root>` emits
   `tree_quiet`, `linked_worktrees`, and per-tracker sizes/last-change in one read — a sweep during
   churn (`tree_quiet=false` or live worktrees) fights concurrent edits, so confirm quiet first. The
   tracker sizes tell you which trackers carry accumulating system-facing signal and earn a deep read.
2. **Harvest the dev-experience signal.** Read `/backlog`'s `.records/feedback.md` (the primary
   instrument), `.records/issues.md`, and `.records/notes/` for the slice that is about **the
   development system, not the product**: dev-experience friction, a routing rule that misfires, a
   convention stated as fact that has since changed, a doc that keeps getting reached for and isn't
   wired in, a durable fact parked as a `note` that belongs in memory or a gotchas doc. (Product/feature
   items stay in `.records/tasks.md` — those are `/backlog curate`'s, not signal for the
   doctrine.) Look for **patterns**: one complaint is a note; the same friction three times is a
   doctrine miscalibration.

   **Classify each entry by the layer its fix would edit** — this verb wears foreman's composer
   hat here, same as `route`: **operational** (a routing rule, workflow doctrine, the front
   door's wiring/table, MEMORY/GOTCHAS) → this pass acts on it in step 3; **doc-form**
   (front-door bloat, navigation, a spine that loses agents) → dispatch to the installed
   doc-spine steward's own drain verb, else the by-hand fallback (fix per the deployed docs);
   **design-seed** (a spec/contract/tenet that misleads) → dispatch to the installed design
   steward's drain verb, else the fallback. Mixed entries split; unclassifiable entries stay
   here (the default owner).
3. **Turn each pattern into a concrete doctrine edit — the calibration.** A gauge reading is only
   useful once it moves a knob; turn the signal into a real change:
   - a routing gap → sharpen `.agents/foreman/docs/ROUTING.md` (the change-router walk), then
     **recompile the front door's routing table** so the projection matches the source;
   - a host still on pre-rollout shapes (a `docs/DEVELOPMENT.md` name, a deployed `docs/WORKFLOWS.md`
     menu, an unstamped front door) → apply the upgrade as this pass's calibration: `git mv` the
     rename, dissolve the menu into the door + owning content docs, stamp the routing table
     (`verbs/migrate.md` → *legacy deployed shapes* has the full walk);
   - a recurring how-to question → answer it in the content doc that owns the topic
     (ARCHITECTURE / GOTCHAS / DIAGNOSTICS / PERFORMANCE) and, if it is a *where-does-work-start*
     question, add the missing row to the front door's routing table — never a menu doc;
   - a planning-weight mismatch → adjust the tiers in `.agents/foreman/docs/PLANNING.md`;
   - a load-bearing invariant that changed → update `.agents/foreman/MEMORY.md` (highest stakes — a wrong "fact"
     agents internalize is actively harmful; hand-edit, never bulk);
   - a durable project fact `/backlog` parked as a `note` → **promote** it: a load-bearing invariant into
     `.agents/foreman/MEMORY.md`, a known trap into `.agents/foreman/GOTCHAS.md`, else the fact's home doc — then
     clear the note from `.records/notes/` (this is the promotion `/backlog debrief` no longer does);
   - a command/entrypoint the skills resolve generically but `AGENTS.md` no longer names → fix the
     `AGENTS.md` wiring so "run the gate" / "the fast doc-linter" still resolve.
   Fix drift in place; file anything too big for this pass back to `/backlog` as its own item.
4. **Record the outcome on the source signal.** For each `FEEDBACK`/`ISSUES` entry (or promoted `note`)
   you acted on, record the resolution and clear it (or hand it to `/backlog curate` to drain from the list) — the
   goal is a live signal, never a graveyard. An entry that recurs across two passes unrouted is itself
   a finding.
5. **Log the pass, then commit.** Append a dated entry to `.records/logs/foreman-calibrate.md` (created
   on first use) summarizing this pass: which trackers were harvested, how many patterns became doctrine
   edits, which source entries were cleared. This is a **record**, not a seed — unlike the doctrine
   edits above (which agents read as live instruction and must stay curated/stable, hence living in the
   `.agents/foreman/` seed unchanged), the pass log is append-only audit evidence, never re-read as
   instruction (settles the seed-vs-record open question,
   `docs/design/2026-07-19-phase4-foreman-rescope.md` §7 — the doctrine itself was never in question;
   only its calibration *history* needed a home). Then commit the doctrine edits **and** the log entry
   atomically with **explicit paths** via `scripts/scoped-commit.sh <root> "<msg>" <paths…>` (never
   `git add -A` on the shared root — see `.agents/foreman/docs/WORKTREES.md`). As a sweep, `calibrate`
   makes the single commit; capture verbs it touched only write. Commits carry **no** `Co-Authored-By`
   trailer. Then run the host's gate / doc-linter.

## Relationship to neighboring verbs & skills

- **`/foreman check`** finds the *mechanical* drift (missing pointer, stale ref, glue-vs-runbook gap);
  `calibrate` acts on the *semantic* drift it can't see and folds accumulated friction into the doctrine.
- **`/backlog curate`** owns the tracker lists (sharpen, reorder, remove shipped, archive). `calibrate`
  consumes their signal and promotes durable notes; it does not curate the lists.
- **`/backlog feedback`** and the other capture verbs *feed* the trackers `calibrate` drains — capture is
  their job, folding-into-doctrine is this one's.
- **`/chiropractor`** owns doc-spine *ergonomics*; **`/architect`** owns the design seed.
  `calibrate` classifies the harvested signal by layer (step 2) and **dispatches** the doc-form
  and design-seed slices to those stewards' own drain verbs — it acts only on the operational
  slice itself.
- **`/auditor`** is the project-code analogue: same surface-then-drain shape, different domain.

## Done when

The recurring dev-experience signal in `/backlog`'s trackers has been folded into concrete doctrine /
workflow / `AGENTS.md` edits (and durable notes promoted into `.agents/foreman/MEMORY.md` /
`.agents/foreman/GOTCHAS.md` / docs), or filed back to `/backlog` when too big; each acted-on source entry
recorded and cleared; each dispatched entry (doc-form / design-seed) recorded in the pass log with the
steward it went to — the receiving steward's own pass owns its resolution; the pass logged to
`.records/logs/foreman-calibrate.md`; and the changes committed atomically with explicit paths. Gate green.
