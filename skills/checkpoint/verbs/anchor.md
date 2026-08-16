# `anchor` — install the discoverability guarantee (the recovery-anchor convention)

A compacted (or fresh) session only benefits from the checkpoint if something it *still reads*
points at the file. That something is a short block in the host's **always-loaded front door**
(`AGENTS.md` / `CLAUDE.md` / equivalent — re-injected every request, so it survives compaction
by construction). Without it, automatic compaction recovery is undiscoverable — a save still
produces a resumable save-state, but nothing routes a compacted session back to it.

1. **Check**: scan the root's always-loaded front-door files for the block (a line matching
   `^## Checkpoint recovery`). Present → report which file carries it; done.
2. **Absent → propose the block below as a one-off edit** and apply it on the human's approval,
   appended to the front door they pick. Never self-install without the approval, and never
   commit it — whether the front door is tracked, and whether this edit ships, stays the
   host's convention (this skill ships no registration machinery; the `anchor` verb is a
   proposed, human-approved edit, not self-registration).

The copy-paste block:

```markdown
## Checkpoint recovery

If `CHECKPOINT.md` exists at this project's root, it is the living save-state of work in
flight (`/checkpoint`):
- If your context was **just compacted/summarized** (a compaction/continuation summary sits
  where conversation history should be), you are the session that work belongs to — STOP,
  re-read `CHECKPOINT.md` in full, reconcile it against the durable trail (git, records),
  and continue without a user round-trip if the next action is KNOWN.
- If you are a **fresh session**, read it, echo its suggested first action, and **confirm
  with the user** before continuing that work.
```

(An *installer* skill with a genuine install moment may automate its own instance of this
recovery-anchor convention — `/workstream create` does, for its stream anchor; that automation
belongs to the installer, not here.)

**Done when:** the front door's anchor state was reported; if absent, the block was proposed
and — on approval — applied to the file the human picked, verbatim.
