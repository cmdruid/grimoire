---
doctype: specs
status: published
schema: architect/spec@1
tags: [spec, checkpoint]
---

# Checkpoint lifecycle and recovery anchor — Spec

When published, this specification supersedes the lifecycle activation, foreign-occupancy Save,
Resume confirmation, Recovery admission/write-back, closure-verb, and recovery-anchor decisions in
`.records/specs/2026-08-27-single-root-checkpoint.md`. That record remains the authority for the
single managed root file, Git-ignore guards, document identity, transaction safety, Workstream
exclusion, and all hard-cut removals not changed here. Historical design documents remain history.

## Problem

Checkpoint already binds one root `CHECKPOINT.md` to one session with a stable path-and-token
handle, but its lifecycle and recovery surfaces do not yet share one coherent enrollment rule.

The live skill permits a request to "maintain" Checkpoint to schedule a future automatic first
save. That lets project instructions initiate runtime ownership before the user has explicitly
chosen to place the session under Checkpoint. Conversely, after an unrelated session is compacted,
the current recovery overlay treats the absence of a retained handle as a Checkpoint failure and
directs the user to Resume. File presence and an always-loaded anchor can therefore make Checkpoint
visible to a session that never enrolled.

The remaining enrolled-session behavior is unnecessarily interruptive or mutable. Fresh-session
Resume reads and reconciles, then spends a second user turn confirming the custody transfer even
though `/checkpoint resume` already expressed that intent. Recovery may write reconciled state
immediately, risking promotion of a lossy compaction summary into the last trusted save. Automatic
refreshes report a handle today, but the recovery-only anchor does not carry the lifecycle cadence
that makes those refreshes reliable after ordinary context drift.

The desired boundary is explicit enrollment with quiet non-participation outside it: a session must
invoke Save or Resume to enter the lifecycle; once enrolled, maintenance and matching-token Recovery
are automatic and visible; without an exact handle or explicit verb, Checkpoint has no standing.

## Goal

Make `/checkpoint anchor` install one versioned, always-loaded lifecycle-and-recovery contract while
preserving explicit session custody. Only successful explicit Save, explicit Resume, or admitted
matching-token Recovery enrolls a session. Enrolled sessions refresh automatically at the three
Lifecycle moments and report their complete stable handle and next action without requesting a
response. Fresh or compacted sessions without a root-matching handle receive no implicit Checkpoint
behavior. Resume transfers custody in one command, Recovery is read-only, and closure remains
explicit through `/checkpoint close`.

## Approach

**Chosen: explicit enrollment plus a locally complete version-2 anchor.** The stable handle is both
the mutation capability for an enrolled live session and the admission evidence for its compacted
continuation. The anchor projects only the rules that must survive context loss: how enrollment is
established, when an enrolled session refreshes, when Checkpoint is inert, how token-gated Recovery
reconciles, and when a mismatch becomes user-visible. Detailed Save, Resume, overwrite, and Close
procedures remain in their verbs.

The supported anchor format begins with `<!-- checkpoint:recovery-anchor@2 -->`. Only the exact
version-2 block is admitted as current. Other content in the reserved marker family is treated as
an opaque collision, never identified as a known version; the implementation has no legacy state,
version-specific compatibility branch, content import, or migration path. The human-facing heading
becomes `## Checkpoint lifecycle and recovery` because the block now owns both duties.

**Rejected: anchor-driven or scheduled first save.** It would create ownership from project policy
rather than an explicit session decision and force foreign-file semantics onto sessions that never
opted in.

**Rejected: presence-driven prompts or recovery.** `CHECKPOINT.md` is predictable root scratch, not
proof that the current session owns it. An unrelated fresh or compacted session remains silent until
the user invokes a runtime verb or retained context supplies the exact root handle.

**Rejected: silent automatic refreshes.** Repeating the stable handle and next action at meaningful
seams confirms that the refresh succeeded and gives a compaction summarizer repeated opportunities
to preserve the admission evidence. The report is informational and never creates a round trip.

**Rejected: a second Resume confirmation.** The command name already expresses the user's intent to
load and take custody. Concurrency and validity remain protected by the guarded read, fingerprint,
lock, and token-rotation transaction.

