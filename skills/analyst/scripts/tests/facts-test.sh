#!/usr/bin/env bash
# facts-test.sh — exercise analyst-facts.sh against a planted fixture.
#
# Patient-zero holds: the fixture is built in a mktemp dir; nothing here runs
# against the library's own tree or any real project.
#
# Every assertion is paired with a BREAK case: the fixture is mutated so the
# fact should disappear, and the test asserts it does. A check nobody has seen
# fail is not a check (grimoire gate doctrine).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
FACTS="$HERE/../analyst-facts.sh"
# shellcheck source=/dev/null
. "$HERE/lib.sh"

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT
OUT="$FIX/out.txt"

# --- build the fixture -------------------------------------------------------

mk_record() { # mk_record <store> <name> <status> <updated> [extra-body]
  mkdir -p "$FIX/.records/$1"
  cat > "$FIX/.records/$1/$2.md" <<EOF
---
doctype: $1
status: $3
created: $4
updated: $4
tags: [${5:-}]
---

# $2

${6:-Fixture body.}
EOF
}

mkdir -p "$FIX/.records/scripts" "$FIX/.records/templates" "$FIX/.records/trackers"

# Two closures in span, one long before it.
mk_record plans   2026-08-10-planted-feature "done"      2026-08-10
mk_record plans   2026-08-12-second-feature "done"      2026-08-12
mk_record plans   2026-01-05-ancient-work "done"      2026-01-05
# An open record inside the span, and a stale open one.
mk_record specs   2026-08-14-open-design     open      2026-08-14
mk_record bugs    2026-02-01-stale-bug       open      2026-02-01
# An audit report the health snapshot must attribute, never re-derive.
mk_record reports 2026-08-05-audit-pass      open      2026-08-05 audit

printf '%s\n' \
  "2026-08-10	done	plans/2026-08-10-planted-feature.md	plans	planted closure" \
  "2026-08-12	done	plans/2026-08-12-second-feature.md	plans	second closure" \
  "2026-01-05	done	plans/2026-01-05-ancient-work.md	plans	out of span" \
  > "$FIX/.records/history.tsv"

cat > "$FIX/.records/trackers/2026-08-14-backlog.md" <<'EOF'
---
doctype: trackers
status: current
created: 2026-08-01
updated: 2026-08-14
tags: []
---

# Backlog
- planted tracker line one
- planted tracker line two
EOF

mkdir -p "$FIX/src/widget"
echo 'fn main() {}' > "$FIX/src/widget/mod.rs"

git -C "$FIX" init -q
git -C "$FIX" config user.email t@example.com
git -C "$FIX" config user.name Test
git -C "$FIX" add -A
git -C "$FIX" commit -qm "planted commit touching the widget subsystem"

# --- span --------------------------------------------------------------------

"$FACTS" span "$FIX" --since 2026-08-01 > "$OUT" 2>&1
expect "span: records layer found"        "records_layer=present"  "$OUT"
expect "span: ledger found"               "ledger=present"         "$OUT"
expect "span: counts the two in-span closures" "closures=2"        "$OUT"
expect "span: surfaces the planted closure"    "planted closure"   "$OUT"
expect_absent "span: excludes the out-of-span closure" "out of span" "$OUT"
expect "span: surfaces the in-span open record" "2026-08-14-open-design.md" "$OUT"

# BREAK: remove the planted closure — the fact must vanish.
grep -v 'planted closure' "$FIX/.records/history.tsv" > "$FIX/tmp" && mv "$FIX/tmp" "$FIX/.records/history.tsv"
"$FACTS" span "$FIX" --since 2026-08-01 > "$OUT" 2>&1
expect_absent "span BREAK: planted closure gone" "planted closure" "$OUT"
expect "span BREAK: count drops to one"          "closures=1"      "$OUT"
printf '%s\n' "2026-08-10	done	plans/2026-08-10-planted-feature.md	plans	planted closure" \
  >> "$FIX/.records/history.tsv"

# --- status ------------------------------------------------------------------

"$FACTS" status "$FIX" > "$OUT" 2>&1
# Open: the design record, the stale bug, and the audit report.
expect "status: counts open records"        "open_records=3"          "$OUT"
expect "status: lists the open design"      "2026-08-14-open-design"  "$OUT"
expect "status: counts tracker lines"       "trackers/2026-08-14-backlog.md	2"  "$OUT"

# BREAK: close the open design — the open count must drop.
sed -i.bak 's/^status: open/status: done/' "$FIX/.records/specs/2026-08-14-open-design.md"
"$FACTS" status "$FIX" > "$OUT" 2>&1
expect "status BREAK: open count drops"     "open_records=2"          "$OUT"
sed -i.bak 's/^status: done/status: open/' "$FIX/.records/specs/2026-08-14-open-design.md"

