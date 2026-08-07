# The patch lane — one self-contained fix, no ceremony

<!-- spine-doc v1
kind: workflow
doctrine: clankshop
doctrine-version: 1
refs: .handbook/**
budget: 60 lines
-->

Land a single self-contained fix or tweak directly on `<trunk>` — no plan, no worktree, no
planning artifact. The lane exists so small work stays small.

**Enter from:** the routing walk's self-contained-fix row (`.handbook/rules/ROUTING.md`). If the
change turns out to touch a design decision or grows past one coherent edit, stop and re-route to
the feature lane — promotion is cheap, unwinding ceremony is not (INV-11).

**Project policy:** the gate before the commit (INV-1); commit scoped to exactly the paths you
wrote (INV-3); the fix is done when it is landed on `<trunk>`, not when it compiles (INV-2).

**Seam glue:** no skill owns this lane — it is by-hand by design. A follow-up the fix surfaces is
captured with `/backlog` by kind; a human call mid-patch (a scope or preference question) is
`/backlog promote` per the promotion bar (`.handbook/rules/RECORDS.md`).

## The walk

1. Make the edit; keep it to the one self-contained change the routing row classified.
2. Run `<gate>`; green before any commit (INV-1).
3. Commit scoped to your paths (INV-3), message referencing the tracker ID if one exists.
4. If the patch completes a tracker entry, append its done-log line (`backlog done <id>`, or the
   by-hand line per `.handbook/rules/RECORDS.md`).

**Done when:** the change is landed on `<trunk>`, the gate is green, and any tracker entry it
closes has its done-log line.