**Rejected: Recovery write-back.** The checkpoint is the last trusted synthesis and the compaction
summary is the least authoritative input. Recovery reconstructs the working set in memory; the next
ordinary Lifecycle refresh persists it after continued work establishes a trusted boundary.

## Mechanism

### Definitions and authority

The project anchor is persistent policy; enrollment is session-local runtime custody. Installing or
reading the anchor, observing `CHECKPOINT.md`, knowing its path, or loading the Checkpoint skill does
not enroll a session.

A session becomes enrolled only after one of these completed operations:

1. The user explicitly invokes `/checkpoint save`, creation succeeds, and the helper emits the new
   stable handle.
2. The user explicitly invokes `/checkpoint resume`, guarded read and reconciliation succeed, the
   identity-only claim rotates the token, and the helper emits the replacement handle.
3. A compacted session presents exactly one complete stable handle for this root and guarded
   Recovery admission returns `token_match=true`.

The stable handle remains exactly:

```text
CHECKPOINT — file: <absolute-root-path>/CHECKPOINT.md — token: <32-lowercase-hex>
```

An unscoped token, a path without a token, another root's handle, or file presence is not enrollment
evidence. Reconciliation authority remains:

```text
committed or external systems of record
  > current files on disk
  > checkpoint
  > compaction summary
```

### Save and foreign occupancy

There is no automatic first save. A request merely to maintain Checkpoint does not schedule one.
Only explicit `/checkpoint save` may create the first file and token. Creation retains all existing
root, Workstream, ignore, shape, lock, and atomic-publication guards.

An enrolled refresh requires the exact current handle and preserves its token. A presented handle
whose token or identity no longer matches stops without reading or overwriting the body and reports
the mismatch.

When explicit Save finds a valid managed checkpoint but the current session has no matching handle,
it stops, tells the user that another checkpoint occupies the singleton target, and offers to
overwrite it. Confirmation authorizes one guarded atomic replacement at that fixed target with the
current session's synthesized body and a new token. The replacement keeps no backup and creates no
second checkpoint. The operation re-runs ordinary target and mutation guards; an unsafe, malformed,
tracked, symlinked, or non-regular obstruction refuses and does not receive the overwrite offer.

### Enrolled lifecycle

After enrollment, automatic refreshes occur only at the three numbered Lifecycle moments:

1. before a deliberate healthy reset;
2. after a human-visible work-unit completion; and
3. on a context-pressure warning, followed by a reset recommendation.

A work-unit remains an expensive-to-reconstruct milestone, not a file edit, review pass, routine
reply, or status message. A polluted context resets without saving, deliberately retaining the last
trusted checkpoint. Workstream custody continues to refuse the root lifecycle.

Every successful automatic refresh reports the complete stable handle and the checkpoint's single
recorded next action. The report requests no response. If current context has no complete handle,
Checkpoint performs no automatic refresh. If it presents a complete root handle and guarded matching
fails, Checkpoint stops and reports the ownership mismatch.

Enrollment has no completion heuristic. Checkpoint never decides that the session is finished,
describes the checkpoint as ready to close, suggests closure, or synthesizes a closure-oriented next
action. Automatic refresh continues at the three Lifecycle moments until the user explicitly invokes
`/checkpoint close`.

`/checkpoint close` is argument-free and is the only closure verb. The former `/checkpoint done`
verb is removed as a hard cut with no alias or compatibility routing. Close retains the existing
owned-handle and durable-trail gates, including confirmation before abandoning dirty or unlanded
work, then transactionally deletes the exact owned root file and reports its path.

The exported Lifecycle discipline changes from automatic first-save-early wording to an owner-neutral
contract: an owner defines its explicit enrollment or creation event; only afterward do the three
numbered refresh moments apply. The ordinals remain stable for Workstream, whose explicit stream
creation already establishes its save-state. The discipline no longer characterizes landed state as
a forgotten close or infers a closure transition from durable facts. An owner's save-state remains
active until that owner's explicit close procedure runs.

### Resume

`/checkpoint resume` remains explicit and argument-free. Invocation itself authorizes both the
guarded full read and, after reconciliation, the identity-only custody claim; there is no second
confirmation turn.

