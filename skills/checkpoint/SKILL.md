---
name: checkpoint
description: "Keep one token-bound living save-state for a root project session and recover it safely after context loss. Use when asked to save, checkpoint, snapshot, resume, or finish root-session work; when a compaction or continuation summary replaces conversation history; or when asked to install the guarded recovery anchor. Manages only root CHECKPOINT.md."
---

# Checkpoint skill

Keep one root session's work-in-progress in `<root>/CHECKPOINT.md`. It is locally ignored scratch,
rewritten at each save, and deleted by `done`; it is not a durable record. Parallel development uses
an isolated worktree lifecycle rather than another root checkpoint.

This `SKILL.md` is a thin router. Read the selected file under `verbs/` and, at Save, Resume,
Lifecycle, or Recovery moments, read `references/disciplines.md`. Resolve every bundled resource
relative to this skill's own directory. `scripts/repo-snapshot.sh <root>` supplies repo facts;
`scripts/checkpoint-file.sh` owns token-gated reads and every file mutation.

## Scope and root

Resolve `<root>` in order: the project directory established by the conversation; otherwise the
current path's Git toplevel; otherwise one unambiguous non-Git project directory already in context.
Ask before choosing when none is established. The root must be an existing real directory.

The only managed target is `<root>/CHECKPOINT.md`. Arguments that supply another path, filename, or
identifier are rejected. Do not search for, report, read, import, migrate, or delete any other
save-state file.

A session driving a worktree stream, or holding the root checkout through an in-place stream,
refuses Checkpoint before reading or writing. `scripts/save-guard.sh <root>` is the package's
read-only stream and Git preflight.

## Identity and ownership

A valid file begins exactly:

```text
# CHECKPOINT — file: <absolute-root-path>/CHECKPOINT.md
checkpoint-token: <32-lowercase-hex-characters>
```

At successful save, confirmed resume, and Recovery seams, report exactly:

```text
CHECKPOINT — file: <absolute-path> — token: <token>
```

The token is a correlation identifier, not a secret. Creation establishes ownership. Refresh and
done require the current context's exact stable handle. Confirmed Resume rotates the token before
conferring ownership, invalidating every older handle. Admitted Recovery restores ownership to the
compacted session. Presence, project instructions, or knowledge of the path never confers it.

A tracked or unignored Git target, malformed identity, symlink, non-regular file, missing or
mismatched handle, or mutation contention refuses without loading or overwriting checkpoint
content.

## Verb dispatch

| Invocation | Verb file | Does |
|---|---|---|
| `save [next: ...]` | `verbs/save.md` | immediately create or refresh the root checkpoint |
| `resume` | `verbs/resume.md` | explicitly read, confirm, and claim the root checkpoint |
| `done` | `verbs/done.md` | gate and delete the active owned checkpoint |
| `anchor` | `verbs/anchor.md` | classify or propose the guarded recovery anchor |

Recovery is a discipline, not a verb. It fires only when a compaction/continuation summary replaces
conversation history.

## Automatic Recovery admission

On detecting compaction, stop before task work or repo facts-gathering. Extract exactly one complete
stable handle from the compacted context; an unscoped token-looking string is not a candidate.
Require its path to equal this root's absolute `CHECKPOINT.md`, then call:

```text
scripts/checkpoint-file.sh admit <absolute-root> <complete-stable-handle>
```

Only `token_match=true` admits the emitted body as Recovery's one full read. Never open the file
again. Reconcile and continue under the generic Recovery discipline.

No unique handle, wrong root or path, malformed handle or file, missing file or token, mismatch,
unsafe target, or helper failure emits only `token_match=false`. Refuse without checkpoint content,
facts-gathering, saving, or recovered-task continuation; direct the human to explicit
`/checkpoint resume`. For Checkpoint only, failed admission disables Recovery's generic no-file
fallback. A fresh session never loads based on presence.

## Lifecycle activation

Checkpoint activates only when the human asks this session to maintain or save it, confirmed Resume
completes, or Recovery is admitted. Anchor use, file presence, and merely loading this skill do not
activate it. Once active: save early after meaningful work begins; refresh before a deliberate
reset, at a human-visible work-unit completion, and on a context-pressure warning. Do not save
routine replies or a polluted context.

## Project templates

None. `templates/recovery-anchor.md` is package-only content proposed by `anchor`, never a
project-editable template.

## Edges

Checkpoint has no durable home or setup floor. Its one root file is gitignored scratch.

<!-- edges:checkpoint -->
- produces: checkpoint-doc — one living root-session save-state
- handoff: — (none; Resume in this skill picks the document up)
- consumes: checkpoint-doc — Resume reads the save-state back
<!-- /edges:checkpoint -->

## Done when

The selected verb's procedure is complete, or Recovery either admitted and reconciled the exact
token-bound file or refused without disclosing it.
