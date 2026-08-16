---
name: checkpoint
description: Keep a living save-state for the current session's work and recover it after context loss. Use when asked to save/checkpoint/snapshot the session's context or working state, to resume or pick up prior work, to recover after a compaction/continuation summary appears where conversation history should be, to install the recovery anchor, or to close out (done) a finished checkpoint. Writes one gitignored CHECKPOINT.md at the project root — presence means work in flight; an explicit path argument targets an unmanaged second file instead. Scoped to the single root session's save-state — a session driving an isolated stream saves through that stream's own hand-off and save verb, never this skill.
---

# Checkpoint skill

Keep the session's work-in-progress in a **living save-state** — a file a future agent (any
vendor) or a context-loss survivor can read as the entry point and continue from. The file is
**gitignored per-machine scratch, rewritten at each save** — never merged, never a durable
record. *(Formerly the `handoff` skill — the one-shot baton is retired.)* A *durable* record of
*finished* work closes through the host's records layer (or its own done trail), not a
checkpoint.

This `SKILL.md` is a **thin router**: scope, guards, and dispatch live here; each verb's
procedure lives in `verbs/<verb>.md`, and the four disciplines — the skill's citable core,
which other skills borrow by name — live in **`references/disciplines.md`**. When a verb is
selected, **read its file and follow it**; read the disciplines file at any save/resume/
recovery moment if it is not already in context.

## Scope — two layers, one owner

**Two layers, by isolation** — pick by where the session lives:
- A session **driving a stream** (its own worktree, or in-place custody of the main checkout —
  an in-place stream is rooted at the root checkout, so "this is the root session" proves
  nothing on its own) saves through that stream's own hand-off and save verb — never this
  skill: a competing root save-state beside a stream hand-off corrupts the resume path. The save procedure's **stream
  guard**, fed by this skill's `scripts/save-guard.sh` (the canonical probe for these sites),
  is the mechanical form of this refusal.
- **The single active root session** → `/checkpoint` → root `CHECKPOINT.md`.

**One root checkpoint, one owner — and ownership must survive the very event this skill exists
for.** Session memory is what compaction destroys, so "did I create this file?" cannot be the
whole test. Four rules:
1. **Ownership is conferred by creating the file, by completing a Resume** (steps 1–2 plus the
   human's confirm — resume's transition clause), **or by running Recovery's reconcile** — a
   compacted session that finds the root file and reconciles it against the durable trail IS
   the owning session; the foreign guard must never fire against a post-compaction self.
2. **Reading is not resuming.** A session that merely read the file while exploring has not
   resumed it and gains no ownership.
3. **Foreignness requires positive evidence of another session** — content describing work
   unrelated to this session's, or a different root. A compacted session (a
   compaction/continuation summary sits where history should be) that finds a checkpoint whose
   content matches its own in-flight work runs **Recovery's reconcile** rather than treating
   its own file as foreign — refusing there strands the session into the competing second file
   this rule exists to prevent.
