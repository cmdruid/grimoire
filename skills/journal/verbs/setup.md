# `setup` — stand up the records tool layer

Stand up `records.sh`, the empty ledger, and the records README in a target
project. Works standalone on any repo; it is also the **delegated records
step** the workshop's `setup` runs (the workshop never improvises a records
layer of its own). It creates **no store directory and no pre-seeded
`templates/`**.

1. **Resolve the two facts** (judgment stays here, mechanics are scripted):
   - `<root>`: a project directory the conversation references, else the working directory,
     else ask.
   - `<agent-records>`: first line-start `agent-records:` or `records-root:` in
     `AGENTS.md`, then `CLAUDE.md`; else `.records`. Never invent a third location.
     Pass the relative path to standup (`--records-root` is the flag name; the
     *scan* is what changed).
2. **Run the mechanics**: `scripts/standup.sh <root> [--records-root <rel>]` — creates
   the agent-records home directory itself, installs `records.sh` into
   `<agent-records>/scripts/`, seeds an empty `history.tsv`, writes the records
   README if absent, and self-checks. It is additive (a home that merely exists
   — a leftover path, or a notepad-created `.records/notes/` with no tool — is
   fine). It does not `mkdir` store directories, write `.gitkeep`, or copy
   templates.
   **Exit 2** (already stood up: `scripts/records.sh` present — not `templates/`)
   → **STOP and report**. Do not re-run standup. Do not improvise an upgrade.
   Upgrade or legacy conversion only if the human asked: diff the skill's current
   `scripts/records.sh` and the records README against the deployed copies.
   Converting legacy record *content* is a migration the human named, not this
   verb.
3. **Commit** per the commit policy (SKILL.md): standalone →
   `scripts/scoped-commit.sh <root> "Stand up the records layer" <records-root>`; inside a
   client's sweep → write-only.

## Done when

- Tool layer stood up: deployed `records.sh` + empty ledger + README; no store
  directories created; standalone commit landed (or write-only inside a sweep).
- Already stood up: stopped and reported; no writes.
- Upgrade/migrate: only if the human asked; named files diffed; standup was not re-run.
