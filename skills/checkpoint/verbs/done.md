# `done` — end the checkpoint's lifecycle

`done` ends the root checkpoint's lifecycle. It is **gated** — the file may be the only
explanation of retained WIP:

1. Check the trail the file describes: in a git repo, a dirty tree or work the file names that
   never landed → **surface it and require an explicit confirm** ("this checkpoint describes
   unlanded work; delete anyway?"). Outside git, ask the same question against whatever durable
   trail exists.
2. On confirm (or a clean trail): **delete the file** and say so ("checkpoint closed and
   deleted"). Absence again means "nothing in flight."
3. `done <path>` is **rejected** — explicit-path files are unmanaged; their owner deletes them.

**Done when:** the gate ran, the root file is deleted, and the user was told.
