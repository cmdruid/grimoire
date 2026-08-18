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
for what shipped); resolve relative dates to absolute.

## Resume discipline

How it is read: read **in full**, load as context, echo the single next action, **rewrite
nothing**. Non-destructive — resume never deletes or edits the file, with no exception: a
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
compaction/continuation summary sitting where your conversation history should be. Then:
**stop** current work → re-read the checkpoint file **in full** → **reconcile**: the durable
trail is truth for everything committed; the compaction summary is truth only for in-flight
intent — merge them (completing this reconcile **confers ownership** of the root file — the
one-owner rules, `SKILL.md`) → **continue without a user round-trip** if the next action is
KNOWN. Re-confirming after a compaction is a nag, not a seam; round-trip only if the reconcile
surfaces genuine ambiguity. **No-file fallback:** if compaction strikes before the first save,
Recovery still runs — reconcile from the durable trail plus the summary alone, then **save
immediately** once re-oriented. **Failed compaction** (the summarizer refuses, or runs out of
room and the session hard-stalls) is a hard session boundary: save if the session can still
act, then reset and resume. **Recovery is for the compacted session only** — a **fresh**
session that finds a checkpoint file runs **Resume** and *confirms before continuing*: it holds
no prior launch confirmation, so the no-round-trip rule does not apply to it.

**Done when (Recovery):** the compacted session is re-oriented (file + durable trail
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
