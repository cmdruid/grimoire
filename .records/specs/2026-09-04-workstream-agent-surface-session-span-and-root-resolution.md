---
doctype: specs
status: draft
schema: architect/spec@1
tags: [workstream, surface]
---

# Workstream agent surface, session span, and root resolution — Spec

This specification refines the agent-facing surface of
→ `specs/2026-09-02-workstream-lean-runtime-and-resumable-shipping.md` and
→ `specs/2026-09-03-workstream-worktree-only-runtime-and-primary-checkout-safety.md`.
Those documents remain authoritative for worktree custody, resumable shipments, landing
authority, primary-checkout safety, and exact teardown. This document replaces their
agent-loop, save/load, recovery-read, cadence-teaching, primary-root resolution, and
`.streams/history.tsv` requirements.

It does not otherwise implement
→ `specs/2026-09-03-workstream-essential-lifecycle-simplification.md`.
It does adopt that draft's deletion of `.streams/history.tsv`. Where that draft removes
cadence from the product, this specification stops teaching it and drops it from the
`read` projection; CONFIG and runbook may still store the field.

## Problem

The helper already owns the durable machine: one registered worktree at
`<root>/.streams/<stream>` on `stream/<stream>`, a single `next_action`, receipts, a
landing lease, and optional setup. The agent-facing skill does not tell the truth of that
machine.

The runtime loop in `skills/workstream/SKILL.md` narrates one continuous
define→build→ship→recycle procedure. The verb table splits those jobs. `next_action` is
declared as the control signal but is not mapped to helper commands. Agents must invent
`unit-complete`, the teardown script, landing argv, and the canonical primary root.
`admit_root` in `skills/workstream/scripts/workstream.sh` refuses a linked worktree, which
is the ordinary driving checkout.

`save` currently patches a one-line `operator-note`. After `/workstream save` → `/clear` →
`/workstream load`, helper facts survive and session synthesis does not: decisions,
remaining work, constraints, and a load-executable next action.

Compaction recovery keys off a top-level `WORKSTREAM.md` and currently forbids reading
that file. There is no durable place in the stream for the intent a later session needs.

## Goal

A session can create, save, clear, load, and continue one stream without inventing helper
commands or losing session intent. Landing happens only through `/workstream ship`. Agents
can review live, in-flight, and landed activity without a Workstream history ledger. The
skill stays named `workstream` and stays at `.streams/`.

## Approach

**Chosen: thin agent surface plus helper facts, with session intent in
`WORKSTREAM.md`.** Keep the helper as fact authority. Rewrite `SKILL.md` around a
`next_action` table. Keep `save` and `load`. Store living save-state in a delimited
session span; the helper installs it via `session-set`. Enrollment is a nonempty span,
not conversation memory; refresh at the three lifecycle moments while enrolled. Accept
any checkout, resolve the primary, and re-exec the installed helper when one exists.
Emit `root=` from `read` / `read-current`. Drop `ship-cadence` from agent-facing prose
and from the `read` projection. Name
`skills/workstream/scripts/worktree-teardown.sh` from `close`. List every live helper
operation in `usage()`. Keep the optional `AGENTS.md` recovery anchor. Delete
`.streams/history.tsv` as a live surface. Teach agents how to review activity from
`status`, `read`, the session span, and Git — not from a second ledger.

Rejected alternatives:

- **Rename to `workspace` / `.spaces/`.** The names are retired in this library and name
  the folder, not the job.
- **Prose-only trim.** Leaves `ROOT` unresolvable from inside a stream and `close`
  unnamed.
- **Helper-emitted shell recipes.** Mixes recommendation into a fact helper.
- **Agent edits `WORKSTREAM.md` directly.** Two writers on a file `reconfig` already
  fingerprints. The helper owns `session-set`.
- **`operator-note` as the only save payload.** Fails `/clear` → `load`.
- **A sibling `CHECKPOINT.md` in the worktree.** Copies the root checkpoint file split.
  `WORKSTREAM.md` is already ignored session scratch and is the compaction discovery
  document.
- **Call the checkpoint skill.** That skill manages only the primary `CHECKPOINT.md` and
  refuses a checkout that has `WORKSTREAM.md`. One session never runs both lifecycles.
- **Keep `.streams/history.tsv` as an agent-readable landed overview.** A shared tracked
  file that every stream appends at prepare does not scale to many concurrent streams:
  it needs a special union-merge, a prepare-time metadata commit, and a repair data-loss
  path, for a document the skill already calls non-authoritative. Agents must not read
  `workstream.tsv`; the helper should emit completed-unit facts on `read`, and landed
  work is `git log` on the target.
- **Drop the `AGENTS.md` anchor.** Compaction does not load the skill. Without an
  always-loaded pointer, a compacted session inside a stream worktree has no instruction
  to stop and recover.

