#!/usr/bin/env bash
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
PRIME="$DIR/../workstream-prime.sh"; HELPER="$DIR/../workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-prime.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"; ROOT="$TMP/project"; OUT="$TMP/out"; trap 'rm -rf "$TMP"' EXIT
init_repo "$ROOT"
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial
"$HELPER" "$ROOT" runtime-init prime main prime >"$OUT"
"$PRIME" "$ROOT" prime first 'First bounded unit' >"$OUT"
expect 'prime delegates to guarded unit transition' 'status=unit-started' "$OUT"
expect 'prime records unit summary' $'summary\tFirst bounded unit' "$ROOT/.streams/prime/workstream.tsv"
"$PRIME" "$ROOT" prime first 'First bounded unit' >"$OUT"; expect 'prime retry recovers' 'status=resumed' "$OUT"
if "$PRIME" "$ROOT" other first first >"$OUT" 2>/dev/null; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect_absent 'prime has no foreign workflow knowledge' 'foreman' "$PRIME"
report 'workstream-prime-test.sh'
