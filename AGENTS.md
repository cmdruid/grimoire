# AGENTS.md — building the skills in this library

This repo is a **library of agent skills** (see `README.md` for layout, how harnesses consume
them, and the authoring mechanics — self-contained packages, generic instruction, `SKILL.md`
frontmatter rules).

This file captures the **design philosophy** for the tools, scripts, and skills built here. Apply
it whenever you add or revise one. It is distilled from practice; the `workstream` skill (its
`scripts/workstream-git.sh` + *Helper scripts* section) is the worked reference.

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
  not noise to absorb. Surface it at `/dev debrief` (and via a delegate's byproduct return), and
  route it to the **skills' home feedback channel** — tagged by skill, never a consuming project's
  tracker, where it strands and the authors never see it. For this library that channel is **GitHub
  issues** (an installation may override it with its own collection file — see `README.md`). The
  bar: *would this change the skill?*
