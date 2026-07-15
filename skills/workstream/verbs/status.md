# `status`  · runs anywhere · READ-ONLY

1. `git -C <root> worktree list` -> the active worktrees under `.workstreams/`; ALSO scan
   `<root>/.workstreams/*/WORKSTREAM.md` directly — an **in-place** stream owns no worktree, so
   only the scan finds it.
2. For each, read its `WORKSTREAM.md`: stream name, branch, isolation (`worktree` | `in-place`),
   current feature, last-saved (file mtime or a stamp in the hand-off), and for in-place streams
   the `Parked:` state. A `.workstreams/` entry with no `WORKSTREAM.md` isn't a workstream — skip
   it (or list it as "not a workstream").
3. For each workstream, read its Coordinates `integration-target` and run
   `git -C <root> log <branch>..<target> --oneline`; non-empty -> mark "sync due".
4. Print a table: stream | isolation | branch | current feature | last-saved | sync-due? |
   parked? (in-place only). Read-only; touch nothing.
