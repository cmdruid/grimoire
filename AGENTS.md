# AGENTS.md — building the skills in this library

This repo is a **library of agent skills** (see `README.md` for layout, how harnesses consume
them, and the authoring mechanics — self-contained packages, generic instruction, `SKILL.md`
frontmatter rules).

This file captures the **design philosophy** for the tools, scripts, and skills built here. Apply
it whenever you add or revise one. It is distilled from practice; the `workstream` skill (its
`scripts/workstream-git.sh` + *Helper scripts* section) is the worked reference.

Four skills are concrete agent **roles** rather than plumbing: `architect`, `foreman`, and
`chiropractor` are **stewards** — each stands up, evaluates, maintains, and drift-corrects one
cross-cutting layer against the code; `auditor` owns no layer and only emits findings. The rest
group as operators (`feature`, `backlog`, `workstream`) and plumbing (`delegate`, `mailbox`,
`handoff`). See `README.md` for the full inventory and `docs/design/2026-07-17-library-refactor.md`
for the refactor that produced this shape.

These skills deploy to **two roots**: hand-curated **seeds** under `.agents/` (one home per steward —
`architect`/`foreman`/`auditor`) and typed **records** under `.records/` (trackers + durable
history). Because the paths no longer encode ownership, `foreman setup` writes an **ownership index**
(`.agents/README.md` + `.records/README.md`) mapping content → location → steward — a stamped
snapshot, per the *snapshot must never pose as authoritative* rule below. The full layout + steward
map live in `README.md` (*Storage convention*) and `packs/clankshop.md`. The front-door architecture
that layout serves — read-cost tiers, the compiled routing table — is
`docs/design/2026-07-26-front-door-architecture.md`.

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
- **Patient-zero caveat.** The self-init/typed-edge mechanism (`docs/DOCTRINE.md` § Typed edges &
  registration) is **built and tested here**, but grimoire's own `AGENTS.md` is authored library
  doctrine, not a consuming project's scaffold — **never let self-registration blocks accrete in it**.
  Every skill that self-registers exercises the mechanism against a throwaway fixture front-door
  instead (`docs/design/2026-07-18-skill-self-init-model.md` §3.2).
