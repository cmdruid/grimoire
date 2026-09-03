# `brainstorm [topic]` — divergent ideation, conversational by default

Open the space before narrowing it. Harvest the current conversation first: pull every constraint,
preference, and half-decision already stated into the working synthesis before asking anything.
Brainstorm never creates a record and writes nothing unless the user explicitly saves or explicitly
names a contained Architect draft to resume.

## Invocation

- Bare `brainstorm` and `brainstorm [topic]` work in conversation only.
- Parse `brainstorm save [name]` before treating `save` as a topic. It explicitly authorizes creating
  or updating one living draft from the current synthesis. An unambiguous natural-language request
  to save the current idea is equivalent.
- A named path resumes a draft only when it resolves beneath the canonical
  `.agents/skilldata/architect/drafts/` home, is a regular non-symlink Markdown file, and follows the
  package `templates/draft.md` shape. An explicit valid path authorizes updating that same draft.
- No heuristic grants save permission: not duration, importance, open questions, multiple agents,
  or Architect's judgment that the idea may matter.

## Procedure

1. **Explore context.** Read the relevant code, docs, recent commits, the `specs/` store's current
   published spec, and the project's own design docs before asking anything. Do not brainstorm blind.
2. **Scope check.** Split an idea spanning independent subsystems before continuing. Probe by
   capability keywords repo-wide and inspect every path or registry the idea would claim. An existing
   implementation turns the feature into a docs or discoverability task.
3. **Diverge.** Propose 2–3 genuinely different approaches with trade-offs; lead with a recommendation
   and say why.
4. **Converge conversationally.** Ask one question at a time, confirm decisions, and YAGNI ruthlessly.
   Unresolved branches are legitimate.
5. **Stop or persist.** For an ordinary brainstorm, recap the current synthesis in conversation and
   offer either `spec` or an explicit save; do not write. For `save` or a valid resumed path, resolve
   `.agents/skilldata` through SKILL.md *Project homes*, fill the package-only `templates/draft.md` outline as one current synthesis
   rather than an event log, and call package-local `scripts/architect-artifacts.sh draft-save`.
   Use a lowercase kebab slug. Same-title replacement is allowed; a different title at that slug
   refuses and asks for another name or explicit path.

Existing `status: draft`, `schema: architect/spec@1` records remain valid inputs to `grill` and
`spec`; brainstorm does not move or convert them.

## Done when

The user has a useful conversational synthesis with no write, or explicitly requested persistence
and received the saved draft path. No record was created and no implicit save occurred.
