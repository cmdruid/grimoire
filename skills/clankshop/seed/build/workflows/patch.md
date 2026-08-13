# The patch lane — one self-contained fix, no ceremony

Land a single self-contained fix or tweak directly on `<trunk>` — no plan, no worktree, no
planning artifact. The lane exists so small work stays small.

**Enter from:** the routing walk's self-contained-fix row (`core/ROUTING.md`). The line: **if it
earns its own branch, it's a feature; otherwise it's a patch.** If the change turns out to touch
a design decision or grows past one coherent edit, stop and re-route to the feature lane —
promotion is cheap, unwinding ceremony is not (INV-12).

**Policy:** the gate before the commit (INV-1); commit scoped to exactly the paths you wrote
(INV-3); the fix is done when it is landed on `<trunk>`, not when it compiles (INV-2).

## The walk

1. Make the edit; keep it to the one self-contained change the routing row classified.
2. Run `<gate>`; green before any commit (INV-1).
3. Commit scoped to your paths (INV-3), message referencing the tracker record if one exists.
4. If the patch completes a tracker entry, close it — `records.sh done <path>` writes the
   ledger line (INV-2, INV-7).

**Done when:** the change is landed on `<trunk>`, the gate is green, and any record it closes
has its ledger line.
