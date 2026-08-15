---
name: checkpoint
description: Keep a living save-state for the current session's work and recover from context loss. `/checkpoint save` writes/refreshes the root CHECKPOINT.md (gitignored living scratch, never consumed); `/checkpoint resume` loads it and continues; `/checkpoint done` ends the lifecycle (gated delete). Owns the Save/Resume/Lifecycle/Recovery disciplines other skills borrow, including compaction recovery. An explicit path argument targets that file instead (unmanaged escape hatch). Use when asked to save/snapshot/checkpoint context, resume prior work, recover after compaction, or close out a finished checkpoint. Scoped to the single root session; refused inside a workstream (worktree or in-place), whose hand-off is the checkpoint with its own save verb.
---

# Checkpoint skill

Keep the session's work-in-progress in a **living save-state** — a file a future agent (any
vendor) or a context-loss survivor can read as the entry point and continue from. The file is
**gitignored per-machine scratch, rewritten at each save** — never merged, never a durable
record. *(Formerly the `handoff` skill — the one-shot baton is retired; see Lifecycle below.)*

Two layers, by isolation — pick by where the session lives:
- **Workstream sessions** → `/workstream` (its own `WORKSTREAM.md` hand-off). Not this skill:
  a `/checkpoint save` from a session driving a stream — **worktree or in-place** (an in-place
  stream is rooted at the root checkout, so "this is the root session" proves nothing on its
  own) — is **refused** with a pointer to `/workstream save` — a competing root save-state
  beside a stream hand-off corrupts the resume path. The save procedure's **stream guard**
  (step 1) is the mechanical form of this refusal.
- **The single active root session** → `/checkpoint` → root `CHECKPOINT.md`.

**One root checkpoint, one owner.** A session that did not create or resume the root
`CHECKPOINT.md` treats an existing one as **foreign**: it either resumes that work (becoming its
session) or stays out — its own work goes to an explicit-path file. `save` onto a foreign
checkpoint **stops and surfaces** instead of overwriting another session's only save-state.
(There is no named-session layer: concurrent parallel sessions are `/workstream`'s job; the rare
legitimate second file is an **explicit path**, below, with no managed lifecycle.)

A *durable* record of *finished* work closes through the host's records layer (`records.sh done`
+ the history ledger, where deployed — else the host's own done trail), not a checkpoint.

Verbs:
- **save** — synthesize the current conversation into the checkpoint file (create or refresh).
- **resume** — load the checkpoint and continue the work. Never consumes the file.
- **done** — end the lifecycle: confirm the work is genuinely landed (or deliberately
  abandoned), delete the file, say so.

## When to use

- **save:** "save this context", "checkpoint this", "I want to come back to this later" — and,
  unprompted, at the Lifecycle discipline's checkpoint moments (below).
- **resume:** "resume our work", "pick up where we left off", "/checkpoint resume" — or a fresh
  session discovering a root `CHECKPOINT.md` via the recovery anchor.
- **done:** the checkpointed work has landed (or is deliberately abandoned) and the file should
  stop signaling work-in-flight.
- **Recovery** (no verb — a discipline): your context was just compacted/summarized mid-work —
  see *Recovery discipline*.

Do not invoke for routine status updates within the same session, or for memory entries. For a
session driving a **workstream** (isolated worktree or in-place), use `/workstream`, not this —
"save a checkpoint" there means `/workstream save`, the stream's hand-off being its checkpoint.

## Where it writes

First classify the trailing argument, then resolve the target:

- **No argument** → the root `CHECKPOINT.md`.
- **A path-like argument** (contains `/` or ends in `.md`) → that literal path, verbatim — the
  unmanaged escape hatch for a deliberate second checkpoint file. Unmanaged end to end: no
  anchor check, no lifecycle, and `done <path>` is **rejected** — its owner deletes it.
  **And unmanaged means un-refreshed:** a persistent explicit-path file is only as fresh as its
  last save — nothing here maintains it between saves, so **living-memory behavior requires the
  caller to supply an update cadence** (re-save after each completed unit is the lightweight
  convention; `/workstream`'s checkpoint routine — refresh at every feature-completion seam — is
  the reference). The file *shape* alone is not crash-resilient working memory; the cadence is
  what makes it one, and the difference is easy to miss when reaching for an explicit path as a
  lighter workstream substitute.
- **A bare word** (`dev`, `research`, …) → **reject and explain**: named checkpoints do not
  exist. Suggest the root checkpoint (no argument), an explicit path, or — if the real need is a
  concurrent/parallel session — a `/workstream` stream. Never silently reinterpret a bare word
  as a path.

