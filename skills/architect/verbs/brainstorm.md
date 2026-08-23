# `brainstorm [topic]` — divergent ideation into a draft design

Open the space before narrowing it. **Harvest the current conversation first** —
pull every constraint, preference, and half-decision already stated into the
draft before asking anything; never start from a blank template.

Summon the design station per SKILL.md *One environment probe*. Feature
`brainstorm` mints a `specs/` record (SKILL.md destination). It is not
founding-shaped and does not fill a named founding file.

## Procedure

1. **Explore context** — the relevant code, docs, recent commits, and the host's
   design context (workshop: design-station summon + the `specs/` store's
   `status: published` spec; standalone: the project's own design docs) before
   asking anything. Don't brainstorm blind.
2. **Scope check** — an idea spanning several independent subsystems decomposes
   into separate features first; brainstorm the first one. **And ask "is this
   already built?"** — probe by *capability* keywords repo-wide (not just the
   subsystem you expect it in), and `ls`/glob every path or name the idea would
   claim (plus the host's skills/workflows registry where one exists). An
   existing implementation turns the feature into a docs/discoverability task —
   the cheapest outcome, and one that has otherwise surfaced only at execution,
   after a design doc, an ADR, and a first commit duplicated it.
3. **Diverge** — propose 2–3 genuinely different approaches with trade-offs;
   lead with a recommendation and say why.
4. **Converge conversationally** — one question at a time (multiple-choice when
   possible), confirming each section before the next. YAGNI ruthlessly.
5. **Write the draft** — a `specs/` doc (`status: draft`), shaped per
   `templates/spec.md`'s sections at draft weight: problem, goal, candidate
   approach, open questions listed at the foot. Unresolved branches are
   *expected* here — `grill` or `spec` resolves them.

Output: the draft design doc. Tell the human where it is. Stop if they
need to read it; otherwise offer `grill` or `spec`. A draft is a
legitimate resting state.

## Done when

A `specs/` record exists at `status: draft` with problem / goal / candidate
approach filled at draft weight and open questions at the foot. No
`published` write. No reshape onto a founding file.
