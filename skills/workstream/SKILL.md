---
name: workstream
description: "Drive a long-lived development stream through a guarded, resumable lifecycle. Use for /workstream create, load, save, sync, ship, recycle, close, status, setup, repair, anchor, reconfig, or migrate."
---

# Workstream

Use one persistent branch and checkout to build and land a queue of coherent units. The project
remains free-form outside a stream. Inside one, `WORKSTREAM.md` is the concise runbook and
`workstream.tsv` is helper-owned state; never read or edit the TSV directly.

## Scope and zero floor

One session drives exactly one stream. Never load or create a different stream from inside an
active stream. On an explicit human request, you may seed another stream for a separate session,
then stop without entering it. Capture tangents through the host's follow-up lane.

Setup is optional. When `.streams/workstream.sh` is absent, use this package's
`scripts/workstream.sh` with the canonical primary root. When the installed helper exists, every
ordinary operation must use that exact file; stale, unsafe, or partial installed state points to
`repair`. Control operations use the package helper so they can refresh installed bytes.

Always pass the canonical primary checkout as the helper's first argument. Resolve stream paths
from admitted helper output, never from the current directory. Every Git command uses `git -C` and
every file operation uses an absolute path.

## Custody and safety

- Every stream lives at `<root>/.streams/<stream>` on `stream/<stream>`. Its ignored top-level
  `WORKSTREAM.md` and `workstream.tsv` never merge. Tracked `.streams` control files may appear in
  every checkout; only `<root>/.streams/workstream.sh` is installed authority.
- Stop on a root, worktree, branch, target, instance, runbook-hash, tracker-schema, worktree-registry,
  symlink, nested-runtime, or interrupted-Git mismatch. Ignore rules are hygiene, not admission.
- The custodial parent is the sole lifecycle writer. Helpers compute and mutate typed facts; you
  decide semantic scope, conflict resolution, gate selection, hook completion, and follow-up.
- Never force a ref. Preparation may commit only on the stream branch. `ship --prepare` never
  changes a target or remote ref. Landing requires the user's current explicit invocation or one
  explicit approval bound to the reported instance, shipment, batch, target, and landing mode.
- A `running`, `uncertain`, or rejected external receipt is not failure proof. Inspect durable
  effects and reconcile it; never replay automatically.

## Dispatch

Read only the selected verb file, then follow it. No verb requires another verb file.

| Invocation | Procedure |
|---|---|
| `create <stream> [<source-or-brief>] [policy options]` | `verbs/create.md` |
| `load <stream>` | `verbs/load.md` |
| `save [<operator-note>]` | `verbs/save.md` |
| `sync` | `verbs/sync.md` |
| `ship [--prepare]` | `verbs/ship.md` |
| `recycle [<source>]` | `verbs/recycle.md` |
| `close` | `verbs/close.md` |
| `status` | `verbs/status.md` |
| `setup [<root>]` | `verbs/setup.md` |
| `repair [<stream>]` | `verbs/repair.md` |
| `anchor [status|install|refresh|remove] [<front-door>]` | `verbs/anchor.md` |
| `reconfig [<stream>] [options]` | `verbs/reconfig.md` |
| `migrate` | `verbs/migrate.md` |

## Runtime loop

Use the helper's single `next_action`; don't reconstruct state by reading the tracker. Define a
bounded unit, build and verify it, commit it, complete its unit boundary, and resolve the emitted
feature hook. Accumulate completed units until the runbook cadence or an explicit request reaches
a landing point. Prepare one immutable shipment, select the host's documented gate for what will
land, resolve pre-land friction, obtain authority, land, and finalize. `recycle` starts a fresh
intake only after finalization. `close` is teardown, not a reporting ceremony.

In `manual` mode, make each phase boundary explicit with `phase-set`: move
`none/define-unit` through `phase-set STREAM plan plan`, then `phase-set STREAM build build`, and
only after completed unit work with no unresolved hook use
`phase-set STREAM ship prepare-ship`. Stop for the human at each emitted phase action. The helper
rejects skipped, reversed, or arbitrary phase/action pairs; ordinary lifecycle commands own all
later ship phases.

`save` changes only the bounded operator note when semantic intent must survive a reset or custody
transfer. Git and helper state already record mechanical progress; don't save after every action.
After compaction, follow the project's recovery anchor, admit this stream, call `read`, reconcile
the projection with Git, and continue the one known action. Never inspect sibling runbooks.

## Hooks

Version 1 recognizes only `feature-completion` and `ship-friction`. The helper stores their
compiled snapshot and receipt. When it returns `feature-hook` or a friction phase, call
`hook-start` with whether the current harness already exposes native same-context isolation.

If the helper selects isolation, use only that native full-context fork: pause the parent after the
receipt is `running`, give the fork the one emitted body and custody facts, suppress its reasoning
and tool transcript, and accept only this closure:

```text
status: complete | blocked | uncertain
summary: <single-line summary>
effects: <paths, identifiers, or none>
parent-actions: <actions or none>
```

The fork may perform scoped hook effects but must not invoke Workstream lifecycle verbs, edit the
runbook or tracker, create/load another stream, or outlive the parent. Do not substitute
`/delegate`, `codex exec`, a shell subprocess, a generic worker, capability discovery, or a
parallel dispatcher. If native isolation is unavailable, use the helper's inline-or-stop result.
Once execution starts, failure never falls back inline. Validate claimed Git/filesystem effects
before `hook-complete`.

## Gates and delivery

Select a gate from host instructions. Use only:

- `gate-run --class docs|full --label LABEL -- ARGV...` for an exact direct command.
- `gate-run --class semantic --selector --label LABEL -- ARGV...` for a documented selector.
- `gate-none` only when the helper proves the shipment has no build-relevant own path.

Unknown paths default to the full gate. Only the shipment's validated history rows are exempt from
build relevance. The helper stores digests and a bounded output tail, not commands or transcripts.
Changed inputs invalidate evidence.

For an autonomous landing point, run preparation first and ask once with its readiness envelope.
An explicit bare `ship` authorizes preparation and landing; `ship --prepare` authorizes preparation
only. Local and destination updates are non-force and receipt-backed. A partial delivery retains
the shipment. The two-parent reconciliation exception is legal only when the helper proves exact
divergent destination tips and reports `partial-delivery`; its old candidate must be first parent.

## Project surfaces

The only tracked control files are `.streams/.gitignore`, `CONFIG.md`, `README.md`, `history.tsv`,
and `workstream.sh`. Immediate child directories are ignored runtime worktrees. `CONFIG.md` is
absent-only project configuration; `reconfig` is the sole adoption path. `history.tsv` has one
landed row per unit and is overview, never recovery authority.

Workstream consumes tracked plans and roadmaps or an inline brief. It creates no Workstream record
store, execution manifest, debrief archive, project template home, or generic activity log.

## Project templates

None. Workstream's project control files are fixed owned surfaces, not generic project templates.
The package-only `templates/streams-config.md`, `templates/streams-readme-block.md`,
`templates/workstream-runbook.md`, and `templates/compaction-anchor.md` document or generate their
named fixed surfaces. `templates/debug.md` and `templates/design.md` are optional intake briefs;
`templates/coordinator.md` is an optional root-session guide. Read any of the latter three only
when the user explicitly selects it.

## Edges

<!-- edges:workstream -->
- produces: — (history is Workstream's internal control ledger)
- handoff: — (the stream loop is live state, not a cross-skill artifact)
- consumes: plan, roadmap — optional durable queue sources; inline briefs are direct input
<!-- /edges:workstream -->

Done when the selected verb reaches its stated terminal result or stops on one explicit blocker.
