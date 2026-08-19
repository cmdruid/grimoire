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

# Brownfield omitted --template: standup no longer plants templates/, so the
# fixture mkdir's the dest and drops contract-shaped files there. records.sh
# is the subject; it mints from whatever path it is given (or $RR/templates/).
mkdir -p "$proj/.records/templates"
for t in plans notes trackers tickets; do
  printf -- '---\ndoctype: %s\nstatus: open\ncreated: <date>\nupdated: <date>\ntags: []\n---\n\n# <title>\n' "$t" \
    > "$proj/.records/templates/$t.md"
done

# --- --template: path outside $RR is accepted -----------------------------------
outside="$TMP/outside-plans.md"
printf -- '---\ndoctype: plans\nstatus: open\ncreated: <date>\nupdated: <date>\ntags: []\n---\n\n# <title>\noutside\n' \
  > "$outside"
p_out="$("$RS" new plans --template "$outside" --title "From outside")"
expect_eq "new --template outside \$RR" "$proj/.records/plans/$today-from-outside.md" "$p_out"
expect "outside template body used" "outside" "$p_out"
expect "outside template title filled" "# From outside" "$p_out"

# omitted --template still reads $RR/templates/<doctype>.md (brownfield)
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
expect "check green after lifecycle" "records check: OK (4 records)" "$OUT"

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

rc=0; "$RS" touch "$proj/.records/templates/notes.md" >"$OUT" 2>"$ERR" || rc=$?
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

# --- record links: `→ <store>/<file>.md` must resolve (link-rot detection) --------
tr_rec="$("$RS" new trackers --title "Backlog")"
note_rel="$("$RS" list --type notes | head -1 | cut -f1)"
printf -- '- [ ] %s — wire the alpha [→ %s]\n' "$today" "$note_rel" >> "$tr_rec"
printf -- '- [ ] %s — prose example, unchecked [→ path/to/linked-record.md]\n' "$today" >> "$tr_rec"
"$RS" check >"$OUT"
expect "resolving link passes check" "records check: OK" "$OUT"
printf -- '- [ ] %s — rotted [→ notes/never-existed.md]\n' "$today" >> "$tr_rec"
rc=0; "$RS" check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "broken link check rc" "2" "$rc"
expect "check names the broken link" "broken link → notes/never-existed.md" "$ERR"
sed -i.bak '/rotted/d' "$tr_rec" && rm -f "$tr_rec.bak"

# A template teaching the tracker-line FORM must name a real store to be useful,
# which defeats the first-segment filter -- so code blocks are skipped outright.
# Both fence styles and the four-space indent, since templates use all three.
printf -- '\n    - [ ] %s — indented example [→ notes/%s-nope.md]\n' "$today" "$today" >> "$tr_rec"
printf -- '\n```\n- [ ] %s — fenced example [→ notes/%s-also-nope.md]\n```\n' "$today" "$today" >> "$tr_rec"
lrc=0; "$RS" check >"$OUT" 2>"$ERR" || lrc=$?   # rc captured so a regression here
expect_eq "example links in code blocks do not fail the check" "0" "$lrc"  # reports, not aborts
expect "example links inside code blocks are not followed" "records check: OK" "$OUT"
# Red-proof: the skip must not be a blanket amnesty -- a real link OUTSIDE a code
# block, added while those examples remain, still has to fail.
printf -- '- [ ] %s — rotted-again [→ notes/never-existed-either.md]\n' "$today" >> "$tr_rec"
rc=0; "$RS" check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "real rot still caught alongside examples" "2" "$rc"
expect "check still names the real broken link" "broken link → notes/never-existed-either.md" "$ERR"
sed -i.bak '/rotted-again/d' "$tr_rec" && rm -f "$tr_rec.bak"

# --- open-ticket visibility: check surfaces the count both ways -------------------
"$RS" check >"$OUT"
expect "no tickets reports zero" "open tickets: 0" "$OUT"
tk="$("$RS" new tickets --title "Need the API key")"
"$RS" check >"$OUT"
expect "open ticket surfaces in check" "open tickets: 1" "$OUT"
"$RS" 'done' "$tk" --note "key provided" >/dev/null
"$RS" check >"$OUT"
expect "closed ticket leaves the count" "open tickets: 0" "$OUT"