4. A genuinely foreign checkpoint → `save` **stops and surfaces** (never overwrites another
   session's only save-state; never silently): resume it (becoming its session) or stay out —
   own work goes to an explicit-path file.
(There is no named-session layer: concurrent parallel sessions are a stream driver's job; the
rare legitimate second file is an **explicit path**, below, with no managed lifecycle.)

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does |
|---|---|---|
| `save` | `verbs/save.md` | synthesize the conversation into the checkpoint file (create or refresh) |
| `resume [<path>]` | `verbs/resume.md` | load the checkpoint and continue; never consumes the file |
| `done` | `verbs/done.md` | gated close-out: confirm landed/abandoned, delete, say so |
| `anchor` | `verbs/anchor.md` | check/install the front-door recovery anchor (human-approved edit) |

**Recovery is a discipline, not a verb** (`references/disciplines.md`) — it fires on detecting
a compaction, not on invocation.

## When to use

- **save:** "save this context", "checkpoint this", "snapshot where we are" — and, unprompted,
  at the Lifecycle discipline's checkpoint moments (see *Unprompted behaviors*).
- **resume:** "resume our work", "pick up where we left off" — or a fresh session discovering a
  root `CHECKPOINT.md` via the recovery anchor.
- **done:** the checkpointed work has landed (or is deliberately abandoned) and the file should
  stop signaling work-in-flight.
- **anchor:** "install the recovery anchor", save's anchor warning, or standing up a project
  where compaction recovery should be discoverable from day one.
- **Recovery** (no verb): a compaction/continuation summary sits where your conversation
  history should be.

Do not invoke for routine status updates within the same session, or for memory entries; a
stream-driving session uses its stream's save verb (*Scope*).

## Where it writes

Classify the trailing argument, then resolve the target:

- **No argument** → the root `CHECKPOINT.md`. Resolve the root in order: (1) the project
  directory the conversation references; (2) `./CHECKPOINT.md` in the cwd; (3) still unsure →
  ask before generating.
- **A path-like argument** (contains `/` or ends in `.md`) → that literal path, verbatim — the
  unmanaged escape hatch for a deliberate second checkpoint file. Unmanaged end to end: no
  anchor check, no lifecycle, `done <path>` rejected — and **only as fresh as its last save**:
  living-memory behavior requires the caller to supply an update cadence (re-save after each
  completed unit is the lightweight convention).
- **A bare word** (`dev`, `research`, …) → **reject and explain**: named checkpoints do not
  exist. Suggest the root checkpoint, an explicit path, or — for a genuinely concurrent
  session — a stream with its own hand-off. Never silently reinterpret a bare word as a path.

Write-guards (tracked-file, ignore-as-checked-mechanism) are save's: `verbs/save.md` → *The
ignore mechanism*, fed by `scripts/save-guard.sh`.

## The four disciplines (names + glosses — normative text in `references/disciplines.md`)

- **Save discipline** — elide secrets; synthesize, don't transcribe; absolute dates.
- **Resume discipline** — read in full, echo the next action, rewrite nothing.
- **Lifecycle discipline** — first save early; refresh at the three checkpoint moments; ended
  only by `done`; presence = work in flight; rollback exception for polluted contexts.
- **Recovery discipline** — on compaction: stop, re-read, reconcile (durable trail beats
  summary), continue without a round-trip if KNOWN; anchor-dependent for discoverability.

## Unprompted behaviors (the during-the-session rules — no invocation needed)

- **First save early**: once the session is demonstrably mid-work, create the checkpoint — the
  window before the first save has no compaction protection.
- **Refresh at the checkpoint moments**: before a deliberate reset; at each work-unit
  completion; on a context-pressure warning (save now, recommend a reset).
- **Anchor-line repetition**: while a checkpoint is live, lead every substantial status message
  with `CHECKPOINT — file: <absolute path>` — repeated, salient state a compaction summarizer
  reliably keeps, so even a lossy summary points back at the file.
- **Compaction summary detected → stop and run Recovery** (`references/disciplines.md`).

## Done when

Each verb's done-when closes its own file (`verbs/*.md`); Recovery's closes the discipline
(`references/disciplines.md`).

## Edges

Checkpoint's **typed edges** -- its place in a workflow declared as artifact *types*, never as
sibling names (the typed-edge tenet -- portable home: skill-builder's `docs/DOCTRINE.md`
§ *Typed edges*; library history: `docs/design/2026-07-18-skill-self-init-model.md` §2). A
real **self-chain**: `save` produces the doc, `resume` consumes it back (consumes in the *edge*
sense of reading -- the living file is never deleted by resume). No durable home (the root
`CHECKPOINT.md` is gitignored scratch, lazily created) -- registration is optional and not
implemented.

<!-- edges:checkpoint -->
- produces: checkpoint-doc — the written save-state (root `CHECKPOINT.md`, or an explicit-path file)
- handoff: — (none; the doc is picked up by *resume*, not handed to another skill)
- consumes: checkpoint-doc — resume reads the doc back (intra-skill: same skill on both ends)
<!-- /edges:checkpoint -->

**`checkpoint-doc` is a stated intra-skill chain** (a produces line AND a consumes line in one
skill), which `skills-lint.sh` check 8's BL-4 exclusion deliberately covers — so a clean lint is
the expected state. **A `checkpoint-doc` WARN appearing means the pair broke** (an edge-block
typo dropped one side) and is a real finding, never a known false positive to wave through.
