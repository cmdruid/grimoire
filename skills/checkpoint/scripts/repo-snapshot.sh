#!/usr/bin/env bash
# repo-snapshot.sh <root>
#
# Repo-state facts for /checkpoint's Save discipline -- the "Repo state" section
# (branch, clean/dirty) and the "What's been done" reconciliation against
# `git log`, in one read instead of several probes.
#
# DOCTRINE: facts, not verdicts. It reports state; the save prose decides what to
# write and synthesises it forward-looking. The wall-clock `date` here is correct
# (a hand-off is a dated snapshot meant to outlive the conversation -- unlike a
# determinism-bound build, real time is what you want). Read-only; bash-3.2 safe.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: repo-snapshot.sh <root>" >&2
  exit 2
fi
root="$1"

if ! git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
  echo "is_git_repo=false"
  echo "date=$(date +%Y-%m-%d)"
  exit 0
fi

porcelain="$(git -C "$root" status --porcelain 2>/dev/null || true)"
staged="$(printf '%s\n' "$porcelain" | grep -cE '^[MTADRCU]' || true)"
unstaged="$(printf '%s\n' "$porcelain" | grep -cE '^.[MTDU]' || true)"
untracked="$(printf '%s\n' "$porcelain" | grep -c '^??' || true)"

echo "is_git_repo=true"
echo "date=$(date +%Y-%m-%d)"
# Branch detection, structurally one line: symbolic-ref names the branch even on
# an UNBORN branch (HEAD is a symref to a not-yet-existing ref) and fails quietly
# on detached HEAD; the fallback's --verify -q emits NOTHING on failure (a bare
# `rev-parse HEAD` prints a stray "HEAD" line to stdout while fataling, which is
# exactly the two-line branch= defect this replaces).
branch="$(git -C "$root" symbolic-ref --short -q HEAD || true)"
detached=false
if [ -z "$branch" ]; then
  branch="$(git -C "$root" rev-parse --short --verify -q HEAD || true)"
  [ -n "$branch" ] && detached=true
fi
[ -n "$branch" ] || branch=unknown
echo "branch=$branch"
echo "detached=$detached"   # true => branch= holds a commit sha, not a branch name
echo "dirty=$([ -n "$porcelain" ] && echo true || echo false)"
echo "staged=$staged"
echo "unstaged=$unstaged"
echo "untracked=$untracked"

# Recent commits -- the source of truth for "What's been done"; reconcile the
# narrative against these rather than memory.
echo "recent_commits:"
git -C "$root" log -8 --format='  %h %s' 2>/dev/null || echo "  (none)"

# Dirty paths (capped) so the hand-off can name what's uncommitted. awk consumes
# ALL its input -- an early-closing reader (head) would SIGPIPE the printf under
# pipefail (observed exit 141 on a ~3000-file dirty list).
if [ -n "$porcelain" ]; then
  echo "dirty_paths:"
  printf '%s\n' "$porcelain" | awk 'NR<=20 { print "  " $0 }'
fi
