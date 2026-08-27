---
doctype: specs
status: published
schema: architect/spec@1
tags: [spec, checkpoint]
---

# Single token-bound root checkpoint — Spec

This specification supersedes the singleton ownership, legacy discovery, arbitrary-path, and
pre-write ambiguity decisions in `docs/design/2026-08-13-checkpoint-skill-design.md` and
`docs/design/2026-08-24-checkpoint-next-action-spec.md`. Those dated documents remain historical
records. It also supersedes the root-runtime-state portions of
`.records/specs/2026-08-26-foreman-autonomous-workflow-control-plane.md`; that published record
remains immutable history.

The working tree may contain an implementation attempted before this specification was accepted.
Those bytes are non-authoritative. Implementation must be reconciled against this document only
after review and publication.

## Problem

The main checkout is one mutable filesystem. Multiple sessions operating there do not own separate
untracked files, staged changes, or dirty tracked paths, even if each session has a distinct
checkpoint document. Named checkpoints would make those sessions look independent while their work
remains physically interleaved. Once the tree is dirty, a Workstream cannot reliably determine
which session owns which paths, which changes are safe to carry or ignore, or which session must
clean the integration checkout before shipping.

Checkpoint should therefore express the actual concurrency boundary instead of creating a second
one in metadata. The root checkout supports one active root session. Parallel development belongs
in isolated Workstreams/worktrees, where filesystem and lifecycle custody are explicit.

A root singleton alone is not safe after context loss. Session memory cannot prove ownership after
compaction, and an always-loaded instruction that says “read `CHECKPOINT.md` when present” can cause
an unrelated session to ingest another session's local state. Presence is a lifecycle signal, not
identity. Recovery needs a path-and-token correlation proof retained by the compacted context.

The current skill also carries avoidable surface: an arbitrary-path escape hatch, pre-write
round-trips for name or next-action ambiguity, and legacy discovery. Those features weaken one-root
ownership and make the utility larger for Workstream to borrow from.

## Goal

Make Checkpoint a small, strict utility around exactly one
`<project-root>/CHECKPOINT.md`: one root checkout, one active root session, one living save-state.
Bind that file to its session with an opaque token and require an exact path-and-token handle before
automatic post-compaction loading.

The skill must protect context immediately, refuse foreign ownership, remain self-initializing and
locally Git-ignored, and export its four generic disciplines without imposing Checkpoint's token or
custody mechanism on Workstream.

The change is a hard cut. Named checkpoints, `.checkpoints/`, arbitrary checkpoint paths,
`list`, `rename`, manifests, current-pointer files, legacy save-state discovery, data migration,
compatibility aliases, and dual-read periods do not exist.

## Approach

**Chosen: one root file plus a session-correlation token.** The path supplies a single visible
custody flag for the checkout; the current token distinguishes its owning session from every other
session. A stable handle containing both values is repeated at save/resume/Recovery seams so a
compaction summary can preserve it. Confirmed Resume rotates the token and invalidates every older
handle.

The public lifecycle stays four verbs:

| Invocation | Behavior |
|---|---|
| `save [next: ...]` | immediately create or refresh root `CHECKPOINT.md` |
| `resume` | explicitly load and adopt the root checkpoint in a fresh session |
| `done` | close the active owned checkpoint after its durable-trail gate |
| `anchor` | classify, propose, install, or replace guarded recovery instructions |

**Rejected: named checkpoints in one checkout.** Ignored checkpoint files do not themselves dirty
Git, but the concurrent sessions they authorize still share code changes and untracked work.
Metadata names cannot establish filesystem custody.

**Rejected: preserve the arbitrary-path escape hatch.** A second path is an unmanaged second root
session by another spelling. It has no canonical ignore, lifecycle, recovery, or ownership
boundary.

**Rejected: rely on file presence or path alone after compaction.** Every root session can predict
the singleton path. Only the retained token correlates the compacted context with the file.

**Rejected: automatically load in a fresh session.** A fresh session has no inherited ownership.
Only explicit `resume` plus human confirmation may transfer custody.

**Rejected: delay a save for naming or next-action selection.** There is no name to choose, and an
ambiguous continuation can be recorded as an instruction to ask the user after the state is safe.

**Rejected: `/checkpoint setup`.** Save must establish its local ignore and file lazily with no
installation floor. The recovery anchor is a separate human-approved project-document edit.

## Mechanism

### Root and managed file

Resolve `<project-root>` in this order: a project directory explicitly established by the
conversation; otherwise the current path's Git toplevel; otherwise an unambiguous non-Git project
directory already established in context. Ask before choosing when none is established.

The only managed target is:

```text
<project-root>/CHECKPOINT.md
```

