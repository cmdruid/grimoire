# INVARIANTS — the load-bearing rules

<!-- spine-doc v1
kind: invariants
entry: ^(INV-[0-9]+):
ids: INV
doctrine: clankshop
doctrine-version: 1
refs: .handbook/** .records/**
budget: 25 entries
-->

One line per rule, grouped by area — the "just the rules" read. This seed carries only
**universal** load-bearing rules, parameterized: `<gate>` is the project's one gate command,
`<trunk>` its trunk branch; setup fills the slots. Project-specific invariants accrue below the
seed as the project earns them; an entry that stops being load-bearing is retired by the
improvement loop, never left to rot.

## Verification

INV-1: Run `<gate>` green before any commit — a red gate blocks the land; never commit "to fix later".
INV-2: Completion means landed on `<trunk>`, not gate-green — the done-log line is written at the landing moment.

## Git discipline

INV-3: Stage and commit scoped to exactly the paths you wrote — never `git add -A`.
INV-4: Small shared-state edits — tracker captures, ID allocation, promotions and their pause markers — are pathspec-scoped commits on the `<trunk>` checkout, wherever the working session lives.
INV-5: In a shared worktree the main session is the sole writer of the tree — a delegated sub-agent authors its result out-of-band and hands it back; it never edits the tree directly.
INV-12: In a linked worktree, file ops take absolute worktree paths and commands take `git -C <worktree>` — a bare `cd` does not persist across tool calls, so relying on it silently edits the root checkout.

## Records

INV-6: An ID is immutable once published (cited outside its own store); counter IDs are allocated only on the `<trunk>` checkout.
INV-7: `bugs/` and `notes/` are stores, never work queues — work is tracked from a linked tracker entry, not fished out of a store.
INV-8: A dated record (an ADR, a done-record, a report) is never retroactively edited; a standing judgment lives in POLICY and is edited in place.

## Documents

INV-9: One source of truth per fact — point, don't duplicate; the moment a fact lives in two places, one is going stale.
INV-10: Every capture surface has a drain and every living doc has an audit — an artifact with no drain is a future graveyard.

## Planning

INV-11: Match planning weight to the work — patch, then feature, then track; when unsure, start light and promote the moment a second phase or a cross-cutting decision appears.

## Design

INV-13: Abstractions are earned — extract the shared form at the second consumer, never the first.
