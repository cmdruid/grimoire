# `/foreman tune` — drain the system's own signal into doctrine

The **self-growing curation loop**. As work ships, `/backlog`'s trackers accumulate signal *about the
development system itself* — friction with a workflow, a routing rule that misfired, a convention
that has quietly changed, a `FEEDBACK` note that the docs are getting heavy. `tune` **drains the
system-relevant slice of that signal into concrete improvements** to the doctrine (`.agents/dev/docs/*`), the
workflow, and the `AGENTS.md` wiring — and **promotes durable `notes`** `/backlog` parked into
`.agents/dev/MEMORY.md` / `.agents/dev/GOTCHAS.md` / the docs (the promotion `/backlog debrief`
deliberately no longer does). The living docs both **drift** (as code and the filesystem
move) and **accumulate** a backlog of "the system should work differently" — `tune` turns that into
edits, so the factory tunes itself instead of ossifying.

It is a **thin driver**: the maintenance methodology lives in `.agents/dev/docs/MAINTENANCE.md` (the single
source of truth) — **re-read it each pass**; this verb orchestrates the drain and surfaces the
routine, it does not restate the per-audit checklists.

**Scope boundary (read this).** Three neighboring jobs are deliberately *not* here:

- **Curating the trackers as lists** — sharpening/reordering `TASKS.md`, removing shipped items,
  archiving to `.agents/dev/done/` — is **`/backlog curate`**, not `tune`. `tune` *consumes* the trackers'
  signal to improve doctrine and promote durable notes; it does not curate the lists themselves.
- **Mechanically validating that the deployed glue still resolves** — spine coverage, stale
  `file:line` refs, runbook-vs-installed-skills drift — is **`/foreman check`** (the cheap
  validator). Run `check` first to *find* drift; `tune` is where you *act* on the semantic half.
- **Project-code quality** is **`/auditor`**. Different domain, different files.

## When to use

- The user runs **`/foreman tune`**, or asks to "tune the dev system", "fold this friction back into
  the docs", "the workflow keeps tripping me — fix the doctrine", or notes that the system-facing
  signal (`FEEDBACK.md`, `ISSUES.md`) is **piling up** with recurring complaints about how development
  works here.
- **Periodically, when the tree is quiet** — and after a structural change to the `.agents/dev/` system, or
  once a body of friction has accumulated enough to see a pattern.

**Do NOT use** mid-task, or **while the tree is churning**: `MAINTENANCE.md` is explicit that these
files are concurrently edited, so a sweep mid-churn fights other agents. Confirm quiet first (step 1).

## The pass

Go **item by item**, **when the tree is quiet**, and **worktree it if the pass is big** (it earns a
branch):

1. **Confirm quiet + take the inventory.** `scripts/dev-health.sh inventory <root>` emits
   `tree_quiet`, `linked_worktrees`, and per-tracker sizes/last-change in one read — a sweep during
   churn (`tree_quiet=false` or live worktrees) fights concurrent edits, so confirm quiet first. The
   tracker sizes tell you which trackers carry accumulating system-facing signal and earn a deep read.
2. **Harvest the system-relevant signal.** Read `/backlog`'s `.agents/backlog/FEEDBACK.md`,
   `.agents/backlog/ISSUES.md`, and `.agents/backlog/notes/` for the slice that is about **the
   development system, not the product**: dev-experience friction, a routing rule that misfires, a
   convention stated as fact that has since changed, a doc that keeps getting reached for and isn't
   wired in, a durable fact parked as a `note` that belongs in memory or a gotchas doc. (Product/feature
   items stay in `.agents/backlog/TASKS.md` — those are `/backlog curate`'s, not signal for the
   doctrine.) Look for **patterns**: one complaint is a note; the same friction three times is a
   doctrine bug.
3. **Drain each pattern into a concrete doctrine edit.** Turn the signal into a real change:
   - a routing gap → sharpen `.agents/dev/docs/DEVELOPMENT.md` (the change-router walk);
   - a recurring how-to question → add/repoint it in `.agents/dev/docs/WORKFLOWS.md`;
   - a planning-weight mismatch → adjust the tiers in `.agents/dev/docs/PLANNING.md`;
   - a load-bearing invariant that changed → update `.agents/dev/MEMORY.md` (highest stakes — a wrong "fact"
     agents internalize is actively harmful; hand-edit, never bulk);
   - a durable project fact `/backlog` parked as a `note` → **promote** it: a load-bearing invariant into
     `.agents/dev/MEMORY.md`, a known trap into `.agents/dev/GOTCHAS.md`, else the fact's home doc — then
     clear the note from `.agents/backlog/notes/` (this is the promotion `/backlog debrief` no longer does);
   - a command/entrypoint the skills resolve generically but `AGENTS.md` no longer names → fix the
     `AGENTS.md` wiring so "run the gate" / "the fast doc-linter" still resolve.
   Fix drift in place; file anything too big for this pass back to `/backlog` as its own item.
4. **Record the outcome on the source signal.** For each `FEEDBACK`/`ISSUES` entry (or promoted `note`)
   you acted on, record the resolution and clear it (or hand it to `/backlog curate` to drain from the list) — the
   goal is a live signal, never a graveyard. An entry that recurs across two passes unrouted is itself
   a finding.
5. **Commit.** Commit the doctrine edits atomically with **explicit paths** via
   `scripts/scoped-commit.sh <root> "<msg>" <paths…>` (never `git add -A` on the shared root — see
   `.agents/dev/docs/WORKTREES.md`). As a sweep, `tune` makes the single commit; capture verbs it touched only
   write. Commits carry **no** `Co-Authored-By` trailer. Then run the host's gate / doc-linter.

## Relationship to neighboring verbs & skills

- **`/foreman check`** finds the *mechanical* drift (missing pointer, stale ref, glue-vs-runbook gap);
  `tune` acts on the *semantic* drift it can't see and folds accumulated friction into the doctrine.
- **`/backlog curate`** owns the tracker lists (sharpen, reorder, remove shipped, archive). `tune`
  consumes their signal and promotes durable notes; it does not curate the lists.
- **`/backlog feedback`** and the other capture verbs *feed* the trackers `tune` drains — capture is
  their job, folding-into-doctrine is this one's.
- **`/chiropractor`** owns general doc-spine *ergonomics* for any repo (front-door bloat, navigation,
  glossaries). `tune` stays scoped to *this system's* doctrine; hand broad doc-tuning to
  `/chiropractor`.
- **`/auditor`** is the project-code analogue: same surface-then-drain shape, different domain.

## Done when

The recurring system-facing signal in `/backlog`'s trackers has been folded into concrete doctrine /
workflow / `AGENTS.md` edits (and durable notes promoted into `.agents/dev/MEMORY.md` /
`.agents/dev/GOTCHAS.md` / docs), or filed back to `/backlog` when too big; each acted-on source entry
recorded and cleared, and the changes committed atomically with explicit paths. Gate green.