## Mechanism

### Loop

`SKILL.md` keeps job, zero floor, helper selection, custody, dispatch, the table below,
save/load/recovery, and the hook isolation recipe (feature-completion has no verb).
Gate-run recipes and PR/postflight/two-parent law live only in
`skills/workstream/verbs/ship.md`.

```text
next_action      agent does
define-unit      pick one unit; unit-begin STREAM SLUG SUMMARY
build            implement, verify, commit; then unit-complete STREAM
feature-hook     hook-start / hook-complete
accumulate       next unit, or stop until /workstream ship
prepare-ship     verbs/ship.md
land             verbs/ship.md
await-merge      verbs/ship.md
postflight       verbs/ship.md
sync             verbs/sync.md
recycle          verbs/recycle.md
close            verbs/close.md
blocked          stop with the helper's reason
```

`accumulate` never calls `ship-prepare`. `/workstream ship` is the only prepare/land path.
`ship.md` names exact argv, including `land-advance STREAM --authority confirmed` and
`pr-await STREAM --authority confirmed --reference VALUE`.

`load` and compaction may follow the table through **local** helper operations
(`unit-begin`, `unit-complete`, hooks, `accumulate`, `sync`, `ship-prepare`). They must
not invoke `land-advance`, mutate the primary checkout or recorded target, or otherwise
land. If `next_action` is `land` (or any action that would mutate the primary or target),
stop and ask. Bare `/workstream ship` remains the landing authority. `prepare-ship` is
local and may continue after load.

### Session span

`WORKSTREAM.md` holds three kinds of content:

- **Managed spans** — identity, policy, hooks. Contract-hashed. Agents do not edit them.
- **Brief span** — purpose, queue source, orientation, one-line `operator-note`. Compact
  `read` facts. Helper may patch `operator-note`.
- **Session span** — `<!-- workstream:session@1 -->` … `<!-- /workstream:session@1 -->`
  at the end of the file. Agent-owned living save-state. Not contract-hashed. Helper
  copies it through on `reconfig` and repair and never parses the body.

The agent synthesizes the body; the helper is the only writer. `save` and later
refreshes invoke:

```text
workstream.sh CHECKOUT session-set STREAM --body PATH
```

The helper replaces only the session span, atomically, the same way `hook-complete`
takes a closure file. It also sets `operator-note` to the one suggested next action so
the compact `read` envelope stays useful. `cmd_operator_note` is not the save path.
Agents do not edit `WORKSTREAM.md` directly.

Create emits empty session markers. `session=empty` until the first successful
`session-set` with a nonempty body. **Enrollment is `session=present`** (nonempty span),
not a memory of having typed `save`. After `/clear` → `load`, a nonempty span means the
session is still enrolled. While enrolled, refresh (1) before a deliberate reset,
(2) after a completed unit, and (3) on a context-pressure warning. Never save a polluted
context. `session=empty` means no automatic refresh.

Body shape: last-updated date, TL;DR, completed work and decisions, repo/stream
pointers, ordered pending work, one suggested first action. Synthesize; do not
transcribe the chat; elide secrets. No size target beyond "only what a later session
needs to resume."

`load <stream>` admits with `read`, then reads the session span if nonempty. Explicit
load is the claim. Empty span degrades to helper facts; load still succeeds.

Compaction is not `load`. A top-level `WORKSTREAM.md` activates `read-current`, then the
session span. Do not reconstruct identity or policy from managed spans. Durable Git and
helper state win for landed work; the session span wins for last-saved intent. No
top-level runbook means inert; never scan sibling streams.

Workstream-local gloss (do not send the agent to the checkpoint skill):

- **Save** — synthesize, elide secrets, one load-executable next action, rewrite the
  span via `session-set`.
- **Resume** — read the span in full; write nothing.
- **Recovery** — stop; `read-current`; read the span if nonempty; then the authority
  order below.
- **Lifecycle** — the three moments above, only while `session=present`.
- **Authority order** — committed or external systems of record > current files on
  disk > session span > compaction summary.

### Root resolution

The first helper argument is any checkout in the repository (primary or linked
worktree). `admit_root` resolves the canonical primary from Git's worktree list / common
directory and refuses an unrelated repository.

When `.streams/workstream.sh` is installed at that primary, a package-copy invocation
**re-execs** that exact file with the same operation after resolving the primary.
Agents pass the checkout they are in and do not have to know the primary path to find
the binary. Control operations (setup, repair, anchor) still use the package copy so
they can refresh installed bytes.

`read` and `read-current` emit `root=` and `session=present|empty`. They do not emit
`ship-cadence`. `usage()` lists every operation the dispatcher already implements,
including `session-set`, `pr-await`, `pr-verify`, `delivery-classify`, and
`reconcile-partial`.

