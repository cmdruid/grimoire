# `debrief` — sweep a finished body of work

Fires when a body of context worth routing is about to be lost — a feature done, a session
about to reset, an investigation wrapped. The sweep routes **every byproduct** to its durable
home; capture broadly and honestly, let the loop sift meaning later.

1. Resolve the records root and the deployed `records.sh` (SKILL.md guard — no records layer → stop and point at `/journal setup`).
2. **Gather the candidates** — facts first, memory second:
   - `git -C <root> status --porcelain` — uncommitted record/doc writes already made;
   - `git -C <root> diff <base>` — newly added `TODO`/`FIXME` markers. `<base>` is the
     merge-base of this checkout and the integration trunk
     (`git -C <root> merge-base HEAD <target>`), or the known commit range of this body of
     work if you already have one. Never invent a branch name for `<base>` or `<target>`;
     `<target>` is the current trunk (never hardcode `main`).
   - the conversation — follow-ups spoken but never filed, surprises, gotchas, dev-experience
     friction, facts worth persisting, open questions for the human.
3. **Route each item by kind, write-only** — apply the matching capture verb's procedure
   (`task`/`bug`/`issue`/`feedback`/`note`/`ticket`) with its commit step **skipped**; the
   sweep commits once. Skip what is already recorded; a duplicate line is curation debt.
4. **Close what completed**: records this work finished get
   `records.sh done <path> [--as <disposition>] --note "<one line>"`; tracker line-items get
   the contract's completed form + `records.sh touch` (no ledger line for the line-item).
5. **One atomic commit** over every file touched, on the tree the SKILL.md commit-tree probe
   selects: `scripts/scoped-commit.sh <root> "Backlog: debrief — <what finished>" <paths…>`,
   then the host's cheap doc gate if it has one.
6. **Report the sweep** in one short list: what was filed where, what was closed, what needs
   the human (open tickets).

A shipped stream unit whose story warrants narrative also gets a `reports/` record tagged
`debrief` — one page, findings first.

## Done when

- Candidates gathered from status, the resolved `<base>` diff, and the conversation; each
  routed write-only; completed records closed via `records.sh done`; completed tracker lines
  match the contract's completed form and were touched; one scoped commit on the probed tree;
  sweep reported.
- No records layer: stopped; pointed at standing the layer up.
