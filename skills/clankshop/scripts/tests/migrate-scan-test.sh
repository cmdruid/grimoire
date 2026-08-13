#!/usr/bin/env bash
# migrate-scan-test.sh — the brownfield preflight reports the facts the mapping table
# needs: doc inventory with git dates, tracker-shaped files, doc roots, door presence.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/clankshop-migrate-scan-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

proj="$TMP/proj"
mkdir -p "$proj/dev/notes" "$proj/src"
git init -q "$proj"
git -C "$proj" config user.email t@t; git -C "$proj" config user.name t
printf '# Old plan\ncontent\n' > "$proj/dev/notes/plan.md"
printf '# Todo\n- [ ] x\n' > "$proj/TODO.md"
printf '# Door\n' > "$proj/AGENTS.md"
printf 'fn main() {}\n' > "$proj/src/main.rs"
git -C "$proj" add -A && git -C "$proj" commit -qm init

"$SKILL/scripts/migrate-scan.sh" "$proj" >"$OUT" 2>"$ERR"
expect "root fact" "root=$(cd "$proj" && pwd)" "$OUT"
expect "git fact" "git=true" "$OUT"
expect "handbook absent" "handbook=absent" "$OUT"
expect "door detected" "door=AGENTS.md" "$OUT"
expect "legacy doc root detected" "docroot=dev/" "$OUT"
expect "tracker-shaped file detected" "tracker-shaped=TODO.md" "$OUT"
expect "doc row with git date" "dev/notes/plan.md	$(date +%Y-%m-%d)" "$OUT"
expect "doc row heading" "# Old plan" "$OUT"
expect_absent "non-md files not inventoried" "src/main.rs" "$OUT"

rc=0; "$SKILL/scripts/migrate-scan.sh" "$TMP/nosuchdir" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "bad root rc" "2" "$rc"

report "migrate-scan-test"
