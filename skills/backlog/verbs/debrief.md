# `debrief` — sweep a finished body of work

Fires when a body of context worth routing is about to be lost — a feature done, a session
about to reset, an investigation wrapped. The sweep routes **every byproduct** onto the
three trackers. Speech alone is not a drain.

1. Resolve both homes (SKILL.md).
2. **Gather the candidates** — facts first, memory second:
   - `git -C <root> status --porcelain` — uncommitted record/doc writes already made;
   - `git -C <root> diff <base>` — newly added `TODO`/`FIXME` markers. `<base>` is the
     merge-base of this checkout and the integration trunk
     (`git -C <root> merge-base HEAD <target>`), or the known commit range of this body of
     work if you already have one. Never invent a branch name for `<base>` or `<target>`;
     `<target>` is the current trunk (never hardcode `main`).
   - the conversation — follow-ups spoken but never filed, surprises, gotchas, dev-experience
     friction, facts worth persisting, open questions for the human.
3. **Route each item write-only** — apply `task` / `issue` / `feedback` only, with the
   capture verb's commit step **skipped**. The sweep commits once. Skip what is already
   recorded; a duplicate line is curation debt. Leftover prefixes (prose convention, not a
   format change):
   - a thing to build → task.
   - a project concern / limitation → issue.
   - a dev-experience observation → feedback.
   - needs the human → one Issue line `needs human: <the ask, one sentence>`.
   - looks like a fileable repro → one Backlog line `file repro: <symptom, one sentence>`.
     Do not mint a `bugs` record. The cold record is the host's bug-filing lane later.
     When that record exists, rewrite this line to the completed form and add
     `→ <dir>/<file>.md` for the minted relpath — or let the format authority's close
     path do the linked-line rewrite.
   - a leftover durable fact → one Backlog line `write down: <the fact, one sentence>`.
     When the fact is written, complete the line.
4. **Close what completed**: records this work finished get
   `scripts/record-mint.sh stamp <agent-records> <abs-path> --status <disposition> --note "<one line>"`;
   tracker line-items get the contract's completed form + `record-mint.sh stamp`
   (no ledger line for the line-item). A `needs human:` line completes when the human
   answers (completed form, no Resolution section).
5. **One atomic commit** over every file touched, on the tree the SKILL.md commit-tree probe
   selects: `scripts/scoped-commit.sh <root> "Backlog: debrief — <what finished>" <paths…>`,
   then the host's cheap doc gate if it has one.
6. **Report the sweep** in one short list: every leftover line filed, what was closed.

A shipped stream unit whose story warrants narrative also gets a `reports/` record tagged
`debrief` — one page, findings first. Do not invoke `promote`.

## Done when

- Candidates gathered from status, the resolved `<base>` diff, and the conversation; each
  routed write-only onto the three trackers; completed records closed via stamp (ledger
  line only when `records.sh` ran); completed tracker lines match the contract's completed
  form and were touched; one scoped commit on the probed tree; sweep reported; no
  `tickets`, `bugs`, or `notes` record minted.
