#!/usr/bin/env bash
# Unit boundaries, supporting subjects, and delegate/manual phase rules.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-unit.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"
trap 'rm -rf "$TMP"' EXIT

init_repo "$ROOT"
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial
"$HELPER" "$ROOT" runtime-init units main units >"$OUT"
"$HELPER" "$ROOT" unit-begin units first 'First unit' >"$OUT"
if "$HELPER" "$ROOT" unit-complete units >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
printf 'one\n' >>"$ROOT/.streams/units/file"; git -C "$ROOT/.streams/units" add file; git -C "$ROOT/.streams/units" commit -qm 'first supporting subject'
printf 'two\n' >>"$ROOT/.streams/units/file"; git -C "$ROOT/.streams/units" add file; git -C "$ROOT/.streams/units" commit -qm 'second supporting subject'
"$HELPER" "$ROOT" unit-complete units >"$OUT"
expect 'disabled hook accumulates' 'next_action=accumulate' "$OUT"
TRACKER="$ROOT/.streams/units/workstream.tsv"
expect 'subject one ordered' $'unit-subject\t1/1\tsubject\tfirst supporting subject' "$TRACKER"
expect 'subject two ordered' $'unit-subject\t1/2\tsubject\tsecond supporting subject' "$TRACKER"
expect 'commit count reconciled' $'unit\t1\tcommit-count\t2' "$TRACKER"
"$HELPER" "$ROOT" phase-set units none sync >"$OUT"
expect 'delegate phase stays none' 'phase=none' "$OUT"
if "$HELPER" "$ROOT" phase-set units plan plan >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi

mkdir -p "$ROOT/.streams"
cat >"$ROOT/.streams/CONFIG.md" <<'EOF'
<!-- workstream:defaults@1 -->
mode: manual
isolation: worktree
landing: local
ship-cadence: per-stage
<!-- /workstream:defaults@1 -->
EOF
"$HELPER" "$ROOT" runtime-init manual main manual >"$OUT"
"$HELPER" "$ROOT" phase-set manual plan plan >"$OUT"; expect 'manual enters plan' 'next_action=plan' "$OUT"
if "$HELPER" "$ROOT" phase-set manual ship prepare-ship >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
"$HELPER" "$ROOT" phase-set manual build build >"$OUT"; expect 'manual enters build' 'phase=build' "$OUT"
"$HELPER" "$ROOT" unit-begin manual built 'Built unit' >"$OUT"
printf 'manual\n' >>"$ROOT/.streams/manual/file"; git -C "$ROOT/.streams/manual" add file; git -C "$ROOT/.streams/manual" commit -qm manual
"$HELPER" "$ROOT" unit-complete manual >"$OUT"
"$HELPER" "$ROOT" unit-begin manual second 'Second built unit' >"$OUT"
printf 'manual two\n' >>"$ROOT/.streams/manual/file"; git -C "$ROOT/.streams/manual" add file; git -C "$ROOT/.streams/manual" commit -qm 'manual two'
"$HELPER" "$ROOT" unit-complete manual >"$OUT"
"$HELPER" "$ROOT" phase-set manual ship prepare-ship >"$OUT"; expect 'manual enters ship' 'phase=ship' "$OUT"
if "$HELPER" "$ROOT" phase-set manual invalid build >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
if "$HELPER" "$ROOT" phase-set manual plan close >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi

report 'workstream unit lifecycle'
