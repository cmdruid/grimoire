# `sync`  · runs in the worktree (pulls the trunk -> worktree)

0. **(In-place streams with `landing: push | pr` only)** refresh the local trunk from the remote
   first: `git -C <root> fetch origin <target>:<target>` — safe while the stream holds the tree
   (`<target>` is not checked out). A rejected (non-fast-forward) refresh with the LOCAL trunk
   ahead is not an error — it means a landed-but-unpushed ship (**push pending**): finish the push
   tail (`verbs/ship.md`) rather than forcing anything. If the stream is parked ON `<target>`, use
   `git -C <root> pull --ff-only` instead. `landing: local` (and every worktree stream) skips this — there the trunk
   moves only by local ships.
   If the hand-off carries an `Open PR:` line (a `landing: pr` ship whose queue advance was
   deferred): after the refresh, check the PR state (`gh pr view <branch> --json state`, or test
   whether `<target>` now contains the branch's changes). If MERGED: run the deferred queue advance
   (mark the landed features done in the hand-off, set the next item current — ship step 3's
   hand-off part), remove the `Open PR:` line, then `git -C <root> rebase <target>` to re-baseline
   (squash-merged commits replay as empty and are dropped) — the gate-by-what-lands matrix
   (step 3) is a deliberate no-op on this pass: post-rebase the branch sits EMPTY on
   `<target>`'s already-green tip (your own work landed via the PR; any sibling content was
   gated when it landed), which is the matrix's skip case by construction. The next
   feature's commits re-enter the normal sync/gate flow. If still open, continue — the
   queue stays deferred.

   **Custody check (in-place, all landing modes):** if `inplace-state` reports
   `on_stream_branch=false`, STOP — while the trunk is checked out, step 2's `rebase <target>`
   silently no-ops (the stream branch never moves) and reports a sync that didn't happen. Parked →
   `load` (unpark) first; foreign → report.

1. **Read `workstream-git.sh land-readiness <root> <worktree> <branch> <target>`** (root/branch/`<target>`
   = this stream's Coordinates — `<target>` is the `integration-target`, never hardcode `main`). `behind=0`
   ⇒ report "up to date" and stop. Otherwise its `will_conflict` / `conflict_files:` **forecast** the rebase
   you're about to run — feeding the pre-flight in step 2. (One call replaces the old bare `git log`
   behind-check and carries the forecast for free; the `root_*`/`ff_safe` facts it also computes are unused
   here — those matter at Landing, `verbs/ship.md`.)
2. **Capture the pre-rebase base** (you need it to scope the re-gate):
   `BASE=$(git -C <worktree> merge-base <branch> <target>)`. Then
   `git -C <worktree> rebase <target>`. Resolve conflicts (commonly additive: a shared registration
   point — config/module/system registry — build manifests, or shared `.records/` ledger files — usually
   "keep both"), then
   `git -C <worktree> add <file>` and `GIT_EDITOR=true git -C <worktree> rebase --continue`.
   - **Pre-flight the collision (from step 1's forecast).** You already hold `will_conflict` /
     `conflict_files:` — so resolve the named files deliberately and know up front whether a
     `REVIEW(conflict):` marker is coming, instead of being surprised mid-rebase. It's a forecast
     (`merge-tree` models a merge; this is a rebase) — the rebase is truth.
   - **Contentious resolutions — mark them for a review pass.** Most conflicts are routine (the additive
     "keep both" above) — **don't** flag those (noise). But when a resolution is *contentious* — you
     **overrode or dropped one side's intent**, took a **shortcut/hack** to make it compile or pass, or
     resolved a **semantic** conflict (both sides changed the same logic) without confidence both intents
     survived — capture it **at the moment** (not deferred to reset, where the detail is lost), two ways:
     - leave a grep-able marker at the band-aid site: `// REVIEW(conflict): <one-line why>` — this **is**
       the review-pass target, and it satisfies the host's annotate-debt-in-source rule;
     - add a one-line entry to the host's dev-experience/friction tracker (workshop host: an **Issues**
       tracker line via `/journal issue`; else the project's own) tagged
       `[conflict band-aid]`: `<file:line>` + why + this stream's name.
     A later review pass walks `grep -rn "REVIEW(conflict)"` (or the `[conflict band-aid]` entries) with
     the host's code-review tooling or `/feature review`.
3. **Re-gate by what the rebase actually pulled in — the gate-by-what-lands matrix.** This is the
   canonical decision (Landing step 2 in `verbs/ship.md` applies this same matrix): do NOT
   blanket-run the full gate. A rebase that only
   replays sibling commits onto your branch does not, by itself, require a full gate — that sibling
   code was already gated when it landed on `<target>`, and your own work hasn't changed. Read both
   axes from
   `workstream-git.sh gate-facts <worktree> <branch> <target>` (SKILL.md -> *Helper scripts*) — where
   **docs-only == every changed path ends in `.md`** and anything else (`*.rs`, build manifests,
   `*.ron` data) is **build-relevant**:
   - **`own_docs_only=false` AND `incoming_docs_only=false`** → run the host's **full gate** (the only
     case the clean-rebase-≠-green-build trap can fire — your code recompiled against changed sibling
     code).
   - **`own_docs_only=true`** → the host's **fast doc-linter** only, **even after a code-heavy rebase**
     (markdown doesn't compile; the incoming code is already green on `<target>`).
   - **`own_docs_only=false` but `incoming_docs_only=true`** → **skip the re-gate** (the sync brought
     nothing that can break your compile; your last green gate holds). Skip equally when you have
     **already gated this `<target>` tip this turn** — a fact `gate-facts` can't see.
   - **`incoming_empty=true` / up to date / no replay** → nothing to re-run.
   This is the fix for the fresh-stream full-build: a markdown-only stream that rebases onto a moved
   `<target>` now runs at most the seconds-long doc-linter, never a from-scratch full build. Report
   which path you took and the result. (The concrete gate and doc-linter are the host's — surfaced in
   its `AGENTS.md` / `.handbook/test/`; the docs-vs-build split needs no host globs, it is just the `.md`
   test, so it stays portable.)

`sync` **does not save** — it rebases + gates, nothing else (saves are coupled to the reset;
`flow.md` -> *Reset ritual*). If a reset is imminent after a sync, the flow's pre-reset checkpoint
makes the save; a sync that lands right after a `load` has nothing to checkpoint.
