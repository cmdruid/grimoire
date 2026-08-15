---
name: delegate
description: "Use when about to do work a sub-agent could do (or on explicit /delegate [task]) -- the delegation front-door. Route work for speed, token cost, or context hygiene: offload grunt work to a cheaper model, keep your own context lean. Decide delegate-or-not, pick the mechanism (inline sub-agent / mailbox slot / Codex executor / parallel fan-out / isolated worktree), and confirm the route (which provider/model) with the human -- live cost/quota/availability is state you cannot see. Degrades to a fallback ladder (down to inline) on provider failure, so it runs safely in an autonomous loop. Harness-agnostic (Claude or Codex). Keywords: dispatch, byproducts, model routing."
---

# delegate -- hand work to a sub-agent, keep the judgment

## Overview

You are the expensive brain coordinating the work. A sub-agent is cheap hands and an isolated context.
Delegating well buys three things: **speed** (parallelize independent work), **token cost** (a cheaper
model does the grunt work), and **context hygiene** (the delegate's exploration never pollutes your
context; you collect a compact summary).

**Core thesis -- delegation trades context for distance.** You gain a lean context but lose sight of
*what the delegate saw* and *where it ran*. So the two things you can't reconstruct must cross back **by
contract**:

- the **route** (which provider/model) -- **confirmed up front**, because you can't see live
  cost/quota/availability;
- the **byproducts** (follow-ups / bugs / friction the delegate hit) -- **returned compactly**, because
  you can't see the delegate's dead context.

Everything else stays **pass-by-reference**: a path is paid once; pasted content is paid repeatedly.

