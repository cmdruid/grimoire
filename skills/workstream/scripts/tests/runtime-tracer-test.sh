#!/usr/bin/env bash
# End-to-end tracer for one zero-setup local shipment.
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-tracer.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"
OUT="$TMP/out"
ERR="$TMP/err"
if [ -z "${WORKSTREAM_KEEP_TMP:-}" ]; then
  trap 'rm -rf "$TMP"' EXIT
else
  echo "fixture=$TMP"
fi

init_repo "$ROOT"
printf '# fixture\n' >"$ROOT/README.md"
git -C "$ROOT" add README.md
git -C "$ROOT" commit -qm 'initial'
initial_tip="$(git -C "$ROOT" rev-parse main)"

"$HELPER" "$ROOT" runtime-init demo main 'Trace one local unit' >"$OUT"
expect 'zero-setup create' 'status=created' "$OUT"
first_id="$(sed -n 's/^instance_id=//p' "$OUT")"
expect_eq 'instance id length' 32 "${#first_id}"
expect_eq 'instance id lowercase hex' "$first_id" "$(printf '%s' "$first_id" | tr -cd '0-9a-f')"

"$HELPER" "$ROOT" runtime-init demo main 'Trace one local unit' >"$OUT"
expect 'create retry recovers' 'status=existing' "$OUT"
expect 'create retry preserves id' "instance_id=$first_id" "$OUT"

"$HELPER" "$ROOT" unit-begin demo tracer 'Implement the tracer' >"$OUT"
expect 'unit begins' 'status=unit-started' "$OUT"
"$HELPER" "$ROOT" unit-begin demo tracer 'Implement the tracer' >"$OUT"
expect 'unit begin retry recovers' 'status=resumed' "$OUT"

printf 'implemented\n' >>"$ROOT/.streams/demo/README.md"
git -C "$ROOT/.streams/demo" add README.md
git -C "$ROOT/.streams/demo" commit -qm 'implement tracer unit'
"$HELPER" "$ROOT" unit-complete demo >"$OUT"
expect 'unit completes' 'status=unit-complete' "$OUT"
"$HELPER" "$ROOT" unit-complete demo >"$OUT"
expect 'completion retry recovers' 'status=already-complete' "$OUT"

"$HELPER" "$ROOT" ship-prepare demo >"$OUT"
expect 'shipment prepares' 'status=gate-required' "$OUT"
expect_eq 'prepare leaves target unchanged' "$initial_tip" "$(git -C "$ROOT" rev-parse main)"
"$HELPER" "$ROOT" ship-prepare demo >"$OUT"
expect 'prepare retry reuses shipment' 'status=gate-required' "$OUT"

"$HELPER" "$ROOT" gate-run demo --class docs --label tracer -- true >"$OUT"
expect 'direct gate passes' 'status=passed' "$OUT"
expect_eq 'gate leaves target unchanged' "$initial_tip" "$(git -C "$ROOT" rev-parse main)"
"$HELPER" "$ROOT" gate-run demo --class docs --label tracer -- true >"$OUT"
expect 'gate retry reuses receipt' 'status=reused' "$OUT"

if "$HELPER" "$ROOT" land-advance demo >"$OUT" 2>"$ERR"; then
  fail=$((fail + 1))
  echo 'FAIL: landing without authority succeeded' >&2
else
  pass=$((pass + 1))
fi
expect_eq 'missing authority leaves target unchanged' "$initial_tip" "$(git -C "$ROOT" rev-parse main)"

"$HELPER" "$ROOT" land-advance demo --authority confirmed >"$OUT"
expect 'authorized landing advances' 'status=landed' "$OUT"
landed_tip="$(git -C "$ROOT" rev-parse main)"
expect_eq 'target equals candidate' "$landed_tip" "$(git -C "$ROOT/.streams/demo" rev-parse HEAD)"
"$HELPER" "$ROOT" land-advance demo --authority confirmed >"$OUT"
expect 'landing retry is idempotent' 'status=already-landed' "$OUT"

"$HELPER" "$ROOT" ship-finalize demo >"$OUT"
expect 'shipment finalizes' 'status=finalized' "$OUT"
"$HELPER" "$ROOT" ship-finalize demo >"$OUT"
expect 'finalize retry is idempotent' 'status=already-finalized' "$OUT"
expect_eq 'history has one data row' 2 "$(wc -l <"$ROOT/.streams/history.tsv" | tr -d ' ')"
expect 'history names unit' $'demo\t1\t' "$ROOT/.streams/history.tsv"
expect_absent 'output hides raw tracker' $'record\tid\tfield\tvalue' "$OUT"
expect_absent 'output hides hook bodies' 'feature-completion' "$OUT"

git -C "$ROOT" worktree remove --force "$ROOT/.streams/demo"
git -C "$ROOT" branch -D stream/demo >/dev/null
"$HELPER" "$ROOT" runtime-init demo main 'Recreated stream' >"$OUT"
second_id="$(sed -n 's/^instance_id=//p' "$OUT")"
if [ "$first_id" != "$second_id" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo 'FAIL: recreated stream reused its instance id' >&2
fi
expect_eq 'history seeds next unit' 2 "$(awk -F '\t' '$1=="meta"&&$3=="next-unit"{print $4}' "$ROOT/.streams/demo/workstream.tsv")"
expect_eq 'history seeds next shipment' 2 "$(awk -F '\t' '$1=="meta"&&$3=="next-shipment"{print $4}' "$ROOT/.streams/demo/workstream.tsv")"

refs_before="$(git -C "$ROOT" show-ref)"
worktrees_before="$(git -C "$ROOT" worktree list --porcelain)"
status_before="$(git -C "$ROOT" status --porcelain --untracked-files=all)"
: >"$TMP/empty-entropy"
if WORKSTREAM_TEST_ENTROPY_SOURCE="$TMP/empty-entropy" "$HELPER" "$ROOT" runtime-init entropy main >"$OUT" 2>"$ERR"; then
  fail=$((fail + 1))
  echo 'FAIL: empty entropy source was accepted' >&2
else
  pass=$((pass + 1))
fi
expect_eq 'entropy failure preserves refs' "$refs_before" "$(git -C "$ROOT" show-ref)"
expect_eq 'entropy failure preserves worktree registry' "$worktrees_before" "$(git -C "$ROOT" worktree list --porcelain)"
expect_eq 'entropy failure preserves runtime bytes' "$status_before" "$(git -C "$ROOT" status --porcelain --untracked-files=all)"
if [ ! -e "$ROOT/.streams/entropy" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi

report 'workstream runtime tracer'
