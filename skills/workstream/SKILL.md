---
name: workstream
description: "Drive a long-lived development stream as a continuous loop, shipping features off the stream's queue — in its own git worktree (default) or in-place in the main checkout (`create --in-place`, for repos where worktrees are impractical). `create <name> [<src>]` seeds the stream and enters the loop (`delegate` or `manual` execution mode); `save`/`load` checkpoint and re-enter across session resets; `sync` pulls the trunk in; `ship` lands accumulated work per the stream's landing mode (local merge / push / PR) and advances the queue; `park`/`unpark` hand the shared tree back and forth (in-place streams); `recycle` starts a fresh unit in the same slot; `close` tears the stream down; `status` lists active streams. Use when the user runs `/workstream ...`, or asks to start/resume/continuously build a stream of features."
---

# workstream

Encodes a development pipeline (the host's `ROUTING -> PLANNING -> WORKTREES` docs, where
present) as an explicit, re-entrant loop. A workstream = one isolated slot — its own worktree
(default) or the main checkout held in place — bound to one stream of work for its whole life,
shipping features off the stream's queue. **The queue's source is pluggable** —
a standalone plan, a section of an ongoing roadmap, an inline brief, or defined ad hoc in the first
iteration. **Two archetypes follow from the source:** a *plan/roadmap* stream has a **linear queue**
and `ship` advances item->item; a *template/intake* stream (a `kind: workstream-template` source —
e.g. debug, design) has **no predefined queue** — each unit is independent, so `ship` lands a unit
and **`recycle`** clears the instance back to a blank unit from the template. The hand-off is the
loop's save-state; a session reset is your version-control operation on context (save then reset =
checkpoint; reset without save = rollback). The steady state is build-then-land — but **how often it
lands is the stream's `Ship cadence`** (`flow.md`), because `ship` is expensive; teardown (`close`)
is rare — only when the stream's queue is exhausted or the stream is paused.

This `SKILL.md` is a **thin router**: it holds the scope rule, the dispatch table, and the
discipline every verb shares. Each verb's procedure lives in `verbs/<verb>.md`, and the loop's
orchestration doctrine (execution modes, autonomy/seam rules, confident launch, ship cadence, reset
ritual, event-driven debrief) lives in **`flow.md`** — both **read on demand**. When a verb is
selected, **read its file and follow it**; do not reconstruct a procedure from memory.

## Scope — one session drives exactly one workstream

A `/workstream` session **drives one** stream for its life. The invariant is about *driving*, not
merely *touching*: **an agent operating inside a workstream NEVER drives or `load`s another
workstream** (here *another* = a *different* stream; re-entering the SAME stream after a context reset
is the normal resume, not a violation). Driving two streams from one context splits the loop — that
is the harm this rule exists to prevent. Two consequences follow, keyed on *what you'd actually do*:

- **You never spawn a stream for your own work.** When in-stream work surfaces something that *would
  be* its own stream — a tangent, a debug bug, the next roadmap track — you **capture or surface it;
  you never stand it up to drive**: a **defect** → `/backlog bug`; **feature work** → `/backlog task` (`.records/tasks.md`);
  the **next track / a new stream** → name it at a seam and hand it to the human/coordinator. Plain
  `create` *enters the loop*, so standing up a stream to drive is a **coordinator-only**,
  trunk-resident action — never yours. Needing isolation for a sub-task of your *own* feature is a
  `/delegate` worktree, not a second stream.
- **You MAY *seed* a stream for someone else to drive — only on an explicit human request.** When the
  human explicitly asks you to stand up a *different* stream for **them** to drive in a **separate
  session**, you may run **`create --seed-only`** (`verbs/create.md`): it runs create's mechanics,
  hands back the `/workstream load` command, and **STOPS before entering the loop**. You seed; you
  never drive it. This is the *only* way a second stream originates from inside a workstream; it fires
  **only** on that explicit, in-band request — never inferred, never for your own tangent, and never
  in an unattended/autonomous loop (no human is present to ask) — and it never touches your own loop.

The `create`/`load` guards (in their verb files) enforce this mechanically.

A stream's **isolation** (Coordinates `isolation: worktree | in-place`, chosen at `create`) does not
change scope: one session still drives one stream. An **in-place** stream additionally holds the one
shared tree (custody — `verbs/park.md`), so at most one exists per repo, enforced at `create`.

## Two layers: verbs are primitives, the flow orchestrates them

