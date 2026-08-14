# AGENTS.md — building the skills in this library

This repo is a **library of agent skills** (see `README.md` for layout, how harnesses consume
them, and the authoring mechanics — self-contained packages, generic instruction, `SKILL.md`
frontmatter rules).

This file captures the **design philosophy** for the tools, scripts, and skills built here. Apply
it whenever you add or revise one. It is distilled from practice; the `workstream` skill (its
`scripts/workstream-git.sh` + *Helper scripts* section) is the worked reference.

Most of these skills are members of the **`clankshop` pack**, tiered by the pack doctrine's roster
(`skills/clankshop/doctrine/README.md`): the pack **face** (`skills/clankshop/`) carries the
doctrine, the runbook, and the **role hats** — expertise layers its intent verbs inherit
(`design` the architect, `route` the foreman, `verify` the guardian, `calibrate`/`docs` the
chiropractor; `ask <role>` for hat-on discussion); **instruments** — procedures anyone operates
(`backlog` the records instrument, `debugger` the diagnostic instrument, `auditor` the
code-quality instrument); **pipelines** (`feature`, `workstream`);
and portable **helpers** (`delegate`, `mailbox`, `checkpoint`). `skill-builder` is the library's own
toolmaker and stays outside the pack. See `README.md` for the full inventory.

A consuming project gets the pack **deployed**, not copied: `/clankshop setup` (or `migrate`)
projects the doctrine through the project's facts into **`.handbook/`** (the projected,
locally-grown chapters — that project's source of truth), stands up **`.records/`** (typed records:
trackers, tickets, plans, the done log, reports, audit) and lazy machinery-only seats under
**`.agents/roles/`**, writes the two-region **stewardship maps** (`.handbook/README.md` +
`.records/README.md`) — stamped snapshots, per the *snapshot must never pose as authoritative* rule
below — and stamps the installation block. The full layout is the doctrine's record schema
(`skills/clankshop/doctrine/rules/RECORDS.md`); `README.md` (*Storage convention*) has the short
version.

## Design philosophy

The generalizable design philosophy for building agent skills — tools, scripts, self-init/edges,
boundary independence, the lint gate — lives in **`skills/skill-builder/docs/DOCTRINE.md`**, a
**portable** doc bundled with the `skill-builder` skill so it travels to any skills library, not just
this one. Apply it whenever you add or revise a skill here; `/skill-builder distill` is what keeps it
current as practice evolves. (`skill-builder` is itself the Phase 7 capstone of
`docs/design/2026-07-18-skill-self-initialization-roadmap.md` — the toolmaker steward nothing else in
this library was.)

**Local overrides (this library only):**

- **Feedback channel.** `docs/DOCTRINE.md`'s "skills are living artifacts" bullet says route friction
  to the skills' home feedback channel. For grimoire that channel is **GitHub issues**, tagged by
  skill — an installation may override it with its own collection file (see `README.md`).
- **Patient-zero caveat.** The deployed mechanisms — door registration, projections, self-init
  (`docs/DOCTRINE.md` covers the helpers' portable regime) — are **built and tested here**, but
  grimoire's own `AGENTS.md` is authored library doctrine, not a consuming project's scaffold —
  **never let registration blocks or deployed-layout content accrete in it**. Every deployed
  mechanism is exercised against throwaway fixtures instead (committed harnesses in
  `skills/clankshop/scripts/tests/`; fixture instances in temp dirs).

## Workstream compaction recovery

_(The workstream instance of `/checkpoint`'s recovery-anchor convention, with stream-specific
custody rules.)_

Applies only when your context has just been compacted or summarized (you see a
compaction/continuation summary in place of the full conversation), and only to the tree your
working directory is inside (`git rev-parse --show-toplevel`):

- If `WORKSTREAM.md` exists at that tree's **top level**, you are the session driving that
  workstream — STOP before any further work: re-read it in full, reconcile it against the durable
  progress records it names, and only then resume from its recorded queue state.
- If instead a `.workstreams/<stream>/WORKSTREAM.md` under the top level records
  `isolation: in-place` **and** HEAD is on that stream's branch, the same applies — you are in the
  shared tree that stream holds.
- Hand-offs visible under `.workstreams/` from the root checkout otherwise belong to **other
  sessions'** worktrees: never read, load, or recover them.
