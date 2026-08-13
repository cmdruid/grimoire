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
   eight stores, copies the templates, installs `records.sh` into
   `<records-root>/scripts/`, seeds an empty `history.tsv`, writes the records README, and
   self-checks. It is additive (a legacy records root that merely exists is fine) and refuses
   a root that is **already stood up** — an upgrade is a judgment-assisted diff against the
   skill's current templates/scripts, not a re-standup. Converting legacy record content is
   migration's job, not standup's.
3. **Commit if the human wants it**, scoped to exactly what was written:
   `scripts/scoped-commit.sh <root> "Stand up the records layer" <records-root>`.

Lazy path: a capture verb finding no records layer runs steps 1–2 inline (no round-trip) and
notes it did so.
