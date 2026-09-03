#!/usr/bin/env bash
# worktree-teardown.sh <root> <stream> [--force]
#
# The lean `close` teardown: remove only the admitted runtime and branch, then prune.
# The deterministic mechanic only -- the JUDGMENT that precedes an explicit discard
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
runtime="$root/.streams/$stream"
branch="stream/$stream"
[ -d "$runtime" ] && [ ! -L "$runtime" ] || { echo 'worktree-teardown.sh: unsafe runtime coordinate' >&2; exit 2; }
[ -f "$runtime/WORKSTREAM.md" ] && [ ! -L "$runtime/WORKSTREAM.md" ] || { echo 'worktree-teardown.sh: runbook is unsafe' >&2; exit 2; }
[ -f "$runtime/workstream.tsv" ] && [ ! -L "$runtime/workstream.tsv" ] || { echo 'worktree-teardown.sh: tracker is unsafe' >&2; exit 2; }
if awk -F '\t' '$1=="shipment" || ($1=="hook"&&$3=="state"&&($4=="ready"||$4=="running")){blocked=1}END{exit blocked?0:1}' "$runtime/workstream.tsv"; then
  echo 'worktree-teardown.sh: unresolved lifecycle state blocks teardown' >&2
  exit 2
fi
isolation="$(sed -n 's/^isolation[[:space:]]*//p' "$runtime/WORKSTREAM.md" | head -n 1)"
recorded_worktree="$(sed -n 's/^worktree[[:space:]]*//p' "$runtime/WORKSTREAM.md" | head -n 1)"
target="$(sed -n 's/^target[[:space:]]*//p' "$runtime/WORKSTREAM.md" | head -n 1)"
landing="$(sed -n 's/^landing[[:space:]]*//p' "$runtime/WORKSTREAM.md" | head -n 1)"
git -C "$root" rev-parse --verify --quiet "$target^{commit}" >/dev/null || { echo 'worktree-teardown.sh: target does not resolve' >&2; exit 2; }
if [ "$force" != "--force" ]; then
  if [ "$landing" = pr ]; then
    git -C "$root" fetch -q origin "refs/heads/$target" || { echo 'worktree-teardown.sh: cannot fetch merged PR target' >&2; exit 2; }
    git -C "$root" merge-base --is-ancestor "$branch" FETCH_HEAD || { echo 'worktree-teardown.sh: stream branch is not contained in remote target' >&2; exit 2; }
  else
    git -C "$root" merge-base --is-ancestor "$branch" "$target" || { echo 'worktree-teardown.sh: stream branch is not contained in target' >&2; exit 2; }
  fi
fi

if [ "$isolation" = in-place ]; then
  [ "$recorded_worktree" = "$root" ] || { echo 'worktree-teardown.sh: in-place coordinate mismatch' >&2; exit 2; }
  [ -z "$(git -C "$root" status --porcelain --untracked-files=no)" ] || { echo 'worktree-teardown.sh: tracked work is dirty' >&2; exit 2; }
  current="$(git -C "$root" branch --show-current)"
  if [ "$current" = "$branch" ]; then git -C "$root" switch -q "$target"; else [ "$current" = "$target" ] || { echo 'worktree-teardown.sh: branch mismatch' >&2; exit 2; }; fi
  [ "$(find "$runtime" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" -eq 2 ] || { echo 'worktree-teardown.sh: unknown runtime content' >&2; exit 2; }
  rm -f "$runtime/WORKSTREAM.md" "$runtime/workstream.tsv"
  rmdir "$runtime"
  git -C "$root" branch -D "$branch"
  exit 0
fi

worktree="$runtime"
[ "$isolation" = worktree ] || { echo 'worktree-teardown.sh: unknown isolation' >&2; exit 2; }
[ "$recorded_worktree" = "$worktree" ] || { echo 'worktree-teardown.sh: recorded worktree mismatch' >&2; exit 2; }
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
