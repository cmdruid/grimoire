# `setup` — stand up the records layer

Stand up the stores, templates, `records.sh`, and the ledger in a target project. Works
standalone on any repo; it is also the **delegated records step** the workshop's `setup` runs
(the workshop never improvises a records layer of its own).

1. **Resolve the two facts** (judgment stays here, mechanics are scripted):
   - `<root>`: a project directory the conversation references, else the working directory,
     else ask.
   - `<records-root>`: the front-door `AGENTS.md`'s declared `records-root:` if the project
     has one, else `.records` — never invent a third location.
2. **Run the mechanics**: `scripts/standup.sh <root> [--records-root <rel>]` — creates the
   eight stores, copies the bundled commons/example templates (the other stores' templates
   arrive with the skills that mint them — SKILL.md's template convention), installs
   `records.sh` into
   `<records-root>/scripts/`, seeds an empty `history.tsv`, writes the records README, and
   self-checks. It is additive (a legacy records root that merely exists is fine).
   **Exit 2** (already stood up: `templates/` or `scripts/records.sh` present) → **STOP and
   report**. Do not re-run standup. Do not improvise an upgrade. Upgrade or legacy
   conversion only if the human asked: diff the skill's current `scripts/records.sh`,
   `templates/`, and the records README against the deployed copies. Converting legacy
   record *content* is a migration the human named, not this verb.
3. **Commit** per the commit policy (SKILL.md): standalone →
   `scripts/scoped-commit.sh <root> "Stand up the records layer" <records-root>`; inside a
   client's sweep → write-only.

Standing the layer up is always this verb's deliberate act — clients that find no records
layer stop and point here rather than improvising one (their guard, this verb's job).

## Done when

- Layer stood up: stores + commons template + deployed `records.sh` + empty ledger +
  README; standalone commit landed (or write-only inside a sweep).
- Already stood up: stopped and reported; no writes.
- Upgrade/migrate: only if the human asked; named files diffed; standup was not re-run.
