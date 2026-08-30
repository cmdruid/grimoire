# `save` — write the root checkpoint immediately

Use the generic **Save discipline** in `references/disciplines.md`; this file adds Checkpoint's root,
ownership, Git, and publication rules.

1. Resolve the root through `SKILL.md`, reject target-like arguments, and run
   `scripts/save-guard.sh <root>`. A worktree stream or matching in-place stream refuses before any
   Checkpoint read or write. In Git, tracked `CHECKPOINT.md` or `CHECKPOINT.md.tmp` also refuses.
2. Determine ownership without reading a body:
   - Absent target: create a token with `scripts/checkpoint-file.sh token`.
   - One complete stable handle for this root: validate it with
     `scripts/checkpoint-file.sh match <root> <handle>`. A failed match stops as an ownership
     mismatch without probing or overwriting the file.
   - Existing target with no matching root handle: run
     `scripts/checkpoint-file.sh occupancy <root>`. Only `checkpoint_occupancy=valid` may stop and
     tell the user that another checkpoint occupies the singleton target and offer to overwrite it.
     Retain the emitted opaque fingerprint. Unsafe or malformed occupancy refuses without an
     overwrite offer. Never disclose the incumbent token or body.
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
   `scripts/checkpoint-file.sh save <root> <current-token>` for refresh. For valid foreign
   occupancy, rejection performs no mutation. Confirmation authorizes one replacement: generate a
   fresh token, synthesize the complete document, and send it to
   `scripts/checkpoint-file.sh overwrite <root> <expected-fingerprint>`. The helper revalidates the
   incumbent and fingerprint under the mutation lock, requires the token to differ, and publishes
   atomically without a backup. Never write the managed or temporary path around the helper.
6. Report the emitted stable handle and the one recorded next action. Classify the lifecycle and
   recovery anchor through `anchor`. A missing anchor, drifted-v2 anchor, or generic conflict is a
   warning and pointer to `/checkpoint anchor`; an unsafe classifier error is reported as a refusal.
   Save never edits project instructions or offers a compatibility or migration route.

Successful explicit Save enrolls the session. A request merely to maintain Checkpoint schedules
nothing. After enrollment, automatic refreshes occur only at the three Lifecycle moments. Every
successful refresh reports the complete handle and recorded next action without asking. A missing
current handle is inert; a presented exact-root handle that no longer matches stops visibly. Never
save a polluted context or infer that the session is complete.

**Done when:** the helper published one independently resumable root file, the stable handle and next
action were reported, and anchor status was surfaced without editing project instructions.
