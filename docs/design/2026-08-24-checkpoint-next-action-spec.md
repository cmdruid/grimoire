---
doctype: specs
status: published
created: 2026-08-24
updated: 2026-08-24
tags: [spec]
---

# Checkpoint next-action contract — Spec

This library's design home is `docs/design/` (patient-zero: grimoire
authors the workshop, it does not run one on itself). This spec lives
here. It doubles as the implementation plan.

Settled 2026-08-24 in conversation: hybrid C (named / KNOWN write
immediately; user-invoked human-present AMBIGUOUS asks once;
unprompted never interviews). Remaining forks resolved in
*Approach* and *Mechanism* below. Small feature: slices live in
this file.

Lineage this amends, not replaces:
`docs/design/2026-08-13-checkpoint-skill-design.md` §2 (Save / Resume
disciplines). Frozen borrow surface from
`docs/design/2026-08-15-checkpoint-refinement-plan.md` still binds:
do **not** rename or renumber the four disciplines or the three
Lifecycle checkpoint moments.

## Problem

A checkpoint's job is to let a later session continue. Resume already
echoes *Suggested first action* and waits for a confirm. Recovery
already auto-continues when that action is KNOWN. Workstream `load`
already runs Confident launch on the same idea.

Save does not author that action as a contract. It **synthesizes** a
sentence from the conversation and writes it. The human has no
first-class way to name what comes next, or to take the agent's
recommendation, when they ask for the save. A trailing bare word is
rejected as a named checkpoint. After the write, confirmation reports
the path (and, for workstream, whatever the agent just recorded) — not
an agreed next step.

So a fresh session can load the file and still be designing the next
move. That is the wrong seam. It is sharpest for Recovery, which will
auto-continue a KNOWN action the human never confirmed.

The root need: **the next action is decided at save, honored at load.**

## Goal

After this feature, a human can:

1. Call for a save in one turn.
2. Name the next step in that same turn, **or** take the agent's
   recommendation (explicit pick only when the next step is a real
   fork).
3. Open a new session, resume/load, and continue that recorded
   course of action — resume/load echo and confirm; they do not
   reopen "what should we do next?" — unless load-time disk /
   stream-state forces otherwise (same veto as save).

Unprompted saves (lifecycle moments, Recovery write-back, workstream
flow-triggered save/park) still write immediately. They never
interview. A save that exists to beat compaction must not stall.

## Approach

**Hybrid C**, already chosen.

The next action is a **contract written at save**. Classification:

| Situation | What happens |
|---|---|
| This turn **names** a load-executable next step | Write it. No ask. |
| **KNOWN** from context | Write it. Report it. Override is a same-breath refresh. |
| **User-invoked, human-present, AMBIGUOUS** | Propose the recommendation plus one or two alternatives, one pick, **then** write. Only extra round-trip. |
| **Unprompted** | Best-guess synthesis, write immediately, report what was recorded. |

**One home per fact.** Next-action *authoring* (named > KNOWN >
best-guess; one load-executable sentence; git/disk veto) lives in
**Save discipline** — workstream already borrows it. The *round-trip
gate* (ask only on user-invoked human-present AMBIGUOUS) lives in
each skill's `save` verb, so a flow-triggered save cannot stall the
loop. Resume *does not reopen* the next-action design — that clause
lives in **Resume discipline**.

Rejected alternatives:

- **Always optimistic-write (A).** Easiest call, but Recovery will
  auto-continue a wrong guess. The whole point of C is to catch a
  fork while the human is present.
- **Always propose-then-write (B).** Makes every save a two-turn
  ceremony and fights "easy to call." Unprompted saves could not
  honor it without stalling compaction protection.
- **A new `save-next` verb or named checkpoints.** Named checkpoints
  stay rejected. Next-action is an argument to `save`, not a second
  file or a second verb.
- **Re-open the next step at load.** Load already has a confirm
  (checkpoint resume; workstream Confident launch). Designing there
  duplicates the seam and leaves Recovery with an unconfirmed
  contract.

**Forks settled with this spec (confirm at review):**

1. **Named-next detection is intent, not "any extra words."**
   Markers (`next:`, `—`) and same-turn prose that states the
   subsequent work both count. Politeness (`please`, `now`) does
   not. A single bare word is still a named-checkpoint reject.
   `--` is not a marker (it looks like a flag).
