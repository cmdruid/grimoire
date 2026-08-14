# Journal / backlog split — the format authority and the follow-up lifecycle

Design for the v2 roadmap's Phase 6 (inserted 2026-08-14, before the deployment test — so the
finish-line test validates the final shape). Settled conversationally with the human; this doc
records the decisions.

## The split

v2's `journal` fuses two different things: a *substrate* (the `.records/` stores, the
front-matter contract, templates, `records.sh`, the history ledger) and a *workflow* that runs
on it (capture, debrief, curate). They separate along the library's recurring
mechanism/procedure seam (mailbox/delegate; checkpoint/workstream):

- **`journal` — the format authority.** An independent skill that *defines* `.records`: the
  eight stores, the record format and front-matter contract, the templates, and the tooling for
  searching and lifecycle (`records.sh` — query, mint, touch, close-in-place, the ledger,
  `check`). **All specification of `.records` and record front-matter lives here, in exactly
  one citable place**, with `records.sh check` as its mechanical enforcement. Other skills that
  save artifacts in `.records` (debugger reports, auditor findings, workstream plan closures,
  blueprint plans, backlog trackers) are **clients**: they cite journal's contract instead of
  restating it (the BL-6 / locally-complete-citation anti-drift rule).
- **`backlog` — the follow-up lifecycle.** Independently owns the loop: **debrief** an agent's
  finished work → **file** items into trackers (capture by kind) → **curate** the trackers.
  Draining trackers into scheduled work is explicitly **shelved** (noted, not designed).

## Decisions

- **Dependency shape: doctrinal on the skill, runtime on the deployment.** At runtime every
  client (backlog included) talks to the **deployed** tool — `<records-root>/scripts/records.sh`
  travels with `.records/` — not to journal's skill directory. Backlog's dependency on
  journal-the-skill is only *understanding the format* (cite the contract). Guard: on a host
  with no records layer, backlog refuses in one breath and points at `/journal setup`.
- **Verb map.**
  - `journal`: `setup` (stand up `.records`, standalone or as the workshop's delegated seam),
    the `records.sh` surface (`new` / `touch` / `done` / `history` / `list` / `show` /
    `check`), templates, the contract doc, `standup` (a canned report over the stores — query
    surface), and curate's **substrate half** (ledger-prune proposals, record rot) — hygiene of
    the format belongs to the format owner.
  - `backlog`: `task`, `bug`, `issue`, `note`, `feedback` (capture by kind → tracker lines +
    linked records), `ticket` (escalate to the human), `debrief` (sweep finished work),
    `curate` (tracker grooming half).
- **The `bug`/`task` proxies are RETIRED** (human decision 2026-08-14): delete `skills/bug` and
  `skills/task`, drop them from the pack manifest and README; capture routes through
  `/backlog bug …` / `/backlog task …` directly. (Post-ship: `install.sh --remove bug task` on
  wired machines.)
- **Pack tiers**: `journal` stays the pack's sole **required** member (clankshop `setup`
  delegates records standup to it). `backlog` joins as **optional-but-default** — the workshop
  runs without the follow-up lifecycle, but the debrief seams want it present.
- **Name recycling, eyes open**: v1's `backlog` was the whole records instrument (renamed to
  `journal` in v2); the new `backlog` is the tracker workflow only. The name has the right
  muscle-memory ("where follow-ups go") and manages the capital-B **Backlog** tracker; history
  docs (`docs/design/`, BACKLOG.md) keep their v1 meaning as dated record. Both SKILL.md bodies
  carry a one-line lineage note.
- **Cross-skill re-points** (the churn the split buys): `workstream` flow/verbs' `/journal
  debrief` seams → `/backlog debrief`; `delegate`'s byproducts-block taxonomy citation →
  backlog; `clankshop` seed/setup references stay journal (records standup); README/AGENTS
  rosters and PACK.md updated.

## Non-goals

- No change to the `.records` layout, front-matter contract, ledger semantics, or `records.sh`
  behavior — this phase moves ownership and routing, not the format. (Format changes, if any,
  are their own later work.)
- No drain verb (shelved).
- No new storage mode for backlog on bare hosts — it guards, it does not degrade into a second
  format.

## Verification sketch

- Lint `fails=0`; the routing-probe run on the two new descriptions (a capture request must
  route to backlog, a format/setup request to journal — a mis-route fails the gate).
- The journal/clankshop fixture suites stay green with verbs relocated (setup-journal
  delegation exercised; records-test untouched by design).
- Sweep: zero `/journal task|bug|issue|note|feedback|ticket|debrief` refs outside history docs;
  zero `skills/bug` / `skills/task` remnants — proven by breaking (macOS-ERE caveat: plain
  patterns, no `\b`).
