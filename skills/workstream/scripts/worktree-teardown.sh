#!/usr/bin/env bash
# worktree-teardown.sh <root> <stream> [--force]
#
# The lean `close` teardown (SKILL.md close, step 2): remove the worktree, force-delete
# the branch, prune. The deterministic mechanic only -- the JUDGMENT that precedes it
# (is the branch fully merged? ship-or-discard any unshipped WIP? the default is discard)
# stays in `close`'s prose and must be settled BEFORE calling this.
#
# Pass --force when WIP was discarded or the worktree is otherwise dirty (e.g. a
# drafted-next-plan left uncommitted by the last ship). WORKSTREAM.md is excluded, so it
# never blocks removal. `branch -D` is safe here: by this point the branch is either
# merged or deliberately discarded.
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

worktree="$root/.workstreams/$stream"
branch="stream/$stream"
script_dir="$(cd "$(dirname "$0")" && pwd)"
resource_helper="$script_dir/workstream-resource.sh"
handoff="$worktree/WORKSTREAM.md"

# Fail closed before any destructive Git command. --force never bypasses this gate.
validation="$($resource_helper validate "$root" "$stream" "$handoff")" || {
  printf '%s\n' "$validation" >&2
  echo "worktree-teardown.sh: resource validation refused teardown" >&2
  exit 1
}
printf '%s\n' "$validation" | grep -q '^held_count=0$' || {
  printf '%s\n' "$validation" >&2
  echo "worktree-teardown.sh: held resources refuse teardown" >&2
  exit 1
}

if [ "$force" = "--force" ]; then
  git -C "$root" worktree remove --force "$worktree"
else
  git -C "$root" worktree remove "$worktree"
fi
git -C "$root" branch -D "$branch"
git -C "$root" worktree prune
