# `close`  · runs at the seam (tear down — queue exhausted or paused)

**`close` is a lean teardown — by default it creates no artifacts, makes no root commit, and writes
no record.** The stream's durable trail already exists: every shipped feature left its ledger entry
(and any debrief report) at `ship`, and follow-ups were already routed by the reset ritual's `debrief`. Do
**not** re-capture at close — no close record, no Feedback/Issues/notes sweep, no
`<target>` advance. (If a close is *genuinely* eventful and you have unrouted learnings, run
`/journal debrief` explicitly **before** closing — the user's call, never the default path.) The common case
(queue exhausted, nothing unshipped) is **three git commands** and no token-heavy bookkeeping.

`<target>` = the workstream's `integration-target` (Coordinates).

1. **Decide what happens to unshipped WIP** — `git -C <worktree> log <target>..<branch> --oneline`
   (this same check is the merge-safety guard: empty ⇒ the branch is fully merged into `<target>`):
   - **Empty** (nothing unshipped) → go straight to teardown.
   - **Non-empty** → surface the unshipped commits and ask **ship or discard** (**default discard** —
     never auto-land at close). On *ship*: run `ship` (`verbs/ship.md` — its Landing sequence) first
     so nothing is stranded, then teardown. On *discard*: teardown with `--force`.
2. **Teardown** (the worktree-local `WORKSTREAM.md` is scratch — discarded here, never merged) —
   once the step-1 ship-or-discard decision is settled, run this skill's bundled
   `scripts/worktree-teardown.sh <root> <stream> [--force]` (resolve `scripts/` from the skill's own
   base directory, not the host project), which does the three mechanical steps:
   - `git -C <root> worktree remove <root>/.workstreams/<stream>` — pass `--force` (the script's 3rd
     arg) if WIP was discarded or the worktree is otherwise dirty (e.g. a drafted-next-plan left
     uncommitted by the last `ship`); `WORKSTREAM.md` itself is excluded so it never blocks a clean
     removal.
   - `git -C <root> branch -D <branch>` — force-delete is safe: the branch is either merged (step 1
     was empty / you just shipped) or deliberately discarded, so the no-op of confirming `--merged`
     against the right ref is unneeded.
   - `git -C <root> worktree prune`.

   **In-place teardown** (`isolation: in-place`) — no worktree to remove; once step 1's
   ship-or-discard is settled: clear the tree first — a plain `git switch` CARRIES
   uncommitted/untracked files (a drafted next plan, WIP) onto `<target>` as foreign dirt (or
   refuses on tracked changes); on *discard*, `git -C <root> reset --hard` + remove stray
   untracked files explicitly (never silently — name what you delete); on *ship*, the land itself
   required a clean tree, but ship's step 3 may have since drafted the next plan uncommitted —
   bank or remove that deliberately too. Then: `git -C <root> switch <target>` (hand the tree back), then
   `git -C <root> branch -D <branch>`, then `rm -rf <root>/.workstreams/<stream>/` (hand-off
   directory — scratch, never merged). `worktree-teardown.sh` is not invoked.

   Any ADR stays live in the records root's `adr/` store.