- **Verbs** are *primitives* — each does exactly one intrinsic job and is invokable by **either
  party at any time** (`/workstream sync` by hand works identically to the agent calling it
  mid-flow) — with one scope limit: an agent already inside a workstream must not invoke plain
  `create` (create-and-drive) nor `load` a *different* stream; it may only run `create --seed-only`,
  and only on an explicit human request to stand a stream up for a separate session (see *Scope*).
- **The flow** (`flow.md`) is the agent's orchestration — it calls verbs at the loop's seams and
  sequences saves/debriefs around the one event that matters, the **context reset**. Read it at
  every loop entry (`create` / `load` / `recycle`).

**No verb auto-saves** (one exception: `park` embeds a save — its custody hand-over is a context-loss
boundary, `verbs/park.md`). A save otherwise belongs to the flow's reset ritual, not to `sync` or
`ship`. A manual verb invocation runs its own procedure and then rejoins the flow at the next seam.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Also read | Does | Runs |
|---|---|---|---|---|
| `create <stream> [<src>] [--in-place]` | `verbs/create.md` | `flow.md` | seed worktree or in-place branch + hand-off, enter the loop (`--seed-only`: seed + hand back a `load` command, no loop) | root checkout (`--seed-only`: also from a workstream) |
| `load <stream>` | `verbs/load.md` | `flow.md` | re-enter an existing stream after a reset | worktree |
| `save` | `verbs/save.md` | — | checkpoint the hand-off in place | worktree |
| `sync` | `verbs/sync.md` | — | pull the trunk's movement into the worktree | worktree |
| `park` / `unpark` | `verbs/park.md` | — | hand the shared tree back to the trunk / take it back (in-place only) | root (in-place) |
| `ship` | `verbs/ship.md` | `verbs/sync.md` | land accumulated feature(s), advance the queue | worktree |
| `recycle [<template>]` | `verbs/recycle.md` | `flow.md`, `verbs/create.md` | fresh unit in the same worktree | worktree |
| `close` | `verbs/close.md` | `verbs/ship.md` (if WIP ships) | tear the stream down | root |
| `status` | `verbs/status.md` | — | list active workstreams (read-only) | anywhere |

## Unstamped conduct

Every workstream verb is **read-only on an unstamped root**: emit `unstamped`, point at the
clankshop onramps (the pack face's `setup` / `migrate`), and stop. A stream drives the lanes and
records of a stamped system; workstream is not a pre-stamp writer.

## Discipline (applies to EVERY verb — non-negotiable)

- **cwd-independent.** Every git command uses `git -C <path>`; every file op uses an **absolute**
  path. Never trust a bare `cd` to persist between tool calls ("cd doesn't stick").
  A `cd` is UX-only — it positions the user's prompt, never the agent's correctness.
- **Present worktree-local references as absolute worktree paths.** When you show the user (in chat,
  a summary, a hand-off) a doc/file you created or changed in the worktree, give its **absolute
  worktree path** (`<worktree>/.records/plans/foo.md`), not a bare repo-relative one — a bare path
  resolves against the **root checkout**, where the worktree's unmerged work doesn't exist yet, so the
  link is broken until the stream ships. The same applies to a `file:line` you cite. Note such a doc
  is "on the stream branch until ship" so the reader knows why the root copy isn't there.
- **Resolve paths from Coordinates**, never from cwd. Each workstream's hand-off carries a
  Coordinates block (worktree, root checkout, branch, queue source) written once by `create`.
  Read it; do not guess.
- **The main session is the sole writer of the shared worktree.** A subagent can't hold the worktree's
  cwd, so it must **never edit or commit in the shared tree directly** — a stray edit silently corrupts
  the trunk. Authoring is still delegable **read-only**: a subagent may write a `/mailbox` patch slot
  the main session applies (see the `mailbox` skill), or work in its **own isolated worktree** it merges
  back. Delegate the authoring; never the writing of the shared tree.
- **The live hand-off never merges.** It lives at `.workstreams/<stream>/WORKSTREAM.md`. The
  `.workstreams/` .gitignore hides it from the **main** checkout; `create` ALSO adds it to the
  worktree's own `info/exclude` so it's ignored from **inside** the worktree too. Durable records
  (the feature's `.records/done/` record, plan-archive, roadmap-ledger row, ADR) are committed **on the
  branch** and reach the trunk through the ff-merge — not hand-committed to the root.
- **No remote.** Integrate locally against the workstream's `<target>` (Coordinates
  `integration-target`): `git -C <worktree> rebase <target>` + a by-ref advance of `<target>`
  (`verbs/ship.md` -> *Landing*). Never hardcode `main` — the trunk may be `dev` later.
- **Shared trunk is contended — the root index is a shared resource.** Every stream's trunk commit
  passes through the *one* root index, and `git commit` records the **entire** index — not just what
  you `git add`'d this turn — so a sibling staging concurrently gets swept into your commit (ISSUES
  W1). Two rules: **(1) Don't hand-commit a stream's own records to the root at all** — the feature's
  `.records/done/` record, plan-archive, and roadmap-ledger row commit **on the branch** and reach the trunk
  via the **ff-merge**, the single root mutation (and `--ff-only` fails safe: rejected → re-`sync` +
  retry). **(2) For the few commits that must touch the root** (`/backlog debrief`'s captures — `create`
  seeds its plan **on the branch**, and `close` writes nothing), stage **and** commit in **one** tool call scoped with an
  explicit pathspec: `git -C <root> add <p> && git -C <root> commit -m "…" -- <p>` — the `-- <p>`
  excludes anything that raced into the index. A **rename/move** (`git mv`) stages a delete + an
  add: the commit pathspec must name **both** paths (`git commit -- <old> <new>`) — naming only the
  new path records the add-half and silently strands the staged deletion (`git status --short`
  showing `R` is not proof the commit captured it). Never `git add -A` / `commit -a`; never leave
  staged work in the root index across tool calls.
