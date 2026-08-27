# `goal` — compile and pursue an immutable runbook

## Create: `goal <owner/stem> <objective>`

1. Require one active, current operation closure and one concrete objective. Run package-local
   `scripts/goal-compile.sh render` to an ephemeral file. It resolves nested procedures in written
   order, retains source pointers, and computes one closure source digest.
2. Preview the complete `foreman/goal@1` record. Explicit human acceptance authorizes publication,
   not a commit or any operation effect. Run `goal-compile.sh publish` only after acceptance.
3. The writer publishes under `<agent-records>/goals/` through the staged records tool when it is
   executable, otherwise by atomic file mode. The body is immutable; later progress belongs only to
   the current runtime owner.
4. Return or invoke the harness goal objective:
   `Pursue the published runbook at <goal-record>. Resume with /foreman goal resume <goal-record>.`
   If no goal feature is available, return that exact ready-to-submit objective without claiming it
   started.

For a root launch, ask the calling session to use ordinary `/checkpoint save` with the goal record,
current runbook step, and `/foreman goal resume <goal-record>` as its one next action.
Foreman never writes `CHECKPOINT.md`. If that capability is unavailable, continue only with the
explicit warning that project-level recovery across a reset is unavailable; do not create
substitute state.

## Resume: `goal resume <goal-record>`

Validate the published schema and recompute the closure source digest. Drift pauses for attended
review. Run `scripts/runtime-context.sh`: for a Checkpoint owner, pass `--checkpoint` with the exact
absolute root file from the current session's already-admitted stable handle; omit it rather than
using file presence as admission. The probe's dual Checkpoint/Workstream custody refuses before
action; otherwise read the one current owner's state. Continue from its recorded step until a
genuine decision, blocker, stop condition, or context boundary. Return completed work, evidence,
current step, and one exact next action for that owner to save through its ordinary procedure.

The goal's Delegated decisions section bounds recommendations that the harness may auto-accept.
Always stop for destructive action, credential selection or acquisition, policy change,
verification waiver, or permission expansion. Runbook instruction never changes tool permission.

## Inspect and close

- `goal status <goal-record>` is read-only: report the immutable contract, source drift, and the
  current state owner's latest progress.
- `goal close <goal-record>` requires a reached stop condition. Ask the current owner to perform its
  ordinary cleanup. When the records tool is available, archive only through its normal `done`
  command; otherwise leave the published record as history. Never add archival or runtime state.

## Optional Workstream launch

Use this path only from a root coordinator that is not already driving a stream.

1. Resolve the intended integration target. For the published goal and every project-local operation
   path in Sources, require `git cat-file -e <target>:<path>` to succeed. An uncommitted file or a
   commit not reachable from that target refuses before stream creation.
2. Call the installed stream driver's public seed-only procedure with the goal record as source.
3. Call its generic prime helper with that hand-off, the exact goal source pointer, one current-unit
   sentence for the whole goal, and literal next action `/foreman goal resume <goal-record>`.
4. Load exactly the same stream just seeded, then invoke that next action from inside the stream.

The whole goal is one queue unit. Inner operation steps update only the runbook progress reported to
the stream's ordinary save procedure; they never advance, ship, recycle, or close the stream queue.
An agent already driving a stream cannot use the coordinator exception and must return a launch
hand-off for a separate session.