The root must be an existing real directory. The target must be absent or a direct regular
non-symlink file. A path argument, alternate filename, nested target, or second checkpoint is
rejected. `HANDOFF.md`, files under `.checkpoints/`, and every other legacy or ad hoc save-state
are invisible: no verb detects, reports, reads, imports, migrates, or deletes them.

A Workstream-owned session refuses before creating, reading, or modifying the root checkpoint and
points to the stream's own save-state procedure. Checkpoint does not attempt to partition a dirty
root tree among sessions.

### Git-ignore invariant

In a Git repository, every mutation MUST prove the root checkpoint and its fixed sibling temporary
path ignored before writing:

1. Refuse when either path is tracked, including deleted-but-tracked. An ignore rule cannot untrack
   history.
2. Ask Git whether `CHECKPOINT.md` and `CHECKPOINT.md.tmp` at the root are already ignored.
3. For either missing rule, resolve the repository's local exclude file through Git and append the
   root-anchored `/CHECKPOINT.md` or `/CHECKPOINT.md.tmp` exactly once.
4. Re-run both ignore checks and refuse the mutation if either does not pass.
5. Only then publish the checkpoint.

An incumbent committed `.gitignore`, global exclude, or local exclude rule wins and is not
duplicated. Ordinary operation never edits committed `.gitignore`. A non-Git project has no
Git-ignore step.

### Document identity and stable handle

Every valid managed checkpoint begins with these exact lines:

```text
# CHECKPOINT — file: <absolute-root-path>/CHECKPOINT.md
checkpoint-token: <32-lowercase-hex-characters>
```

The 128-bit token is generated on creation, preserved on ordinary refresh, and replaced only by a
confirmed Resume claim. It is a correlation identifier, not a secret or authentication credential.
A tracked or unignored Git path, tokenless file, malformed header, wrong absolute path, symlink, or
non-regular target is an unmanaged obstruction; refuse without reading its body or overwriting it.
There is no tokenless upgrade path.

Checkpoint content follows the existing document structure and Save discipline: elide secrets,
synthesize rather than transcribe, use absolute dates, reconcile shipped claims against the
durable trail, and record one load-executable suggested first action.

At every successful save, resume, and Recovery seam, report exactly:

```text
CHECKPOINT — file: <absolute-path> — token: <token>
```

Ordinary status replies do not repeat the handle.

### Ownership

The root file has one owner.

- Creating it establishes ownership for the creating session.
- Completing explicit Resume—validated read, reported next action, human confirmation, then an
  atomic token-rotation claim—transfers ownership to the fresh session and invalidates older
  handles.
- Completing admitted Recovery and reconciliation restores ownership to the compacted session.
- Merely knowing the root path, observing file presence, or reading project instructions confers no
  ownership.
- Refresh and done require the current context's exact stable handle to match the file.
- A missing, malformed, ambiguous, or mismatched current handle refuses mutation without reading or
  overwriting the body.

When a second root session attempts first-save-early and the valid root checkpoint already exists,
it stops and surfaces the custody conflict. It may explicitly resume that root work or move its own
work into an isolated Workstream; it never creates a second checkpoint.

### Mutation transaction

Create, refresh, Resume claim, and done use one exclusive project-scoped transaction. In Git, its
short-lived lock lives at a path resolved through Git's administrative directory; outside Git it is
`<project-root>/.CHECKPOINT.lock`. Atomic lock contention refuses, and the helper never breaks an
incumbent lock; it reports the path for human inspection rather than guessing that it is stale. An
incumbent temporary path also refuses and is never deleted. The helper removes only the lock and
temporary file it created.

While holding the lock, the helper revalidates the tracked/ignore guards, target shape, and expected
token immediately before mutation. First creation publishes without clobber and refuses if the
target appeared.
Refresh, Resume claim, and done refuse if the file changed or the token no longer matches. Save
builds and validates the complete replacement at the fixed same-filesystem temporary path, then
publishes atomically. A successful operation leaves no Checkpoint runtime artifact in the project
root other than `CHECKPOINT.md`.

### Save

Save is immediate. A first save generates the token and writes root `CHECKPOINT.md`; a refresh
preserves the token and rewrites the whole document. The operation performs the Workstream,
tracked-file, ignore, target-shape, and ownership guards before content publication.

Named next-action intent wins. Otherwise use a KNOWN continuation. At a genuine fork, write one safe
load-executable instruction such as “Ask the user whether to continue with X or Y before modifying
the project,” then report the ambiguity after the checkpoint exists. Disk may veto a false action;
in that case the recorded action is to reconcile the contradiction with the user. Save never waits
for a pre-write next-action round trip.

