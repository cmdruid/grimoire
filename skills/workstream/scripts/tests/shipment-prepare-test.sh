#!/usr/bin/env bash
# Preparation allocates one immutable batch and one metadata commit.
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
"$HELPER" "$ROOT" ship-prepare batch >"$OUT"
expect 'prepare reaches gate' 'status=gate-required' "$OUT"
if git -C "$ROOT/.streams/batch" merge-base --is-ancestor main HEAD; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
expect_eq 'prepare does not advance target' "$target_before" "$(git -C "$ROOT" rev-parse main)"
expect_eq 'metadata makes one commit' "$((commits_before + 1))" "$(git -C "$ROOT/.streams/batch" rev-list --count main..HEAD)"
expect_eq 'metadata commit names shipment' 'workstream: prepare shipment 1' "$(git -C "$ROOT/.streams/batch" log -1 --format=%s)"
TRACKER="$ROOT/.streams/batch/workstream.tsv"
expect 'shipment batch is fixed' $'shipment-unit\t1/1\tunit\t1' "$TRACKER"
expect 'shipment phase is gate' $'phase\tgate' "$TRACKER"
history_hash="$(shasum -a 256 "$ROOT/.streams/batch/.streams/history.tsv" | awk '{print $1}')"
tip="$(git -C "$ROOT/.streams/batch" rev-parse HEAD)"
"$HELPER" "$ROOT" ship-prepare batch >"$OUT"
expect 'prepare resumes same shipment' 'shipment=1' "$OUT"
expect_eq 'retry preserves candidate' "$tip" "$(git -C "$ROOT/.streams/batch" rev-parse HEAD)"
expect_eq 'retry preserves history' "$history_hash" "$(shasum -a 256 "$ROOT/.streams/batch/.streams/history.tsv" | awk '{print $1}')"
expect_eq 'one history row' 2 "$(wc -l <"$ROOT/.streams/batch/.streams/history.tsv" | tr -d ' ')"
printf 'later incoming\n' >"$ROOT/later"; git -C "$ROOT" add later; git -C "$ROOT" commit -qm 'later target movement'
new_target="$(git -C "$ROOT" rev-parse main)"
"$HELPER" "$ROOT" ship-prepare batch >"$OUT"
expect 'target movement resumes the same shipment' 'shipment=1' "$OUT"
expect 'target movement returns to gate selection' 'status=gate-required' "$OUT"
expect 'target movement is retained as friction' $'friction\t1/repeat-sync\tpresent\tyes' "$TRACKER"
expect 'shipment target receipt refreshes' $'target-tip\t'"$new_target" "$TRACKER"
expect_eq 'target movement does not duplicate history' 2 "$(wc -l <"$ROOT/.streams/batch/.streams/history.tsv" | tr -d ' ')"

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

ROOT3="$TMP/history-union"; init_repo "$ROOT3"
mkdir -p "$ROOT3/.streams"; printf 'base\n' >"$ROOT3/file"; printf 'stream\tsequence\trecorded_at\ttarget\tunit\tcommits\tsummary\n' >"$ROOT3/.streams/history.tsv"
git -C "$ROOT3" add file .streams/history.tsv; git -C "$ROOT3" commit -qm initial
for stream in alpha beta; do
  "$HELPER" "$ROOT3" runtime-init "$stream" main "$stream" >"$OUT"; "$HELPER" "$ROOT3" unit-begin "$stream" unit "$stream unit" >"$OUT"
  printf '%s\n' "$stream" >"$ROOT3/.streams/$stream/$stream"; git -C "$ROOT3/.streams/$stream" add "$stream"; git -C "$ROOT3/.streams/$stream" commit -qm "$stream"
  "$HELPER" "$ROOT3" unit-complete "$stream" >"$OUT"; "$HELPER" "$ROOT3" ship-prepare "$stream" >"$OUT"; "$HELPER" "$ROOT3" gate-run "$stream" --class full --label "$stream" -- true >"$OUT"
done
"$HELPER" "$ROOT3" land-advance alpha --authority confirmed >"$OUT"
"$HELPER" "$ROOT3" ship-prepare beta >"$OUT"
expect 'history-only rebase conflict resumes automatically' 'status=gate-required' "$OUT"
expect_eq 'strict history union retains both populations' 3 "$(wc -l <"$ROOT3/.streams/beta/.streams/history.tsv" | tr -d ' ')"
expect 'strict history union retains alpha' $'alpha\t1\t' "$ROOT3/.streams/beta/.streams/history.tsv"
expect 'strict history union retains beta' $'beta\t1\t' "$ROOT3/.streams/beta/.streams/history.tsv"

ROOT4="$TMP/history-divergence"; init_repo "$ROOT4"
mkdir -p "$ROOT4/.streams"; printf 'base\n' >"$ROOT4/file"
printf 'stream\tsequence\trecorded_at\ttarget\tunit\tcommits\tsummary\nseed\t1\t2026-09-03T00:00:00Z\tmain\tseed\t1\tbase row\n' >"$ROOT4/.streams/history.tsv"
git -C "$ROOT4" add file .streams/history.tsv; git -C "$ROOT4" commit -qm initial
"$HELPER" "$ROOT4" runtime-init divergent main divergent >"$OUT"; "$HELPER" "$ROOT4" unit-begin divergent unit unit >"$OUT"
sed 's/base row/stream rewrite/' "$ROOT4/.streams/divergent/.streams/history.tsv" >"$TMP/stream-history"; cp "$TMP/stream-history" "$ROOT4/.streams/divergent/.streams/history.tsv"
git -C "$ROOT4/.streams/divergent" add .streams/history.tsv; git -C "$ROOT4/.streams/divergent" commit -qm 'rewrite history in stream'
"$HELPER" "$ROOT4" unit-complete divergent >"$OUT"
sed 's/base row/target rewrite/' "$ROOT4/.streams/history.tsv" >"$TMP/target-history"; cp "$TMP/target-history" "$ROOT4/.streams/history.tsv"
git -C "$ROOT4" add .streams/history.tsv; git -C "$ROOT4" commit -qm 'rewrite history on target'
if "$HELPER" "$ROOT4" ship-prepare divergent >"$OUT" 2>"$TMP/divergent.err"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'divergent history key refuses automatic union' 'status=conflict' "$OUT"
report 'workstream shipment prepare'
