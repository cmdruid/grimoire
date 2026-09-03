#!/usr/bin/env bash
# worktree-teardown.sh <root> <stream> [--force]
#
# The lean `close` teardown (SKILL.md close, step 2): remove the worktree, force-delete
# the branch, prune. The deterministic mechanic only -- the JUDGMENT that precedes it
# (is the branch fully merged? ship-or-discard any unshipped WIP? the default is discard)
# stays in `close`'s prose and must be settled BEFORE calling this.
#
# Pass --force when WIP was deliberately discarded or the worktree is otherwise dirty.
# WORKSTREAM.md and workstream.tsv are excluded, so they never block removal. `branch -D`
# is safe here only after the caller has proved the branch landed or obtained discard authority.
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: worktree-teardown.sh <root> <stream> [--force]" >&2
  exit 2
fi

root="$1"
stream="$2"
force="${3:-}"
if [ -n "$force" ] && [ "$force" != "--force" ]; then
  echo "worktree-teardown.sh: unrecognized argument '$force' (only --force is accepted)" >&2
  exit 2
fi

case "$stream" in ''|*[!a-z0-9-]*|-*|*-|*--*) echo 'worktree-teardown.sh: invalid stream name' >&2; exit 2;; esac
root="$(cd "$root" && pwd -P)"
worktree="$root/.streams/$stream"
branch="stream/$stream"
[ -d "$worktree" ] && [ ! -L "$worktree" ] || { echo 'worktree-teardown.sh: unsafe worktree coordinate' >&2; exit 2; }
top="$(git -C "$worktree" rev-parse --show-toplevel)"
[ "$top" = "$worktree" ] || { echo 'worktree-teardown.sh: worktree coordinate mismatch' >&2; exit 2; }
[ "$(git -C "$worktree" branch --show-current)" = "$branch" ] || { echo 'worktree-teardown.sh: branch mismatch' >&2; exit 2; }
git -C "$root" worktree list --porcelain | grep -qxF "worktree $worktree" || { echo 'worktree-teardown.sh: unregistered worktree' >&2; exit 2; }

if [ "$force" = "--force" ]; then
  git -C "$root" worktree remove --force "$worktree"
else
  git -C "$root" worktree remove "$worktree"
fi
git -C "$root" branch -D "$branch"
git -C "$root" worktree prune