The helper validates the exact ignored, untracked, regular non-symlink root file before disclosure,
emits its token and opaque fingerprint with the body, and later requires the same fingerprint and
token while rotating the token under the mutation lock. A concurrent change still refuses and
requires Resume to restart. After a successful claim, Resume reports the new stable handle and
reconciled next action, then continues without a round trip when the action is unambiguous. Genuine
ambiguity is asked after custody is safe. Already-landed work is reported after the claim and remains
enrolled until the user explicitly invokes Close. Resume does not infer or suggest closure from the
landed state.

The exported Resume discipline remains a read-only primitive for borrowers. Checkpoint's explicit
invocation-as-claim rule stays in Checkpoint's Resume overlay rather than imposing token or custody
semantics on Workstream.

### Automatic Recovery

Checkpoint considers Recovery only when compacted context contains exactly one complete stable
handle whose path equals this root's absolute `CHECKPOINT.md`.

- With no exact-root handle and no explicit runtime verb, Checkpoint does nothing: it does not inspect
  the file, mention Checkpoint, ask the user to Resume, gather checkpoint-directed facts, or override
  the harness's ordinary continuation behavior.
- With one exact-root handle, the package helper performs the existing single-read guarded admission.
  A match emits the full body exactly once. Recovery reconciles against bounded durable facts using
  the authority order, preserves the token, reports the unchanged handle and reconciled next action,
  and continues without a user round trip when the action is unambiguous.
- Once a root handle makes the session Checkpoint-affiliated, a token, title, file-shape, or guarded
  identity mismatch stops without body disclosure and tells the user Recovery failed. The response
  may point to explicit Resume; it never silently adopts or overwrites the file.

Recovery never writes the checkpoint. Summary-only information remains in working context, and even
a durable-state reconciliation waits for the next normal Lifecycle refresh before persistence. The
exported Recovery discipline adopts the same read-only rule; its write-back step is removed. Landed
work is reported as a durable fact but does not route to, suggest, or invoke the owner's close
procedure. This is compatible with Workstream's existing explicit `do not refresh this file from the
merge` overlay.

### Version-2 lifecycle and recovery anchor

The package-only template becomes exactly:

```markdown
<!-- checkpoint:recovery-anchor@2 -->
## Checkpoint lifecycle and recovery

- This anchor and the presence of `CHECKPOINT.md` never enroll a session. Enrollment begins only
  through successful explicit `/checkpoint save`, `/checkpoint resume`, or token-matched Recovery.
- An enrolled session refreshes after a human-visible work unit, before a healthy reset, and on a
  context-pressure warning. Each refresh reports the complete handle and next action without
  requesting a response. Never save a polluted context. The lifecycle never infers that work is
  complete or suggests closure. Enrollment ends only through explicit `/checkpoint close`.
- Absent an explicit Checkpoint verb, a fresh or compacted session without a complete stable handle
  for this root receives no Checkpoint behavior and never reads the file.
- After compaction with exactly one complete handle for this root, use Checkpoint's guarded reader.
  On a match, read in full and reconcile using: committed or external systems of record, then current
  files, then checkpoint, then compaction summary. Report the unchanged handle and next action,
  write nothing, and continue when unambiguous.
- On a token or identity mismatch, stop without disclosing checkpoint content and tell the user
  Recovery failed.
