# Workstream Compaction Survival — Design

**Status:** Designed (2026-07-24), spike-validated on Claude Code 2.1.219 (Sonnet 5) + Codex
0.144.5 (gpt-5.6-sol), with a small-context verification on gpt-5.3-codex-spark against the final
(narrowed) anchor text. Implementation pending (see *Changes* below).

## Problem

The `workstream` skill's continuity machinery assumes all context loss is **deliberate**: the reset
ritual (`flow.md`) sequences `debrief -> ship -> save -> reset -> load` around a *chosen* `/clear`,
and "a save is justified only by imminent context loss" reads *imminent* as *scheduled*. Both target
harnesses now **auto-compact**: when the context window fills, the harness summarizes the transcript
and the session continues — mid-turn, mid-feature, with no save preceding it and no session boundary
to fire `load`. That breaks three assumptions at once:

1. **Arbitrary timing** — compaction can strike mid-feature or mid-ship; the on-disk `WORKSTREAM.md`
   may be many features stale.
2. **No resume trigger** — the session continues on a lossy summary; nothing routes the agent back
   through the resume discipline.
3. **Silent doctrine loss** — `flow.md` and the verb procedures live in the *transcript* ("mid-loop
   verbs assume it is already in context"), so compaction can degrade the seam rules, ship cadence,
   and sole-writer discipline into whatever the summarizer kept — and the agent doesn't know.

## What structurally survives compaction (the design's foundation)

Three channels sit outside the summarizer's blast radius; the design builds only on these:

- **Files on disk.** `WORKSTREAM.md`, the plan, git state — all trivially durable. The gap is purely
  that nothing *tells* the post-compaction agent to re-read them.
- **Instruction files (`AGENTS.md` / `CLAUDE.md`).** Both harnesses re-inject the project front-door
  with every request; it is not part of the summarized transcript. **Spike-verified in both**: after
  compaction, both agents quoted a sentinel-tagged front-door block verbatim without tools, and
  Codex's rollout log shows the `AGENTS.md` instructions message re-injected in the post-compaction
  `replacement_history` at the API level. This is the one **guaranteed-survival channel**.
- **The summary itself** — lossy but steerable: summarizers preferentially keep salient, repeated,
  recent state.

## Design

Three layers. (A fourth — a Claude `PreCompact` hook steering the summarizer — was in the draft and
is **dropped**; the spike showed it unnecessary, see *Spike evidence*.)

### 1. The anchor — a generic recovery block in the host front-door

A short block registered **once per project** into the host's `AGENTS.md`/`CLAUDE.md` front-door
(the same self-registration pattern every grimoire skill uses for its route):

> **Workstream compaction recovery.** Applies only when your context has just been compacted or
> summarized (you see a compaction/continuation summary in place of the full conversation), and only
> to the tree your working directory is inside (`git rev-parse --show-toplevel`):
> - If `WORKSTREAM.md` exists at that tree's **top level**, you are the session driving that
>   workstream — STOP before any further work: re-read it in full, reconcile it against the durable
>   progress records it names, and only then resume from its recorded queue state.
> - If instead a `.workstreams/<stream>/WORKSTREAM.md` under the top level records
>   `isolation: in-place` **and** HEAD is on that stream's branch, the same applies — you are in the
>   shared tree that stream holds.
> - Hand-offs visible under `.workstreams/` from the root checkout otherwise belong to **other
>   sessions'** worktrees: never read, load, or recover them.

Properties that make this the right shape:

- **Generic convention text, not per-stream state** — checked in once; every worktree checkout
  inherits it from the branch; in-place streams get it from the root file. No per-stream stub files,
  no gitignore gymnastics, no Codex-has-no-`CLAUDE.local.md` problem.
- **Registered idempotently by `create`** (like `worktree-exclude.sh`): present -> no-op; absent ->
  propose the one-time front-door commit (root-commit contention rules apply — explicit pathspec).
- **Patient-zero caveat** (grimoire `AGENTS.md`): this library's own front-door never accretes the
  block; the mechanism is exercised against throwaway fixture front-doors only.

### 2. Scenario C — the involuntary reset (re-entry ritual)

`flow.md`'s reset ritual gains a third scenario alongside A (feature-boundary) and B (mid-feature):

> **Scenario C — involuntary reset (auto-compaction).** Detected by the compaction/continuation
> summary marker in context (both harnesses leave one) or by the anchor's instruction. Ritual:
> stop current work -> re-read `WORKSTREAM.md` in full -> re-read `flow.md` -> run the START HERE
> guard -> reconcile against `git log` and the durable records (git is truth for committed work;
> the compaction summary is truth for in-flight intent — merge them) -> continue **without a user
> round-trip** if the next action is KNOWN. The pre-compaction session already held its launch
> confirm; re-confirming is a nag. Round-trip only if re-orientation surfaces genuine ambiguity.

This is `load`-lite: `load`'s resume discipline run in place, minus the session-boundary mechanics
and minus the launch-confirm seam. A **failed compaction** (see *Failure modes*) routes to the
existing Scenario A/B machinery instead: save -> reset -> load.

### 3. Freshness — bound the hand-off's staleness

"A save is justified only by imminent context loss" gets one amendment: under auto-compaction, loss
is no longer *predictable*, so the justification becomes **imminent or unpredictable loss**:

- `save` also fires at every **feature-completion seam** (alongside debrief #1), not only pre-reset.
  Staleness is bounded to one in-flight feature.
- Mid-feature freshness is deliberately **not** solved by more saves: git commits + the on-disk plan
  already carry it, and Scenario C's reconcile step recovers it. (The spike's continuity leaned on
  exactly this durable-record reconcile.)
- **For small-context models this layer is the load-bearing one.** The spark verification showed
  compaction on small windows can terminally fail (see *Failure modes*) — when it does, the anchor
  never gets a post-compaction turn to fire in, and only the durable records + a fresh session
  carry the stream. The anchor covers the mid-size case; freshness covers the floor.
- A harness context-pressure warning, when visible, is an explicit trigger to run Scenario B
  proactively — beat the compactor to a clean checkpoint.
- Cheap insurance for the "hand-off read long ago" case: the loop's seam-status lines lead with a
  fixed anchor line (`WORKSTREAM <name> — hand-off: <abs path>`), repeated salient state the
  summarizer reliably keeps.

## Spike evidence (2026-07-24)

Fixture: throwaway repo with the anchor block (sentinel-tagged) in `AGENTS.md` (`CLAUDE.md` =
`@AGENTS.md`), a 14-task `WORKSTREAM.md` queue (read a ~40k-token telemetry file, extract a planted
token, append to `notes/log.txt` — the durable record), driven by real interactive sessions in both
harnesses. (Raw transcripts/rollouts lived in the spike session's scratchpad — ephemeral; the
findings below are the durable record.)

| Test | Claude Code (Sonnet 5) | Codex (gpt-5.6-sol) |
|---|---|---|
| S1 anchor survives compaction | pass — quoted verbatim, no tools | pass — quoted verbatim, no tools |
| S2 post-`/compact` resume, bare "continue" | pass — correct task + token | pass — **anchor explicitly fired** |
| S3 auto-compact mid-turn, unattended | pass — 1 auto-compact, 14/14 correct | pass — **3 auto-compacts**, anchor fired after each, 14/14 correct |

Load-bearing findings:

- **Codex is where the design earns its keep.** It compacted 3x in one queue run and, after every
  compaction, announced it was "applying the workstream recovery rule", re-read the hand-off + the
  durable log, reconciled, and resumed correctly — the designed mechanism executing verbatim,
  unattended.
- **Claude Code has a native assist**: it auto-restores *recently-read* files after compaction
  (`WORKSTREAM.md` was re-injected unasked) and its summary alone carried correct resumption. This
  is why the `PreCompact` hook layer is dropped. The assist only covers recently-read files — a
  hand-off loaded hours pre-compaction may not qualify, which is what the anchor + seam anchor line
  cover.
- **The anchor is behaviorally sufficient**: no hooks, no per-stream files, no harness-specific
  wiring needed in the skill core.
- The spike ran the anchor's **pre-narrowing wording** (the scoping to the agent's own toplevel /
  in-place custody was added in review, closing a root-checkout false-positive on *other* streams'
  hand-offs). The narrowing changes the trigger's scope, not the mechanism; the small-context
  verification below already ran the **narrowed** text.

