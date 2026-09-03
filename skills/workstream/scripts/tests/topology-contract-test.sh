#!/usr/bin/env bash
# Canonical coordinates and Git topology, not ignore files, prevent nesting.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-topology.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
git init -q -b main "$ROOT"; git -C "$ROOT" config user.name test; git -C "$ROOT" config user.email test@example.invalid
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial
mkdir -p "$ROOT/.streams/copied"; printf 'nested\n' >"$ROOT/.streams/copied/state"; git -C "$ROOT" add -f .streams/copied/state; git -C "$ROOT" commit -qm 'tracked nested state'
refs="$(git -C "$ROOT" show-ref)"
if "$HELPER" "$ROOT" runtime-init refused main refused >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect_eq 'nested target refusal preserves refs' "$refs" "$(git -C "$ROOT" show-ref)"
if [ ! -e "$ROOT/.streams/refused" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi

ROOT2="$TMP/symlink-project"; git init -q -b main "$ROOT2"; git -C "$ROOT2" config user.name test; git -C "$ROOT2" config user.email test@example.invalid
printf 'base\n' >"$ROOT2/file"; git -C "$ROOT2" add file; git -C "$ROOT2" commit -qm initial
mkdir "$TMP/outside"; ln -s "$TMP/outside" "$ROOT2/.streams"
if "$HELPER" "$ROOT2" runtime-init unsafe main unsafe >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
if [ ! -e "$TMP/outside/unsafe" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi

ROOT3="$TMP/no-ignore"; git init -q -b main "$ROOT3"; git -C "$ROOT3" config user.name test; git -C "$ROOT3" config user.email test@example.invalid
printf 'base\n' >"$ROOT3/file"; git -C "$ROOT3" add file; git -C "$ROOT3" commit -qm initial
"$HELPER" "$ROOT3" runtime-init safe main safe >"$OUT"
exclude="$(git -C "$ROOT3" rev-parse --git-path info/exclude)"
case "$exclude" in /*) ;; *) exclude="$ROOT3/$exclude" ;; esac
expect 'runtime exclusion installed' '/.streams/*/' "$exclude"
expect 'tracker exclusion installed' '/workstream.tsv' "$exclude"
report 'workstream topology contract'
