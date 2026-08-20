# `setup` — stand up or refresh the records tool layer

Stand up `records.sh`, the empty ledger, and the records README in a target
project — or refresh `records.sh` on a later visit. Works standalone on any
repo; this is also the records step a workshop setup delegates (the workshop
never improvises a records layer of its own). It creates **no writer
directory and no pre-seeded `templates/`**.

1. **Resolve the two facts** (judgment stays here, mechanics are scripted):
   - `<root>`: a project directory the conversation references, else the working directory,
     else ask.
   - `<agent-records>`: first line-start `agent-records:` or `records-root:` in
     `AGENTS.md`, then `CLAUDE.md`; else `.records`. Never invent a third location.
     Pass the relative path to standup (`--records-root` is the flag name; the
     *scan* is what changed).
2. **Run the mechanics**: `scripts/standup.sh <root> [--records-root <rel>]` —
   creates the agent-records home directory itself if needed, installs or
   refreshes `records.sh` in `<agent-records>/scripts/`, seeds an empty
   `history.tsv` only if missing, writes the records README only if absent,
   and self-checks. It is additive (a home that merely exists — a leftover
   path, or a notepad-created `.records/notes/` with no tool — is fine). It
   does not `mkdir` writer directories, write `.gitkeep`, or copy templates.
   **First visit** (no deployed `records.sh`): stands the layer.
   **Later visit** (script present): refreshes `records.sh` when the skill
   copy has drifted (`current` vs `refreshed`); never truncates the ledger
   or overwrites README.
   **Exit 2**: missing target directory, or missing skill-side `records.sh`
   → STOP and report.
   Converting legacy record *content* is a migration the human named, not
   this verb.
3. **Commit** per the commit policy (SKILL.md): standalone →
   `scripts/scoped-commit.sh <root> "Stand up the records layer"
   <records-root>` **only if `records.sh` bytes changed** (a no-op later
   visit must not run scoped-commit — "nothing to commit" is a failed
   commit). Inside a client's sweep → write-only.

## Done when

- First visit: tool layer stood up — deployed `records.sh` + empty ledger +
  README; no writer directories created; standalone commit landed (or
  write-only inside a sweep).
- Later visit: `records.sh` current or refreshed; ledger and README
  untouched if they already existed; standalone commit only if
  `records.sh` bytes changed (or write-only inside a sweep).