Checkpoint is activated only when the human asks the session to maintain or save a checkpoint, a
confirmed Resume claim completes, or Recovery is admitted. An anchor request, file presence, or
merely loading the skill does not activate it. After activation, retain the narrow lifecycle:
first-save-early once meaningful work is underway, before a deliberate reset, at a human-visible
work-unit completion, and on a context-pressure warning. Never auto-save during routine replies,
from a polluted context, or in a Workstream-owned session. Every automatic save reports the stable
handle.

### Resume

`resume` has no argument. The explicit user invocation permits a deliberate read without a token
already in context, but the file must still pass a non-disclosing pre-read validator: exact managed
path, untracked and ignored in Git, exact line-1 absolute path, valid line-2 token, regular file, and
no symlink. Only then may the helper emit and the agent load the full body.

Resume reads in full, retains an opaque fingerprint, reconciles against the durable trail, reports
staleness or already-landed work, echoes at most the single suggested first action, and waits for
human confirmation. Before confirmation it is read-only and emits no ownership handle. Confirmation
authorizes an identity-only claim through the mutation transaction: the helper requires the same
fingerprint and token, rotates only the token, and then emits the new stable handle. A changed file
refuses and requires Resume to restart. A later content refresh remains a separate save.
Already-landed work routes to `done` rather than ghost continuation.

An invalid or tokenless root file is reported only as an unmanaged obstruction. Its body is not
loaded, and Checkpoint provides no repair, adoption, or migration verb.

### Done

`done` has no argument and targets only the active owned root checkpoint. First match the current
stable handle, then inspect the durable trail the already-admitted checkpoint describes. Dirty or
unlanded work is surfaced and requires explicit confirmation before deletion. A clean or explicitly
abandoned checkpoint is deleted exactly, and the user is told. A foreign, mismatched, malformed, or
unadmitted file is untouched.

Absence of `CHECKPOINT.md` means no Checkpoint-owned root work is in flight. It does not prove the
working tree clean; Git remains authoritative for filesystem state.

### Automatic Recovery admission

Checkpoint layers an admission gate before the exported Recovery discipline's full-read step. The
overlay belongs only to Checkpoint; borrowers such as Workstream retain their own save-state
identity and custody rules. The shared four disciplines remain token-free.

On detecting a compaction/continuation summary:

1. Stop before task work or repo facts-gathering.
2. Extract exactly one complete stable handle from the compacted context. An unscoped token-looking
   string is not a candidate.
3. Require the handle path to equal this root's absolute `CHECKPOINT.md`.
4. Call the package helper with the explicit root file and complete handle. The helper opens the
   candidate once, buffers it, and emits `token_match=true` plus the full body only when the handle
   path, line-1 path, and line-2 token agree and the target is a regular non-symlink file.
5. Treat successful helper output as Recovery's one full read; never open the file again.
6. Reconcile and continue under the exported Recovery discipline.

No unique candidate, malformed handle, wrong root or path, missing file or token, malformed title,
token mismatch, symlink, non-regular target, or helper failure emits only `token_match=false`.
Refuse without loading checkpoint content, gathering task facts, saving, or continuing recovered
work. Direct the human to explicit `/checkpoint resume`.

For Checkpoint, the admission overlay disables the exported discipline's generic no-file fallback:
without an admitted file, the compacted task does not continue from its summary alone. This
restriction does not alter the generic discipline borrowed by Workstream.

### Recovery anchor

The package carries one package-only, marker-bounded anchor block beginning with
`<!-- checkpoint:recovery-anchor@1 -->`. This first published version states:

- Presence of root `CHECKPOINT.md` never authorizes a read.
- A fresh session does nothing unless the human explicitly invokes `/checkpoint resume`.
- A compacted session may recover only through exactly one retained stable handle and the atomic
  admission helper.
- Every refusal condition forbids loading the body or continuing recovered work.

`anchor` classifies each actual always-loaded front door as exact current, drifted current,
obsolete versioned, obsolete unversioned, absent, duplicate, or malformed. Exact current is a
no-op. Any single well-bounded drifted or obsolete block may be replaced only after showing the
exact old and new bounded content and receiving human approval. Duplicate or malformed boundaries
refuse rather than guessing. An absent block may be appended to the human-selected front door only
with approval.

Ordinary save reports a missing or obsolete anchor and points to `anchor`; it never edits project
instructions. Anchor classification and replacement inspect only front-door instructions, never a
checkpoint or legacy save-state file. No `setup` verb exists.

### Exported disciplines and downstream seams

`skills/checkpoint/references/disciplines.md` remains the generic normative home of Save, Resume,
Lifecycle, and Recovery plus the authority order and anchor-line/context-pressure techniques.
Checkpoint's root path, token, ownership transfer, admission gate, no-file override, and
`/checkpoint anchor` guarantee stay outside that export. Borrowers supply their own custody and
anchor rules through locally complete glosses.

