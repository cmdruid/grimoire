#!/usr/bin/env bash
# save-guard.sh <dir>
#
# Pre-save facts for /checkpoint's save step 1 -- the stream guard (is this tree
# a workstream context?) and the root-file write guards (tracked? ignored? which
# exclude file?), in one read. Canonical for CHECKPOINT's prose sites; workstream
# carries its own probe for its own verbs.
#
# DOCTRINE: facts, not verdicts. The refusal decision (refuse-and-point-to-
# /workstream-save; stop-on-tracked) stays in the skill prose. Read-only;
# bash-3.2 safe; no dependency on the workstream skill being installed.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: save-guard.sh <dir>" >&2
  exit 2
fi
dir="$1"

if ! top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)"; then
  echo "is_git_repo=false"
  exit 0
fi
echo "is_git_repo=true"
echo "toplevel=$top"

# ---- stream facts -----------------------------------------------------------
# A worktree stream: the tree carries its own top-level hand-off.
echo "worktree_stream=$([ -f "$top/WORKSTREAM.md" ] && echo true || echo false)"

# An in-place stream: a hand-off under .workstreams/ records in-place isolation;
# custody shows as HEAD sitting on that stream's recorded branch.
head_branch="$(git -C "$top" symbolic-ref --short -q HEAD || true)"
[ -n "$head_branch" ] || head_branch="(detached)"
echo "head_branch=$head_branch"

inplace="none"
inplace_match=false
for f in "$top"/.workstreams/*/WORKSTREAM.md; do
  [ -f "$f" ] || continue
  grep -qE '^- isolation:[[:space:]]*in-place' "$f" || continue
  name="$(basename "$(dirname "$f")")"
  if [ "$inplace" = "none" ]; then inplace="$name"; else inplace="$inplace,$name"; fi
  sb="$(sed -n 's/^- branch:[[:space:]]*//p' "$f" | head -1 | sed 's/[[:space:]]*$//')"
  [ -n "$sb" ] && [ "$sb" = "$head_branch" ] && inplace_match=true
done
echo "inplace_stream=$inplace"
echo "inplace_branch_match=$inplace_match"   # true => the shared tree is held by that stream

# ---- root-file write guards -------------------------------------------------
# Tracked beats ignored: an exclude line cannot untrack a file.
echo "checkpoint_tracked=$(git -C "$top" ls-files --error-unmatch CHECKPOINT.md >/dev/null 2>&1 && echo true || echo false)"
echo "checkpoint_ignored=$(git -C "$top" check-ignore -q CHECKPOINT.md >/dev/null 2>&1 && echo true || echo false)"
# git-path output is cwd-relative (here: relative to <toplevel> via -C); resolve
# to absolute so a caller in any cwd appends to the right file. From a linked
# worktree it resolves into the shared common dir -- one line covers every checkout.
gp="$(git -C "$top" rev-parse --git-path info/exclude)"
case "$gp" in /*) ;; *) gp="$top/$gp" ;; esac
echo "exclude_file=$gp"