### Small-context verification (gpt-5.3-codex-spark, medium effort)

A second Codex pass on a deliberately small-window model, against the **narrowed** anchor text and
a worktree-shaped fixture (hand-off at tree top). Three findings, each design-relevant:

- **Small models dodge ingestion by instinct.** The first run "completed" the queue with zero
  compactions: spark extracted every token via `rg` one-liners and `cat file >/dev/null` — content
  never entered its context. Only explicit no-text-processing rules forced genuine reads. Upshot:
  small-model sessions compact *less* than window size suggests (they shell out), but when they do
  ingest, compaction density is high (~every 2 tasks here vs ~every 10 for gpt-5.6-sol).
- **The anchor holds on a small model: 3/3.** After every successful auto-compaction, spark's
  first mid-turn action was re-read `WORKSTREAM.md` + the durable log, announce it was resuming
  from durable state, and continue — including resuming a half-read file at the correct chunk
  offset. Anchor compliance is not a frontier-model luxury.
- **Compaction terminally fails on small windows — recurrently.** Two threads each eventually hit
  `Error running remote compact task: Codex ran out of room in the model's context window` and
  hard-stalled (nudges re-error; the harness says start a new thread). One thread died on its
  first compaction attempt, the other after three successful ones. The recovery that works is the
  skill's classic session boundary: fresh thread + durable state — tested, it reconciled
  `notes/log.txt`, skipped completed tasks, and resumed exactly (queue reached 8/14 across two
  threads with no repeated or lost work before the spike was concluded).