- **Commits:** imperative subject; no `Co-Authored-By` trailer.
- **Gate before landing code, not for nothing.** Run the host's full gate before a trunk commit
  whose **own diff** is **build-relevant**, defined by one simple rule: **any changed path that does
  not end in `.md`** (so code, build manifests, AND *data* files all count — only pure
  markdown is exempt; a host gate may validate data files, so they are never silently skippable). A
  **markdown-only** change needs only the host's fast doc-linter. Key the decision on *what your
  commits change*, never on *what a sync pulled in* — the full four-branch matrix is
  `verbs/sync.md` step 3 (Landing applies the same one); an **unchanged tree** (a no-op sync) still
  carries the loop's last green gate. `workstream-git.sh gate-facts` computes both axes for you.
- **Auto-compaction is an involuntary reset (Scenario C).** If your context has just been
  compacted/summarized mid-loop, stop and run `flow.md` -> *Scenario C*: re-read the hand-off +
  `flow.md`, reconcile against git and the durable records, then continue without a user
  round-trip if the next action is KNOWN. (`create` registers the host front-door anchor that
  points a compacted session here; a *failed* compaction is a hard session boundary — save if
  possible, reset, `load`.)

### Helper scripts (token-free state analysis — facts, not verdicts)

The skill ships `scripts/workstream-git.sh` (resolve it from **this skill's own base directory**,
never a host path — invoke it by that absolute path so an approval allowlist can match a single
stable entrypoint). Read-only git/worktree inspection printing compact `key=value` facts + evidence
(it never touches the worktree/index/refs; `land-readiness`'s conflict forecast writes loose objects
only). It **never recommends an action** — it reports the variables the verb procedures consume, and
you layer on session state it cannot see (e.g. "I already gated this `<target>` tip this turn").
Subcommands (each consuming verb file names the facts it reads):

- `stream-state <worktree> <branch> <target>` — launch/`load`/`recycle` snapshot (behind/ahead,
  dirty vs drafted-plan, branch/toplevel guards).
- `gate-facts <worktree> <branch> <target>` — the two docs-only axes + changed-file lists for the
  gate-by-what-lands matrix.
- `land-readiness <root> <worktree> <branch> <target>` — ff-safety, root state, and a read-only
  conflict **forecast** (`git merge-tree`; `unknown` on git <2.38).
- `cheatsheet-check <worktree> [<handoff>]` — flags hand-off cheat-sheet pointers that no longer
  resolve at HEAD — in-place streams pass their `.workstreams/<stream>/WORKSTREAM.md` path.
- `inplace-scan <root>` — which streams record in-place isolation (`create --in-place`'s
  one-resident guard).
- `inplace-state <root> <stream> <branch> <target>` — custody facts for an in-place stream
  (held/parked/foreign classification inputs; WIP-bank + dirty state).

The skill also bundles `scripts/worktree-exclude.sh` (idempotent hand-off exclusion, used by
`create`) and `scripts/worktree-teardown.sh` (the `close` mechanics).

## On-demand doctrine

**`flow.md`** — the agent orchestration: execution modes (`delegate`/`manual`), the autonomy rule,
the seam rule, confident launch, ship cadence, the reset ritual, the manual-mode phase loop, and
event-driven debrief. Read it at every loop entry (`create`/`load`/`recycle`); mid-loop verbs assume
it is already in context.