`close` names `skills/workstream/scripts/worktree-teardown.sh ROOT STREAM [--force]`
after `close-check`.

`ship-cadence` is not taught in `SKILL.md` or the verbs and is not present on the `read`
projection. This cut does not migrate `CONFIG.md` or strip the runbook field.

### Recovery anchor

Keep `/workstream anchor` and the optional `workstream:recovery-anchor@1` extent in the
project front door (default `AGENTS.md`). Setup, repair, create, and load still never
install it. Refresh the bundled body so it matches this recovery rule: current Git top
level only; inert without `WORKSTREAM.md`; stop; `read-current`; then read the session
span if nonempty; do not scan `.streams` or reconstruct managed spans. `templates/compaction-anchor.md`
carries the same text.

### Reviewing activity (no history ledger)

Delete `.streams/history.tsv` from the tracked control surface, setup, repair, README,
validation, shipment preparation, gate relevance, migration output, and tests. Setup
owns exactly `.streams/.gitignore`, `.streams/CONFIG.md`, `.streams/README.md`, and
executable `.streams/workstream.sh`. Missing history is not data loss. Prepare does not
append rows or make a history metadata commit. Sync has no path-specific history merge.
An incumbent tracked `.streams/history.tsv` in a consuming project is left in place:
not validated, not adopted, not deleted.

Agents still must not read `workstream.tsv`. `SKILL.md` (and `status` as needed) teach
this review map:

| Question | Look here |
|---|---|
| Which streams exist, and what is each waiting on? | `status` (`list`) |
| What is this stream's purpose, unit, and `next_action`? | `read` / `read-current` |
| What has this live stream already completed? | completed-unit facts on `read` (slug, summary, commit count). The helper projects them; agents do not open the tracker. |
| What was I doing before `/clear` or a crash? | session span after `save` |
| What has already landed on the target? | `git log` on the integration target (and on `stream/<name>` while that branch exists) |

`read` gains compact completed-unit facts for the current instance: id, slug, summary,
commit count, bounded list (no commit subjects, no hook bodies, no raw tracker rows, no
project-wide event log). `status` stays a bounded view of admitted current streams.
After `close`, Git on the target is the remaining history; Workstream does not replace
it with another ledger, record type, or cache.

### Out of scope

Topology change, in-place streams, park, `.spaces`, splitting the skill, rewriting
landing mechanics, depending on the checkpoint package, a second stream-local
`CHECKPOINT.md`, deleting cadence from CONFIG in this cut, deleting an incumbent
`.streams/history.tsv` from a consuming project, deleting empty-hook receipts, or
collapsing the gate-run classes.

## Verification

Helper and package tests:

- Invoking the package helper from inside `.streams/<stream>` on an initialized tree
  re-execs `$PRIMARY/.streams/workstream.sh`. `read` / `read-current` print `root=` equal
  to the primary. Passing the primary still succeeds. An unrelated directory is refused.
- `usage()` names every dispatcher operation used by `ship.md`, the loop table, and
  `session-set`.
- Create emits empty session markers (`session=empty`). `session-set` replaces only that
  span and sets `operator-note` to the next action. Direct edits of `WORKSTREAM.md` are
  not part of the save path. `reconfig` and stream `repair` leave a nonempty session span
  byte-identical. Contract hash is unchanged by `session-set`.
- `read` emits `session=present|empty` and bounded completed-unit facts. It does not emit
  `ship-cadence`.
- `.streams/history.tsv` is absent from setup's write set and from `ship-prepare`. Helper
  and tests have no history-union merge. An incumbent file in a fixture is left in place
  and not validated.
- Existing landing-lease, non-force, and primary-clean admission tests remain green.

Skill-surface checks (prose and behavior, not only shell):

- `SKILL.md` contains the `next_action` table and the review map. `accumulate` never
  documents `ship-prepare`. `close.md` names `worktree-teardown.sh`. `ship.md` names
  exact landing argv. Cadence is not an agent-facing instruction.
- `SKILL.md` glosses Save / Resume / Recovery / Lifecycle / authority order locally and
  does not route to the checkpoint skill.
- After `session-set`, a fresh agent given only `load STREAM` continues from the session
  span's next action. `session=present` still enrolls automatic refreshes. Missing/empty
  span: load admits from `read` and does not auto-refresh.
- If `next_action=land`, load/compaction stop and ask; they do not call `land-advance`.
- Compaction: top-level `WORKSTREAM.md` plus nonempty session span; recovery reads the
  span and does not read `workstream.tsv`.
- `anchor` install/refresh writes the updated recovery body; setup/create/load do not.