## Failure modes

- **Compaction itself can fail — two observed modes, one remedy.** (a) *Content refusal* (Claude):
  transcript content can make the summarizer refuse, deterministically — repeated attempts fail.
  (b) *Window exhaustion* (Codex, small models): the compact operation runs out of room and the
  session hard-stalls ("start a new thread"); observed recurrently on spark — sometimes on the
  first compaction, sometimes after several successful ones. Either way the session is pinned and
  cannot compact; the remedy is the existing ritual as a hard session boundary: save (if the
  session can still act) -> reset/new thread -> `load` — the hand-off + durable records carry
  continuity (spike-verified: a fresh thread reconciled the log, skipped completed work, resumed
  exactly). Scenario C's text names this exit.
- **Anchor not yet registered** (pre-existing streams, host never ran the new `create`): behavior
  degrades to today's status quo — summary-only continuity. The seam anchor line still raises the
  odds the summary carries the pointer.
- **Summary actively wrong.** Scenario C's reconcile step trusts git + durable records over the
  summary for anything committed; the summary is authoritative only for in-flight intent.

## Changes (implementation scope)

| File | Change |
|---|---|
| `skills/workstream/flow.md` | Scenario C section; freshness amendment to the reset ritual; context-pressure trigger |
| `skills/workstream/verbs/save.md` | Justification clause: "imminent or unpredictable loss"; feature-seam saves |
| `skills/workstream/verbs/create.md` | Idempotent anchor registration step (front-door commit, pathspec-scoped) |
| `skills/workstream/templates/workstream-handoff.md` | Loop-routine: Scenario C entry + seam anchor line |
| `skills/workstream/SKILL.md` | One-line pointer to Scenario C in the discipline section (verbs stay thin) |

**Boundary call:** workstream-first, shaped for extraction. The anchor + Scenario C concepts are
written so they lift into `/handoff` later (its root `HANDOFF.md` sessions share the exposure), but
the generic version is not designed until a second consumer exists.

## Verification

- Re-run the spike matrix against the *implemented* skill text (fixture front-door registered by
  `create` itself rather than hand-written) — S2/S3 in both harnesses are the acceptance tests.
- **Acceptance re-run: 2026-07-24, both cells pass** (fixture anchor taken verbatim from the
  implemented `templates/compaction-anchor.md`). Claude Code (Sonnet 5): manual compact
  (~300k -> ~20k) -> bare "continue" -> correct-task resume, correct token; the session also
  routed itself through the real installed skill and read the implemented `flow.md`, and the
  harness restored the loaded skill post-compaction ("Skills restored (workstream)") alongside
  recently-read files. Codex (gpt-5.3-codex-spark, medium): 3 compactions (1 manual + 2 auto),
  correct resume in all 3, explicit hand-off + durable-log re-read in 2 of 3 (the third resumed
  correctly from the summary + durable log).
- `skill-builder check` on the touched skill files (lint gate + boundary audit).
- The compaction-refusal path is exercised only by inspection (deliberately re-creating a refusing
  transcript is not worth automating); the Scenario C text just names the manual exit.
