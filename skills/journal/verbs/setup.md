# `setup` — stand up or refresh the records tool layer

Stage `records.sh` at the agent-records root and stand up the empty ledger and records README in a
target project — or refresh `records.sh` on a later visit. Works standalone on any
repo; this is also the records step a workshop setup delegates (the workshop
never improvises a records layer of its own). It creates **no writer
directory and no pre-seeded `templates/`**.

1. **Resolve the three facts** (judgment stays here, mechanics are scripted):
   - `<root>`: `git rev-parse --show-toplevel` of the checkout that should
     hold the records; else a project directory the conversation
     references; else ask. Read `AGENTS.md` / `CLAUDE.md` under that root.
   - `<agent-records>`: first line-start `agent-records:` or `records-root:` in
     `AGENTS.md`, then `CLAUDE.md`; else `.records`. Never invent a third location.
     The relative path must have no leading `/` and no `..` segment (standup
     refuses otherwise). Pass it as `--records-root`.
   - `<agent-workspace>`: first line-start `agent-workspace:` in those same files;
     else `.spaces`. Apply the same relative-path constraints and pass it as `--workspace-root`.
     Setup derives the exact prior tool path `<agent-workspace>/journal/scripts/records.sh`
     internally; callers never select a cleanup target.
2. **Run or resume the mechanics**: `scripts/standup.sh setup <root> --records-root <rel>
   --workspace-root <rel>` —
   creates the agent-records home directory itself if needed, installs or
   refreshes `records.sh` at `<agent-records>/records.sh`, seeds an empty
   `history.tsv` only if missing, creates the records README if absent, refreshes only Journal's
   delimited `journal:records-tool` block when present, safely replaces the exact prior generated
   workspace-tool paragraph, and self-checks. Surrounding project prose is preserved. It is
   additive (a home that merely exists — a leftover
   path, or a notepad-created `.records/notes/` with no tool — is fine). It
   does not `mkdir` writer directories, write `.gitkeep`, or copy templates.
   Every non-clean invocation atomically creates or resumes
   `<agent-workspace>/journal/setup.intent` before changing the tool layer. It validates the
   recorded roots and already-complete results, executes only incomplete steps, and reports the
   complete cross-attempt union as `wrote: <repo-relative-path>` lines. The intent is transient:
   never report, stage, or commit it. A clean invocation creates no intent and reports no writes.
   **First visit** (no staged `records.sh`): stands the layer.
   **Later visit** (script present): refreshes `records.sh` and its README block when the skill
   copy has drifted (`current` vs `refreshed`); restores the executable bit
   if needed; removes the obsolete workspace-staged engine; then `check`; never migrates records,
   truncates the ledger, or overwrites prose outside Journal's block.
   **Exit 2**: missing target directory, or missing skill-side `records.sh`
   → STOP and report.
   **Exit 1**: usage, a bad root, or an unsafe/symlinked destination.
   If standup wrote the tool and then `check` failed, the tool layer **is
   up** — report that and point at `/journal curate`. That is not a setup
   refuse.
   Converting legacy record content or metadata is a migration the human named, not this verb.
   Legacy records remain unchanged and are routed to the owning skill's explicit `migrate` verb.
3. **Take custody, then finalize.** Parse each unique
   `wrote: <path>` line from standup stdout. Before calling the commit helper, omit a reported path
   only when it is now absent **and** `git -C <root> ls-files --error-unmatch -- <path>` confirms it
   was untracked (the obsolete tool may have come from an interrupted, never-committed setup).
   Standalone →
   `scripts/scoped-commit.sh <root> "Stand up the records layer" <those
   paths>`, then `scripts/standup.sh finalize <root> --records-root <rel>
   --workspace-root <rel>`. Never pass the records-root directory as a pathspec. A ready rerun with
   no outstanding Git change across its reported union revalidates and finalizes without attempting
   an empty commit. Inside a client's announced sweep → retain the complete union in the sweep's
   approved diff custody, then finalize without a nested commit. No intent means the setup was a
   clean no-op: do not commit or call finalize. Any interruption before finalization → rerun setup;
   do not delete or hand-edit the intent.

## Done when

- First visit: tool layer stood up — staged `records.sh` + empty ledger + README with current
  managed block; no writer directories created; standalone commit landed on the
  `wrote:` paths (or write-only inside a sweep); no setup intent remains.
- Later visit: `records.sh` and the managed README block current or refreshed; obsolete
  workspace-staged tool absent; ledger and surrounding README prose untouched; standalone commit
  only if standup printed `wrote:` lines (or write-only inside a sweep); no setup intent remains.
- `check` failed after a successful write: said the tool layer is up and
  named `/journal curate`.
