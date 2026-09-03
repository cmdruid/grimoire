#!/usr/bin/env bash
# Attended hard-cut migration moves registered worktrees, not customization archives.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-migration.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
git init -q -b main "$ROOT"; git -C "$ROOT" config user.name test; git -C "$ROOT" config user.email test@example.invalid
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial; mkdir -p "$ROOT/.workstreams"
git -C "$ROOT" worktree add -q -b stream/legacy "$ROOT/.workstreams/legacy" main
printf '# legacy handoff\n' >"$ROOT/.workstreams/legacy/WORKSTREAM.md"
"$HELPER" "$ROOT" migrate inventory >"$OUT"
expect 'migration inventories stream' 'stream=legacy' "$OUT"
expect 'inventory reports one' 'streams=1' "$OUT"
if [ -d "$ROOT/.workstreams/legacy" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
"$HELPER" "$ROOT" migrate apply >"$OUT"
expect 'migration applies' 'status=migrated' "$OUT"
if [ -d "$ROOT/.streams/legacy" ] && [ ! -e "$ROOT/.workstreams/legacy" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
expect 'new tracker created' $'schema\tworkstream@1' "$ROOT/.streams/legacy/workstream.tsv"
expect 'new runbook identifies migration' 'Migrated workstream legacy' "$ROOT/.streams/legacy/WORKSTREAM.md"
expect 'Git registry follows move' "worktree $ROOT/.streams/legacy" <(git -C "$ROOT" worktree list --porcelain)
"$HELPER" "$ROOT" read legacy >"$OUT"; expect 'migrated stream admits' 'schema=workstream-read@1' "$OUT"

mkdir -p "$ROOT/.workstreams"; git -C "$ROOT" worktree add -q -b stream/nested "$ROOT/.workstreams/nested" main
mkdir -p "$ROOT/.workstreams/nested/.streams/copied"
if "$HELPER" "$ROOT" migrate apply >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
if [ -d "$ROOT/.workstreams/nested" ] && [ ! -e "$ROOT/.streams/nested" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
report 'workstream migration'
