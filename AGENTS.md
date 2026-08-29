# AGENTS.md — building the skills in this library

This repo is a **library of agent skills** (see `README.md` for layout, how harnesses consume
them, and the authoring mechanics — self-contained packages, generic instruction, `SKILL.md`
frontmatter rules).

This file captures the **design philosophy** for the tools, scripts, and skills built here. Apply
it whenever you add or revise one. It is distilled from practice; the `workstream` skill (its
`scripts/workstream-git.sh` + *Helper scripts* section) is the worked reference.

Most of these skills are members of the root, faceless **`clankshop` pack** (`PACK.md`):
**helpers** (`architect` the specification spine,
`contractor` the job lead, `inspector` critique and fold, `journal` the
records format authority and the one required member, `backlog` the follow-up lifecycle,
`notepad` project memory, `analyst` reports and briefings, `workstream` the stream driver,
`auditor`, `debugger`, `foreman` project operations and goal runbooks); **utilities** (`checkpoint`, `mailbox`,
`delegate`, `scheduler`, `workspace`). `agent-council`, `code-humanizer`,
`developer-writing`, and `skill-builder` stay outside the pack. See `README.md`
for the full inventory.

The pack is distribution plus a human-readable seam map. It has no skill face and no project
lifecycle: installation never writes doctrine, hooks, operations, records, trackers, or a project
front door. Skills with durable project surfaces expose and own their own explicit setup.

## Design philosophy

The generalizable design philosophy for building agent skills — tools, scripts, self-init/edges,
boundary independence, the lint gate — lives in **`skills/skill-builder/docs/DOCTRINE.md`**, a
**portable** doc bundled with the `skill-builder` skill so it travels to any skills library, not just
this one. Apply it whenever you add or revise a skill here; `/skill-builder calibrate` is what keeps it
current as practice evolves. (`skill-builder` is itself the Phase 7 capstone of
`docs/design/2026-07-18-skill-self-initialization-roadmap.md` — the toolmaker steward nothing else in
this library was.)

**Local overrides (this library only):**

- **Feedback channel.** `docs/DOCTRINE.md`'s "skills are living artifacts" bullet says route friction
  to the skills' home feedback channel. For grimoire that channel is **GitHub issues**, tagged by
  skill — an installation may override it with its own collection file (see `README.md`).
- **Patient-zero caveat.** The deployed mechanisms — self-registration, records standup, and
  skill-owned project files
  (`docs/DOCTRINE.md` covers the helpers' portable regime) — are **built and tested here**, but
  grimoire's own `AGENTS.md` is authored library doctrine, not a consuming project's scaffold —
  **never let door blocks or deployed-layout content accrete in it**. Every deployed
  mechanism is exercised against throwaway fixtures in its owning skill's test harness.

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
