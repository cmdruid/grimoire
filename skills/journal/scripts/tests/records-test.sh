#!/usr/bin/env bash
# records-test.sh — four-key mint, lifecycle, validation, and relocation.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/journal-records-test.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"
proj="$TMP/proj"
mkdir -p "$proj"
"$SKILL/scripts/standup.sh" setup "$proj" \
 >/dev/null

RS="$proj/.records/records.sh"
rs() { "$RS" "$@"; }
today="$(date +%Y-%m-%d)"

# Journal synthesizes metadata. A project template is body-only and optional.
body="$TMP/body.md"
printf '# <title>\n\nMinted <date>.\n' > "$body"
p="$(rs new plans --schema contractor/plan@1 --title 'Alpha plan' --template "$body" --tag plan --tag alpha)"
expect_eq "new prints canonical path" "$proj/.records/plans/$today-alpha-plan.md" "$p"
expect "doctype synthesized" "doctype: plans" "$p"
expect "schema synthesized" "schema: contractor/plan@1" "$p"
expect "tags synthesized" "tags: [plan, alpha]" "$p"
expect "title substituted literally" "# Alpha plan" "$p"
expect "date substituted literally" "Minted $today." "$p"
expect_absent "created is not minted" "created:" "$p"
expect_absent "updated is not minted" "updated:" "$p"

plain="$(rs new notes --schema notepad/note@1 --title 'No body template')"
expect "template-less mint has title" "# No body template" "$plain"

rc=0; rs new notes --title Missing --schema '' >"$OUT" 2>"$ERR" || rc=$?
expect_eq "schema required rc" "2" "$rc"
expect "schema required finding" "--schema is required" "$ERR"
rc=0; rs new notes --title Bad --schema Notepad/note@0 >"$OUT" 2>"$ERR" || rc=$?
expect_eq "schema grammar rc" "2" "$rc"
expect "schema grammar finding" "invalid schema" "$ERR"
printf '# <title>\n<schema>\n' > "$TMP/bad-schema.md"
rc=0; rs new notes --title Bad --schema notepad/note@1 --template "$TMP/bad-schema.md" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "schema body slot refused rc" "2" "$rc"
expect "schema body slot finding" "forbidden <schema>" "$ERR"
printf '# <title>\n<tags>\n' > "$TMP/bad-tags.md"
rc=0; rs new notes --title Bad --schema notepad/note@1 --template "$TMP/bad-tags.md" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "tags body slot refused rc" "2" "$rc"

# List/search dates come from the filename, not mutable metadata.
rs list > "$OUT"
expect "list includes filename date column" "plans/$today-alpha-plan.md"$'\t'"plans"$'\t'"draft"$'\t'"$today" "$OUT"
rs list --since "$today" --until "$today" > "$OUT"
expect "date bounds use filename" "alpha-plan" "$OUT"
rs list --until 2000-01-01 > "$OUT"
expect_absent "date bounds exclude newer filename" "alpha-plan" "$OUT"

# Lifecycle mutates status only and Journal rejects legacy inputs.
rs touch "$p" --status published >/dev/null
expect "touch changes status" "status: published" "$p"
expect_absent "touch does not add updated" "updated:" "$p"
rs 'done' "$p" --as consumed --note folded > "$OUT"
expect "done closes in place" "status: archived" "$p"
expect "done appends ledger" "consumed"$'\t'"plans/$today-alpha-plan.md" "$proj/.records/history.tsv"
expect_absent "done does not add updated" "updated:" "$p"

legacy="$proj/.records/notes/2020-01-01-legacy.md"
mkdir -p "$(dirname "$legacy")"
printf '%s\n' '---' 'doctype: notes' 'status: draft' 'created: 2020-01-01' 'updated: 2020-01-02' 'tags: []' '---' '# Legacy' > "$legacy"
rc=0; rs check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "legacy profile fails check rc" "2" "$rc"
expect "legacy lacks schema" "missing key: schema" "$ERR"
expect "created is retired" "retired reserved key: created" "$ERR"
expect "updated is retired" "retired reserved key: updated" "$ERR"
rc=0; rs touch "$legacy" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "ordinary mutation rejects legacy rc" "2" "$rc"
expect "legacy routes to owning migrator" "owning skill's migrate" "$ERR"
rm "$legacy"

for key in created_at updated_at revision; do
  bad="$proj/.records/notes/$today-retired-$key.md"
  printf '%s\n' '---' 'doctype: notes' 'status: draft' 'schema: notepad/note@1' "$key: 1" 'tags: []' '---' '# Bad' > "$bad"
  rc=0; rs check >"$OUT" 2>"$ERR" || rc=$?
  expect_eq "$key rejected rc" "2" "$rc"
  expect "$key rejected" "retired reserved key: $key" "$ERR"
  rm "$bad"
