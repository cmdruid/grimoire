# `/backlog close <TK-id>` — resolve, wontfix, or demote a ticket

Take a ticket out of play the schema's way: apply the human's answer, run the **writebacks** on
the origin entry, and write the done-log line where one is due. The transition table, pause
encodings, and log-line format are the schema's (the installation's `.handbook/rules/RECORDS.md`
→ *Tickets*, *The done log*) — this verb executes them. The agent is the only state writer; the
human converses, the agent interprets.

## When to use

- The human's comment settles the ticket ("resolve it as X", "wontfix", "this didn't need me —
  demote it"), directly or via the mirror.
- The user says: "/backlog close TK-…", "apply my answer to that ticket", "wontfix that".

**Do NOT use** to complete an ordinary entry (`/backlog done` — refuses paused IDs precisely so
completion of a promoted entry flows through here), to open a ticket (`ticket`/`promote`), or on
an already-resolved ticket (refuse with the fact). A **partial** answer doesn't close: record it
in `## Comments`, keep `status: open` (or `answered → open` on follow-up), and continue the
conversation. On an **unstamped root** this verb refuses: report `unstamped` and point at the
clankshop onramps.

## The three outcomes (the transition table, executed)

All three set `status: resolved` and fill `## Resolution`; they differ in the origin writeback
and the log line:

- **resolve** — the answer lands and the wrapped work completes. *(p)* Un-pause the origin
  (remove its marker/key), then complete it per the completion table — `scripts/done-entry.sh
  <root> <origin-id> done "<gist citing the TK-id>" [<shas>]` (flat: removed; store-dir: status
  advanced). The log line carries the **origin entry's ID**, gist citing the `TK-`. A **direct**
  ticket logs the **`TK-` ID** itself: append
  `- <date> · <TK-id> · <gist> · commits: <shas|-> · done` to `.records/done/log.md`.
- **wontfix** — the human declines the work. *(p)* Un-pause, then
  `done-entry.sh <root> <origin-id> wontfix "<gist citing the TK-id>"` (`commits: -`). Direct:
  append the `TK-` line with outcome `wontfix`, `commits: -`.
- **demote** — this didn't need the human. *(p)* Un-pause the origin and **leave it live** (it
  returns to the fast path); **no done-log line**. Record the demotion in `## Resolution`;
  re-promotion later mints a new ticket citing the same `origin:`.

## Procedure

1. **Resolve root + date**; confirm the root is stamped. Read the ticket; refuse if absent or
   already resolved.
2. **Interpret the human's answer** into one outcome (ask when genuinely ambiguous — a wrong
   writeback is worse than one more question). A sufficient answer that still needs agent work
   before completion: set `status: answered`, do the work, then close.
3. **Execute the outcome** (above): ticket frontmatter (`status: resolved`, `updated:` today) +
   `## Resolution`; the origin writeback; the log line where due.
4. **Commit — trunk-side, pathspec-atomic**, everything the outcome touched in one step:
   `scripts/scoped-commit.sh <root> "Close <TK-id>: <outcome>" .records/tickets/<file>
   [<origin-store-path>] [.records/done/log.md]`.
5. **Report** the outcome, the origin's new state, and the log line (or that demote wrote none).
   A configured mirror pushes the closed state at this verb (see `/backlog sync`).

## Done when

The ticket is `resolved` with its `## Resolution` filled; the origin entry is un-paused and in the
state its outcome demands (completed, wontfixed, or live again); exactly the due done-log line
exists (origin-ID for promoted, `TK-` for direct, none for demote); all of it one trunk-side
scoped commit — and the chat states outcome + writebacks.
