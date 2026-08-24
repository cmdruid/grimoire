# The four disciplines — checkpoint's citable core

This file is the **normative home** of the four named disciplines, the authority order, and the
two techniques. They are `/checkpoint`'s own procedures AND an exportable doctrine: another
skill may borrow a discipline **by name** for its *own* save-state — targeting its own file,
using its own document structure, layering its own rules on top (e.g. `/workstream`'s
`WORKSTREAM.md` borrows all four, adding worktree guards and custody checks). A borrowing site
should carry a one-line gloss alongside the reference (a *locally-complete citation*) so it
degrades gracefully where this skill isn't installed. **The names — and the numbered
checkpoint moments below — are load-bearing API for those borrow sites; never rename or
renumber them.**

## Save discipline

How the file is written: scan/elide secrets; **synthesize, don't transcribe** (the document is
for a future agent, not a chat log — and in a git repo, reconcile against `git log`, the truth
for what shipped); resolve relative dates to absolute. Author a **single next action** as a
**load-executable** contract: one imperative sentence a fresh agent can act on immediately
(names the act, and the skill/verb when that *is* the move; not a paragraph). Prefer a next
step **named** this turn; else a **KNOWN** continuation; else a best-guess synthesis
(highest-priority pending item, or continue the in-flight unit). Git/disk veto a next-action
that claims work undone when it has landed — do not write that lie.

**Named** means this turn's invocation or same-turn message states a load-executable next
step (intent, not extra words: markers and same-turn prose count; politeness and chatter do
not). A string that is not concrete enough to act on immediately is not named. **KNOWN**
means one clear continuation, any of: a single in-flight unit being paused; pending has one
obvious first item; a queue / phase / flow-determined next is already determined; standing
direction from earlier in the session that has not been superseded.

## Resume discipline

How it is read: read **in full**, load as context, echo the single next action, **rewrite
nothing**; **do not reopen the next-action design**. A redirect ("do Y instead") is new
in-session intent; resume itself does not write; the next `save` captures Y. Non-destructive —
resume never deletes or edits the file, with no exception: a
discrepancy resume discovers (a stale file, landed work) is **reported**, and any refresh
happens as a separate, confirmed **`save`** after resume completes — never inside the read.

## Lifecycle discipline

How it lives: created at the **first save, which should come early** — once the session is
demonstrably mid-work (a first unit done, or a stretch of unrecoverable in-flight state ahead),
not "when I'm done"; before the first save there is no compaction protection, and that exposure
window is why the first save is prescribed early. Refreshed at **checkpoint moments**:
(1) before a deliberate reset, (2) at a work-unit completion — bounding staleness to one
in-flight unit should compaction strike, (3) on a context-pressure warning — save proactively
**and recommend a reset**; beat the compactor to a clean checkpoint. A **work-unit** is a
human-visible milestone that would be expensive to reconstruct (a finished feature, an
accepted plan, the end of a working session). A contractor slice, a file edit, a review
pass, or a status reply is not a work-unit — refreshing there is chatter, not protection.
Never consumed by resume; ended only by `done`. **Presence = work in flight**, with two qualified states: a file the
durable trail contradicts is **stale** (the file is intent, disk is truth — trust disk, refresh
the file **via `save`**, never inside a resume), and a file describing work that has since
landed is a **forgotten `done`** (resume detects this and proposes `done` rather than resuming
ghost work). **Rollback exception:** a *polluted* context resets **without** saving —
deliberately rolling back to the last clean checkpoint. Never refresh the file from a context
you don't trust; the pre-reset refresh applies only to a healthy-but-heavy context.

## Recovery discipline

Surviving an involuntary compaction. **Automatic recovery is anchor-dependent**: it fires only
when something still-loaded points at the file (the recovery anchor, or the summary itself);
without the anchor, the product of a save is a *resumable* save-state, not automatic recovery —
`/checkpoint anchor` installs the guarantee. You detect a compaction by a
compaction/continuation summary sitting where your conversation history should be. Recovery is
a discipline, not a verb — it fires on detection. Then, in order:

1. **Stop.** Do not continue the in-flight task from the summary alone.
2. **Read the save-state file in full.** Do not re-summarize it into the reply. **No-file
   fallback:** if compaction struck before the first save, skip to facts-gather against the
   summary alone, then **save immediately** once re-oriented.
3. **Gather facts once, then stop.** Repo state (branch, dirty, recent commits) plus existence
   of paths the file cites as in-flight artifacts (done, pending, first action) — not
   orientation pointers. Do not open a search. Do not re-read doctrine or sibling skills
   unless the next action requires them. A borrowing site substitutes its own snapshot for
   the repo-state half.
4. **Reconcile** (authority order below). Completing this **confers ownership** of the file
   (the one-owner rules, `SKILL.md`):
   - Disk/git wins for landed work.
   - The file wins for last-saved intent (pending, first action, decisions).
   - The summary wins only for in-flight work *since the last save* that does not contradict
     disk.
   - Summary vs disk → disk wins; that is not a round-trip.
   - Round-trip only if two in-flight intents both remain plausible.
   - Work the file describes has since landed → propose `done` rather than continuing
     (Lifecycle's forgotten `done`).
5. **Working set** is the file's TL;DR + reconciled pending + suggested first action.
   Orientation material (user, project, cheat sheet, pointers) is not the working set.
6. **Write-back.** Refresh via a separate `save` (never an edit inside the read) only when
   pending or first-action *changed*, the change is **grounded in disk/git**, and this file is
   the session's **only mid-unit store**. Do not persist summary-only deltas. Do not save a
   merge you don't trust (Lifecycle's rollback exception). A borrowing site with commits + an
   on-disk plan as the mid-unit store skips this step.
7. **Reply** is the file's path plus the next action, then do the work. If a context-pressure
   warning is still visible, that is still Lifecycle moment (3).
8. **Continue without a user round-trip** if the next action is KNOWN. Re-confirming after a
   compaction is a nag, not a seam. **Failed compaction** (the summarizer refuses, or runs out
   of room and the session hard-stalls) is a hard session boundary: save if the session can
   still act, then reset and resume. **Recovery is for the compacted session only** — a
   **fresh** session that finds a save-state file runs **Resume** and *confirms before
   continuing*: it holds no prior launch confirmation, so the no-round-trip rule does not
   apply to it.

**Done when (Recovery):** the compacted session is re-oriented (file + bounded facts-gather
reconciled) and work continued — or, with no file, a fresh save now exists.

## Authority order

Checkpoint serves any long session, not only git repos: committed/durable artifacts (git
history, records, external systems of record) > files on disk > the checkpoint file > the
compaction summary. In a git repo this reduces to "git + records are truth for the committed;
the file/summary for intent."

## Two techniques the disciplines cite

- **Anchor-line repetition** (the anchor-line technique) — the save-state file itself
  carries its absolute path in the first heading (or an equally early, unique line) so a
  compaction summarizer that keeps headings can still find it. Speak that path to the
  human only at a seam: `save`, `resume`, Recovery, or when they ask where the
  save-state lives. Ordinary status replies do not open with it.
- **Context-pressure cue** — a harness context-low warning is Lifecycle checkpoint moment (3),
  not a separate rule: save now, recommend a reset.