2. **Resume stays read-only on a redirect.** "Do Y instead" is new
   in-session intent. The next save captures it. Compaction between
   redirect and save is the same exposure Lifecycle already accepts
   mid-unit; the human who wants it locked says save again.
3. **Workstream named next is a detour of the immediate action**,
   not a queue rewrite. TL;DR + *What's next* first item change.
   Queue and plan do not. In `manual` mode, a named next step that
   *is* a phase change updates `Phase:` (that is the launch key);
   a named next step *inside* the current phase does not. If it
   conflicts with `Phase:` and is not itself a phase change →
   AMBIGUOUS. Confident launch still applies stream-state first.
4. **Suggested first action stays one imperative sentence.**
   Resume echoes that line. Details stay in pending / cheat sheet /
   workstream queue. Not a mini-runbook. TL;DR's "what comes next"
   restates that same sentence.
5. **Named-but-vague is not named.** A string that is not concrete
   enough to act on immediately fails the named predicate and takes
   the AMBIGUOUS path, constrained by the stated intent.

## Mechanism

### Terms

- **Named.** This turn's invocation or same-turn message states a
  load-executable next step (see *Invocation*).
- **KNOWN.** One clear continuation, any of: a single in-flight unit
  being paused; pending has one obvious first item; workstream queue
  item / `Phase:` / flow-determined next (`sync`, `recycle`, unpark)
  is already determined; standing direction from earlier in the
  session that has not been superseded.
- **AMBIGUOUS.** A real fork: two or more reasonable next moves;
  several equally plausible pending first items; user invoked save
  at a pause with no direction and no KNOWN predicate holds.
- **User-invoked.** The human asked to save / checkpoint / snapshot
  this turn.
- **Human-present.** A human is in the conversation and can pick.
  Loop-driven / no-human saves take the unprompted path for the
  round-trip gate.
- **Unprompted.** Lifecycle first-save-early; the three checkpoint
  moments; Recovery write-back; workstream flow-triggered
  save / park / feature-completion / pre-reset. Also the
  round-trip-gate path when no human is present to pick, even if
  a save verb was requested by a loop.
- **Load-executable.** One imperative sentence a fresh agent can
  act on immediately. Names the act, and the skill/verb when that
  *is* the move (`/inspector review the spec at <path>`). Not a
  paragraph.

### Save discipline (`skills/checkpoint/references/disciplines.md`)

Keep the three existing bullets (elide secrets; synthesize, don't
transcribe; absolute dates). Add a fourth:

> Author a **single next action** as a load-executable contract.
> Prefer a next step **named** this turn; else a **KNOWN**
> continuation; else a best-guess synthesis (highest-priority
> pending item, or continue the in-flight unit). Git/disk veto a
> next-action that claims work undone when it has landed — do not
> write that lie.

Do not put the round-trip gate in the discipline. Unprompted and
flow-triggered saves must keep synthesizing without an interview;
that exemption is a verb-flow fact, not a writing technique.

SKILL.md gloss becomes: *elide secrets; synthesize, don't
transcribe; absolute dates; author a single next action (named >
KNOWN > best-guess).*

Workstream's locally-complete citation at
`skills/workstream/verbs/save.md` updates to the same four-part
gloss. Discipline **names** stay Save / Resume / Lifecycle /
Recovery.

### Resume discipline

