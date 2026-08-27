# `save` — write the root checkpoint immediately

Use the generic **Save discipline** in `references/disciplines.md`; this file adds Checkpoint's root,
ownership, Git, and publication rules.

1. Resolve the root through `SKILL.md`, reject target-like arguments, and run
   `scripts/save-guard.sh <root>`. A worktree stream or matching in-place stream refuses before any
   Checkpoint read or write. In Git, tracked `CHECKPOINT.md` or `CHECKPOINT.md.tmp` also refuses.
2. Determine ownership without reading a body:
   - Absent target: create a token with `scripts/checkpoint-file.sh token`.
   - Existing target: require exactly one stable handle in current context for the root path and
     validate it with `scripts/checkpoint-file.sh match <root> <handle>`. Anything else refuses and
     points to explicit `resume`.
3. Elide secrets, synthesize rather than transcribe, use absolute dates, and reconcile shipped
   claims against durable evidence. A named load-executable next action wins, then a KNOWN
   continuation. At a genuine fork, record one safe instruction to ask the human which branch to
   take after loading. Save does not wait for that choice.
4. Render the complete replacement. Its first two lines are the exact title path and token required
   by `SKILL.md`. Keep only the sections needed to resume:
   - Core: last-updated date, read-this-first, TL;DR, completed work and decisions, repo state,
     ordered pending work, and one suggested first action.
   - Add user, project, constraints, a verify-before-trust pointer map, or entry-document pointers
     only when they materially help a later session.
5. Send the complete document on standard input to
   `scripts/checkpoint-file.sh save <root> new` for creation or
   `scripts/checkpoint-file.sh save <root> <current-token>` for refresh. The helper establishes the
   narrow local ignores, serializes mutation, validates the document, publishes without clobber on
   creation, and replaces atomically on refresh. Never write the managed or temporary path around
   the helper.
6. Report the emitted stable handle and the one recorded next action. Classify the recovery anchor
   through `anchor`; a missing or obsolete block is a warning and pointer to `/checkpoint anchor`,
   never an automatic project-instruction edit.

An explicit request to maintain Checkpoint activates first-save-early once work is meaningful; an
explicit `save` writes now. After activation, automatic refreshes occur only at the three Lifecycle
moments. Every automatic save reports the handle.

**Done when:** the helper published one independently resumable root file, the stable handle and next
action were reported, and anchor status was surfaced without editing project instructions.
