# Checkpoint — the persistence utility (handoff v2 + the machinery move from workstream)

Design for Phase 5 task 2, expanded: `handoff` does not merely rename to `checkpoint` — it becomes
the **canonical home of session-persistence doctrine**, absorbing the compaction-persistence
machinery `workstream` currently owns. Workstream then *borrows* it by named-discipline reference,
exactly as it already borrows handoff's Save/Resume disciplines today. Companion to
`2026-08-12-clankshop-v2.md` (the v2 design) and the Phase 5 plan.

## Why

Two forces:

1. **The rename was already queued** (PACK.md transition note: `handoff` → `checkpoint`).
2. **The compaction-persistence machinery is generic, but lives stream-bound.** Workstream's
   living hand-off, Scenario C recovery, recovery anchor, anchor-line repetition, and
   context-pressure cue protect *any* long session from involuntary context loss — yet today only
   worktree streams get them. A long root session compacts and loses everything, because the old
   `/handoff` file is a one-shot baton that exists only *between* sessions, never *during* one —
   compaction strikes mid-session, precisely when no `HANDOFF.md` exists.

The move direction follows the existing seam: workstream already consumes handoff's disciplines by
reference (`verbs/save.md`: "apply `/handoff`'s Save discipline"; `verbs/load.md`: Resume). This
design widens what is borrowed from "how the file is written/read" to "how the file **lives**."

## Decision summary (settled with the human, 2026-08-13)

- **Lifecycle: living save-state** (option a) — not a one-shot baton, not a dual-layer hybrid.
- **Ownership moves; workstream borrows.** Not a copy (BL-6: parallel doctrine drifts).
- **The split**: Lifecycle, Recovery, anchor-line, context-pressure cue, and the cheat-sheet
  *concept* move to checkpoint; START HERE guard, Coordinates/custody/queue state, and the
  stream-specific checkpoint seams stay in workstream.
- **Structure of the borrow: named disciplines** (approach 1) — doctrinal reference as
  locally-complete citation, no shared scripts (a save is synthesis, not mechanics). Checkpoint
  ships **no generic registration machinery** (register-route was retired this same phase): its
  anchor is a documented convention — human-installed for root sessions, while workstream's
  existing create-time registration of its own anchor instance stays (§4).

## 1. Shape and naming

- `skills/handoff/` → `skills/checkpoint/`. `scripts/repo-snapshot.sh` moves with it, untouched.
- Verbs: **`save`**, **`resume`**, and new **`done`**.
- Managed file: root `CHECKPOINT.md` (was `HANDOFF.md`) — still gitignored per-machine scratch,
  never merged, never a durable record. **The ignore is now a checked mechanism, not an
  assumption**: in a git repo, `save` verifies the target is ignored (`git check-ignore`) and, if
  not, appends it to `.git/info/exclude` before writing — the same per-machine mechanism that
  ignores `HANDOFF.md` today (and workstream's `worktree-exclude.sh` precedent). The old
  exclusion line for `HANDOFF.md` is left alone; machines converge as saves happen.
- **One root checkpoint, one owner** (the existing single-active-root-session rule, kept and
  sharpened by the living model): a session that did not create or resume the root
  `CHECKPOINT.md` treats an existing one as **foreign** — it either resumes that work (becoming
  its session) or stays out (its own work goes to an explicit-path file). `save` onto a foreign
  checkpoint **stops and surfaces** instead of overwriting another session's only save-state.
- The **explicit-path escape hatch** (path-like argument → that literal file, unmanaged) and the
  **bare-word rejection** (named hand-offs do not exist; suggest root / explicit path /
  `/workstream`) survive unchanged.
- The **worktree redirect survives**: a session living in a worktree stream is `/workstream`'s
  territory — its save-state is `WORKSTREAM.md`, and `/checkpoint save` there is refused with a
  pointer to `/workstream save` (a competing root save-state beside a stream hand-off is the
  corruption this guard prevents).
- SKILL.md description rewritten for routing (save / resume / done; living save-state; compaction
  recovery); the body carries a one-line "formerly `/handoff`" note for muscle-memory.
- External invocation refs re-pointed: `skills/workstream/verbs/load.md`, `verbs/save.md`
  (the only two outside the skill), plus PACK.md's manifest `optional:` list and transition note
  (flips to landed).

## 2. The four disciplines (the exported doctrine)

The skill's core is four **named disciplines** other skills borrow by reference:

- **Save discipline** — unchanged: scan/elide secrets; synthesize, don't transcribe (reconcile
  against `git log` — it is truth for what shipped); resolve relative dates to absolute.