Keep: read in full, echo the single next action, rewrite nothing.
Add: **do not reopen the next-action design.** A redirect ("do Y
instead") is new in-session intent; resume itself does not write;
the next `save` captures Y.

SKILL.md gloss becomes: *read in full, echo the next action, rewrite
nothing; do not reopen the next-action design.*

`skills/checkpoint/verbs/resume.md` gets the matching one-line
rule (redirect is new intent, not a resume write). Recovery is
unchanged: continue without a round-trip if the recorded next
action is KNOWN.

### Invocation (`skills/checkpoint/SKILL.md` *Where it writes*)

Path classification is unchanged and wins first:

- Path-like token (contains `/` or ends in `.md`) → unmanaged
  explicit path. At most one; first wins.
- A **single bare word** with no next-action marker → reject
  (named checkpoints do not exist). Suggest root, explicit path, or
  a stream.

**New — named next action**, classified from the invocation and the
same-turn message after path tokens are peeled:

- `next:` plus the remainder of that span.
- Remainder after `—` (the explicit delimiter form).
- Same-turn prose that states the subsequent work ("checkpoint
  this, next we'll grill the spec"; "then we'll X").

`--` is not a marker. Politeness and chatter are not named. `next`
as a bare word (no colon, no remainder) is still the
named-checkpoint reject.

Combinations are legal: `/checkpoint save ./notes.md next: grill
the spec`. Workstream `save` has no path hatch; the same named
markers and same-turn prose apply.

Do not change the checkpoint `description:` for this. Save already
routes; next-action is an argument to save, not a new verb.

### Checkpoint `save` verb (`skills/checkpoint/verbs/save.md`)

Steps 2–4 remain the Save discipline (now including next-action
authoring). Steps 1, 5–7 are this skill's flow:

1. Sanity-check, resolve target **and classify named next-action**
   per *Where it writes*. Existing guards unchanged (stream,
   tracked-file, ignore, foreign).
2–4. Save discipline, including authoring the next-action
   sentence into section 12 *Suggested first action*. TL;DR's
   "what comes next" **restates that same sentence** — not a
   second independent line.
5. **Round-trip gate (before write).**
   - Named (and load-executable) or KNOWN or unprompted → write.
   - User-invoked, human-present, AMBIGUOUS → **STOP.** Propose
     the recommendation first, then one or two alternatives, each
     one line + why. One pick (or a named other). Then write in
     the pick's turn. Do not re-confirm "should I save?"
   - Named-but-vague → AMBIGUOUS, constrained by the stated
     intent.
   - Git/disk veto of a named action → do not write the lie;
     surface the contradiction; the situation is AMBIGUOUS;
     propose the real next from disk/pending.
6. Write the file (existing structure; section 12 is the
   contract; TL;DR restates it).
7. Confirm: path written; **the recorded next action**; existing
   managed-root anchor warning. **Also resume-how**
   (`/checkpoint resume`, or `resume <path>` for unmanaged) when
   this save precedes a new session: user-invoked, pre-reset, or
   context-pressure that recommends a reset. **Omit resume-how**
   otherwise: first-save-early, work-unit completion with no
   reset, Recovery write-back, feature-completion with no reset.
   Do not use a blanket "unprompted omits."

Same-breath override after confirm ("actually next is Y") is a
user-invoked save with named Y — refresh, do not re-ask.

Unprompted first-save-early and the three checkpoint moments skip
step 5's ask even if the synthesized next action would have been
AMBIGUOUS. They write the best guess and report path + recorded
next action. Resume-how follows step 7 (pre-reset and
context-pressure include it; first-save-early and a work-unit
completion with no reset do not).

### Workstream overlay

`skills/workstream/verbs/save.md`:

- Update the Save-discipline gloss (four-part).
- After applying Save discipline and reconciling TL;DR /
  next-action against `git log` / `log <branch>..<target>` (existing
  veto stays), apply the same round-trip gate: user-invoked
  human-present AMBIGUOUS asks once; named / KNOWN / flow-triggered
  write immediately. That pick is **part of the `save` verb**, not
  a fifth flow seam — do not add it to `flow.md`'s seam catalog.
- A **named** next step writes into TL;DR and *What's next* first
  item as **the same sentence**. Queue and plan do not rewrite.
- **`manual` mode:** a named next step that *is* a phase change
  updates `Phase:` (that is the launch key). A named next step
  *inside* the current phase leaves `Phase:` alone. If it
  conflicts with `Phase:` and is not itself a phase change →
  AMBIGUOUS; do not write the lie.
- The recorded line is what Confident launch confirms **when
  `stream-state` does not force otherwise**. The parenthetical
  cases (`behind>0` → sync; rebase / stray hand-off → hard stop)
  are examples, not the set — authority is
  `workstream-git.sh stream-state` / Confident launch. Git/disk
  still vetoes a lie at save.
- Flow-triggered saves (reset ritual, feature-completion, park,
  manual phase-boundary) are unprompted. Queue / `Phase:` is
  KNOWN when it already determines the next move.
- Post-write confirm: path + recorded next action + trunk
  movement (already). Resume-how (`/workstream load <stream>`)
  when the save precedes a new session (user-invoked, pre-reset,
  context-pressure that recommends a reset); omit otherwise.

`skills/workstream/flow.md`: one sentence at Confident launch that
a save authors the next-action contract the launch confirms unless
stream-state forces otherwise. Do not duplicate the hybrid table.
Confident launch stays the load seam.

`skills/workstream/templates/workstream-handoff.md` already
requires an unambiguous immediate *What's next* item and a TL;DR
that includes the recommended next action. No template change.

### What does not change

- Discipline names and Lifecycle checkpoint-moment ordinals.
- Resume read-only; stale-refresh is a separate `save`.
- Recovery: no user round-trip if KNOWN; write-back only when
  grounded and this file is the only mid-unit store.
- Stream guard, tracked-file guard, ignore mechanism, one-owner
  rules, explicit-path hatch, bare-word rejection.
- No new scripts. Next-action policy is agent prose.
- Checkpoint `description:` budget; no new frontmatter trigger.
- Workstream seam catalog (launch / blocker / fork / feature
  completion, plus `manual` phase-boundary and in-place park).

### Greenfield check

Constraints this mechanism designs around rather than deletes:

- **Bare-word rejection** — named checkpoints do not exist; deleting
  it would collide with the next-action remainder. Keep; peel path
  and `next:` first so a remainder is not a name.
- **Explicit-path hatch** — still needed for a deliberate second
  file; next-action classification runs *after* path tokens.
- **Recovery auto-continue if KNOWN** — keep; it is why save must
  author a confirmed-or-KNOWN contract. Deleting it would re-nag
  after every compaction.

Pay-the-debt: none. HEAD's save procedure is missing the contract;
the fix is to add it, not to remove Recovery or resume confirm.

## Verification

No new mechanical tests — there is no new script. Proof is prose
plus the existing lint gate.

1. `skills/skill-builder/scripts/skills-lint.sh` clean on
   `skills/checkpoint/` and `skills/workstream/` (frontmatter,
   bundled-ref, edge blocks, independence). Description length
   unchanged unless a slice edits it (it must not).
2. Grep the frozen borrow surface (discipline names, "third
   checkpoint moment", anchor-line technique) — this change only
   *adds* a bullet under Save / a clause under Resume; it does not
   rename.
3. Followability read of four save cases against the written
   verbs, as a fresh agent:
   - Named: "checkpoint this, next we'll grill the spec" or
     `next: grill the spec` → writes that sentence, confirms path
     + contract + resume how, no extra ask. `--` is not a marker.
   - KNOWN: user-invoked save mid-unit with one pending item →
     writes it, reports it.
   - AMBIGUOUS: user-invoked human-present save at a fork →
     stops with rec + alternatives; after pick, writes in that
     turn.
   - Unprompted feature-completion (no reset) → writes
     immediately even if a fork exists; reports path + recorded
     next action; no resume-how. Unprompted pre-reset /
     context-pressure → same write, **with** resume-how.
4. Resume redirect: file untouched; session proceeds with Y.
5. Workstream:
   - named in-phase detour changes TL;DR / *What's next* first
     item only; `Phase:` unchanged;
   - named phase change updates `Phase:`;
   - git-landed veto still refuses the lie;
   - `behind>0` still surfaces sync at load (stream-state wins);
   - flow-triggered save does not ask.

## Slices

### S1 — Checkpoint contract

Authoring rule + invocation + save/resume flow.

- **id:** S1
- **paths:** `skills/checkpoint/references/disciplines.md`,
  `skills/checkpoint/SKILL.md`,
  `skills/checkpoint/verbs/save.md`,
  `skills/checkpoint/verbs/resume.md`
- **verify:** `skills/skill-builder/scripts/skills-lint.sh`
  against `skills/checkpoint/`; followability cases Named / KNOWN /
  AMBIGUOUS / Unprompted on the checkpoint verbs; SKILL.md glosses
  match the discipline bullets.

### S2 — Workstream overlay

Borrow gloss + user-invoked gate + one flow sentence.

- **id:** S2
- **paths:** `skills/workstream/verbs/save.md`,
  `skills/workstream/flow.md`
- **verify:** `skills/skill-builder/scripts/skills-lint.sh`
  against `skills/workstream/`; locally-complete Save-discipline
  citation matches checkpoint's four-part gloss; followability
  cases Named-detour / named-phase-change / git-veto /
  stream-state-wins / flow-triggered-silent; Confident launch
  still the load seam; seam catalog unchanged.

S1 before S2 (workstream cites the discipline S1 writes). One
landing after S2.