Workstream borrows the named disciplines with locally complete glosses for its own
`WORKSTREAM.md`. It does not borrow Checkpoint's root file, token helper, anchor block, lifecycle
verbs, or ownership rules, and it must remain operable when Checkpoint is not installed.

Current downstream surfaces adopt the one-root-session seam:

- Workstream owns isolated stream sessions and rejects a competing Checkpoint lifecycle inside the
  stream.
- Foreman may use root checkpoint state only after the current session has established Checkpoint
  ownership; it never treats file presence as admission.
- `README.md` and `PACK.md` state that root mutable pursuit uses one root checkpoint while
  parallel pursuit uses isolated Workstreams.
- Historical dated records remain unchanged. Live skill/package/template/test documentation carries
  no operative named-store, arbitrary-path, list, rename, manifest, legacy-data, or fresh-auto-load
  behavior.

## Verification

Verification uses throwaway fixtures and controlled copies; it never creates `CHECKPOINT.md` or a
recovery-anchor block in grimoire's own root. Every new assertion or sweep is proven red before the
implementation is trusted, then its fixture is restored byte-identically.

### Root file and Git guards

- Resolve the conversation-established root, Git toplevel, and unambiguous non-Git root; refuse an
  unestablished root.
- Prove path arguments, alternate names, `.checkpoints/`, nested paths, symlink targets,
  non-regular targets, and second-file attempts refuse.
- Prove incumbent ignores are preserved; missing rules append root-anchored `/CHECKPOINT.md` and
  `/CHECKPOINT.md.tmp` to the resolved local exclude; neither rule hides nested names; recheck gates
  the write; linked-worktree metadata resolves correctly; tracked and deleted-but-tracked targets
  refuse.
- Prove competing first saves yield one no-clobber winner; refresh preserves its 128-bit token;
  lock contention and changed-token mutations refuse; successful and ordinary-failure paths leave
  no temporary file or lock; incumbent temporary files remain untouched.

### Ownership and lifecycle

- Prove a second root session with no matching handle cannot read or overwrite an existing valid
  checkpoint during automatic first-save.
- Prove current-handle refresh succeeds and wrong/missing/ambiguous handles refuse without body
  disclosure. Confirmed Resume rotates the token, invalidates the old handle, and refuses its claim
  if the file changed after the read.
- Prove save writes before reporting genuine next-action ambiguity and records a safe executable
  ask rather than a guessed branch.
- Prove explicit maintain/save intent, confirmed Resume, and admitted Recovery activate Checkpoint;
  anchor use, file presence, and instruction loading do not. Automatic saves occur only at the four
  admitted lifecycle moments after activation.
- Prove Resume is read-only before confirmation, its claim changes only the token,
  malformed/tokenless files disclose no body, stale state is reported, and landed state routes to
  done.
- Prove done requires current ownership, gates dirty or unlanded work, deletes only the root file,
  and leaves foreign or invalid files untouched.
- Prove the Workstream guard refuses before ignore or checkpoint mutation.

### Recovery and anchor

- Plant unique secret body text and prove exact handle path + title path + token admits it once.
- Prove wrong path, alternate root, root path without token, token outside line 2, wrong token,
  malformed handle, multiple handles, missing file, symlink, and non-regular target emit no
  checkpoint bytes.
- Prove failed admission performs no repo facts-gather, save, or recovered-task continuation.
- Prove the exported disciplines contain no Checkpoint root, token, ownership-transfer, admission,
  no-file-override, or `/checkpoint anchor` requirement; Workstream's locally glossed full-read path
  remains usable.
- Classify exact current, drifted current, obsolete versioned, obsolete unversioned, duplicate,
  malformed, absent, missing, and invalid front doors. Replacement requires approval and preserves
  every surrounding byte.
- Prove the anchor never tells a fresh session to load based on file presence.

### Package and boundary gates

- Remove the premature named-store helper, tests, verb, and package prose rather than retaining
  dormant compatibility.
- Run Checkpoint's fixture harness, relevant Foreman and Workstream suites, shell syntax,
  ShellCheck at the repository's accepted severity, Skill Creator validation, the library lint
  gate, and `git diff --check`.
- Sweep live package and current documentation for operative `.checkpoints/`, named checkpoint,
  arbitrary-path, `list`, `rename`, manifest, current-pointer, migration, and fresh-auto-load
  behavior. Exclude dated historical records and deliberate negative fixtures; attribute every
  remaining occurrence.
- Description-only routing probes distinguish one root-session checkpoint from Workstream's
  isolated stream lifecycle without requiring one skill description to name the other.
- The final implementation diff contains no project-root checkpoint, anchor block, committed ignore
  rule, compatibility shim, or unrelated user-work mutation.
