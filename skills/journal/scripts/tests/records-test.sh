#!/usr/bin/env bash
# records-test.sh — the deployed records.sh end to end: the new→touch→done→history
# lifecycle round-trip (ledger line appended), list/history filters, and `check`
# proven by breaking — broken front-matter, closed-status-without-ledger-line,
# a malformed ledger, and every refusal the script advertises.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/journal-records-test.XXXXXX")"
TMP="$(cd "$TMP" && pwd)"   # canonical (a trailing-slash TMPDIR would break path equality)
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

proj="$TMP/proj"
mkdir -p "$proj"
"$SKILL/scripts/standup.sh" "$proj" >/dev/null
RS="$proj/.records/scripts/records.sh"
today="$(date +%Y-%m-%d)"

# --- new: minted from the template, slots filled, date-slug filename ------------
p="$("$RS" new plans --title "Alpha: the first plan")"
expect_eq "new prints the path" "$proj/.records/plans/$today-alpha-the-first-plan.md" "$p"
expect "front-matter doctype" "doctype: plans" "$p"
expect "front-matter status open" "status: open" "$p"
expect "front-matter created stamped" "created: $today" "$p"
expect "title slot filled" "# Alpha: the first plan" "$p"
expect_absent "no unfilled date slot" "<date>" "$p"
expect_absent "no unfilled title slot" "<title>" "$p"

p2="$("$RS" new plans --title "Alpha: the first plan")"
expect_eq "colliding slug gets a suffix" "$proj/.records/plans/$today-alpha-the-first-plan-2.md" "$p2"

# --- list: TSV row + filters -----------------------------------------------------
"$RS" new notes --title "A fact" >/dev/null
"$RS" list >"$OUT"
expect "list row is TSV" "plans/$today-alpha-the-first-plan.md	plans	open	$today" "$OUT"
"$RS" list --type notes >"$OUT"
expect "type filter keeps notes" "A fact" "$OUT"
expect_absent "type filter drops plans" "plans" "$OUT"
sed -i.bak "s/^tags: \[\]/tags: [alpha, hot]/" "$p" && rm -f "$p.bak"
"$RS" list --tag hot >"$OUT"
expect "tag filter matches" "alpha-the-first-plan" "$OUT"
"$RS" list --tag cold >"$OUT"
expect_absent "tag filter excludes" "alpha-the-first-plan" "$OUT"

# --- touch: stamps without hand-editing ------------------------------------------
"$RS" touch "$p" --status current >/dev/null
expect "touch sets status" "status: current" "$p"
expect "touch keeps updated stamped" "updated: $today" "$p"

# --- done: closure in place + the one ledger line --------------------------------
"$RS" 'done' "$p" --as consumed --note "folded into the spec" >"$OUT"
expect "done reports the ledger line" "consumed	plans/$today-alpha-the-first-plan.md" "$OUT"
expect "record closed in place" "status: consumed" "$p"
expect "ledger line appended" "$today	consumed	plans/$today-alpha-the-first-plan.md	plans	Alpha: the first plan	folded into the spec" "$proj/.records/history.tsv"

"$RS" history >"$OUT"
expect "history round-trips" "folded into the spec" "$OUT"
"$RS" history --disposition dropped >"$OUT"
expect_absent "disposition filter excludes" "consumed" "$OUT"
"$RS" history --grep "folded" >"$OUT"
expect "history grep matches" "consumed" "$OUT"

"$RS" check >"$OUT"
expect "check green after lifecycle" "records check: OK (3 records)" "$OUT"

# --- proven by breaking -----------------------------------------------------------
rc=0; "$RS" 'done' "$p" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "double-done refused rc" "2" "$rc"
expect "double-done names the status" "already closed (consumed)" "$ERR"

rc=0; "$RS" touch "$p2" --status 'done' >"$OUT" 2>"$ERR" || rc=$?
expect_eq "closing via touch refused rc" "2" "$rc"
expect "closing via touch routed to done" "closing status goes through 'done'" "$ERR"

rc=0; "$RS" 'done' "$p2" --as wontfix >"$OUT" 2>"$ERR" || rc=$?
expect_eq "unknown disposition rc" "2" "$rc"

rc=0; "$RS" new gizmos --title "No such store" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "unknown doctype rc" "2" "$rc"
expect "unknown doctype names the template" "no template for doctype 'gizmos'" "$ERR"

rc=0; "$RS" touch "$proj/.records/templates/adr.md" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "reserved path refused rc" "2" "$rc"
expect "reserved path named" "reserved path" "$ERR"

rc=0; "$RS" show "plans/nope.md" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "missing record rc" "2" "$rc"

# broken front-matter: check FAILs and names each violation
bad="$proj/.records/notes/$today-broken.md"
printf -- '---\ndoctype: bugs\nstatus: bogus\ncreated: 2026-8-1\n---\n# Broken\n' > "$bad"
rc=0; "$RS" check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "broken front-matter check rc" "2" "$rc"
expect "check flags missing key" "missing key: updated" "$ERR"
expect "check flags store mismatch" "does not match store 'notes'" "$ERR"
expect "check flags bad status" "status not in the contract: bogus" "$ERR"
expect "check flags bad date" "created is not YYYY-MM-DD: 2026-8-1" "$ERR"
rm "$bad"

# closed status with no ledger line: the coherence half of check
sneaky="$proj/.records/notes/$today-sneaky.md"
printf -- '---\ndoctype: notes\nstatus: done\ncreated: %s\nupdated: %s\ntags: []\n---\n# Sneaky\n' "$today" "$today" > "$sneaky"
rc=0; "$RS" check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "closed-without-ledger check rc" "2" "$rc"
expect "check names the coherence break" "closing status 'done' but no history.tsv ledger line" "$ERR"
rm "$sneaky"

# malformed ledger: hand-written lines are a fact check reports
echo "garbage line" >> "$proj/.records/history.tsv"
rc=0; "$RS" check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "malformed ledger check rc" "2" "$rc"
expect "check counts ledger fields" "1 fields (want 6)" "$ERR"

report "records-test"
