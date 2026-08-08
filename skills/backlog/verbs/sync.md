# `/backlog sync` — reconcile the ticket mirror

Run one mirror pass over `.records/tickets/`: push tickets whose canonical projection changed,
pull the full comment inventory, surface drift facts. **The in-repo file is canonical; the mirror
is a stamped projection** — comments flow in, content flows out, and on any disagreement the file
wins. The protocol (projection hash, adoption, drift facts, the lock) is frozen in the pack
doctrine and executed by `scripts/mirror-sync.sh`; this verb owns only when to run it and what
the facts mean.

## When to use

- The user says "/backlog sync", "sync the tickets", "check the mirror for answers".
- `promote` and `close` push their ticket's state as part of their own flow — sync is **verb-time
  only, never a daemon**; a mid-sync comment lands on the next pass.

**Do NOT use** from a linked worktree (the script refuses — sync runs **only on the trunk
checkout**), on an unstamped root (refuses: report `unstamped`, point at the clankshop onramps),
or to answer/resolve tickets (reading an imported answer and acting on it is `/backlog close`).
**No remote, or no issue system** → the script reports `mirror=absent` and changes nothing — the
degradation is silence, not an error.

## Procedure

1. **Resolve root**; confirm trunk checkout (not a worktree) and a stamped root.
2. **Run the pass:** `scripts/mirror-sync.sh <root> [--session <name>]`. The script acquires the
   sync lock (`.records/tickets/.sync-lock`, atomic `mkdir`; a stale 10-minute lock is taken over
   with the takeover logged; a live one refuses with `lock-held=` — just report it and stop),
   creates-or-adopts issues idempotently (lowest issue number wins; `adoption-extras=` names
   duplicates for the human), pushes on hash change only, pulls the full comment inventory, and
   commits each mutated ticket scoped.
3. **Judge the facts:**
   - `comments-imported=` — read the new comments; a human answer that settles a ticket routes to
     `/backlog close` (a sufficient answer → `answered` → close); a partial one keeps the
     conversation going.
   - `comment-edited=` / `comment-deleted=` — remote drift; the file's imported copy stands.
     Surface it to the human, never rewrite history.
   - `adoption-extras=` — duplicate stamped issues on the remote; the human closes the extras.
   - `lock-takeover=` — a prior sync died mid-pass; note it, results are still valid.
4. **Report** pushed / unchanged / imported counts and every drift fact verbatim.

## Done when

The pass ran (or refused with its fact), every mutated ticket is committed, imported answers are
routed onward (to `close` where sufficient), and drift facts reached the human unedited.
