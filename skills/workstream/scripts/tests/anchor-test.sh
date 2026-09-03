#!/usr/bin/env bash
# Recovery-anchor lifecycle is bounded, explicit, and patient-zero.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-anchor.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; FRONT="$ROOT/AGENTS.md"; trap 'rm -rf "$TMP"' EXIT
git init -q -b main "$ROOT"; git -C "$ROOT" config user.name test; git -C "$ROOT" config user.email test@example.invalid
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial
printf '# Project instructions\n\nKeep this prose.\n' >"$FRONT"
"$HELPER" "$ROOT" anchor status >"$OUT"; expect 'absent anchor classified' 'status=absent' "$OUT"
"$HELPER" "$ROOT" anchor install >"$OUT"; expect 'anchor installs' 'status=installed' "$OUT"
expect 'surrounding prose preserved' 'Keep this prose.' "$FRONT"
expect_eq 'one start marker' 1 "$(grep -cFx '<!-- workstream:recovery-anchor@1 -->' "$FRONT")"
"$HELPER" "$ROOT" anchor status >"$OUT"; expect 'current anchor classified' 'status=current' "$OUT"
hash="$(shasum -a 256 "$FRONT" | awk '{print $1}')"; "$HELPER" "$ROOT" anchor install >"$OUT"
expect_eq 'install rerun preserves bytes' "$hash" "$(shasum -a 256 "$FRONT" | awk '{print $1}')"
sed 's/Only after context compaction/Only after accidental drift/' "$FRONT" >"$TMP/drift"; cp "$TMP/drift" "$FRONT"
"$HELPER" "$ROOT" anchor status >"$OUT"; expect 'drift is explicit' 'status=drifted' "$OUT"
"$HELPER" "$ROOT" anchor refresh >"$OUT"; "$HELPER" "$ROOT" anchor status >"$OUT"; expect 'refresh restores current' 'status=current' "$OUT"
printf '\n<!-- workstream:recovery-anchor@1 -->\n' >>"$FRONT"
if "$HELPER" "$ROOT" anchor refresh >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
sed -n '1,/<!-- \/workstream:recovery-anchor@1 -->/p' "$FRONT" >"$TMP/one"; cp "$TMP/one" "$FRONT"
"$HELPER" "$ROOT" anchor remove >"$OUT"; expect 'anchor removes' 'status=removed' "$OUT"
expect 'remove preserves prose' 'Keep this prose.' "$FRONT"
expect_absent 'remove clears marker' 'workstream:recovery-anchor' "$FRONT"
ln -s "$FRONT" "$ROOT/LINK.md"
if "$HELPER" "$ROOT" anchor install LINK.md >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
report 'workstream anchor'
