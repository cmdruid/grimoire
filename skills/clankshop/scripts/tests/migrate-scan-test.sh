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

expect "workspace absent on a bare project" "workspace=absent" "$OUT"

rc=0; "$SKILL/scripts/migrate-scan.sh" "$TMP/nosuchdir" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "bad root rc" "2" "$rc"

# --- the dual probe: two keys, neither redundant -------------------------------
# The scan runs BEFORE any door exists, so it can only test the DEFAULT workspace. The
# legacy key is therefore the only thing that can see a pre-relocation workshop.

# a relocated (post-flip) workshop
post="$TMP/post"; mkdir -p "$post/.dev/doctrine"
"$SKILL/scripts/migrate-scan.sh" "$post" >"$OUT" 2>"$ERR"
expect "relocated workshop detected" "workspace=present" "$OUT"
expect "relocated workshop has no legacy tree" "handbook=absent" "$OUT"

# a pre-relocation workshop: the NEW key alone would call this greenfield
pre="$TMP/pre"; mkdir -p "$pre/.handbook"
"$SKILL/scripts/migrate-scan.sh" "$pre" >"$OUT" 2>"$ERR"
expect "pre-relocation workshop seen by the legacy probe" "handbook=present" "$OUT"
expect "pre-relocation workshop absent from the new probe" "workspace=absent" "$OUT"

# a coincident legacy host (records at `dev/`, doctrine at `dev/doctrine/`): the scan cannot
# resolve the door, so BOTH keys read absent. This is why the keys are preflight facts and the
# verb re-tests after resolving `agent-workspace:` — asserted so the limitation stays visible.
coin="$TMP/coin"; mkdir -p "$coin/dev/doctrine"
printf '# Door\nagent-workspace: dev\n' > "$coin/AGENTS.md"
"$SKILL/scripts/migrate-scan.sh" "$coin" >"$OUT" 2>"$ERR"
expect "declared non-default workspace is invisible to the preflight" "workspace=absent" "$OUT"
expect "…and so is the legacy key" "handbook=absent" "$OUT"

report "migrate-scan-test"
