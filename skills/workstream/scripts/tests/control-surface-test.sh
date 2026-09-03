#!/usr/bin/env bash
# Setup and naked repair own exactly the five tracked control artifacts.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-control.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
git init -q -b main "$ROOT"; git -C "$ROOT" config user.name test; git -C "$ROOT" config user.email test@example.invalid
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial; before="$(git -C "$ROOT" rev-list --count HEAD)"
"$HELPER" "$ROOT" setup >"$OUT"
expect 'setup commits control surface' 'status=committed' "$OUT"
expect_eq 'setup makes one commit' "$((before + 1))" "$(git -C "$ROOT" rev-list --count HEAD)"
expect_eq 'exact five control files tracked' 5 "$(git -C "$ROOT" ls-files .streams | wc -l | tr -d ' ')"
for path in .gitignore CONFIG.md README.md history.tsv workstream.sh; do if git -C "$ROOT" ls-files --error-unmatch ".streams/$path" >/dev/null 2>&1; then pass=$((pass + 1)); else fail=$((fail + 1)); fi; done
expect 'runtime directories ignored' '/*/' "$ROOT/.streams/.gitignore"
expect 'README owns one managed block' '<!-- workstream:control@1 -->' "$ROOT/.streams/README.md"
expect_eq 'installed helper is byte-identical' "$(shasum -a 256 "$HELPER" | awk '{print $1}')" "$(shasum -a 256 "$ROOT/.streams/workstream.sh" | awk '{print $1}')"
tip="$(git -C "$ROOT" rev-parse HEAD)"; "$HELPER" "$ROOT" setup >"$OUT"
expect 'setup rerun converges' 'status=current' "$OUT"; expect_eq 'setup rerun makes no commit' "$tip" "$(git -C "$ROOT" rev-parse HEAD)"

printf '\nproject explanation\n' >>"$ROOT/.streams/README.md"
printf '\n# project configuration prose\n' >>"$ROOT/.streams/CONFIG.md"
"$HELPER" "$ROOT" repair >"$OUT"
expect 'repair leaves authored-only edits uncommitted' 'status=current' "$OUT"
expect 'README prose preserved' 'project explanation' "$ROOT/.streams/README.md"
expect 'CONFIG prose preserved' 'project configuration prose' "$ROOT/.streams/CONFIG.md"

mv "$ROOT/.streams/CONFIG.md" "$TMP/config-saved"
"$HELPER" "$ROOT" repair >"$OUT"; expect 'repair restores absent default config' 'status=current' "$OUT"
expect 'default config restored' '<!-- workstream:defaults@1 -->' "$ROOT/.streams/CONFIG.md"
mv "$ROOT/.streams/history.tsv" "$TMP/history-saved"
if "$HELPER" "$ROOT" repair >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
if [ ! -e "$ROOT/.streams/history.tsv" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi

report 'workstream control surface'
