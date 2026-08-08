# `/backlog promote <id>` — graduate a tracker entry into a ticket

Wrap an **existing** tracker entry in a ticket: the entry needs the human before work on it can
proceed. Promotion stamps the ticket's `origin:`, **pauses the entry** (its pause marker excludes
it from fast-path pickup and every drain until the ticket resolves), and leaves everything else to
the ticket lifecycle. The schema (the installation's `.handbook/rules/RECORDS.md` → *Tickets*) is
the contract — frontmatter, pause encodings, lifecycle, and the promotion bar live there.

## When to use

- An entry (`T-`/`I-`/`F-`/`B-`/`N-`) hits the promotion bar mid-route or mid-work: a *decision*,
  *sign-off*, *ambiguity*, or *access* trigger — resolving it would mean standing in for the
  human.
- The user says: "/backlog promote I-017", "escalate that issue to me", "make that a ticket".
- **Re-promotion after demotion** is legal and mints a **new** ticket citing the same `origin:`
  (same-day re-promotion collides on the slug → deterministic `-2` suffix, file and ID together).

**Do NOT use** for something with no existing entry (`/backlog ticket` — direct), to answer or
resolve a ticket (`/backlog close`), or on an already-paused entry (one open ticket per entry —
point at the existing `TK-`). On an **unstamped root** this verb refuses: report `unstamped` and
point at the clankshop onramps.

## Procedure

1. **Resolve root + date**; confirm the root is stamped. Locate the entry by ID in its store; if
   it's absent or already paused, refuse with that fact.
2. **Confirm the bar** (the schema's four triggers; tie-breaker favors motion — promote only what
   genuinely needs the human).
3. **Write the ticket** from `templates/ticket.md`:
   `.records/tickets/<YYYY-MM-DD>-<slug>.md`, ID `TK-<YYYY-MM-DD>-<slug>` (collision → suffix
   before first publication), `subject_kind` = the entry's kind, **`origin: <id>`**, `## Context`
   linking the origin entry, `## Decision needed` with your recommended answer.
4. **Pause the origin entry, per its store's encoding** (the schema's pause table):
   - flat trackers (`T-`/`I-`/`F-`): append ` [⇧ TK-<date>-<slug>]` to the entry line (the
     pattern the tracker's declaration block names);
   - store dirs (`B-`/`N-`): add frontmatter `paused: TK-<date>-<slug>`.
5. **Commit — trunk-side, always.** Promotion and its pause marker are one scoped commit on the
   trunk checkout: `scripts/scoped-commit.sh <root> "Promote <id> → <TK-id>" .records/tickets/<file>
   <origin-store-path>`. A working branch cites the `TK-` ID; it never carries the promotion.
6. **Report** the ticket ID, the paused entry, and the decision needed. A configured mirror pushes
   at this verb (see `/backlog sync`); no remote → no `mirror:` block, no behavior change.

## Why the pause matters (stated once)

A promoted entry is **the human's** until its ticket resolves: consumers skip what the pause
declaration matches, and a drain that cannot *prove* an item unpaused (missing or malformed
declaration) skips it and emits a fact — never drain what you cannot prove unpaused. `/backlog
done` refuses a paused ID; the only exit is `/backlog close`, which un-pauses on every outcome.

## Done when

The ticket exists with `origin:` stamped and a recommended answer; the origin entry visibly
carries its store's pause encoding; both landed together as one trunk-side scoped commit — and the
chat names the `TK-` ID and what's blocked on it.
