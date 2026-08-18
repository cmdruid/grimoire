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
  that is not guaranteed? If the skill writes typed records, it must not
  require a sibling standup or an executable `records.sh` as a floor. A
  stop that treats journal standup as a precondition is a finding. A
  description that requires a stood-up records layer is a finding.
- **Judgment vs mechanism** — does it ask an agent to compute what a
  script should, or a script to decide what an agent should?
- **Scope** — does it know when to stop?
- **Output shape** — if it produces something, is that shape specified?
  If it produces a record, the destination is `<agent-records>/<store>/`
  (default `.records/<store>/`), not a confirmed `docs/` fallback and
  not "skip, write nowhere." The in-package contract (five keys, dated
  slug) is specified in the package. Every store it mints has
  `templates/<doctype>.md` in the package. A `## Project templates` list
  names the lock-in set; every listed file exists in the package; the
  skill does not copy a file the list does not name. Project copies land
  under `<agent-templates>/<skill>/`.
- **Home resolution** — for each of the three front-door homes the skill
  touches (`<agent-records>`, `<agent-templates>`, `<agent-doctrine>`),
  **reading counts as touching**. Three questions the lint cannot answer,
  which is why they are yours:
  - Does the **operative procedure** resolve the home, or does the skill
    merely carry a resolution literal somewhere while its actual steps
    name a fixed path? A skill can satisfy the mechanical check and still
    hardcode throughout. That gap is a finding.
  - Does it test for the **specific artifact** after resolving the home,
    and degrade when absent — or does it treat home-exists as
    artifact-exists and break?
  - If it stands doctrine up, does it **leave an incumbent alone**?
    Doctrine is copy-then-customize; a re-run that overwrites host edits
    destroys accumulated project judgment. Creating an explicitly
    *declared* home that is absent is also a finding — that path is
    someone else's territory.

## Do not

- Restate the skill.
- Rank anything.
- Propose a rewrite. Emit discrete claims.
- Run a lint or mechanical gate.
- Tag claims with seat letters.
- Read files the skill does not name.
