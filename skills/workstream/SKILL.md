---
name: workstream
description: "Drive a long-lived development stream through a guarded, resumable lifecycle. Use for /workstream create, load, save, sync, ship, recycle, close, status, setup, repair, anchor, reconfig, or migrate."
---

# Workstream

Use one registered worktree and branch to build and land a queue of coherent units. Inside one,
`WORKSTREAM.md` is the runbook and `workstream.tsv` is helper-owned state; never read or edit the TSV directly.
Session intent lives in the runbook's `workstream:session@1` span; only `session-set` writes it.

## Scope and zero floor

One session drives exactly one stream. Never load or create a different stream from inside an
active stream. On an explicit human request, you may seed another stream for a separate session,
then stop without entering it. Capture tangents through the host's follow-up lane.

Setup is optional. Pass the checkout you are in as the helper's first argument; it resolves the
canonical primary. When `.streams/workstream.sh` is installed there, a package-copy invocation
re-execs that file for ordinary operations. Control operations (setup, repair, anchor) use the
package helper so they can refresh installed bytes. When the installed helper is absent, use this
package's `scripts/workstream.sh`. Stale, unsafe, or partial installed state points to `repair`.

Resolve stream paths from admitted helper output. Every Git command uses `git -C` and every file
operation uses an absolute path.

## Custody and safety

- Every stream lives at `<root>/.streams/<stream>` on `stream/<stream>`. Ignored `WORKSTREAM.md` and
  `workstream.tsv` never merge. Tracked `.streams` control files may appear in every checkout; only
  `<root>/.streams/workstream.sh` is installed authority.
- Stop on a root, worktree, branch, target, instance, runbook-hash, tracker-schema, worktree-registry,
  symlink, nested-runtime, or interrupted-Git mismatch. Ignore rules are hygiene, not admission.
- The custodial parent is the sole lifecycle writer. Helpers compute and mutate typed facts; you
  decide semantic scope, conflict resolution, gate selection, hook completion, and follow-up.
- Never force a ref. Preparation may commit only on the stream branch. `ship --prepare` never
  changes a target or remote ref. Landing requires the user's current explicit `/workstream ship`
  or one explicit approval bound to the reported instance, shipment, batch, target, and landing mode.
- Every primary-checkout update runs under the repository landing lease. The primary must be on
  the target branch, completely clean including untracked files, and free of interrupted Git
  administration.
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

Use the helper's single `next_action`. Do not reconstruct state from the tracker.

```text
next_action      you do
define-unit      pick one unit; unit-begin STREAM SLUG SUMMARY
build            implement, verify, commit; then unit-complete STREAM
feature-hook     hook-start / hook-complete
accumulate       next unit, or stop until /workstream ship
prepare-ship     verbs/ship.md
land             verbs/ship.md (only after explicit ship; load/compaction stop and ask)
await-merge      verbs/ship.md
postflight       verbs/ship.md (load/compaction stop and ask; mutates the primary)
sync             verbs/sync.md
recycle          verbs/recycle.md
close            verbs/close.md
blocked          stop with the helper's reason
```

`accumulate` never calls `ship-prepare`. `/workstream ship` is the only prepare/land path.

In `manual` mode, make each phase boundary explicit with `phase-set`: `none/define-unit` through
`phase-set STREAM plan plan`, then `phase-set STREAM build build`, and only after completed unit
work with no unresolved hook `phase-set STREAM ship prepare-ship`. Stop for the human at each
emitted phase action. Ordinary lifecycle commands own all later ship phases.

## Save, load, recovery

- **Save** — synthesize (do not transcribe); elide secrets; one load-executable next action.
  `session-set STREAM --body PATH --note ACTION`. Enrollment is `session=present`. While enrolled,
  refresh (1) before a deliberate reset, (2) after a completed unit, (3) on a context-pressure
  warning. Never save a polluted context. `session=empty` means no automatic refresh.
- **Resume / load** — `read`, then if `session=present` read only the session span. Write nothing
  to the span. Explicit load is the claim. Local `next_action` only; if it is `land` or would
  mutate the primary/target, stop and ask.
- **Recovery** — compaction is not load. Top-level `WORKSTREAM.md` → stop → `read-current` → session
  span if nonempty. Do not reconstruct managed spans or read the TSV. No top-level runbook: inert;
  never scan sibling streams.
- **Authority** — committed or external systems of record > current files on disk > session span >
  compaction summary.

## Reviewing activity

| Question | Look here |
|---|---|
| Which streams, and what are they waiting on? | `status` (`list`) |
| This stream's purpose, unit, `next_action` | `read` / `read-current` |
| What this live stream already completed | `completed:` facts on `read` |
| What I was doing before `/clear` or a crash | session span (`session=present`) |
| What already landed | `git log` on the target (and `stream/<name>` while it exists) |

Never read `workstream.tsv`. There is no Workstream history ledger.

## Hooks

Version 1 recognizes only `feature-completion` and `ship-friction`. When the helper returns
`feature-hook` or a friction phase, call `hook-start` with whether the current harness already
exposes native same-context isolation.

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
runbook or tracker, create/load another stream, or outlive the parent. Do not substitute a generic
worker, a shell subprocess, capability discovery, or a parallel dispatcher. If native isolation is
unavailable, use the helper's inline-or-stop result. Once execution starts, failure never falls back inline.
Validate claimed Git/filesystem effects before `hook-complete`.

## Project surfaces

The only tracked control files are `.streams/.gitignore`, `CONFIG.md`, `README.md`, and
`workstream.sh`. Immediate child directories are ignored registered runtime worktrees.
`CONFIG.md` is absent-only project configuration; `reconfig` is the sole adoption path.
An incumbent `.streams/history.tsv` is leftover: do not read, validate, or delete it.

Workstream consumes tracked plans and roadmaps or an inline brief. It creates no Workstream record
store, execution manifest, debrief archive, project template home, or generic activity log.

## Project templates

None. The package-only `templates/streams-config.md`, `templates/streams-readme-block.md`,
`templates/workstream-runbook.md`, and `templates/compaction-anchor.md` document or generate their
named fixed surfaces. `templates/debug.md` and `templates/design.md` are optional intake briefs;
`templates/coordinator.md` is an optional root-session guide. Read any of the latter three only
when the user explicitly selects it.

## Edges

<!-- edges:workstream -->
- produces: — (the stream loop is live state, not a typed record)
- handoff: — (the stream loop is live state, not a cross-skill artifact)
- consumes: plan, roadmap — optional durable queue sources; inline briefs are direct input
<!-- /edges:workstream -->

Done when the selected verb reaches its stated terminal result or stops on one explicit blocker.
