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
history). Because the paths no longer encode ownership, `foreman init` writes an **ownership index**
(`.agents/README.md` + `.records/README.md`) mapping content → location → steward — a stamped
snapshot, per the *snapshot must never pose as authoritative* rule below. The full layout + steward
map live in `README.md` (*Storage convention*) and `packs/clankshop.md`.

## Design philosophy

- **Scripts compute facts; agents decide.** Push mechanical, deterministic state-analysis into small
  **read-only** scripts that print compact `key=value` facts + evidence, and keep the judgment in the
  agent prose. A script is stateless — it can't see session context ("I already did X this turn") — so
  a *recommendation* it emits will sometimes be confidently wrong, and a confident-wrong verdict is
  worse than none. Facts have no such failure mode. This also pays off in tokens and turns: if the
  agent would otherwise run several commands and reason over their raw output to make a routine call,
  one structured read replaces all of it.

- **One stable entrypoint for approval.** Wrap commands whose arguments vary per run (per-stream
  paths, IDs) behind a single program, so a prefix-matching approval policy can permit the whole
  capability with one rule. You can't allowlist what you can't enumerate.

- **Safe-by-default = allow the safe, let the rest prompt.** When unmatched commands prompt the user,
  you only ever *add* allows for safe, reversible commands; destructive ones keep prompting for free.
  No deny rules, no enumerating the dangerous.

- **A snapshot must never pose as authoritative.** Any derived or cached artifact (an orientation map,
  a precomputed classification) is a snapshot of a moving target. Make it **pointer-heavy** (paths and
  IDs rot gracefully; pasted content rots silently), **stamp what it was built against**, and ship a
  **cheap validator** that flags drift. Say "verify before trusting" in the artifact itself.

- **Prefer the simplest portable rule over a configurable one.** A simple rule that is identical
  everywhere and errs toward the safe/expensive choice beats a precise rule that needs per-host wiring
  — e.g. classify "docs vs build" as *every changed path ends in `.md`*, not host-specific globs.
  Zero-config and conservative travels.

- **Fix the doctrine, not just the tool.** When you change a rule, change it in the prose every agent
  reads — not only in the one script that consumes it. Otherwise the script and the doctrine disagree,
  and that divergence is tech debt.

- **Harness-agnostic packages; harness-specifics at the edge.** A portable skill/script names only the
  generic concept ("a prefix-matching approval policy"), never a specific agent or harness. The one
  place a harness is named is its own config file (e.g. an approval-rules file), which lives outside
  the portable package.

- **Skills are living artifacts — capture the friction of using them.** Strong, concrete feedback about
  a skill you just used (a friction, a gap, a win worth keeping) is a signal that *improves* the skill,
  not noise to absorb. Surface it at `/backlog debrief` (and via a delegate's byproduct return), and
  route it to the **skills' home feedback channel** — tagged by skill, never a consuming project's
  tracker, where it strands and the authors never see it. For this library that channel is **GitHub
  issues** (an installation may override it with its own collection file — see `README.md`). The
  bar: *would this change the skill?*

- **Self-scoping descriptions — the runbook holds the glue, not the leaves.** A skill's frontmatter
  `description:` is its **routing surface**, and it must route **on its own**: the harness selects from
  descriptions alone, and a bare install (skills present, no pack deployed) has no seam map in context.
  So a description states only its **own** job and domain; it does **not** name a sibling to defer,
  disambiguate, or contrast (*"for X use /other"*, *"distinct from /other"*, *"peer to /other"*) — that
  contrast is the runbook's job. Two narrow exceptions: a **router** may name the mechanisms it
  dispatches among (describing its own function — `delegate` → inline/mailbox/codex), and a genuine
  **fragment** may carry one orientation pointer to its parent (`mailbox` → `delegate`). A **body** may
  keep a soft operational pointer a reader needs mid-task, but must not re-document or own another
  skill's seam — point, don't paste. **Competence is the hard constraint:** drop a cross-reference only
  when the two self-scopes still route correctly without it (verify with a routing probe); where they
  can't, **sharpen the scope, never restore the pointer**. Independence is maximized under routing
  accuracy, never traded for it.

- **Cross-skill seams live in the runbook.** How two skills compose — who owns what, where one stops
  and the next starts — belongs in the pack/runbook (`packs/clankshop.md`'s seam table), never
  duplicated into a leaf's frontmatter. The load-bearing invariant: **no skill crosses another's
  seam.** A seam asserted in a leaf but absent from the runbook is drift; a seam duplicated into a leaf
  is co-mingling — audit for both.

- **Glue is content (the pack's) vs. mechanism (the engine's) — birth vs. growth.** The glue *content*
  — the seams, the initial `AGENTS.md`/`WORKFLOWS.md` wiring — is owned by the pack/runbook, which
  **births** the constellation. The workflow engine (`foreman`) is the pack-agnostic **oven**: it
  **stamps** whatever the recipe specifies and **grows** it afterward (via `calibrate`), but it
  **never authors** the pack-specific glue. Recipe owns *what*; oven owns *how* and *ongoing*.