# --- prune-candidates: still-existing × still-closed × ledger-dated ---------------
"$RS" prune-candidates >"$OUT"
expect "consumed plan is a prune candidate" "consumed	plans/$today-alpha-the-first-plan.md" "$OUT"
"$RS" prune-candidates --until 2000-01-01 >"$OUT"
expect_absent "until-filter excludes newer closures" "alpha-the-first-plan" "$OUT"
"$RS" touch "$tk" --status open >/dev/null   # reopened after closure: no longer prunable
"$RS" prune-candidates >"$OUT"
expect_absent "reopened record is not a candidate" "need-the-api-key" "$OUT"
rm "$proj/.records/plans/$today-alpha-the-first-plan.md"   # pruned: ledger line stays,
"$RS" prune-candidates >"$OUT"                             # candidate disappears
expect_absent "pruned record drops off the shortlist" "alpha-the-first-plan" "$OUT"
"$RS" check >"$OUT"
expect "check green after prune (ledger line survives)" "records check: OK" "$OUT"

# --- reserved `doctrine/` -------------------------------------------------------
# A host whose agent-workspace and agent-records homes coincide keeps its
# doctrine at <agent-records>/doctrine: living normative prose with no record
# front-matter. Two arms guard it and they are proven
# INDEPENDENTLY on purpose -- a check-only proof passes a partial fix (patch
# stores(), leave resolve() broken, and `check` still returns OK while `show`
# happily cats the file). So stores() is proven via check/list, resolve() via
# show/touch.
mkdir -p "$proj/.records/doctrine/test/workflows"
printf '# Diagnostics\n\nLiving normative prose. No front-matter, by design.\n' \
  > "$proj/.records/doctrine/test/workflows/diagnostics.md"

# arm 1 -- stores(): doctrine is not a store, so check stays green and list ignores it
rc=0; "$RS" check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "doctrine dir keeps check green rc" "0" "$rc"
expect "doctrine dir does not break check" "records check: OK" "$OUT"
"$RS" list >"$OUT"
expect_absent "doctrine file is not listed as a record" "doctrine/" "$OUT"

# arm 2 -- resolve(): a doctrine path is refused as a record
rc=0; "$RS" show doctrine/test/workflows/diagnostics.md >"$OUT" 2>"$ERR" || rc=$?
expect_eq "show refuses a doctrine path rc" "2" "$rc"
expect "show names the reserved path" "reserved path, not a record" "$ERR"
rc=0; "$RS" touch doctrine/test/workflows/diagnostics.md >"$OUT" 2>"$ERR" || rc=$?
expect_eq "touch refuses a doctrine path rc" "2" "$rc"
expect "touch names the reserved path" "reserved path, not a record" "$ERR"

# A doctrine doc may legitimately carry its own front-matter, which weakens
# require_record's "not a record?" fallback. Note the rc assertions here can still
# pass for the WRONG reason (require_record also rejects on the five-key contract),
# so the MESSAGE assertions are the real discriminator: with the resolve() arm
# reverted, `reserved path, not a record` disappears while the exit code does not
# change. Verified by breaking -- reverting that arm turns these red.
printf -- '---\ntitle: Diagnostics\nowner: test station\n---\n\n# Diagnostics\n\nProse.\n' \
  > "$proj/.records/doctrine/test/workflows/stamped.md"
rc=0; "$RS" touch doctrine/test/workflows/stamped.md >"$OUT" 2>"$ERR" || rc=$?
expect_eq "touch refuses front-mattered doctrine rc" "2" "$rc"
expect "front-mattered doctrine named reserved" "reserved path, not a record" "$ERR"

# malformed ledger: hand-written lines are a fact check reports
echo "garbage line" >> "$proj/.records/history.tsv"
rc=0; "$RS" check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "malformed ledger check rc" "2" "$rc"
expect "check counts ledger fields" "1 fields (want 6)" "$ERR"

report "records-test"
