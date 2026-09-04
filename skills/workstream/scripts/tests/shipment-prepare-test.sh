#!/usr/bin/env bash
# Preparation allocates one immutable batch without a history ledger.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-prepare.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; trap 'rm -rf "$TMP"' EXIT
init_repo "$ROOT"
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial
"$HELPER" "$ROOT" runtime-init batch main batch >"$OUT"; "$HELPER" "$ROOT" unit-begin batch one one >"$OUT"
printf 'one\n' >>"$ROOT/.streams/batch/file"; git -C "$ROOT/.streams/batch" add file; git -C "$ROOT/.streams/batch" commit -qm one
"$HELPER" "$ROOT" unit-complete batch >"$OUT"
printf 'incoming\n' >"$ROOT/incoming"; git -C "$ROOT" add incoming; git -C "$ROOT" commit -qm incoming
target_before="$(git -C "$ROOT" rev-parse main)"; commits_before="$(git -C "$ROOT/.streams/batch" rev-list --count main..HEAD)"
printf 'primary wip\n' >"$ROOT/primary-wip"
"$HELPER" "$ROOT" ship-prepare batch >"$OUT"
expect 'prepare reaches gate' 'status=gate-required' "$OUT"
if git -C "$ROOT/.streams/batch" merge-base --is-ancestor main HEAD; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
expect_eq 'prepare does not advance target' "$target_before" "$(git -C "$ROOT" rev-parse main)"
expect_eq 'prepare preserves unrelated primary dirt' 'primary wip' "$(cat "$ROOT/primary-wip")"
expect_eq 'prepare does not write history.tsv' 0 "$([ -e "$ROOT/.streams/history.tsv" ] && echo 1 || echo 0)"
TRACKER="$ROOT/.streams/batch/workstream.tsv"
expect 'shipment batch is fixed' $'shipment-unit\t1/1\tunit\t1' "$TRACKER"
expect 'shipment phase is gate' $'phase\tgate' "$TRACKER"
tip="$(git -C "$ROOT/.streams/batch" rev-parse HEAD)"
"$HELPER" "$ROOT" ship-prepare batch >"$OUT"
expect 'prepare resumes same shipment' 'shipment=1' "$OUT"
expect_eq 'retry preserves candidate' "$tip" "$(git -C "$ROOT/.streams/batch" rev-parse HEAD)"
rm "$ROOT/primary-wip"
printf 'later incoming\n' >"$ROOT/later"; git -C "$ROOT" add later; git -C "$ROOT" commit -qm 'later target movement'
new_target="$(git -C "$ROOT" rev-parse main)"
"$HELPER" "$ROOT" ship-prepare batch >"$OUT"
expect 'target movement resumes the same shipment' 'shipment=1' "$OUT"
expect 'target movement returns to gate selection' 'status=gate-required' "$OUT"
expect 'target movement is retained as friction' $'friction\t1/repeat-sync\tpresent\tyes' "$TRACKER"
expect 'shipment target receipt refreshes' $'target-tip\t'"$new_target" "$TRACKER"

ROOT2="$TMP/conflict"; init_repo "$ROOT2"
printf 'base\n' >"$ROOT2/file"; git -C "$ROOT2" add file; git -C "$ROOT2" commit -qm initial
"$HELPER" "$ROOT2" runtime-init conflicted main conflicted >"$OUT"; "$HELPER" "$ROOT2" unit-begin conflicted one one >"$OUT"
printf 'stream\n' >"$ROOT2/.streams/conflicted/file"; git -C "$ROOT2/.streams/conflicted" add file; git -C "$ROOT2/.streams/conflicted" commit -qm stream; "$HELPER" "$ROOT2" unit-complete conflicted >"$OUT"
printf 'target\n' >"$ROOT2/file"; git -C "$ROOT2" add file; git -C "$ROOT2" commit -qm target
if "$HELPER" "$ROOT2" ship-prepare conflicted >"$OUT" 2>"$TMP/conflict.err"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'conflict allocates shipment before rebase' 'shipment=1' "$OUT"
expect 'conflict persists sync phase' $'phase\tsync' "$ROOT2/.streams/conflicted/workstream.tsv"
expect 'conflict persists causal friction' $'friction\t1/rebase-conflict\tpresent\tyes' "$ROOT2/.streams/conflicted/workstream.tsv"
printf 'resolved\n' >"$ROOT2/.streams/conflicted/file"; git -C "$ROOT2/.streams/conflicted" add file; GIT_EDITOR=true git -C "$ROOT2/.streams/conflicted" rebase --continue >/dev/null 2>&1
"$HELPER" "$ROOT2" ship-prepare conflicted >"$OUT"
expect 'resolved conflict resumes original shipment' 'shipment=1' "$OUT"
expect 'resolved conflict reaches gate' 'status=gate-required' "$OUT"

report 'workstream shipment prepare'
