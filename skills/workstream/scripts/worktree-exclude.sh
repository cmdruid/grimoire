#!/usr/bin/env bash
# worktree-exclude.sh <worktree>
#
# Idempotently install the three shared runtime exclusions.
#
# For a linked worktree, `--git-path info/exclude` resolves to the SHARED common-dir
# exclude -- so one line covers every stream forever. The grep guard makes re-runs a
# no-op (a blind `>>` would accrete a duplicate line per `create` -- ISSUES W12).
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: worktree-exclude.sh <worktree>" >&2
  exit 2
fi

worktree="$1"
excl="$(git -C "$worktree" rev-parse --git-path info/exclude)"
# --git-path may return a RELATIVE path (a main checkout does); resolve it against
# the worktree, not the caller's cwd, or the line lands in the wrong file.
case "$excl" in /*) ;; *) excl="$worktree/$excl" ;; esac
for pattern in '/.streams/*/' '/WORKSTREAM.md' '/workstream.tsv'; do
  grep -qxF "$pattern" "$excl" || printf '%s\n' "$pattern" >>"$excl"
done
