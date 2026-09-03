#!/usr/bin/env bash
# Recovery admits only the supplied current worktree and emits the named-read projection.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-recovery.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
init_repo "$ROOT"
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial
"$HELPER" "$ROOT" runtime-init alpha main alpha >"$OUT"
"$HELPER" "$ROOT" runtime-init beta main beta >"$OUT"
ALPHA="$ROOT/.streams/alpha"; TRACKER="$ALPHA/workstream.tsv"
tracker_before="$(shasum -a 256 "$TRACKER" | awk '{print $1}')"

if "$HELPER" "$ROOT" read-current "$ROOT" >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'root without a top-level runbook is inert to recovery' 'current worktree has no safe top-level runbook' "$ERR"
expect_eq 'absent recovery does not inspect or mutate a sibling' "$tracker_before" "$(shasum -a 256 "$TRACKER" | awk '{print $1}')"

"$HELPER" "$ROOT" read alpha >"$TMP/named"
"$HELPER" "$ROOT" read-current "$ALPHA" >"$TMP/current"
if cmp -s "$TMP/named" "$TMP/current"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: current recovery projection differs from named load' >&2; fi
expect 'current recovery returns one action' 'next_action=define-unit' "$TMP/current"

mkdir "$ALPHA/nested"
if "$HELPER" "$ROOT" read-current "$ALPHA/nested" >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'nested path is not accepted as current top level' 'current worktree is not its Git top level' "$ERR"
rmdir "$ALPHA/nested"

git -C "$ROOT" worktree add -q -b foreign "$TMP/foreign" main
cp "$ALPHA/WORKSTREAM.md" "$TMP/foreign/WORKSTREAM.md"
cp "$TRACKER" "$TMP/foreign/workstream.tsv"
if "$HELPER" "$ROOT" read-current "$TMP/foreign" >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'foreign top-level handoff is rejected' 'current worktree is not the registered stream coordinate' "$ERR"
expect_eq 'foreign recovery does not mutate the admitted stream' "$tracker_before" "$(shasum -a 256 "$TRACKER" | awk '{print $1}')"

cp "$ALPHA/WORKSTREAM.md" "$ROOT/WORKSTREAM.md"
cp "$TRACKER" "$ROOT/workstream.tsv"
if "$HELPER" "$ROOT" read-current "$ROOT" >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'copied root handoff cannot claim stream custody' 'current worktree is not the registered stream coordinate' "$ERR"
rm -f "$ROOT/WORKSTREAM.md" "$ROOT/workstream.tsv"

mv "$TMP/foreign/WORKSTREAM.md" "$TMP/foreign/real-runbook"
ln -s "$TMP/foreign/real-runbook" "$TMP/foreign/WORKSTREAM.md"
if "$HELPER" "$ROOT" read-current "$TMP/foreign" >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'symlinked current runbook is rejected' 'current worktree has no safe top-level runbook' "$ERR"

report 'workstream recovery contract'
