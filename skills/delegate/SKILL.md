---
name: delegate
description: "Use when work is well-scoped, returns a checkable artifact or conclusion, and does not need your taste to produce — or on explicit `/delegate [task]`. Pick the mechanism, confirm the provider/model once, require the three-part return contract, and apply an optional project byproducts policy. `/delegate setup` creates that policy point absent-only. Keywords: delegate, dispatch, setup, byproducts, model routing."
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
- the **byproducts** (observations outside the requested deliverable) -- **returned compactly**, because
  you can't see the delegate's dead context.

Everything else stays **pass-by-reference**: a path is paid once; pasted content is paid repeatedly.

This skill is a **router**: it owns the decisions (delegate-or-not, mechanism, route gate, return
contract) and the inline + fan-out mechanics, and points at one specialist for deep mechanics
(`mailbox` — the slot protocol; don't re-document it here). It is a **leaf** -- it names delegation
*mechanisms*, never *task
workflows*: a workflow skill may use `/delegate`; `/delegate` never says "use `/architect`".

## When to use

Trigger when work is **well-scoped**, **returns a checkable artifact or conclusion**, and **does not
need your taste to produce** — or on an explicit `/delegate [task]`. With a task, assess and route it;
with none, this is the ambient doctrine. `/delegate setup [<root>]` is the one verb: read and follow
`verbs/setup.md`, then stop without dispatching.

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

## Dispatch-scoped project policy

Before constructing **every** delegate prompt, resolve the project root. Read exactly
`.agents/skilldata/delegate/hooks/byproducts.md` once:

- missing or zero-byte regular file → no overlay;
- non-empty regular file → retain its exact bytes as this dispatch's snapshot;
- directory, unreadable entry, symlink, or read error → surface the problem and do not dispatch.

Do not trim, glob, merge files, or reread on return. When the snapshot is non-empty, append exactly
one block to the prompt:

```text
Project byproducts policy (applies to this dispatch):
---
<exact snapshot>
---
```

The snapshot may add project-specific detection and routing guidance. It cannot redefine the task,
transport, status vocabulary, or mandatory return headings. Interpret returned Byproducts through
the retained snapshot; without one, present them as observations in the calling context.

## The decision tree -- pick the mechanism

A target checkout is **held** when either (a) `<toplevel>/WORKSTREAM.md` exists, or (b) a
`<toplevel>/.streams/*/WORKSTREAM.md` has tab-delimited identity rows with `isolation` equal to
`in-place` and `branch` equal to `git -C <toplevel> branch --show-current`. Codex (or any tree-writing executor)
**must not** write a held tree.

First inventory the dispatch capabilities actually exposed in this session: **native subagent
dispatch**, **model override**, **cwd control**, and **isolated execution**. These are observable
capabilities, not routing permission. Prefer native same-harness dispatch when those capabilities
satisfy the unit's model and isolation needs. A different provider or model still requires the route
confirmation above even when the mechanism can express it.

**Select dispatch before transport.** Dispatch answers who executes and under which isolation;
transport answers how that selected executor returns the result.

```
About to do work →
  Delegable? (well-scoped • returns a conclusion/artifact • you CHECK, don't PRODUCE)
    no  → do it inline
    yes → 1. Select dispatch from native dispatch • model override • cwd control • isolation
              ├─ fitting native route → NATIVE subagent
              ├─ external route required, or sandbox/cwd/output capture is material
              │                       → HEADLESS executor (references/codex.md)
              └─ no fitting route     → INLINE
           Add an ISOLATED worktree when the executor needs a live build loop or held-tree writes.
           For N independent units, repeat this selection and dispatch concurrently.
           2. Select return transport
              ├─ bounded conclusion / ordinary direct result → DIRECT return
              ├─ file-work without target-tree writes         → MAILBOX transport,
              │                                                  using the selected dispatch capability
              └─ owned isolated-worktree changes               → branch diff for parent review
```

- **Native subagent** -- for work the session's native dispatch can isolate with the selected model,
  cwd, and write posture. For read/analysis grunt work that returns information rather than a diff,
  craft a focused task that does **not** inherit your context and ask for a bounded summary. A
  same-harness, same-model route needs no provider/model confirmation.
- **Mailbox slot** -- file-work you want back *without* polluting your context, or *safely when the
  target is held* (the delegate is tree-read-only; only you write the tree). The artifact travels as a
  path you `git apply`. See the **`mailbox`** skill for the protocol; don't re-document it. On a held
  target this is also the path for mechanical coding you do not want in an isolated worktree.
- **Headless executor** -- use `codex exec` only when no fitting native route exists, the confirmed
  route explicitly requires an external process, or its sandbox/cwd/output-capture semantics are
  material. See **`references/codex.md`** for read-only analysis and workspace-writing coding modes.
  A tree-writing executor must never target a held checkout; use Mailbox transport or an owned
  isolated worktree instead.
- **Parallel fan-out** -- 2+ *independent* tasks (different files / subsystems / failures, no shared
  state). One read-only sub-agent per domain, all dispatched **concurrently in a single turn**, each
  with a self-contained prompt (no inherited context, no dependence on a sibling's result) and the
  bounded-summary return contract. You synthesize the results; if two tasks turn out to share
  state, they weren't independent -- run those sequentially instead.
- **Isolated worktree** -- when the delegate needs its own live build/test (red-green) loop, or when
  the target is held and a tree-writing executor must still run. Heaviest (compile/RAM). The walk
  keys on the **target checkout** (`git rev-parse --show-toplevel` of the tree the artifact is for)
  — it works on an unheld clone too. “Held” is only the Codex refuse above.

  1. Slug the unit. Branch is `delegate/<slug>`. If that branch already exists → refuse and ask for
     a new slug. Do not `-B`.
  2. `<abs-path>` default is the sibling `<parent-of-target>/delegate-<slug>`. If that path exists
     or is not writable → ask. Never a path inside the target.
  3. Record **base** = `git -C <target> rev-parse HEAD`. Then
     `git -C <target> worktree add <abs-path> -b delegate/<slug>`.
  4. Dispatch with cwd = `<abs-path>`. The delegate may write and commit **there only**. Any
     executor `-C` is `<abs-path>`.
  5. You review `git -C <abs-path> log` + diff vs **base**, run the gate in that tree, then you
     merge or cherry-pick into **target**. The delegate never merges into the target.
  6. After land: `git -C <target> worktree remove <abs-path>`. If the worktree is dirty → refuse
     remove and surface.

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

Every delegate prompt requires this exact semantic structure; none of the headings is optional:

```markdown
## Deliverable
<the requested artifact or conclusion>

## Status
<DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED>

## Byproducts
- <compact observation outside the deliverable>
```

When there is no applicable observation, the final section is exactly:

```markdown
## Byproducts
- None.
```

The Deliverable is a handle plus one-line summary for a mailbox artifact, or a bounded conclusion
for inline analysis; bulk bytes travel by path. Status describes task fit, not provider health.
Byproducts are compact observations outside the deliverable. They are not permission to expand the
assignment, implement unrelated work, mutate unrelated files, contact external systems, or create a
durable artifact unless the original task required it.

**Route on status, don't just relay it:**
- **DONE** → proceed, but still re-establish trust from evidence (below) -- a self-reported DONE is not
  itself the evidence.
- **DONE_WITH_CONCERNS** → investigate the named doubt yourself before accepting; it is exactly the
  kind of specific, bounded claim worth five minutes of verification.
- **NEEDS_CONTEXT** → re-dispatch with the missing piece filled in rather than guessing or repeating
  the unchanged prompt.
- **BLOCKED** → escalate (bigger model / smaller task) on the first one or two; **three or more BLOCKED
  reports on re-scoped attempts of the same underlying task means the task or the plan itself is
  wrong, not the model** -- stop re-scoping and take it back to whoever owns the plan, the same
  "question the fundamentals, not the Nth attempt" shape used for repeated failed attempts.

Consume the three parts independently: validate or apply Deliverable, use Status for control flow,
and interpret Byproducts through the retained dispatch snapshot. A weak model remains a weak detector;
observation-heavy work is a reason to route up rather than down.

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
Byproducts section. A fallback is also a
signal the confirmed route has gone stale and may need re-confirming -- the same observable fact,
surfaced to whoever owns the route.

## The dispatch seam

Use the capability inventory from the decision tree; do not infer a fixed mechanism from the harness
name. Pass the selected model as the dispatch capability's opaque model value and use its cwd and
isolation controls when the unit requires them. Capability does not waive policy: different-provider
or different-model routes still require confirmation, while same-harness same-model context isolation
does not. If native dispatch cannot satisfy the selected route, use the headless executor only under
the conditions above.

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
- **Delegate edits a held / shared worktree** -- silent corruption (its cwd is often the repo root,
  not the worktree you meant). A held target is mailbox (tree-read-only; it writes only its slot;
  you apply) or an isolated worktree the dispatch owns. Isolated-worktree writes are allowed. You
  remain the sole writer of the **target**.
- **Delegating taste** -- judgment-heavy / ambiguous / architectural work needs your reasoning to
  *produce*, not just to check.

## Quick reference

| Step | Action |
|---|---|
| delegable? | well-scoped • returns a conclusion/artifact • you check, don't produce |
| inventory capabilities | native dispatch / model override / cwd control / isolated execution |
| select dispatch | fitting native route / headless executor / inline; add isolated worktree when required |
| select transport | direct return / Mailbox using the selected dispatch / isolated-worktree branch diff |
| route | compute checkable facts; **confirm the provider/model** with the human (once → session pref) |
| dispatch | self-contained task, no inherited context; on the confirmed model |
| return | exact Deliverable + Status + Byproducts headings; empty Byproducts is `- None.` |
| trust | re-establish from diff / gates / output -- never the self-report, even a DONE one |

## Edges

Delegate is **pure-mechanism plumbing**: no storage, no typed artifact edges (a dispatched task's deliverable is ephemeral and
consumed inline by whoever called `/delegate`), and no registration -- it is ambient doctrine/routing
with no captured items to surface, the exact thing registration exists for.

<!-- edges:delegate -->
- produces: — (a dispatch's deliverable is consumed inline by the caller, not a typed artifact)
- handoff: — (none; delegate routes a task, it doesn't terminate a workflow expecting a landing step)
- consumes: — (none; it reads the caller's task description, not another skill's typed output)
<!-- /edges:delegate -->

## Done when

Mechanism picked; route confirmed or pre-confirmed; return contract received (deliverable +
status + byproducts); trust re-established from evidence; Byproducts interpreted through the dispatch snapshot. If the route
failed: fallback or floor named.
