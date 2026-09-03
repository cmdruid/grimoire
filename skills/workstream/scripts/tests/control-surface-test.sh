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

ROOT2="$TMP/stream-repair"; git init -q -b main "$ROOT2"; git -C "$ROOT2" config user.name test; git -C "$ROOT2" config user.email test@example.invalid
printf 'base\n' >"$ROOT2/file"; git -C "$ROOT2" add file; git -C "$ROOT2" commit -qm initial
"$HELPER" "$ROOT2" runtime-init repairable main repairable >"$OUT"; chmod 644 "$ROOT2/.streams/repairable/WORKSTREAM.md" "$ROOT2/.streams/repairable/workstream.tsv"
"$HELPER" "$ROOT2" repair repairable >"$OUT"; expect 'targeted repair reports scope' 'operation=repair-stream' "$OUT"
expect_eq 'targeted repair restores runbook mode' 600 "$(stat -f '%Lp' "$ROOT2/.streams/repairable/WORKSTREAM.md")"
expect_eq 'targeted repair restores tracker mode' 600 "$(stat -f '%Lp' "$ROOT2/.streams/repairable/workstream.tsv")"
rm "$ROOT2/.streams/repairable/workstream.tsv"
"$HELPER" "$ROOT2" repair repairable >"$OUT"; expect 'idle tracker is reconstructed' 'status=reconstructed' "$OUT"
expect 'reconstructed tracker preserves instance' "$(sed -n 's/^instance-id[[:space:]]*//p' "$ROOT2/.streams/repairable/WORKSTREAM.md")" "$ROOT2/.streams/repairable/workstream.tsv"
printf 'unlanded\n' >>"$ROOT2/.streams/repairable/file"; git -C "$ROOT2/.streams/repairable" add file; git -C "$ROOT2/.streams/repairable" commit -qm unlanded
rm "$ROOT2/.streams/repairable/workstream.tsv"
if "$HELPER" "$ROOT2" repair repairable >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'unlanded reconstruction refuses' 'refuses unlanded commits' "$ERR"

ROOT3="$TMP/helper-only"; git init -q -b main "$ROOT3"; git -C "$ROOT3" config user.name test; git -C "$ROOT3" config user.email test@example.invalid
printf 'base\n' >"$ROOT3/file"; git -C "$ROOT3" add file; git -C "$ROOT3" commit -qm initial; mkdir -p "$ROOT3/.streams"; cp "$HELPER" "$ROOT3/.streams/workstream.sh"
if "$HELPER" "$ROOT3" runtime-init partial main partial >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'helper-only state points to setup' 'partial setup; run /workstream setup' "$ERR"

ROOT4="$TMP/readme-only"; git init -q -b main "$ROOT4"; git -C "$ROOT4" config user.name test; git -C "$ROOT4" config user.email test@example.invalid
printf 'base\n' >"$ROOT4/file"; git -C "$ROOT4" add file; git -C "$ROOT4" commit -qm initial; mkdir -p "$ROOT4/.streams"
printf '<!-- workstream:control@1 -->\n<!-- /workstream:control@1 -->\n' >"$ROOT4/.streams/README.md"
if "$HELPER" "$ROOT4" runtime-init partial main partial >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'managed README without helper points to repair' 'missing its helper; run /workstream repair' "$ERR"

report 'workstream control surface'
