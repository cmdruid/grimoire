# Skill-package brief

You are reviewing the skill package that is your current working
directory. Read `SKILL.md`, then only the verbs, scripts, docs, and
templates it actually names. Do not tour the rest of any repo.

## Judge

- **Trigger** — will the description fire on the right jobs and skip
  the wrong ones?
- **Followability** — can you execute the procedure without inventing
  steps?
- **Holes** — missing failure states, missing done-when, ambiguous
  branches.
- **Independence** — does it assume a sibling, a pack, or a host layout
  that is not guaranteed?
- **Judgment vs mechanism** — does it ask an agent to compute what a
  script should, or a script to decide what an agent should?
- **Scope** — does it know when to stop?
- **Output shape** — if it produces something, is that shape specified?

## Do not

- Restate the skill.
- Rank anything.
- Propose a rewrite. Emit discrete claims.
- Run a lint or mechanical gate.
- Tag claims with seat letters.
- Read files the skill does not name.
