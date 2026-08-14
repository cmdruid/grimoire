#!/usr/bin/env bash
# standup-test.sh — standup.sh end to end: scaffold on a bare repo, honor a declared
# records-root, stay additive on a legacy root, and every advertised failure mode
# actually fails (proven by breaking).
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/journal-standup-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

# --- bare-repo standup, default root -------------------------------------------
proj="$TMP/proj"
mkdir -p "$proj"
git init -q "$proj"

"$SKILL/scripts/standup.sh" "$proj" >"$OUT" 2>"$ERR"
expect "standup reports" "records: $proj/.records (journal)" "$OUT"
expect "standup self-check green" "records check: OK (0 records)" "$OUT"

for s in adr bugs design notes plans reports tickets trackers; do
  [ -f "$proj/.records/$s/.gitkeep" ] && pass=$((pass + 1)) || { echo "FAIL: missing store $s" >&2; fail=$((fail + 1)); }
done
# templates: standup ships ONLY journal's commons/example (reports.md); every other
# store's template is owner-carried and lazy-deployed by the skill that mints it —
# a pre-deployed copy here would mean standup regressed into the template dump.
[ -f "$proj/.records/templates/reports.md" ] && pass=$((pass + 1)) || { echo "FAIL: missing commons template reports.md" >&2; fail=$((fail + 1)); }
for t in adr bugs design notes plans tickets trackers; do
  [ ! -e "$proj/.records/templates/$t.md" ] && pass=$((pass + 1)) || { echo "FAIL: owner-carried template $t.md pre-deployed by standup" >&2; fail=$((fail + 1)); }
done
[ -x "$proj/.records/scripts/records.sh" ] && pass=$((pass + 1)) || { echo "FAIL: records.sh not executable" >&2; fail=$((fail + 1)); }
[ -f "$proj/.records/history.tsv" ] && pass=$((pass + 1)) || { echo "FAIL: missing history.tsv" >&2; fail=$((fail + 1)); }
expect "README stamped with the real date" "Stood up by journal on $(date +%Y-%m-%d)." "$proj/.records/README.md"

# --- declared records-root, additive on a legacy tree ---------------------------
legacy="$TMP/legacy"
mkdir -p "$legacy/dev/records"
echo "pre-existing" > "$legacy/dev/records/keep.txt"
"$SKILL/scripts/standup.sh" "$legacy" --records-root dev/records >"$OUT" 2>"$ERR"
expect "declared root honored" "records: $legacy/dev/records (journal)" "$OUT"
expect "legacy content survives" "pre-existing" "$legacy/dev/records/keep.txt"
[ -x "$legacy/dev/records/scripts/records.sh" ] && pass=$((pass + 1)) || { echo "FAIL: records.sh missing under declared root" >&2; fail=$((fail + 1)); }

# --- proven by breaking ----------------------------------------------------------
rc=0; "$SKILL/scripts/standup.sh" "$proj" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "re-standup refused rc" "2" "$rc"
expect "re-standup refusal message" "refusing" "$ERR"

rc=0; "$SKILL/scripts/standup.sh" "$TMP/nosuchdir" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "bad target rc" "2" "$rc"

rc=0; "$SKILL/scripts/standup.sh" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "no-args usage rc" "1" "$rc"

report "standup-test"
