#!/usr/bin/env bash
# save-guard.sh <root>
#
# Read-only preflight facts for Checkpoint's single root file. Decisions and
# writes stay in the verb/helper. Bash 3.2 safe; no sibling-skill dependency.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: save-guard.sh <root>" >&2
  exit 2
fi
root="$1"

if ! top="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)"; then
  echo "is_git_repo=false"
  exit 0
fi
echo "is_git_repo=true"
echo "toplevel=$top"
echo "checkpoint_target=CHECKPOINT.md"
echo "temporary_target=CHECKPOINT.md.tmp"

echo "worktree_stream=$([ -f "$top/WORKSTREAM.md" ] && [ ! -L "$top/WORKSTREAM.md" ] && echo true || echo false)"
head_branch="$(git -C "$top" symbolic-ref --short -q HEAD || true)"
[ -n "$head_branch" ] || head_branch="(detached)"
echo "head_branch=$head_branch"

inplace="none"
inplace_match=false
for f in "$top"/.streams/*/WORKSTREAM.md; do
  [ -f "$f" ] && [ ! -L "$f" ] || continue
  grep -qE '^isolation[[:space:]]+in-place$' "$f" || continue
  name="$(basename "$(dirname "$f")")"
  if [ "$inplace" = "none" ]; then inplace="$name"; else inplace="$inplace,$name"; fi
  branch="$(sed -n 's/^branch[[:space:]]*//p' "$f" | head -1 | sed 's/[[:space:]]*$//')"
  [ -n "$branch" ] && [ "$branch" = "$head_branch" ] && inplace_match=true
done
echo "inplace_stream=$inplace"
echo "inplace_branch_match=$inplace_match"

tracked() { git -C "$top" ls-files --error-unmatch -- "$1" >/dev/null 2>&1 && echo true || echo false; }
ignored() { git -C "$top" check-ignore -q -- "$1" >/dev/null 2>&1 && echo true || echo false; }
echo "checkpoint_tracked=$(tracked CHECKPOINT.md)"
echo "checkpoint_ignored=$(ignored CHECKPOINT.md)"
echo "temp_tracked=$(tracked CHECKPOINT.md.tmp)"
echo "temp_ignored=$(ignored CHECKPOINT.md.tmp)"

gp="$(git -C "$top" rev-parse --git-path info/exclude)"
case "$gp" in /*) ;; *) gp="$top/$gp" ;; esac
echo "exclude_file=$gp"
