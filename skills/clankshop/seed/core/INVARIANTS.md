# INVARIANTS — the load-bearing rules

One line per rule, grouped by area — the "just the rules" read. This seed carries only
**universal** load-bearing rules, parameterized: `<gate>` is the project's one gate command,
`<trunk>` its trunk branch; setup fills the slots. Project-specific invariants accrue below the
seed as the project earns them; an entry that stops being load-bearing is retired by the review
station, never left to rot.

## Verification

INV-1: Run `<gate>` green before any commit — a red gate blocks the land; never commit "to fix later".
INV-2: Completion means landed on `<trunk>`, not gate-green — the record is closed (`records.sh done`) at the landing moment.

## Git discipline

INV-3: Stage and commit scoped to exactly the paths you wrote — never `git add -A`.
INV-4: Small shared-state edits — record captures, closures, ticket updates — are pathspec-scoped commits on the `<trunk>` checkout, wherever the working session lives.
INV-5: In a shared worktree the main session is the sole writer of the tree — a delegated sub-agent authors its result out-of-band and hands it back; it never edits the tree directly.
INV-6: In a linked worktree, file ops take absolute worktree paths and commands take `git -C <worktree>` — a bare `cd` does not persist across tool calls, so relying on it silently edits the root checkout.

## Records

INV-7: A record's path is its ID — closure happens in place (`records.sh done`), never by moving or renaming the file; the history ledger keeps the trace.
INV-8: `bugs/` and `notes/` are stores, never work queues — work is tracked from a linked tracker entry, not fished out of a store.
INV-9: A dated record (an ADR, a report, a closed plan) is never retroactively edited; a standing judgment lives in POLICY and is edited in place.

## Documents

INV-10: One source of truth per fact — point, don't duplicate; the moment a fact lives in two places, one is going stale.
INV-11: Every capture surface has a drain and every living doc has an audit — an artifact with no drain is a future graveyard.

## Planning

INV-12: Match planning weight to the work — patch, then feature, then roadmap; when unsure, start light and promote the moment a second phase or a cross-cutting decision appears.

## Design

INV-13: Abstractions are earned — extract the shared form at the second consumer, never the first.
INV-14: Build to the spec; when the code needs to deviate, that is a design gap — route it to the design station, never redesign silently from the floor.