Resolving the **root** `CHECKPOINT.md` (the no-argument case), in order:
1. If the conversation references an obvious project directory, write `<that-dir>/CHECKPOINT.md`.
2. Else `./CHECKPOINT.md` in the current working directory.
3. If still unsure, ask the user before generating.

**The ignore is a checked mechanism, not an assumption.** In a git repo, before writing the root
file, verify it is ignored (`git check-ignore CHECKPOINT.md`); if not, append `CHECKPOINT.md` to
`.git/info/exclude` — per-machine, never committed. (A stale `HANDOFF.md` exclusion line from the
pre-rename era is left alone.)

## The four disciplines

The skill's core is four **named disciplines**. They are this skill's own procedures AND an
exportable doctrine: another skill may borrow one by name for its *own* save-state — targeting
its own file, using its own document structure, layering its own rules on top (e.g.
`/workstream`'s `WORKSTREAM.md` borrows all four, adding worktree guards and custody checks).
A borrowing site should carry a one-line gloss alongside the reference (a *locally-complete
citation*) so it degrades gracefully where this skill isn't installed.

- **Save discipline** — how the file is written: scan/elide secrets; **synthesize, don't
  transcribe** (the document is for a future agent, not a chat log — and in a git repo,
  reconcile against `git log`, the truth for what shipped); resolve relative dates to absolute.
- **Resume discipline** — how it is read: read **in full**, load as context, echo the single
  next action, **rewrite nothing**. Non-destructive — resume never deletes or edits the file.
- **Lifecycle discipline** — how it lives: created at the **first save, which should come
  early** — once the session is demonstrably mid-work (a first unit done, or a stretch of
  unrecoverable in-flight state ahead), not "when I'm done"; before the first save there is no
  compaction protection, and that exposure window is why the first save is prescribed early.
  Refreshed at **checkpoint moments**: (1) before a deliberate reset, (2) at a work-unit
  completion — bounding staleness to one in-flight unit should compaction strike, (3) on a
  context-pressure warning — save proactively **and recommend a reset**; beat the compactor to a
  clean checkpoint. Never consumed by resume; ended only by `done`. **Presence = work in
  flight**, with two qualified states: a file the durable trail contradicts is **stale** (the
  file is intent, disk is truth — trust disk, refresh the file), and a file describing work that
  has since landed is a **forgotten `done`** (resume detects this and proposes `done` rather
  than resuming ghost work). **Rollback exception:** a *polluted* context resets **without**
  saving — deliberately rolling back to the last clean checkpoint. Never refresh the file from a
  context you don't trust; the pre-reset refresh applies only to a healthy-but-heavy context.
- **Recovery discipline** — surviving an involuntary compaction. You detect one by a
  compaction/continuation summary sitting where your conversation history should be. Then:
  **stop** current work → re-read the checkpoint file **in full** → **reconcile**: the durable
  trail is truth for everything committed; the compaction summary is truth only for in-flight
  intent — merge them → **continue without a user round-trip** if the next action is KNOWN.
  Re-confirming after a compaction is a nag, not a seam; round-trip only if the reconcile
  surfaces genuine ambiguity. **No-file fallback:** if compaction strikes before the first save,
  Recovery still runs — reconcile from the durable trail plus the summary alone, then **save
  immediately** once re-oriented. **Failed compaction** (the summarizer refuses, or runs out of
  room and the session hard-stalls) is a hard session boundary: save if the session can still
  act, then reset and resume. **Recovery is for the compacted session only** — a **fresh**
  session that finds a checkpoint file runs **Resume** and *confirms before continuing*: it
  holds no prior launch confirmation, so the no-round-trip rule does not apply to it.

**Authority order** (checkpoint serves any long session, not only git repos): committed/durable
artifacts (git history, records, external systems of record) > files on disk > the checkpoint
file > the compaction summary. In a git repo this reduces to "git + records are truth for the
committed; the file/summary for intent."

Two **techniques** the disciplines cite:

- **Anchor-line repetition** — a session working under a checkpoint leads every substantial
  status message with `CHECKPOINT — file: <absolute path>`: repeated, salient state a compaction
  summarizer reliably keeps, so even a lossy summary points back at the file.
- **Context-pressure cue** — a harness context-low warning is Lifecycle checkpoint moment (3),
  not a separate rule: save now, recommend a reset.

## Save procedure

Steps 2–4 are the **Save discipline** (exportable, above). Steps 1, 5–6 are this skill's flow.

1. **Sanity-check the request, and resolve the target.** If the conversation has been short,
   contains no concrete work to checkpoint, or is purely Q&A with nothing to resume, push back —
   ask what specifically to preserve. Resolve the target per *Where it writes*. In a git repo,
   run the **stream guard** (mechanical — the *Two layers* refusal): probe for a workstream
   context — `WORKSTREAM.md` at `git rev-parse --show-toplevel` (a worktree stream), or a
   `.workstreams/<stream>/WORKSTREAM.md` under the toplevel recording `isolation: in-place`
   with HEAD on that stream's branch (an in-place stream). A hit → **refuse and point to
   `/workstream save`**; do not write. Then, for the root file: run the
   **foreign-checkpoint guard** (an existing `CHECKPOINT.md` this session neither
   created nor resumed → stop and surface; never overwrite) and the **ignore check**.
2. **Scan for sensitive material.** Look for secrets, credentials, API tokens, private keys, or
   PII. Do NOT include them; in your reply, mention what you elided so the user can re-supply it
   securely.
3. **Synthesize, do not transcribe.** Reframe past discussion as forward-looking instructions.
   In a git repo, cross-reference `git log` — reconcile it against the conversation rather than
   memory.
4. **Resolve relative time references.** Convert "yesterday", "last week", etc. into absolute
   dates using the real current date — the document outlives the conversation.
5. **Write the file** to the target path using the structure below (overwriting in place — a
   refresh rewrites the whole file, it does not append).
6. **Confirm to the user.** Report the path written. **Managed root saves only:** note whether a
   front door at this root carries a **recovery anchor** (see *Recovery anchor*) — warn (without
   mutating anything) if none is found, since a save that succeeds while recovery stays
   undiscoverable is a silent hole. *Front door* = the files the harness actually always-loads
   at this root (`AGENTS.md`, `CLAUDE.md`, or the host's equivalent); any one carrying the block
   satisfies the check — name which. Offer a memory pointer if the harness supports persistent
   memory.

## Resume procedure

Steps 2–3 are the **Resume discipline** (exportable, above). The file is already a synthesized
summary — **do not re-summarize it**, and never consume it.

1. **Locate the file** (per *Where it writes*): the root `CHECKPOINT.md` for a bare `resume`;
   the literal path for `resume <path>`. **Legacy discovery:** a bare `resume` that finds no
   `CHECKPOINT.md` checks for a `HANDOFF.md` at the same root and reports it if present —
   without consuming or migrating it (it may be a pre-rename baton from an old session; the
   human decides). If neither exists, say so.
2. **Read it in full** and load it as the working context for the session.
3. **Confirm ready — briefly.** Reply that you've read it; at most echo the one-line *Suggested
   first action* verbatim. A resuming session **confirms before continuing** (contrast Recovery,
   which continues without a round-trip — it inherits the compacted session's standing
   confirmation; a fresh session must earn one). While reconciling, apply the Lifecycle
   discipline's qualified states: a **stale** file → trust disk, refresh; work already landed →
   propose **`done`** instead of resuming ghost work.

## Done procedure

`done` ends the root checkpoint's lifecycle. It is **gated** — the file may be the only
explanation of retained WIP:

1. Check the trail the file describes: in a git repo, a dirty tree or work the file names that
   never landed → **surface it and require an explicit confirm** ("this checkpoint describes
   unlanded work; delete anyway?"). Outside git, ask the same question against whatever durable
   trail exists.
2. On confirm (or a clean trail): **delete the file** and say so ("checkpoint closed and
   deleted"). Absence again means "nothing in flight."
3. `done <path>` is **rejected** — explicit-path files are unmanaged; their owner deletes them.

## Document structure

The **default** structure for a saved checkpoint. A skill borrowing only the disciplines (e.g.
`/workstream`) supplies its own structure instead. Use Markdown headings, in this order; omit a
section only if it would be empty (one judgment-call exception: the Cheat sheet).

1. **Title and "last updated" date.** The actual current date, not a placeholder.
2. **Read-this-first preamble.** One line declaring this file the entry point for the work — a
   **living save-state**, rewritten at each save, ended by `/checkpoint done` (not a one-shot
   baton).
3. **TL;DR.** One paragraph: what the work is, where it stands, what comes next.
4. **The user.** Role, technical level, collaboration preferences.
5. **The project.** What it is. Key facts known. Key unknowns still open.
6. **What's been done.** Artifacts with exact file paths; decisions + brief rationale. In a code
   repo, pull the shipped list from `git log`, not just memory.
7. **Repo state** *(code projects).* Current branch; build/tests green as of this save (run them
   if cheap); working tree clean or dirty (and with what). `scripts/repo-snapshot.sh <root>`
   emits the branch, dirty state + counts, recent commits, and the date in one read — it fills
   this section and grounds #6's `git log` reconciliation (build/tests green stays your call:
   that needs the host's gate, not a snapshot).
8. **What's pending.** Numbered next steps in priority order.
9. **Critical considerations.** Constraints, gotchas, easy-to-miss context — always with the WHY.
10. **Cheat sheet** *(optional — by judgment, an explicit exception to omit-only-if-empty: a
    checkpoint expected to outlive several resets earns one; a short-lived one skips it).* An
    orientation map so a resuming agent navigates without re-exploring: a **`built-against:`**
    baseline (the commit/state the pointers were verified at), **repo-relative pointer paths**
    grouped by kind (files/module map; gotchas/invariants), refreshed at each save. Carries the
    **verify-before-trust rule**: a pointer is a snapshot — check it still resolves before
    leaning on it.
11. **Pointers.** Links to the project's other entry docs — `AGENTS.md`, `README`,
    `.handbook/README.md`, relevant plans/roadmaps.
12. **Suggested first action.** A concrete first move, specific enough to act on immediately.
    (Resume echoes this line, so keep it sharp and self-contained.)

## Recovery anchor — the discoverability convention

A compacted (or fresh) session only benefits from the checkpoint if something it *still reads*
points at the file. That something is a short block in the host's **always-loaded front door**
(`AGENTS.md` / `CLAUDE.md` / equivalent — re-injected every request, so it survives compaction by
construction). **The human installs it** (or asks the agent to, as a one-off approved edit) —
this skill ships no registration machinery. The copy-paste block:

```markdown
## Checkpoint recovery

If `CHECKPOINT.md` exists at this project's root, it is the living save-state of work in
flight (`/checkpoint`):
- If your context was **just compacted/summarized** (a compaction/continuation summary sits
  where conversation history should be), you are the session that work belongs to — STOP,
  re-read `CHECKPOINT.md` in full, reconcile it against the durable trail (git, records),
  and continue without a user round-trip if the next action is KNOWN.
- If you are a **fresh session**, read it, echo its suggested first action, and **confirm
  with the user** before continuing that work.
```

An *installer* skill with a genuine install moment may automate its own instance of this
convention — `/workstream create` registers its stream-specific anchor block this way. That
automation belongs to the installer, not here.

## Style guidance

- Write FOR a fresh agent who has never seen this work. Spell things out.
- Include exact file paths for every referenced artifact.
- Quote concrete decisions verbatim where possible — don't paraphrase nuance away.
- Capture WHY behind decisions and constraints, not just what was decided.
- Omit chat-room artifacts: greetings, dead-end debugging, side chatter.
- Call out irreversible deadlines/freezes/external dependencies with absolute dates.
- Keep it as short as it can be while still complete — typically 1–3 pages of Markdown.

## Done when

- **save:** the written file alone lets a fresh agent of any vendor resume the work — current
  state, next action, and repo baseline all present — with no recourse to the original
  conversation; the root file is verifiably gitignored; the anchor check reported.
- **resume:** the checkpoint is loaded into context, you've confirmed ready, and the file is
  untouched on disk.
- **done:** the gate ran, the root file is deleted, and the user was told.
- **Recovery:** the compacted session is re-oriented (file + durable trail reconciled) and work
  continued — or, with no file, a fresh save now exists.

## Edges

Checkpoint's **typed edges** -- its place in a workflow declared as artifact *types*, never as
sibling names (the typed-edge tenet; `docs/design/2026-07-18-skill-self-init-model.md` §2). A
real **self-chain**: `save` produces the doc, `resume` consumes it back (consumes in the *edge*
sense of reading -- the living file is never deleted by resume). No durable home (the root
`CHECKPOINT.md` is gitignored scratch, lazily created) -- registration is optional and not
implemented.

<!-- edges:checkpoint -->
- produces: checkpoint-doc — the written save-state (root `CHECKPOINT.md`, or an explicit-path file)
- handoff: — (none; the doc is picked up by *resume*, not handed to another skill)
- consumes: checkpoint-doc — resume reads the doc back (intra-skill: same skill on both ends)
<!-- /edges:checkpoint -->

**`checkpoint-doc` is used by exactly one skill**, so `skills-lint.sh` check 8 legitimately WARNs
(single-use type) even though the pair is correctly matched -- a known false-positive for an
intra-skill artifact (BL-4), not a fix to make here.
