#!/usr/bin/env bash
# scoped-commit.sh <root> "<commit message>" <path> [<path>...]
#
# Stage AND commit *exactly* the named paths, in one atomic step, in the repository
# at <root>. Encodes the contended-shared-root rule once, portably: the root index
# is shared with concurrent worktree streams, and `git commit` records the ENTIRE
# index -- so a bare `git add -A` / `git commit -a` would sweep a sibling's staged files
# into your commit. Always scope with an explicit pathspec on BOTH add and commit.
#
# <root> is required (git -C) because an agent harness may reset cwd between tool
# calls -- an implicit-cwd commit can silently land in the wrong checkout/worktree.
#
# This script does the deterministic mechanic only. All judgment -- which paths, what
# message, whether to commit at all, and running the host's gate afterward --
# stays in the calling verb's prose. It never changes branches and never touches
# anything outside <path...>.
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "usage: scoped-commit.sh <root> \"<commit message>\" <path> [<path>...]" >&2
  echo "  refuses with no paths -- never stages the whole index." >&2
  exit 2
fi

root="$1"
msg="$2"
shift 2

[ -d "$root" ] || { echo "scoped-commit.sh: root not a directory: $root" >&2; exit 2; }

# Every remaining argument is a pathspec. Stage and commit scoped to exactly those.
# If the commit fails (hook, identity, nothing to commit), unstage the named paths
# again -- the shared index must never be left holding this call's staged residue.
git -C "$root" add -- "$@"
if ! git -C "$root" commit -m "$msg" -- "$@"; then
  git -C "$root" reset -q -- "$@" || true
  echo "scoped-commit.sh: commit failed; unstaged the named paths again." >&2
  exit 1
fi