done
bad="$proj/.records/notes/$today-bad-schema.md"
printf '%s\n' '---' 'doctype: notes' 'status: draft' 'schema: note@0' 'tags: []' '---' '# Bad' > "$bad"
rc=0; rs check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "bad schema check rc" "2" "$rc"
expect "bad schema finding" "schema not in writer/artifact@positive-integer grammar" "$ERR"
rm "$bad"
rs check > "$OUT"
expect "current corpus checks" "records check: OK" "$OUT"

# Relocation materializes current staged bytes, then fixes ledger and internal
# exact links before deleting the old identity.
source="$proj/.records/reports/$today-debrief.md"
mkdir -p "$(dirname "$source")"
printf '%s\n' '---' 'doctype: reports' 'status: archived' 'schema: workstream/debrief@1' 'tags: [debrief]' '---' '# Debrief' > "$source"
printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$today" 'done' "reports/$today-debrief.md" reports Debrief - >> "$proj/.records/history.tsv"
printf '\nSee → reports/%s-debrief.md\n' "$today" >> "$plain"
rs relocate "reports/$today-debrief.md" --to "streams/$today-debrief.md" > "$OUT"
expect "relocation reports identities" "reports/$today-debrief.md"$'\t'"streams/$today-debrief.md" "$OUT"
[ ! -e "$source" ] && pass=$((pass + 1)) || { echo "FAIL: relocation retained source" >&2; fail=$((fail + 1)); }
[ -f "$proj/.records/streams/$today-debrief.md" ] && pass=$((pass + 1)) || { echo "FAIL: relocation omitted destination" >&2; fail=$((fail + 1)); }
expect "ledger retargeted" "streams/$today-debrief.md" "$proj/.records/history.tsv"
expect_absent "old ledger identity gone" "reports/$today-debrief.md" "$proj/.records/history.tsv"
expect "internal link retargeted" "→ streams/$today-debrief.md" "$plain"

# External references are reported and block before writes.
blocked="$proj/.records/reports/$today-blocked.md"
printf '%s\n' '---' 'doctype: reports' 'status: draft' 'schema: analyst/report@1' 'tags: [analyst, status]' '---' '# Blocked' > "$blocked"
printf 'outside → reports/%s-blocked.md\n' "$today" > "$proj/README.external"
rc=0; rs relocate "reports/$today-blocked.md" --to "archive/$today-blocked.md" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "external reference blocks rc" "2" "$rc"
expect "external reference finding" "external references block relocation" "$ERR"
[ -f "$blocked" ] && pass=$((pass + 1)) || { echo "FAIL: blocked source moved" >&2; fail=$((fail + 1)); }
[ ! -e "$proj/.records/archive/$today-blocked.md" ] && pass=$((pass + 1)) || { echo "FAIL: blocked destination written" >&2; fail=$((fail + 1)); }

# A handled mid-transaction failure leaves resumable state. The next identical
# invocation discovers the manifest before requiring source completion and
# advances rather than rolling back.
recover="$proj/.records/reports/$today-recover.md"
printf '%s\n' '---' 'doctype: reports' 'status: draft' 'schema: workstream/debrief@1' 'tags: [debrief]' '---' '# Recover' > "$recover"
rc=0
RECORDS_TEST_FAIL_AFTER_PHASE=1 rs relocate "reports/$today-recover.md" --to "streams/$today-recover.md" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "injected relocation failure rc" "2" "$rc"
[ -f "$proj/.records/reports/.journal-relocate-manifest" ] && pass=$((pass + 1)) || { echo "FAIL: recovery manifest absent" >&2; fail=$((fail + 1)); }
[ -f "$recover" ] && pass=$((pass + 1)) || { echo "FAIL: source removed before recovery phase" >&2; fail=$((fail + 1)); }
[ -f "$proj/.records/streams/$today-recover.md" ] && pass=$((pass + 1)) || { echo "FAIL: staged destination absent at recovery phase" >&2; fail=$((fail + 1)); }
rs relocate "reports/$today-recover.md" --to "streams/$today-recover.md" > "$OUT"
[ ! -e "$recover" ] && pass=$((pass + 1)) || { echo "FAIL: recovery retained source" >&2; fail=$((fail + 1)); }
[ ! -e "$proj/.records/reports/.journal-relocate-manifest" ] && pass=$((pass + 1)) || { echo "FAIL: recovery retained manifest" >&2; fail=$((fail + 1)); }

report "records-test"
