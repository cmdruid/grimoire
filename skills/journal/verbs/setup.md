# `setup` — stand up or refresh the records tool layer

Stand up `records.sh`, the empty ledger, and the records README in a target
project — or refresh `records.sh` on a later visit. Works standalone on any
repo; this is also the records step a workshop setup delegates (the workshop
never improvises a records layer of its own). It creates **no writer
directory and no pre-seeded `templates/`**.

1. **Resolve the two facts** (judgment stays here, mechanics are scripted):
   - `<root>`: `git rev-parse --show-toplevel` of the checkout that should
     hold the records; else a project directory the conversation
     references; else ask. Read `AGENTS.md` / `CLAUDE.md` under that root.
   - `<agent-records>`: first line-start `agent-records:` or `records-root:` in
     `AGENTS.md`, then `CLAUDE.md`; else `.records`. Never invent a third location.
     The relative path must have no leading `/` and no `..` segment (standup
     refuses otherwise). Pass it as `--records-root`.
2. **Run the mechanics**: `scripts/standup.sh <root> [--records-root <rel>]` —
   creates the agent-records home directory itself if needed, installs or
   refreshes `records.sh` in `<agent-records>/scripts/`, seeds an empty
   `history.tsv` only if missing, writes the records README only if absent,
   and self-checks. It is additive (a home that merely exists — a leftover
   path, or a notepad-created `.records/notes/` with no tool — is fine). It
   does not `mkdir` writer directories, write `.gitkeep`, or copy templates.
   **First visit** (no deployed `records.sh`): stands the layer.
   **Later visit** (script present): refreshes `records.sh` when the skill
   copy has drifted (`current` vs `refreshed`); restores the executable bit
   if needed; **migrates statuses**, then `check`; never truncates the ledger
   or overwrites README.
   **Exit 2**: missing target directory, or missing skill-side `records.sh`
   → STOP and report.
   **Exit 1**: usage, or a bad `--records-root`.
   If standup wrote the tool and then `check` failed, the tool layer **is
   up** — report that and point at `/journal curate`. That is not a setup
   refuse.
   Converting legacy record *content* (adopting foreign docs) is a
   migration the human named, not this verb. Status-vocab rewrite
   (`open`/`current`/close-words → `draft`/`published`/`archived`) is this
   verb.
3. **Commit** per the commit policy (SKILL.md): standalone → parse each
   `wrote: <path>` line from standup stdout and
   `scripts/scoped-commit.sh <root> "Stand up the records layer" <those
   paths>`. No `wrote:` lines → do not run scoped-commit (a no-op later
   visit must not: "nothing to commit" is a failed commit). Never pass the
   records-root directory as a pathspec. Inside a client's sweep →
   write-only.

## Done when

- First visit: tool layer stood up — deployed `records.sh` + empty ledger +
  README; no writer directories created; standalone commit landed on the
  `wrote:` paths (or write-only inside a sweep).
- Later visit: `records.sh` current or refreshed (executable); ledger and
  README untouched if they already existed; standalone commit only if
  standup printed `wrote:` lines (or write-only inside a sweep).
- `check` failed after a successful write: said the tool layer is up and
  named `/journal curate`.
