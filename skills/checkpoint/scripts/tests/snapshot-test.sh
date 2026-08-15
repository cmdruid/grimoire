#!/usr/bin/env bash
# snapshot-test.sh — fixture suite for repo-snapshot.sh. mktemp fixtures only.
#
# SNAP_SH overrides the script under test (used to prove the suite red against a
# deliberately-broken or pre-fix copy — a suite that has never failed proves
# nothing).
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
SNAP="${SNAP_SH:-$DIR/../repo-snapshot.sh}"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
OUT="$T/out"
run_snap() { bash "$SNAP" "$1" > "$OUT" 2>&1; echo "$?"; }
gitc() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}"; }

# ---- case 1: not a git repo -------------------------------------------------
mkdir -p "$T/plain"
rc="$(run_snap "$T/plain")"
expect_eq "non-repo exit 0" 0 "$rc"
expect "non-repo fact" "is_git_repo=false" "$OUT"
expect_match "non-repo date shape" '^date=[0-9]{4}-[0-9]{2}-[0-9]{2}$' "$OUT"

# ---- case 2: unborn repo (the two-line branch= defect's home) ---------------
git init -q -b main "$T/unborn"
rc="$(run_snap "$T/unborn")"
expect_eq "unborn exit 0" 0 "$rc"
expect "unborn branch names the unborn ref" "branch=main" "$OUT"
expect "unborn not detached" "detached=false" "$OUT"
expect_eq "exactly one branch= line" 1 "$(grep -c '^branch=' "$OUT")"
expect_eq "no stray bare 'unknown' line" 0 "$(grep -cx 'unknown' "$OUT")"
expect_eq "every line is key=value / list shape" 0 \
  "$(grep -cvE '^([a-z_]+=|[a-z_]+:$|  )' "$OUT")"

# ---- case 3: normal repo, clean --------------------------------------------
git init -q -b main "$T/norm"
gitc "$T/norm" commit -q --allow-empty -m "first commit"
rc="$(run_snap "$T/norm")"
expect_eq "normal exit 0" 0 "$rc"
expect "normal branch" "branch=main" "$OUT"
expect "normal clean" "dirty=false" "$OUT"
expect "recent commits listed" "first commit" "$OUT"
expect_match "commit line shape (hash normalized)" '^  [0-9a-f]{7,} first commit$' "$OUT"

# ---- case 4: detached HEAD --------------------------------------------------
git -C "$T/norm" checkout -q --detach
rc="$(run_snap "$T/norm")"
expect_eq "detached exit 0" 0 "$rc"
expect "detached flagged" "detached=true" "$OUT"
expect_match "detached branch= holds a short sha" '^branch=[0-9a-f]{7,}$' "$OUT"
expect_eq "still exactly one branch= line" 1 "$(grep -c '^branch=' "$OUT")"
git -C "$T/norm" checkout -q main

# ---- case 5: large dirty list (the SIGPIPE/141 defect's home) ---------------
i=1
while [ "$i" -le 3000 ]; do
  echo x > "$T/norm/a-long-untracked-filename-padding-the-pipe-buffer-well-past-64k-$i.txt"
  i=$((i + 1))
done
rc="$(run_snap "$T/norm")"
expect_eq "large dirty list exit 0 (no SIGPIPE under pipefail)" 0 "$rc"
expect "large dirty list dirty=true" "dirty=true" "$OUT"
expect "untracked count" "untracked=3000" "$OUT"
expect_eq "dirty_paths capped at 20" 20 "$(grep -c '^  ?? ' "$OUT")"

finish "snapshot-test"
