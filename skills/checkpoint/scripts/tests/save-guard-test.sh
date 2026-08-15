#!/usr/bin/env bash
# save-guard-test.sh — fixture suite for save-guard.sh. mktemp fixtures only.
#
# The in-place fixture is built FROM workstream's own hand-off template
# (cross-skill coupling made red-able: if workstream renames the WORKSTREAM.md
# artifact, the `isolation:` key, or the Coordinates `branch:` line, the anchored
# transforms below stop matching and this suite fails — the guard's probe and the
# artifact it probes can no longer drift apart silently).
#
# GUARD_SH / WS_TEMPLATE override the script / template under test (used to prove
# the suite red against doctored copies).
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
GUARD="${GUARD_SH:-$DIR/../save-guard.sh}"
TEMPLATE="${WS_TEMPLATE:-$DIR/../../../workstream/templates/workstream-handoff.md}"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
OUT="$T/out"
run_guard() { bash "$GUARD" "$1" > "$OUT" 2>&1; echo "$?"; }
gitc() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}"; }

# ---- case 1: plain repo — no stream, nothing tracked/ignored ----------------
git init -q -b main "$T/plain"
gitc "$T/plain" commit -q --allow-empty -m init
rc="$(run_guard "$T/plain")"
expect_eq "plain exit 0" 0 "$rc"
expect "plain no worktree stream" "worktree_stream=false" "$OUT"
expect "plain no inplace stream" "inplace_stream=none" "$OUT"
expect "plain not tracked" "checkpoint_tracked=false" "$OUT"
expect "plain not ignored" "checkpoint_ignored=false" "$OUT"
expect_match "plain exclude_file absolute" '^exclude_file=/' "$OUT"

# ---- case 2: worktree stream — top-level WORKSTREAM.md ----------------------
git -C "$T/plain" worktree add -q -b stream/wt "$T/plain/.workstreams/wt" main
echo "# wt hand-off" > "$T/plain/.workstreams/wt/WORKSTREAM.md"
rc="$(run_guard "$T/plain/.workstreams/wt")"
expect_eq "worktree-stream exit 0" 0 "$rc"
expect "worktree stream detected" "worktree_stream=true" "$OUT"
# ...and the linked worktree's exclude resolves into the SHARED common dir:
expect_match "worktree exclude in common dir" '^exclude_file=.*/plain/\.git/info/exclude$' "$OUT"

# ---- case 3: in-place stream, fixture built FROM workstream's template ------
[ -f "$TEMPLATE" ] || { echo "FAIL: workstream hand-off template not found at $TEMPLATE" >&2; fail=$((fail+1)); finish "save-guard-test"; exit 1; }
git init -q -b main "$T/inp"
gitc "$T/inp" commit -q --allow-empty -m init
git -C "$T/inp" switch -q -c stream/ts
mkdir -p "$T/inp/.workstreams/ts"
sed -E \
  -e 's#^- branch:([[:space:]]*).*#- branch:\1stream/ts#' \
  -e 's#^- isolation:([[:space:]]*).*#- isolation:\1in-place#' \
  "$TEMPLATE" > "$T/inp/.workstreams/ts/WORKSTREAM.md"
# The anchored transforms must have actually bitten — if workstream renamed
# either key, these two asserts are the suite's red signal:
expect "template transform: branch line anchored" "- branch:" "$T/inp/.workstreams/ts/WORKSTREAM.md"
expect_match "template transform: isolation set" '^- isolation:[[:space:]]+in-place$' "$T/inp/.workstreams/ts/WORKSTREAM.md"
expect_match "template transform: branch set" '^- branch:[[:space:]]+stream/ts$' "$T/inp/.workstreams/ts/WORKSTREAM.md"

rc="$(run_guard "$T/inp")"
expect_eq "in-place (held) exit 0" 0 "$rc"
expect "in-place stream named" "inplace_stream=ts" "$OUT"
expect "custody held: branch matches" "inplace_branch_match=true" "$OUT"
expect "held tree is not a worktree stream" "worktree_stream=false" "$OUT"

git -C "$T/inp" switch -q main
rc="$(run_guard "$T/inp")"
expect "in-place (released) still named" "inplace_stream=ts" "$OUT"
expect "custody released: no branch match" "inplace_branch_match=false" "$OUT"

# ---- case 4: tracked CHECKPOINT.md beats any ignore -------------------------
echo wip > "$T/inp/CHECKPOINT.md"
git -C "$T/inp" add CHECKPOINT.md && gitc "$T/inp" commit -qm "track checkpoint" -- CHECKPOINT.md
rc="$(run_guard "$T/inp")"
expect "tracked detected" "checkpoint_tracked=true" "$OUT"

# ---- case 5: ignored via info/exclude ---------------------------------------
git init -q -b main "$T/ign"
gitc "$T/ign" commit -q --allow-empty -m init
echo "CHECKPOINT.md" >> "$T/ign/.git/info/exclude"
rc="$(run_guard "$T/ign")"
expect "ignored detected" "checkpoint_ignored=true" "$OUT"
expect "ignored but not tracked" "checkpoint_tracked=false" "$OUT"

# ---- case 6: not a repo -----------------------------------------------------
mkdir -p "$T/norepo"
rc="$(run_guard "$T/norepo")"
expect_eq "non-repo exit 0" 0 "$rc"
expect "non-repo fact" "is_git_repo=false" "$OUT"

finish "save-guard-test"