# --- a shared records home holds non-records (was BL-28) ----------------------
# `each_record` must agree with `records.sh`'s discriminator. As a denylist it
# drifted once by omitting `doctrine/`, so a host with doctrine under the records
# home had its chapters counted as open records here but not by `records.sh`.
# Both sides are now the same positive test, so there is no list to drift. The
# three directories are planted with an undated, otherwise contract-shaped
# `status: open` file each -- exactly what a template or a doctrine page looks
# like. If any is scanned, the open count moves.
for shared in doctrine templates scripts; do
  mkdir -p "$FIX/.records/$shared"
  cat > "$FIX/.records/$shared/planted.md" <<'EOF'
---
doctype: specs
status: open
created: 2026-08-01
updated: 2026-08-01
tags: []
---

# Planted in a home shared with the records root
EOF
done
"$FACTS" status "$FIX" > "$OUT" 2>&1
expect "shared home: doctrine/templates/scripts are not records" "open_records=3" "$OUT"
expect_absent "shared home: no planted file is listed"           "planted"        "$OUT"

# Red-proof the conjunct that does the work: date the SAME file and it becomes a
# record. Without this, the assertion above would also pass if each_record were
# broken outright (a scan that finds nothing excludes everything).
mv "$FIX/.records/templates/planted.md" "$FIX/.records/templates/2026-08-01-planted.md"
[ -f "$FIX/.records/templates/2026-08-01-planted.md" ] || { echo "FAIL: rename fixture not applied" >&2; exit 1; }
"$FACTS" status "$FIX" > "$OUT" 2>&1
expect "shared home: dating the same file makes it a record" "open_records=4" "$OUT"
mv "$FIX/.records/templates/2026-08-01-planted.md" "$FIX/.records/templates/planted.md"
"$FACTS" status "$FIX" > "$OUT" 2>&1
expect "shared home: undating it again restores the count" "open_records=3" "$OUT"

# --- health ------------------------------------------------------------------

"$FACTS" health "$FIX" > "$OUT" 2>&1
expect "health: counts the open bug"          "open_bugs=1"                "$OUT"
expect "health: flags the stale open record"  "stale_open_records="        "$OUT"
expect "health: finds the audit report"       "audit_reports=1"            "$OUT"
expect "health: attributes the audit by path" "2026-08-05-audit-pass.md"   "$OUT"
# The gate is NEVER run here — the fact must say so, not report a result.
expect "health: gate state is not-run"        "gate_state=unknown-not-run" "$OUT"
expect_absent "health: emits no score"        "score="                     "$OUT"

# BREAK: close the bug — the defect count must drop.
sed -i.bak 's/^status: open/status: done/' "$FIX/.records/bugs/2026-02-01-stale-bug.md"
"$FACTS" health "$FIX" > "$OUT" 2>&1
expect "health BREAK: bug count drops"        "open_bugs=0"                "$OUT"
sed -i.bak 's/^status: done/status: open/' "$FIX/.records/bugs/2026-02-01-stale-bug.md"

# --- subsystem ---------------------------------------------------------------

"$FACTS" subsystem "$FIX" --path src/widget > "$OUT" 2>&1
expect "subsystem: confirms the path exists"  "path_exists[src/widget]=true" "$OUT"
expect "subsystem: finds the planted commit"  "planted commit"               "$OUT"

"$FACTS" subsystem "$FIX" --path src/nonexistent > "$OUT" 2>&1
expect "subsystem BREAK: absent path reported false" "path_exists[src/nonexistent]=false" "$OUT"

# --- catalog -----------------------------------------------------------------

"$FACTS" catalog "$FIX" > "$OUT" 2>&1
expect "catalog: reports nothing deployed yet" "deployed=false" "$OUT"
expect "catalog: lists briefing as bundled"    "briefing	bundled" "$OUT"

mkdir -p "$FIX/.records/templates/analyst"
cp "$HERE/../../templates/briefing.md" "$FIX/.records/templates/analyst/briefing.md"
cat > "$FIX/.records/templates/analyst/house-style.md" <<'EOF'
---
template: house-style
use-when: "A project-local report kind."
inputs: records
---
EOF
"$FACTS" catalog "$FIX" > "$OUT" 2>&1
expect "catalog: deployed copy wins"        "briefing	deployed"     "$OUT"
expect "catalog: finds host-added template" "house-style	host-added" "$OUT"

# --- standalone degrade (no records layer) -----------------------------------

BARE="$(mktemp -d)"
trap 'rm -rf "$FIX" "$BARE"' EXIT
git -C "$BARE" init -q
git -C "$BARE" config user.email t@example.com
git -C "$BARE" config user.name Test
echo hi > "$BARE/README.md"
git -C "$BARE" add -A
git -C "$BARE" commit -qm "bare repo commit"

rc=0
"$FACTS" span "$BARE" --since 2026-08-01 > "$OUT" 2>&1 || rc=$?
expect_eq "degrade: exits 0, never refuses" "0" "$rc"
expect "degrade: reports the absent layer" "records_layer=absent" "$OUT"
expect "degrade: still reports git facts"  "commits="             "$OUT"

"$FACTS" status "$BARE" > "$OUT" 2>&1
expect "degrade: status survives no layer" "open_records=0" "$OUT"

report "analyst facts"