- **Resume discipline** — unchanged core: read in full, load as context, echo the single next
  action, rewrite nothing. **No longer consumes** — consume dies with the baton.
- **Lifecycle discipline** *(new — moved from workstream's flow)* — the file is a **living
  save-state**: created at the **first save, which should come early** — once a session is
  demonstrably mid-work (a first unit done, or a stretch of unrecoverable in-flight state ahead),
  not only at the end (before the first save there is no compaction protection; that exposure
  window is why the first save is prescribed early, not left to "when I'm done"); refreshed at
  checkpoint moments — before a deliberate reset, at a work-unit completion (bounding staleness to
  one in-flight unit should compaction strike), and on a context-pressure warning (beat the
  compactor to a clean checkpoint, **and recommend a reset** — the warning means loss is near);
  never consumed by resume; ended only by `done`.
  **Presence = work in flight** — with two qualified states: a file whose content git/records
  contradict is **stale** (Recovery/Resume's reconcile detects this: the file is intent, disk is
  truth — trust disk, refresh the file), and a file describing work that has since landed is a
  **forgotten `done`** (resume detects it and proposes `done` rather than resuming ghost work).
  **Rollback exception**: a *polluted* context resets **without** saving — deliberately rolling
  back to the last clean checkpoint. Never refresh the file from a context you don't trust; the
  pre-reset refresh applies only to a healthy-but-heavy context.
- **Recovery discipline** *(new — moved from workstream's Scenario C)* — on detecting an
  involuntary compaction (a compaction/continuation summary sitting where conversation history
  should be): **stop** current work → re-read the checkpoint file in full → **reconcile**: the
  durable trail is truth for everything committed; the compaction summary is truth only for
  in-flight intent — merge them → **continue without a user round-trip** if the next action is
  KNOWN. Re-confirming after a compaction is a nag, not a seam; round-trip only if the reconcile
  surfaces genuine ambiguity. A *failed* compaction (summarizer refuses / runs out of room) is a
  hard session boundary: save if the session can still act, then reset and resume.
  **No-file fallback**: if compaction strikes *before the first save* (no checkpoint file exists),
  Recovery still runs — reconcile from the durable trail plus the compaction summary alone, then
  **save immediately** once re-oriented (the exposure window closes at that first save; this is
  the failure the early-first-save prescription exists to shrink).
  **Recovery is for the compacted session only.** A **fresh** session that finds a checkpoint file
  runs **Resume** — read, load, echo the next action, *confirm before continuing* (it holds no
  prior launch confirmation, so the no-round-trip rule does not apply to it). The two paths differ
  in exactly that one right: compaction inherits the session's standing confirmation; a fresh
  session must earn one.
  **Authority order** (checkpoint serves any long session, not only git repos): committed/durable
  artifacts (git history, records, external systems of record) > files on disk > the checkpoint
  file > the compaction summary. In a git repo that reduces to the familiar "git + records are
  truth for the committed; the file/summary for intent."

Two **techniques** the disciplines cite:

- **Anchor-line repetition** — every substantial status message leads with
  `CHECKPOINT — file: <absolute path>`: repeated, salient state a compaction summarizer reliably
  keeps, so even a lossy summary points back at the file.
- **Context-pressure cue** — a harness context-low warning is the Lifecycle discipline's third
  checkpoint moment (listed above), not a separate rule.

## 3. Document structure

The existing 11-section structure stays. Two changes:

- New optional **Cheat sheet** section — an orientation map for longer-lived checkpoints.
  Minimum schema (from workstream's template): a **`built-against:`** baseline (the commit/state
  the pointers were verified at), **repo-relative pointer paths**, grouped by kind (files/module
  map; gotchas/invariants), refreshed at each save, carrying the **verify-before-trust rule** (a
  pointer is a snapshot; check it still resolves before leaning on it). This section is an
  **explicit exception** to "omit only if empty": include it *by judgment* — a checkpoint expected
  to outlive several resets earns one; a short-lived one skips it.
- The read-this-first preamble declares the file a **living save-state** (rewritten at each save,
  ended by `done`), not a one-shot baton.

## 4. Recovery anchor — checkpoint documents the convention; installers may automate their instance

A session finds the file via a short block in the host's **always-loaded front door**
(`AGENTS.md` / `CLAUDE.md` / equivalent), with **two paths keyed on how the session began**:
*compacted mid-work* → run `/checkpoint`'s Recovery discipline (continue without a round-trip if
KNOWN); *fresh session, file present* → run Resume (load, echo the next action, **confirm** before
continuing). The SKILL.md provides the copy-paste block carrying both paths.

**Installation is layered, and the existing machinery is kept — enumerated here:**

- **Checkpoint itself ships no registration script.** For a plain root session **the human
  installs the block** (or asks the agent to, as a one-off edit they approve). `register-route`
  was retired this phase; checkpoint must not rebuild generic registration under a new name.
  `save` **checks** for the anchor — **managed root saves only** (an explicit-path file is
  unmanaged end to end; no anchor check): step 6's confirmation notes whether a front door carries
  a recovery block, and warns (without mutating anything) if none is found — a save that succeeds
  while recovery stays undiscoverable is a silent hole. *Front door* = the files the harness
  actually always-loads at this root (`AGENTS.md`, `CLAUDE.md`, or the host's equivalent); if
  several exist, **any one** carrying the block satisfies the check, and the confirmation names
  which.
- **Workstream's existing automation stays.** `verbs/create.md` already registers the workstream
  anchor block (`templates/compaction-anchor.md`) into the host `AGENTS.md` at stream creation —
  a targeted, single-purpose seam at a genuine install moment, not generic registration. It
  remains workstream's own (the block carries stream-specific custody rules — in-place holds,
  foreign worktrees). Its template and `create.md` step gain a one-line note that the block is
  the **workstream instance** of checkpoint's anchor convention; grimoire's own `AGENTS.md` copy
  of that block is likewise annotated. No file is deleted; nothing is re-homed.

## 5. Workstream's borrow (the diff on workstream)

Pure re-homing — **zero behavioral change** to the loop:

- `flow.md` Scenario C shrinks to: run `/checkpoint`'s **Recovery discipline** against
  `WORKSTREAM.md`, **plus** the workstream overlays — **re-read `flow.md` itself** (compaction may
  have erased the orchestration rules, which live outside the checkpoint file; the current ritual
  re-reads it and the borrow must not lose that), the START HERE guard, custody checks (in-place),
  never recovering another session's worktree.
- The reset ritual's save rationale cites the **Lifecycle discipline**; workstream keeps its own
  stream-specific checkpoint moments (the feature-completion seam, `park`'s custody hand-over).
- `verbs/save.md` / `verbs/load.md` re-point "`/handoff`'s Save/Resume discipline" →
  "`/checkpoint`'s".
- The hand-off template's anchor-line rule cites checkpoint's **anchor-line technique**.
- **Borrow style: locally-complete citation.** Each borrowing site names the discipline *and*
  carries its one-line gloss (exactly as `verbs/save.md` does today: "apply `/checkpoint`'s Save
  discipline — scan/elide secrets, synthesize don't transcribe, absolute dates"). Workstream thus
  **degrades gracefully** if checkpoint isn't installed — the gloss is enough to operate on; the
  reference is where the full doctrine lives. No pack-manifest dependency edge is added: both
  remain independently-installable optional members, which is precisely what the citation style
  buys.
- **Creation timing is a declared overlay**: Lifecycle's "created at first save" is the root
  default; workstream creates `WORKSTREAM.md` at `create` — legitimate, because an installer verb
  *is* the stream's first save moment (create seeds the hand-off from its template and the borrow
  begins there). Stated so the "zero behavioral change" claim holds without a hidden exception.
- **Stays in workstream:** Coordinates, custody/park, queue state, START HERE guard,
  `cheatsheet-check` plumbing, the stream-specific seams, and `create.md`'s anchor registration
  (§4). `WORKSTREAM.md` remains workstream's own structure (the borrow is discipline, not
  template).

## 6. What retires

- Consume-on-resume, and with it the "presence = unresumed context" signal. Under the living
  model **presence means "work in flight"**; `/checkpoint done` is the explicit end.
- **The `done` gate, specified:** before deleting, check the trail the file describes — in a git
  repo, a dirty tree or work the file names that never landed → **surface it and require an
  explicit confirm** ("this checkpoint describes unlanded work; delete anyway?"); outside git,
  ask the same question against whatever durable trail exists. Rationale: the file may be the
  only explanation of retained WIP. `done <path>` is **rejected** — explicit-path files are
  unmanaged; their owner deletes them (mirrors the existing resume rule).
- **Legacy discovery:** a bare `resume` that finds no `CHECKPOINT.md` **checks for `HANDOFF.md`**
  at the same root and reports it if present — without consuming or migrating it; the human
  decides (it may be a pre-rename baton from an old session). Otherwise stray `HANDOFF.md` files
  are inert gitignored scratch — no migration.

## 7. Edges and lint

- Edges block: artifact type `handoff-doc` → `checkpoint-doc`; still an intra-skill
  produces↔consumes pair (save produces, resume consumes — "consumes" in the *edge* sense of
  reading, unaffected by the death of file-deletion), so the known BL-4 single-use WARN persists —
  expected, documented in the block's postscript.
- The edges-format **line kind** `handoff:` in `skills-lint.sh` is format vocabulary
  (produces / handoff / consumes), unrelated to the skill's name — **untouched**.
- `done` joins the description's verb list; description re-checked against the lint's rules.

## 8. Verification

Doctrine-heavy, so the checks are reference-integrity plus **scenario walkthroughs**, and each
mechanical check is **proven by breaking** (the library rule):

- Lint `fails=0` for the renamed skill (description, frontmatter, edges).
- Phase 5's exit sweep extends to **zero `/handoff` refs** outside `docs/design/` + `.scratch/` —
  proven by planting a stray ref, watching the sweep catch it, removing it. The sweep covers
  prose, scripts, templates, and comments — not only slash-invocations (the word `handoff`
  meaning *this skill* is in scope; the edges-format line kind and generic English "hand-off"
  are not).
- Grep-proof that workstream's verbs point at `/checkpoint` (both files).
- **Lifecycle walkthroughs** (desk-checked against the final SKILL.md text — the doctrine
  equivalent of a fixture suite; each scenario must have one unambiguous answer in the text):
  first save early; resume with no file (+ legacy `HANDOFF.md` present); fresh-session-vs-
  compacted at the anchor; compaction before the first save (no-file fallback); stale checkpoint
  (disk contradicts file); forgotten `done`; `done` with unlanded work; polluted-context rollback
  (no save); save with no anchor installed; save target not gitignored (exclude append); save
  onto a foreign checkpoint (stop-and-surface); workstream host without checkpoint installed
  (gloss suffices).
- The wiring caveat carries over: `~/.claude/skills/` serves the renamed dir only after the root
  clone ships and the human re-runs `install.sh checkpoint` (and drops the old `handoff` symlink) —
  a lint wiring WARN until then, expected.

## Out of scope

- Any harness-side automation of the anchor (hooks, SessionStart injection) — the anchor is a
  documented convention; automation is a separate decision.
- Porting workstream's `cheatsheet-check` script into checkpoint — the *section* and
  verify-before-trust rule move; the git plumbing stays where its Coordinates live.
- Back-porting to deployed hosts — Phase 6's territory.