<!-- /checkpoint:recovery-anchor -->
```

`/checkpoint anchor` classifies a human-selected always-loaded `AGENTS.md` before proposing any
edit. The reserved begin family is one complete line shaped
`<!-- checkpoint:recovery-anchor@<opaque-suffix> -->`; the only current begin marker is the exact
`<!-- checkpoint:recovery-anchor@2 -->` line. The reserved end marker is the exact
`<!-- /checkpoint:recovery-anchor -->` line. A reserved heading collision is any structural H2
whose text begins with `Checkpoint`.

The classifier has four normal results:

- `current` — exactly one ordered current-begin/end pair whose complete bounded block is
  byte-identical to the package template, with no additional reserved marker or heading outside it;
- `drifted-current` — exactly one ordered current-begin/end pair whose complete bounded block
  differs from the package template, with no additional reserved marker or heading outside it;
- `conflict` — exactly one ordered begin-family/end pair whose begin marker is not the current begin
  marker, with no additional reserved marker or heading outside it; and
- `absent` — no reserved begin-family marker, reserved end marker, or reserved heading collision.

Conflict detection is a generic reserved-namespace collision guard, not legacy recognition or
migration. It emits the ordered marker pair as one exact replacement extent but never reports or
interprets the opaque suffix, parses the bounded content, translates state, or selects behavior by
version. An unmarked reserved heading collision, an unmatched counterpart, or duplicate, inverted,
nested, mixed, or overlapping reserved content is an error, not `conflict`; Anchor refuses without
an extent or replacement offer.

For `drifted-current` or `conflict`, Anchor shows the selected `AGENTS.md` path, the exact bounded
current content that would be removed, and the exact version-2 block that would replace it, then
offers the replacement. Approval authorizes replacement of only that extent if the selected file
still contains the exact shown bytes at that extent; otherwise Anchor reclassifies and re-proposes
instead of editing. Replacement preserves every byte before and after the extent. Conflict
replacement is wholesale: no content from the conflicting unit is read into or carried forward by
the new block. For `absent`, Anchor shows the exact version-2 block and insertion target before
offering to append it. Anchor never reads a checkpoint, installs itself, edits ignore rules, or
commits the front-door change.

Ordinary Save reports a missing, drifted, or conflicting anchor and points to `/checkpoint anchor`;
it does not modify project instructions or offer a compatibility or migration route itself.

### Live surfaces

The implementation reconciles these owned surfaces:

- `skills/checkpoint/SKILL.md`: routing descriptions, ownership, Recovery admission, and explicit
  enrollment/lifecycle contract.
- `skills/checkpoint/references/disciplines.md`: owner-defined enrollment, unchanged Lifecycle
  ordinals, completion-neutral persistence, one-command Checkpoint-compatible Resume wording, and
  read-only Recovery without landed-to-close routing.
- `skills/checkpoint/verbs/{save,resume,close,anchor}.md`: explicit enrollment, foreign overwrite
  offer, one-command claim, explicit closure, and version-2 anchor procedure.
- `skills/checkpoint/templates/recovery-anchor.md`: the exact version-2 block above.
- `skills/checkpoint/scripts/{checkpoint-file.sh,anchor-status.sh}`: the minimal guarded mutation and
  classification support required by the public behavior.
- `skills/checkpoint/scripts/tests/`: fixture and document-contract coverage.
- `README.md`: the public Checkpoint verb roster changes from `done` to `close`.

Workstream's locally complete Lifecycle and Recovery glosses are checked for compatibility but do
not acquire Checkpoint's root token, anchor, enrollment, overwrite, or Resume-claim rules. Historical
dated documents and grimoire's real root `AGENTS.md` remain untouched.

## Verification

All mutation and anchor tests run against throwaway project fixtures. Verification never creates a
root `CHECKPOINT.md`, installs an anchor into grimoire's real `AGENTS.md`, or edits a user-owned
front-door block.

### Enrollment and lifecycle scenarios

- Prove anchor installation, file presence, skill loading, ordinary work, and a maintain-style request
  do not create a checkpoint or enroll a session. Explicit Save does both and reports the handle and
  next action.
- Prove enrolled automatic refreshes occur only at the three Lifecycle moments, preserve the token,
  report the handle and next action without asking, and do not fire for routine replies, missing
  handles, polluted context, or Workstream custody.
- Prove a presented root handle that no longer matches stops and reports the mismatch without body
  disclosure.
- Prove apparent task completion neither deletes the file nor describes it as ready to close,
  suggests closure, or records an inferred closure-oriented next action. Explicit Close remains the
  sole closure path, and its unlanded-work confirmation gate remains intact.
- Prove `/checkpoint done` is no longer recognized and has no alias or compatibility route.
- Prove the exported Lifecycle and Recovery disciplines neither characterize landed work as a
  forgotten close nor route, suggest, or invoke an owner's close procedure.

### Save and Resume scenarios

- Prove explicit Save creates an absent target without clobber and preserves the current token on an
  owned refresh.
- Prove explicit Save against a valid foreign checkpoint stops and offers overwrite; rejection leaves
  it byte-identical; confirmation atomically replaces it with the current session body and a distinct
  token; unsafe or malformed obstructions refuse without the offer.
- Prove one `/checkpoint resume` invocation performs the validated read, reconciliation, fingerprinted
  claim, token rotation, handle report, and unambiguous continuation without a second confirmation.
  A concurrent change still refuses; an ambiguous continuation asks only after the new handle exists.

### Recovery and anchor scenarios

- Prove a compacted fixture with no exact-root handle causes no Checkpoint file read, user prompt,
  checkpoint-directed fact gathering, or checkpoint write. A wrong-root handle has the same result.
- Prove a matching handle admits exactly one full read, preserves the token, applies the documented
  authority order, reports the handle and next action, performs no write, and continues when known.
- Prove a root handle with a wrong token or changed identity emits no body sentinel, writes nothing,
  stops, and reports Recovery failure.
- Prove the anchor classifier reports the exact version-2 block `current`, one bounded modified
  version-2 block `drifted-current`, a front door with no reserved marker or Checkpoint H2 `absent`,
  and one ordered non-v2 begin-family/end pair only as generic `conflict`. Both replaceable results
  show the selected `AGENTS.md` path, exact current bytes, and exact version-2 replacement before
  approval; replacement changes only that extent and refuses or re-proposes if the shown bytes
  changed. An unmarked Checkpoint H2, unmatched counterpart, or duplicate, inverted, nested, mixed,
  or overlapping reserved content refuses without an extent or replacement offer.
- Prove no legacy-specific classifier state, version-specific compatibility branch, content-import
  path, migration path, or compatibility alias remains. Non-v2 fixtures may exercise only the
  generic collision-and-replacement contract; their former format is never identified or migrated.

Every guard or absence assertion receives a red-proof in the owning fixture: temporarily disable the
guarded branch or plant a body sentinel or mutation that the assertion must catch, demonstrate that
the test fails, then restore the fixture before the green run. Documentation-contract assertions
likewise receive one controlled broken copy rather than relying on a grep that was never shown
capable of failing.

Run the focused and library gates:

```text
skills/checkpoint/scripts/tests/run.sh
skills/workstream/scripts/tests/run.sh
skills/skill-builder/scripts/skills-lint.sh
```

Architect and Inspector ground-checks must resolve every live path cited by this specification and
the full review must find no unresolved contradiction with the still-governing portions of
`.records/specs/2026-08-27-single-root-checkpoint.md`.

## Slices

| id | behavior | paths | verify |
|---|---|---|---|
| C1 | Explicit enrollment, automatic post-enrollment Lifecycle, read-only Recovery, one-command Resume, and explicit Close doctrine | `skills/checkpoint/SKILL.md`, `skills/checkpoint/references/disciplines.md`, `skills/checkpoint/verbs/{save,resume,close}.md`, `README.md` | `skills/checkpoint/scripts/tests/skill-doc-test.sh` |
| C2 | Foreign valid-checkpoint overwrite after explicit confirmation | `skills/checkpoint/scripts/checkpoint-file.sh`, `skills/checkpoint/verbs/save.md`, `skills/checkpoint/scripts/tests/checkpoint-file-test.sh` | `skills/checkpoint/scripts/tests/checkpoint-file-test.sh` |
| C3 | Version-2-only lifecycle/recovery anchor, bounded v2 or generic-conflict replacement, and unsafe-collision refusal | `skills/checkpoint/templates/recovery-anchor.md`, `skills/checkpoint/verbs/anchor.md`, `skills/checkpoint/scripts/anchor-status.sh`, `skills/checkpoint/scripts/tests/anchor-test.sh` | `bash skills/checkpoint/scripts/tests/anchor-test.sh` |
| C4 | Cross-skill compatibility and full gate | `skills/workstream/flow.md`, `skills/workstream/templates/workstream-handoff.md`, relevant contract tests | `skills/checkpoint/scripts/tests/run.sh && skills/workstream/scripts/tests/run.sh && skills/skill-builder/scripts/skills-lint.sh` |
