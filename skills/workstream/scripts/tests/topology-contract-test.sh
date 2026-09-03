#!/usr/bin/env bash
# Canonical coordinates and Git topology, not ignore files, prevent nesting.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-topology.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
init_repo "$ROOT"
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial
mkdir -p "$ROOT/.streams/copied"; printf 'nested\n' >"$ROOT/.streams/copied/state"; git -C "$ROOT" add -f .streams/copied/state; git -C "$ROOT" commit -qm 'tracked nested state'
refs="$(git -C "$ROOT" show-ref)"
if "$HELPER" "$ROOT" runtime-init refused main refused >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect_eq 'nested target refusal preserves refs' "$refs" "$(git -C "$ROOT" show-ref)"
if [ ! -e "$ROOT/.streams/refused" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi

ROOT2="$TMP/symlink-project"; init_repo "$ROOT2"
printf 'base\n' >"$ROOT2/file"; git -C "$ROOT2" add file; git -C "$ROOT2" commit -qm initial
mkdir "$TMP/outside"; ln -s "$TMP/outside" "$ROOT2/.streams"
if "$HELPER" "$ROOT2" runtime-init unsafe main unsafe >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
if [ ! -e "$TMP/outside/unsafe" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi

ROOT3="$TMP/no-ignore"; init_repo "$ROOT3"
mkdir -p "$ROOT3/.records/plans"; printf 'base\n' >"$ROOT3/file"; printf '# Plan\n' >"$ROOT3/.records/plans/example.md"
git -C "$ROOT3" add file .records/plans/example.md; git -C "$ROOT3" commit -qm initial
"$HELPER" "$ROOT3" runtime-init safe main safe --source-kind plan --cursor .records/plans/example.md --mode manual --ship-cadence per-stage >"$OUT"
exclude="$(git -C "$ROOT3" rev-parse --git-path info/exclude)"
case "$exclude" in /*) ;; *) exclude="$ROOT3/$exclude" ;; esac
expect 'runtime exclusion installed' '/.streams/*/' "$exclude"
expect 'tracker exclusion installed' '/workstream.tsv' "$exclude"
expect 'create records plan queue kind' $'queue\t-\tsource-kind\tplan' "$ROOT3/.streams/safe/workstream.tsv"
expect 'create records plan queue cursor' $'queue\t-\tcursor\t.records/plans/example.md' "$ROOT3/.streams/safe/workstream.tsv"
expect 'create applies explicit mode' $'mode\tmanual\texplicit' "$ROOT3/.streams/safe/WORKSTREAM.md"
expect 'create applies explicit cadence' $'ship-cadence\tper-stage\texplicit' "$ROOT3/.streams/safe/WORKSTREAM.md"
mkdir -p "$ROOT3/.streams/safe/ignored/.git"
if "$HELPER" "$ROOT3" state safe >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'ignored nested Git marker is rejected' 'nested Git marker' "$ERR"
rmdir "$ROOT3/.streams/safe/ignored/.git" "$ROOT3/.streams/safe/ignored"
if "$HELPER" "$ROOT3" runtime-init missing main missing --source-kind plan --cursor absent.md >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'missing queue source refuses explicitly' 'queue source is not a tracked regular file' "$ERR"

ROOT4="$TMP/in-place"; init_repo "$ROOT4"
printf 'base\n' >"$ROOT4/file"; git -C "$ROOT4" add file; git -C "$ROOT4" commit -qm initial
mkdir -p "$ROOT4/.streams"
sed -n 'p' "$DIR/../../templates/streams-config.md" >"$ROOT4/.streams/CONFIG.md"
"$HELPER" "$ROOT4" runtime-init inplace main inplace --isolation in-place >"$OUT"
expect_eq 'in-place creation holds stream branch' 'stream/inplace' "$(git -C "$ROOT4" branch --show-current)"
expect 'in-place runbook records root checkout' $'worktree\t'"$ROOT4" "$ROOT4/.streams/inplace/WORKSTREAM.md"
expect 'explicit isolation beats project default' $'isolation\tin-place\texplicit' "$ROOT4/.streams/inplace/WORKSTREAM.md"
"$HELPER" "$ROOT4" park inplace >"$OUT"; expect 'park returns unpark action' 'next_action=unpark' "$OUT"
expect_eq 'park restores target branch' main "$(git -C "$ROOT4" branch --show-current)"
"$HELPER" "$ROOT4" read inplace >"$OUT"; expect 'parked read returns unpark' 'next_action=unpark' "$OUT"
"$HELPER" "$ROOT4" unpark inplace >"$OUT"; expect_eq 'unpark restores stream branch' stream/inplace "$(git -C "$ROOT4" branch --show-current)"
"$HELPER" "$ROOT4" park inplace >"$OUT"
if "$HELPER" "$ROOT4" runtime-init second main second --isolation in-place >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'second in-place stream is rejected explicitly' 'another in-place stream already exists' "$ERR"

ROOT5="$TMP/tracked-copy"; init_repo "$ROOT5"
printf 'base\n' >"$ROOT5/file"; git -C "$ROOT5" add file; git -C "$ROOT5" commit -qm initial
"$HELPER" "$ROOT5" runtime-init copied main copied >"$OUT"
mkdir -p "$ROOT5/.streams/copied/.streams/nested"; printf 'copied\n' >"$ROOT5/.streams/copied/.streams/nested/state"
git -C "$ROOT5/.streams/copied" add -f .streams/nested/state; git -C "$ROOT5/.streams/copied" commit -qm 'copy nested runtime state'
if "$HELPER" "$ROOT5" state copied >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'ordinary admission rejects tracked nested state' 'nested stream runtime' "$ERR"
report 'workstream topology contract'
