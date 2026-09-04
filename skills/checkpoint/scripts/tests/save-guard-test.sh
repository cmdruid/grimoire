#!/usr/bin/env bash
# save-guard-test.sh — fixture suite for save-guard.sh. mktemp fixtures only.
#
# GUARD_SH overrides the script under test for mutation proofs.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$DIR/lib.sh"
GUARD="${GUARD_SH:-$DIR/../save-guard.sh}"

if [ -x "$GUARD" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: save-guard.sh is not executable although the skill invokes it directly" >&2
  fail=$((fail + 1))
fi
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
expect "plain target reported" "checkpoint_target=CHECKPOINT.md" "$OUT"
expect "plain not tracked" "checkpoint_tracked=false" "$OUT"
expect "plain not ignored" "checkpoint_ignored=false" "$OUT"
expect "plain temp not tracked" "temp_tracked=false" "$OUT"
expect "plain temp not ignored" "temp_ignored=false" "$OUT"
expect_match "plain exclude_file absolute" '^exclude_file=/' "$OUT"

# ---- case 2: worktree stream — top-level WORKSTREAM.md ----------------------
git -C "$T/plain" worktree add -q -b stream/wt "$T/plain/.streams/wt" main
echo "# wt runbook" > "$T/plain/.streams/wt/WORKSTREAM.md"
rc="$(run_guard "$T/plain/.streams/wt")"
expect_eq "worktree-stream exit 0" 0 "$rc"
expect "worktree stream detected" "worktree_stream=true" "$OUT"
# ...and the linked worktree's exclude resolves into the SHARED common dir:
expect_match "worktree exclude in common dir" '^exclude_file=.*/plain/\.git/info/exclude$' "$OUT"

# ---- case 3: sibling runtime handoffs do not claim the primary checkout -----
rc="$(run_guard "$T/plain")"
expect_eq "primary with sibling runtime exits 0" 0 "$rc"
expect "sibling runtime is ignored for custody" "worktree_stream=false" "$OUT"

# ---- case 4: tracked root checkpoint beats any ignore -----------------------
echo wip > "$T/plain/CHECKPOINT.md"
git -C "$T/plain" add -f CHECKPOINT.md
gitc "$T/plain" commit -qm "track checkpoint" -- CHECKPOINT.md
rc="$(run_guard "$T/plain")"
expect "tracked detected" "checkpoint_tracked=true" "$OUT"
echo temp > "$T/plain/CHECKPOINT.md.tmp"
git -C "$T/plain" add -f CHECKPOINT.md.tmp
gitc "$T/plain" commit -qm "track checkpoint temp" -- CHECKPOINT.md.tmp
rc="$(run_guard "$T/plain")"
expect "tracked temp detected" "temp_tracked=true" "$OUT"

# ---- case 5: ignored via info/exclude ---------------------------------------
git init -q -b main "$T/ign"
gitc "$T/ign" commit -q --allow-empty -m init
printf '/CHECKPOINT.md\n/CHECKPOINT.md.tmp\n' >> "$T/ign/.git/info/exclude"
rc="$(run_guard "$T/ign")"
expect "ignored detected" "checkpoint_ignored=true" "$OUT"
expect "ignored but not tracked" "checkpoint_tracked=false" "$OUT"
expect "temp ignored detected" "temp_ignored=true" "$OUT"

# ---- case 6: not a repo -----------------------------------------------------
mkdir -p "$T/norepo"
rc="$(run_guard "$T/norepo")"
expect_eq "non-repo exit 0" 0 "$rc"
expect "non-repo fact" "is_git_repo=false" "$OUT"

finish "save-guard-test"
