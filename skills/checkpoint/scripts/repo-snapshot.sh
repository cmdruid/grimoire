#!/usr/bin/env bash
# repo-snapshot.sh <root>
#
# Repo-state facts for /handoff's Save discipline -- the "Repo state" section
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
echo "branch=$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
echo "dirty=$([ -n "$porcelain" ] && echo true || echo false)"
echo "staged=$staged"
echo "unstaged=$unstaged"
echo "untracked=$untracked"

# Recent commits -- the source of truth for "What's been done"; reconcile the
# narrative against these rather than memory.
echo "recent_commits:"
git -C "$root" log -8 --format='  %h %s' 2>/dev/null || echo "  (none)"

# Dirty paths (capped) so the hand-off can name what's uncommitted.
if [ -n "$porcelain" ]; then
  echo "dirty_paths:"
  printf '%s\n' "$porcelain" | head -20 | sed 's/^/  /'
fi