This skill is a **router**: it owns the decisions (delegate-or-not, mechanism, route gate, return
contract) and the inline + fan-out mechanics, and points at one specialist for deep mechanics
(`mailbox` — the slot protocol; don't re-document it here). It is a **leaf** -- it names delegation
*mechanisms*, never *task
workflows*: a workflow skill may use `/delegate`; `/delegate` never says "use `/blueprint`".

## When to use

Trigger whenever you're **about to do work yourself that a sub-agent could do**, or on an explicit
`/delegate [task]`. No verbs -- with a task, assess and route it; with none, this is the ambient
doctrine.

**Is it delegable?** All three must hold:
- **well-scoped** -- you can state it self-contained, without your session history;
- **returns a conclusion or a reviewable artifact** -- a summary, a diff, a verdict;
- **needs your judgment to CHECK, not to PRODUCE** -- if producing it needs your taste/reasoning, keep
  it.

Judgment-heavy, ambiguous, or architectural work fails the third test -- do it inline.

**Assess at the right granularity, and check two more facts before fanning out:**
- **The unit of the delegate-or-not question is the genuinely-rote SUB-TASK, not the batch.** A
  batch that "looks independent" may decompose into mostly compiler-tight, judgment-heavy pieces
  with only a sub-trivial rote fraction below the dispatch+apply+gate overhead floor. Ask the
  question per sub-task. (Corollary: a run of all-inline work is not itself evidence delegation
  failed to fire — check whether the work was judgment-heavy, sub-trivial, or better scripted
  before treating a zero streak as a missed opportunity.)
- **A mechanical bulk transform with a machine-checkable invariant is a SCRIPTING problem before it
  is a delegation problem.** If the result is provable by diff (byte-identity, a normalized-multiset
  compare), a deterministic partition/codemod script beats a delegate re-deriving the same
  transform by reading — reserve delegation for transforms with real per-item judgment.
- **Does this machine's actual build-parallelism budget make fan-out's wall-clock payoff real?**
  RAM/build-governor constraints can serialize "parallel" isolated-worktree builds into a queue, so
  the payoff shrinks toward delegation's fixed overhead. A hand-off's "looks independent" framing
  alone is not a reason to reach for the heavier mechanism.

## Posture -- proactive on the act, confirm the route

- **Whether to delegate is your call, and proactive.** When work qualifies, delegate without being
  asked. That instinct is the point of this skill.
- **Which provider/model is the human's call.** It rests on live cost, quota, rate limits, and "is this
  actually cheaper on my current plan" -- state you structurally cannot see. A confidently-wrong route
  (rate-limited, unavailable, not actually cheaper) is worse than asking, and it fails *after* you've
  spent time and tokens.
  - **Compute the checkable facts yourself; never ask them.** `command -v codex`, is the API key / env
    present, does the harness offer sub-agents.
  - **Confirm only the unobservable.** Propose the route *with your assumption stated* ("mechanical
    12-file refactor -- a candidate for a cheaper executor, if one's available/cheaper for you now --
    OK?") and wait for the human to approve the provider+model.
  - **Confirm once, then proceed.** A confirmed route becomes a session preference; don't re-ask each
    dispatch.
- **No route, no gate.** A same-harness, *same-model* sub-agent spawned purely for context isolation
  makes no cross-provider claim -- light-touch, no confirmation. The gate fires only when a *specific
  different* provider/model is chosen.
- **Autonomous mode (pre-confirmed route).** When the route is already confirmed and recorded for the
  session/stream (e.g. a `/workstream` hand-off), skip per-dispatch confirmation -- the unobservable was
  decided once. Provider *failures* are then handled per **Failure states** below, not by prompting; an
  unattended loop **degrades, it never stalls**. This is what makes `/delegate` safe to run inside an
  autonomous workstream loop.

## The decision tree -- pick the mechanism

```
About to do work →
  Delegable? (well-scoped • returns a conclusion/artifact • you CHECK, don't PRODUCE)
    no  → do it inline
    yes → What is the shape / payoff?
       ├─ read / analysis → a conclusion        → INLINE read-only sub-agent   (owned here)
       ├─ file-work, want it back clean,          → MAILBOX slot                (→ mailbox skill)
       │   or worktree single-writer safety
       ├─ mechanical CODING → a diff             → CODEX executor              (references/codex.md)
       ├─ N independent tasks at once            → PARALLEL fan-out            (owned here, below)
       └─ delegate needs its own live build loop → ISOLATED worktree           (own branch; you merge)
```

- **Inline read-only sub-agent** -- for read/analysis grunt work that returns information, not a diff
  (broad searches, log triage, summarizing files). Cheapest dispatch; no slot needed. Craft a focused
  task that does **not** inherit your context; ask for a bounded summary.
- **Mailbox slot** -- file-work you want back *without* polluting your context, or *safely in a worktree*
  (the delegate is tree-read-only; only you write the tree). The artifact travels as a path you
  `git apply`. See the **`mailbox`** skill for the protocol; don't re-document it.
- **Codex executor** -- mechanical *coding* → a reviewable diff you gate and commit. See
  **`references/codex.md`** (the `codex exec` invocation, granularity, review/trust discipline, the
  sandbox-can't-reach-network gotcha).
- **Parallel fan-out** -- 2+ *independent* tasks (different files / subsystems / failures, no shared
  state). One read-only sub-agent per domain, all dispatched **concurrently in a single turn**, each
  with a self-contained prompt (no inherited context, no dependence on a sibling's result) and the
  bounded-summary return contract. You synthesize the results; if two tasks turn out to share
  state, they weren't independent -- run those sequentially instead.
- **Isolated worktree** -- when the delegate needs its own live build/test (red-green) loop on its own
  branch. Heaviest (compile/RAM); use when the local loop is worth it. You merge its branch.
  The brief shape that has carried judgment-heavy sweeps cleanly: a **narrow, list-shaped brief**
  (the exact sites, the exact transform) plus an explicit **"flag same-pattern sites outside the
  brief — never silently expand scope"** clause; the flags come back as byproducts you triage.

**Model-routing table** (examples only; the human confirms the actual route):

| Phase | Model tier | Return |
|---|---|---|
| planning / design / review | strong | consume (doc / verdict) |
| implementation / remediation | mid | apply-only (patch) |
| testing / analysis | cheap | consume (findings) |

## The return contract -- compact, three parts

Every delegation returns **three** compact things -- never the raw exploration:

1. **Deliverable** -- a handle + one-line summary (mailbox slot), or a bounded summary (inline). Bulk
   artifacts travel as a **path** you apply, never re-paid through context.
2. **Status** -- the delegate's own assessment of how the task went, one of four states (distinct
   from *provider* failure below -- this is the task's difficulty, not the API's health):
   - **DONE** -- complete, verified against the actual gate/tests, no known gap.
   - **DONE_WITH_CONCERNS** -- complete, but the delegate has one specific, named doubt (an edge case
     it couldn't cover, an assumption it couldn't verify). Never silently ship a concern -- state it.
   - **NEEDS_CONTEXT** -- couldn't proceed with the prompt as given (a missing file, an ambiguous
     requirement, a fact only the orchestrator holds). Re-dispatch with the gap filled; never guess
     on the delegate's behalf, and never re-run the identical prompt expecting a different result.
   - **BLOCKED** -- the task itself doesn't fit: too hard for the model it ran on, or the task/plan as
     written rests on a wrong assumption. Escalate to a stronger model or a smaller re-scoped task --
     never a same-model retry of the unchanged dispatch (that treats a difficulty problem as if it
     were a transient provider hiccup).
3. **Byproducts block** -- a small, structured list in `/backlog debrief`'s capture kinds, surfaced by
   the delegate (it does a mini-debrief of its own slice):
   - follow-up work → Backlog · defect noticed → bug record · project problem/risk → Issues ·
     dev-experience observation → Feedback · **feedback about a skill itself → the skills' home
     feedback channel, tagged by skill** (not a project tracker). **Empty is fine and explicit.**

**Route on status, don't just relay it:**
- **DONE** → proceed, but still re-establish trust from evidence (below) -- a self-reported DONE is not
  itself the evidence.
- **DONE_WITH_CONCERNS** → investigate the named doubt yourself before accepting; it is exactly the
  kind of specific, bounded claim worth five minutes of verification.
- **NEEDS_CONTEXT** → re-dispatch with the missing piece filled in; log why the original prompt fell
  short as a byproduct (an Issues/Feedback line) -- it improves the next prompt, not just this one.
- **BLOCKED** → escalate (bigger model / smaller task) on the first one or two; **three or more BLOCKED
  reports on re-scoped attempts of the same underlying task means the task or the plan itself is
  wrong, not the model** -- stop re-scoping and take it back to whoever owns the plan, the same
  "question the fundamentals, not the Nth attempt" shape `debugger` uses for a run of failed fixes.

**Stash returned byproducts into your running capture notes immediately** (as you would your own
discovered follow-ups) so they survive context compaction to the end-of-work `/backlog debrief`. They land
back in your context by contract, so debrief needs no special handling.

**Weak model = weak detector.** A cheap delegate spots fewer byproducts than you would. "Report anything
that looked like a bug / follow-up / friction" is a low bar most models clear, but **byproduct-rich or
observation-heavy work is a reason to route UP, not down** -- a real counterweight to the cost instinct.

## Re-establish trust on return

Never accept a self-report ("tests pass", "done") -- **including a DONE status**. Re-establish trust
from the evidence yourself -- the diff, the gates you run, the output. The delegate executes literally
and has no judgment to refuse a wrong instruction; when it faithfully produces something wrong, suspect
your prompt, not the delegate.

## Failure states & durability

**Delegation is an optimization, not a dependency.** Every fallback bottoms out at *do it inline on the
orchestrator's own model* -- always available, because the orchestrator is by definition running. So the
worst case of any delegation failure is "no speedup/savings this time," never "stuck." That floor is what
makes autonomous delegation safe.

A provider failure is an **observable fact** -- you *react* to it, unlike the route *prediction* you
confirmed up front (a runtime error is knowable; next week's quota was not). Classify it and respond:

- **Transient** -- rate-limit / 429, 5xx / service down, timeout, network blip. → **bounded backoff +
  limited retries** on the same route; if it persists past a couple of tries, treat it as persistent.
- **Persistent** -- quota / token limit exhausted, model unavailable / deprecated / bad id, auth
  rejected. → **don't retry the same route** (it will keep failing). Re-route to a **pre-approved
  alternate** if one exists, else drop to the floor.
- **Floor -- inline.** Do the work yourself on the orchestrator's model. The optimization is lost; the
  work is not.
- **Last resort -- surface.** Only if even inline isn't viable (e.g. the unit needed an isolated build
  loop you can't run). Interactive: ask the human. **Autonomous loop: park the unit, log it, continue** --
  never block the whole loop on one failed dispatch.

**Log every fallback as a byproduct** (route X failed → fell back to Y) in the return contract's
byproducts block → ISSUES / FEEDBACK. A fallback is also a signal the confirmed route has gone stale and
may need re-confirming -- the same observable fact, surfaced to whoever owns the route.

## The spawn seam (the one harness-specific step)

The protocol above is harness-neutral; only *how you spawn a sub-agent on the named model* differs.
"Model" is an **opaque per-harness string** -- pass it to the spawn, never interpret it.

- **Claude orchestrator** → native sub-agent (Task tool) with a model override; for coding, `codex exec`.
- **Codex orchestrator** → no native model-routed sub-agent, so `codex exec --model <m>` subprocess **is**
  the delegation primitive (for both analysis and coding).

## Anti-patterns

- **Over-delegation** -- dispatching a one-liner costs more (latency + the prompt) than doing it. Don't
  dispatch what you can finish in a sentence.
- **Context-boomerang** -- the delegate returns a wall of raw work, defeating the whole point. Enforce
  the tiny-return contract.
- **Routing blind** -- committing to a specific provider/model without the human OK on live
  cost/availability.
- **Trusting the self-report** -- accepting "tests pass" instead of running the gate yourself.
- **Same-model retry of a BLOCKED task** -- re-running the identical dispatch and hoping for a
  different result. BLOCKED means the task or model doesn't fit; escalate or re-scope, don't repeat.
- **Delegate edits a shared worktree** -- silent corruption (its cwd is the repo root, not the worktree).
  Tree-read-only; it writes only its slot. You are the sole tree writer.
- **Delegating taste** -- judgment-heavy / ambiguous / architectural work needs your reasoning to
  *produce*, not just to check.

## Quick reference

| Step | Action |
|---|---|
| delegable? | well-scoped • returns a conclusion/artifact • you check, don't produce |
| pick mechanism | inline sub-agent / mailbox slot / codex / parallel fan-out / isolated worktree |
| route | compute checkable facts; **confirm the provider/model** with the human (once → session pref) |
| dispatch | self-contained task, no inherited context; on the confirmed model |
| return | deliverable (tiny) + status (DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED) + byproducts block (debrief taxonomy, empty OK); stash byproducts now |
| trust | re-establish from diff / gates / output -- never the self-report, even a DONE one |

## Edges

Delegate's **typed edges** -- its place in a workflow declared as artifact *types*, never as sibling
names (the typed-edge tenet; `docs/design/2026-07-18-skill-self-init-model.md` §2). **Pure-mechanism
plumbing**: no storage, no typed artifact edges (a dispatched task's deliverable is ephemeral and
consumed inline by whoever called `/delegate`), and no registration -- it is ambient doctrine/routing
with no captured items to surface, the exact thing registration exists for. All three edges are a
*stated* empty (model §2.3), not an omission.

<!-- edges:delegate -->
- produces: — (a dispatch's deliverable is consumed inline by the caller, not a typed artifact)
- handoff: — (none; delegate routes a task, it doesn't terminate a workflow expecting a landing step)
- consumes: — (none; it reads the caller's task description, not another skill's typed output)
<!-- /edges:delegate -->
