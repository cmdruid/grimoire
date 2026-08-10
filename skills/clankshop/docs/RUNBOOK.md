# The clankshop runbook — how the system runs

The methodology narrative for the clankshop pack: how a change flows through a deployed
installation, when to assume which role, and how the system improves itself. This document is
**pack-level and universal** — it names no particular project's gate, stack, or lanes.

**Three documents, three altitudes.** The *runbook* (this doc) is the universal methodology; the
*doctrine* (`doctrine/`) is the seed content — the default rules, lanes, and formats `setup`
projects; the *handbook* (a project's `.handbook/`) is per-project and specific — the projected,
locally-grown copy that is the source of project truth. When they seem to disagree, the handbook
governs that project; the improvement loop is how a better local rule flows back upstream.

## The flow of a change, end to end

```
signal → capture → route → lane → gate → land → done log
```

1. **Capture.** Every byproduct of work — a follow-up, a defect, a concern, a durable fact, a
   dev-experience observation — lands in the trackers by kind, one ID each
   (`.handbook/rules/RECORDS.md`). Capture is uniform and cheap: one line now beats a lost
   thought later.
2. **Route.** The front door's compiled table dispatches the common intents at tier 0. The
   ambiguous case walks `.handbook/rules/ROUTING.md` — the classification judgment: known gotcha
   or real bug, patch or feature, spike or build. The unsure row goes to the operations role
   (`/foreman`), whose whole job at this moment is to classify and dispatch.
3. **Lane.** Each lane file (`.handbook/workflows/`) is complete: purpose, policy citations, the
   seams where a role takes over, and a by-hand walk that works with **no skills installed** —
   the skills accelerate the lanes, they are never prerequisites.
4. **Gate.** The project's one gate command must be green before any commit lands — whoever
   authored the change, wherever it was built.
5. **Land.** Work completes when it is **landed on the trunk**, not when it compiles. Small
   shared-state edits (captures, promotions) are trunk-side scoped commits even while feature
   work rides a branch.
6. **Done log.** Completion appends one line to `.records/done/log.md` — the auditable trail from
   item to commits. The books stay closed in one motion, not as an afterthought.

## When to assume which role

A role is an expertise an agent **inherits**: when the moment calls for it, load the skill and
*be* that role for the session. The front door and the lane files say when — the role moments,
not a schedule:

- **A design decision at stake** — a contract, a tenet, a system boundary → work it as the
  architect before planning against it.
- **Routing or rulebook judgment** — where does this change start; does this rule belong in the
  rulebook → the operations role (foreman).
- **Verification judgment** — is this failure a defect or a flaky gate; does this change need a
  deeper pass; is the playbook missing a chapter → the verification role (guardian).
- **A code-quality sweep** → the auditor, scoring against the project rubric.
- **A docs-quality pass** — conformance, citations, budgets, navigability → the docs role
  (chiropractor).
- **What does this signal mean for the system** → the calibrator (the improvement loop, below).

The **instruments** are different: the records instrument (backlog) and the diagnostic instrument
(debugger) are procedures anyone operates — a role mid-work, a pipeline, the human — and the
judgment belongs to the operator. The **pipelines** (feature, workstream) are the work processes
the system supports: one turns an idea into gate-green code, the other encapsulates
shipping. The **helpers** (delegate, mailbox, handoff) are portable plumbing, useful on any repo.

## The escalation story

The default path never waits on a human: tracker → agent → done log. Escalation exists for the
moments an agent would otherwise have to *stand in* for the human — the promotion bar's four
triggers: a **decision** only they can make, a **sign-off** on something risky or outward-facing,
an **ambiguity** where guessing risks real waste, an **access** need (accounts, credentials,
purchases). Big-but-clear work is not a trigger; when uncertain, favor motion if the action is
cheaply reversible.

Crossing the bar turns the entry into a **ticket** (`/backlog promote` — or a direct ticket when
the escalation *is* the capture): the origin entry pauses in place, visible but excluded from
every drain, and the question lands in `.records/tickets/` with the agent's **recommended
answer** — the human reacts, they don't compose. Where the project has a remote issue system, the
ticket projects into it as the **mirror** — UI and notifications for the human; the in-repo file
stays canonical, always. The **answer** (a human comment that gives the agent what it needs)
moves the ticket to answered; **resume** is the consumer that owns the origin work acting on it —
the ticket resolves, the origin un-pauses and advances, the done log gets its line.

## The improvement loop

The system grows from its own exhaust. The **calibrator** runs the loop:

1. **Intake** — one pass over the declared sources: the dev-experience channel, process-flavored
   issues, system-flavored notes, and the quality findings (audit findings past the
   system-improvement bar, doc-drift reports, investigation lessons). Paused entries are always
   skipped; no other role scans these sources.
2. **Dispatch** — each accepted signal becomes an ID'd improvement item routed to the **owning
   role** as ordinary work: a trap to the rulebook, a spec correction to the design chapter, a
   playbook gap to testing, a schema fix to the records projection. The calibrator edits no
   chapter — tend-don't-own holds all the way down.
3. **Uptake and closure** — the calibrator verifies the edit landed (chapter changed,
   check-green), completes the item as `drained`, and stamps the source so nothing is claimed
   twice or never cleared.
4. **Upstream** — a locally-proven rule can flow back: the calibrator compares it against the
   current doctrine, assembles the evidence, and **prepares** the contribution — a human
   lands it in doctrine vNext. Other projects' calibrators then see the update as an *offer*
   (never a silent overwrite; a local edit or deletion is respected as divergence, a state, not
   an error).

Meanwhile the instrument keeps its own house: curation (dedupe, rank, sharpen, ID stamping) is
the records instrument's upkeep — what a signal *means* is the calibrator's question, how the
lists are kept is not.

## Ship continuously, delegate, survive a reset

- **Ship continuously.** A workstream drives a long-lived stream in its own worktree: build per
  queue item (the feature pipeline to gate-green), land per the stream's mode, sweep the debrief,
  advance. The worktree and hand-off persist across ships; teardown is rare.
- **Delegate without polluting context.** The delegate helper decides delegate-or-not and picks
  the route; the mailbox helper carries the result back worktree-safe. In a shared worktree the
  main session stays the sole writer of the tree.
- **Survive a reset.** The handoff helper snapshots the root session and resumes it; workstreams
  reuse the same discipline per stream. Durable state lives in the records, never in a session.

## Which audit?

Three sweeps, one seam rule — every fact has exactly one verdict owner:

- **The documents** → the docs-quality role: entry conformance, citation resolution, budgets,
  link health, read-cost, front-door affordance.
- **The code** → the auditor: rubric-scored quality findings.
- **The assembly** → `/clankshop check`: the installation block, every stamped projection against
  its named input, chapter presence, cross-store integrity, the mirror's drift facts, the pack
  lock against the installed set.

The debugger is not a fourth entry: audits are sweeps that score or survey; the debugger is
symptom-triggered investigation of one reported failure, ending in a root cause.

## Install and onboard

From the library clone: `./install.sh --pack clankshop` (transactional against the pack lock —
never a partial pack). Then, in the target project: **`/clankshop setup`** on a greenfield
project, or **`/clankshop migrate`** where anything already exists — both end with the
installation block stamped, the handbook projected, and `check` green.
