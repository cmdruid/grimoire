#!/usr/bin/env bash
# Agents pass the checkout they are in; the helper resolves the primary and re-execs.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-root.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"
OUT="$TMP/out"
ERR="$TMP/err"
trap 'rm -rf "$TMP"' EXIT

init_repo "$ROOT"
printf 'base\n' >"$ROOT/file"
git -C "$ROOT" add file
git -C "$ROOT" commit -qm initial

"$HELPER" "$ROOT" runtime-init linked main linked >"$OUT"
WT="$ROOT/.streams/linked"
"$HELPER" "$WT" read linked >"$OUT" 2>"$ERR"
expect 'linked checkout admits' 'schema=workstream-read@1' "$OUT"
expect 'read emits primary root' "root=$ROOT" "$OUT"
expect 'read still names the stream worktree' "worktree=$WT" "$OUT"
expect_absent 'read does not emit ship-cadence' 'ship-cadence' "$OUT"

"$HELPER" "$ROOT" setup >"$OUT"
if ! grep -q '^status=committed$' "$OUT" && ! grep -q '^status=current$' "$OUT"; then
  fail=$((fail + 1))
  echo 'FAIL: setup did not report committed or current' >&2
else
  pass=$((pass + 1))
fi
"$HELPER" "$WT" read linked >"$OUT" 2>"$ERR"
expect 'package helper from worktree still reads after setup' 'schema=workstream-read@1' "$OUT"
expect 're-exec read emits primary root' "root=$ROOT" "$OUT"

if "$HELPER" "$TMP" read linked >"$OUT" 2>"$ERR"; then
  fail=$((fail + 1))
  echo 'FAIL: unrelated directory was admitted' >&2
else
  pass=$((pass + 1))
fi
expect 'unrelated directory is refused' 'not a Git checkout' "$ERR"

"$HELPER" "$ROOT" --help >"$ERR" 2>&1 || true
for op in pr-await pr-verify delivery-classify reconcile-partial land-advance; do
  expect "usage lists $op" "$op" "$ERR"
done

report 'workstream root resolution'
