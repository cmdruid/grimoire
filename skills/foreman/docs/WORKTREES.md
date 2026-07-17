# Git worktrees

When more than one stream of feature work is in flight, each needs its own checked-out **source**
tree so one stream's edits or build can't clobber another's. **Git worktrees** give each its own
working directory backed by the same repository. This file is the policy and the load-bearing
rules; follow the rules exactly.

## When to use one

Use a worktree for **anything that earns a feature branch** -- a feature, a roadmap/track, or any
multi-commit scope. Patches, emergency fixes, and small changes unrelated to a feature stay on
`main`. Rule of thumb: *if it'd get its own branch, give it a worktree.*

`.agents/dev/` work scoped to a feature (its plan, its hand-off) rides in that feature's worktree and merges
with it; small standalone `.agents/dev/` edits -- a backlog entry, a doc tweak -- go straight on `main`. The
load-bearing rule is **no *uncommitted* churn on the shared root**, not "never touch `.agents/dev/` on
`main`."

A **large, multi-commit dev-system / meta overhaul** (a skills refactor, a tracker-lifecycle change,
a doc-system restructure) earns a **worktree** even though each individual edit is patch-sized -- the
batch behaves like a feature, and isolating it avoids the shared-`main` thrash a long run of patches
invites while other streams merge.

## The rules (load-bearing -- don't break these)

- **One worktree per branch**, under `.workstreams/<name>/` (gitignored). Never check out the
  same branch in two worktrees -- git forbids it, and it signals two agents fighting over one task.
- **No remote (if this repo is local-only).** New branches come off your local `main`; integration
  is a local **rebase then `merge --ff-only`**, never a PR. (If the repo has a remote, adapt
  accordingly -- the rebase-before-merge rule still holds.)
- **The root checkout is shared -- never assume it's clean or on `main`.** Other streams share it; it
  may hold another agent's branch or uncommitted work. Whatever you do directly on `main`, **commit
  promptly** -- uncommitted churn on the shared root throws off everyone else. Branch a new worktree
  from the `main` *ref* explicitly, so a dirty or off-`main` root can't corrupt its base.
- **Shared `main` is contended -- mutate it atomically.** Other agents may be staging/committing to
  the root checkout *concurrently*. So on `main`: stage **explicit paths**, never `git add -A` /
  `commit -a` -- it sweeps another agent's in-flight files. A `<stack: gate-then-commit helper that
  runs the gate, then stages and commits ONLY the named paths (never `git add -A`)>` makes this the
  easy path. Do each stage->commit (or `merge --ff-only`) as **one step**, not leaving staged/unstaged
  work sitting in the root tree across tool calls -- that lingering window is exactly when another
  agent's `-A` sweeps you. A failed `--ff-only` just means "rebase, you're behind," never corruption.
- **`cd` does not stick; subagents don't mutate.** The harness does not reliably persist the working
  directory between tool calls, so a `cd <worktree>` can silently revert -- later file ops then hit
  `main`. This has corrupted `main` more than once. So: use **absolute worktree paths** for file ops
  and `git -C <worktree>` for commands; verify `git -C <worktree> rev-parse --show-toplevel` before
  you commit. A **dispatched sub-agent can't hold cwd across its own calls**, so subagents are
  **read-only** in a worktree -- never editing or committing.
- **Runtime output is not source.** Anything a run inside a worktree writes to build or output
  directories (`<stack: runtime output dirs>`) is gitignored -- never commit it, and don't let a
  stray `git add -A` sweep it in.

## Mechanics

```sh
# create -- branch explicitly from the main ref (the root may be on another branch):
git worktree add -b stream/<name> .workstreams/<name> main

# integrate -- main almost certainly moved while you worked:
git -C <worktree> rebase main                 # replay your commits onto main's tip; resolve, re-gate
git -C <root> merge --ff-only stream/<name>   # fast-forward main to the rebased, tested tip

# tear down -- only when the stream is exhausted or abandoned (a workstream's worktree
# PERSISTS across features; `ship` lands a feature and keeps looping, `close` tears down):
git worktree remove .workstreams/<name>
git branch -d stream/<name>                   # -D to force-delete an unmerged branch
git worktree prune                            # tidy stale metadata
```

`git worktree list` shows every active worktree and the branch each holds. Common rebase conflicts
are additive (config files, registration chains, shared `.agents/dev/` coordination files) -- resolution is
usually "keep both". Each worktree has its own build output directory.

`<stack: shared compile cache note>` -- if the stack supports it, a per-machine shared compile
cache (e.g. `sccache` for Rust) lets a fresh worktree reuse cached dependency builds rather than
recompiling from scratch. Never commit a cache config.

Run the gate (`<gate>`) in a fresh worktree before changing anything to verify a clean baseline.

## Disk discipline

Each worktree carries its **own** build output directory, which can grow large for compiled
projects. So:

- **Prune at stream end, not after each feature.** A workstream's worktree **persists** while its
  queue has features (`ship` lands one and keeps looping); tear it down only when the stream is
  exhausted or abandoned (`/workstream close` -> `git worktree remove <path>` + `git branch -d
  <branch>`). A worktree left behind *after a stream is done* is dead build artifacts.
- **Park with a clean build.** A persisting stream's worktree that's idle between features can
  clean its build output (`<stack: clean build command>`) to reclaim disk until work resumes.
- **No shared build output dir.** Pointing all worktrees at one output dir is tempting but
  problematic for tools that take exclusive locks -- parallel builds would serialize. Use a
  per-machine shared compile cache instead, if the stack supports one.
