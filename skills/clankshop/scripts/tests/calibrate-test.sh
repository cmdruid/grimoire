#!/bin/sh
# calibrate-test.sh -- the improvement-loop fixtures (plan Task 2.11): the intake
# scan's claim discipline (a repeated pass dispatches nothing already claimed; a
# concurrent second pass sees the first pass's trunk-side claim and dispatches
# nothing), pause skipping, the two-finding report (one finding processed never
# hides the other), and unstamped refusal.
set -eu
DIR=$(CDPATH='' cd "$(dirname "$0")" && pwd -P)
. "$DIR/lib.sh"
pass=0; fail=0   # re-assigned by lib.sh's helpers (shellcheck cannot follow the source)
CLANKSHOP_SCRIPTS=$(CDPATH='' cd "$DIR/.." && pwd -P)
CAL_SCRIPTS=$(CDPATH='' cd "$DIR/.." && pwd -P)

TMP=$(mktemp -d "${TMPDIR:-/tmp}/clankshop-calibrate.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
TODAY=$(date +%Y-%m-%d)

R="$TMP/proj"
mkdir -p "$R/.records/trackers/notes" "$R/.records/reports"
( cd "$R" && git init -q . && git config user.email t@e.st && git config user.name t )

# ---- unstamped refusal ----
out=$(sh "$CAL_SCRIPTS/intake-scan.sh" "$R")
expect_eq "unstamped root refuses" "unstamped=1" "$out"

printf '# Front door\n' > "$R/AGENTS.md"
sh "$CLANKSHOP_SCRIPTS/install-block.sh" write "$R" 1 clankshop 1 > /dev/null

cat > "$R/.records/trackers/feedback.md" <<'EOF'
# Feedback

### F-001 · the gate is slow · 2026-08-07

worth a look.

### F-002 · paused one · 2026-08-07 [⇧ TK-2026-08-07-x]

the human owns this.
EOF

cat > "$R/.records/trackers/tasks.md" <<'EOF'
# Tasks

## Loose ends
EOF

cat > "$R/.records/trackers/notes/trap.md" <<'EOF'
---
type: note
id: N-001
status: evergreen
updated: 2026-08-07
---

# a durable trap
EOF

cat > "$R/.records/reports/doc-drift-2026-08-07-sweep.md" <<'EOF'
---
type: doc-drift
id: doc-drift-2026-08-07-sweep
date: 2026-08-07
source: audit
processed: [stale-map]
---

# report

#### gate-gap — the gate misses doc checks

body.

#### stale-map — the stewardship map is stale

body.
EOF

SCAN() { sh "$CAL_SCRIPTS/intake-scan.sh" "$R" > "$TMP/out"; }

# ---- first pass: eligible set is exactly the unclaimed/unpaused/unprocessed ----
SCAN
expect "unclaimed feedback eligible" "eligible=F-001" "$TMP/out"
expect "paused feedback skipped" "skipped_paused=F-002" "$TMP/out"
expect_absent "paused never eligible" "eligible=F-002" "$TMP/out"
expect "note eligible" "eligible=N-001" "$TMP/out"
expect "unprocessed report finding eligible" "eligible=doc-drift-2026-08-07-sweep#gate-gap" "$TMP/out"
expect "processed finding skipped (never hides the sibling)" "skipped_claimed=doc-drift-2026-08-07-sweep#stale-map" "$TMP/out"
expect_absent "processed finding not eligible" "eligible=doc-drift-2026-08-07-sweep#stale-map" "$TMP/out"

# ---- claim (the trunk-side serialization point), then the repeated pass ----
sed -i '' "s|### F-001 · the gate is slow · 2026-08-07|### F-001 · the gate is slow · 2026-08-07 [⇢ dispatched $TODAY]|" "$R/.records/trackers/feedback.md"
sed -i '' "s|^updated: 2026-08-07|updated: 2026-08-07\ndispatched: $TODAY|" "$R/.records/trackers/notes/trap.md"
printf -- '- T-001 — improve: close the gate gap · source: doc-drift-2026-08-07-sweep#gate-gap · added %s\n' "$TODAY" >> "$R/.records/trackers/tasks.md"
( cd "$R" && git add -A && git commit -qm "claims" )

SCAN
expect "claimed feedback skipped on the repeated pass" "skipped_claimed=F-001" "$TMP/out"
expect "claim age surfaced" "claim_age=F-001:$TODAY" "$TMP/out"
expect "claimed note skipped" "skipped_claimed=N-001" "$TMP/out"
expect "materialized T- item claims its finding" "skipped_claimed=doc-drift-2026-08-07-sweep#gate-gap" "$TMP/out"
expect_absent "nothing already claimed re-dispatches" "eligible=F-001" "$TMP/out"
expect_absent "no eligible findings remain" "eligible=doc-drift" "$TMP/out"

# ---- concurrent second pass: a clone at the pre-claim state pulls the trunk and sees the claims ----
( cd "$TMP" && git clone -q "$R" proj-b )
B="$TMP/proj-b"
out_b=$(sh "$CAL_SCRIPTS/intake-scan.sh" "$B")
printf '%s\n' "$out_b" > "$TMP/outb"
expect "concurrent pass sees the landed claim" "skipped_claimed=F-001" "$TMP/outb"
expect_absent "concurrent pass dispatches nothing claimed" "eligible=F-001" "$TMP/outb"

echo "calibrate: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
