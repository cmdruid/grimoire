#!/usr/bin/env bash
# Changed gitlinks must name locally obtainable objects before the gate.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-gitlink.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; SUB="$TMP/sub"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
init_repo "$ROOT"
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial
init_repo "$SUB"
printf 'sub\n' >"$SUB/sub"; git -C "$SUB" add sub; git -C "$SUB" commit -qm sub
object="$(git -C "$SUB" rev-parse HEAD)"

"$HELPER" "$ROOT" runtime-init ready-link main ready >"$OUT"; "$HELPER" "$ROOT" unit-begin ready-link link link >"$OUT"
git -C "$ROOT/.streams/ready-link" config advice.addEmbeddedRepo false
git clone -q "$SUB" "$ROOT/.streams/ready-link/vendor"
git -C "$ROOT/.streams/ready-link" add vendor; git -C "$ROOT/.streams/ready-link" commit -qm 'add ready gitlink'
"$HELPER" "$ROOT" unit-complete ready-link >"$OUT"; "$HELPER" "$ROOT" ship-prepare ready-link >"$OUT"
expect 'available gitlink reaches gate' 'status=gate-required' "$OUT"
expect 'local object is transferred to landing checkout' $'availability\ttransferred' "$ROOT/.streams/ready-link/workstream.tsv"
if git -C "$ROOT/vendor" cat-file -e "$object^{commit}" 2>/dev/null; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: landing checkout cannot obtain gitlink object' >&2; fi
expect 'local publication is not required' $'published\tnot-required' "$ROOT/.streams/ready-link/workstream.tsv"

"$HELPER" "$ROOT" runtime-init missing-link main missing >"$OUT"; "$HELPER" "$ROOT" unit-begin missing-link link link >"$OUT"
git -C "$ROOT/.streams/missing-link" update-index --add --cacheinfo "160000,$object,missing"
git -C "$ROOT/.streams/missing-link" commit -qm 'add missing gitlink'
git -C "$ROOT/.streams/missing-link" update-index --skip-worktree missing
"$HELPER" "$ROOT" unit-complete missing-link >"$OUT"
if "$HELPER" "$ROOT" ship-prepare missing-link >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'missing gitlink blocks' 'phase=gitlinks' "$OUT"
expect 'missing availability recorded' $'availability\tmissing' "$ROOT/.streams/missing-link/workstream.tsv"
expect_absent 'blocked gitlink has no gate receipt' $'gate\t' "$ROOT/.streams/missing-link/workstream.tsv"

SUB_REMOTE="$TMP/sub-remote.git"; SUB_SEED="$TMP/sub-seed"; PUSH_REMOTE="$TMP/push-remote.git"; PUSH_ROOT="$TMP/push-project"
git init -q --bare "$SUB_REMOTE"; init_repo "$SUB_SEED"
printf 'published\n' >"$SUB_SEED/file"; git -C "$SUB_SEED" add file; git -C "$SUB_SEED" commit -qm published; git -C "$SUB_SEED" remote add origin "$SUB_REMOTE"; git -C "$SUB_SEED" push -qu origin main
git init -q --bare "$PUSH_REMOTE"; init_repo "$PUSH_ROOT"
printf 'base\n' >"$PUSH_ROOT/file"; git -C "$PUSH_ROOT" add file; git -C "$PUSH_ROOT" commit -qm initial; git -C "$PUSH_ROOT" remote add origin "$PUSH_REMOTE"; git -C "$PUSH_ROOT" push -qu origin main
"$HELPER" "$PUSH_ROOT" runtime-init published main published --landing push >"$OUT"
"$HELPER" "$PUSH_ROOT" unit-begin published link link >"$OUT"
git -C "$PUSH_ROOT/.streams/published" config advice.addEmbeddedRepo false; git clone -q -b main "$SUB_REMOTE" "$PUSH_ROOT/.streams/published/vendor"
git -C "$PUSH_ROOT/.streams/published" add vendor; git -C "$PUSH_ROOT/.streams/published" commit -qm 'add published gitlink'
"$HELPER" "$PUSH_ROOT" unit-complete published >"$OUT"; "$HELPER" "$PUSH_ROOT" ship-prepare published >"$OUT"
expect 'published remote gitlink reaches gate' 'status=gate-required' "$OUT"
expect 'remote publication is recorded' $'published\tyes' "$PUSH_ROOT/.streams/published/workstream.tsv"
report 'workstream gitlink readiness'
