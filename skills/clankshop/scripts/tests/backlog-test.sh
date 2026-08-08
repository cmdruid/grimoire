#!/bin/sh
# backlog-test.sh -- the completion-mutation fixtures (plan Task 2.1): done-entry.sh
# against the record schema's completion table. The removal-span cases prove the
# equal-or-higher-rank rule (category headers survive completing a category's last
# entry); the refusal cases prove absent/completed/paused/unstamped conduct.
# Fixture instances are temp-dir-local and destroyed; patient-zero holds.
set -eu
DIR=$(CDPATH='' cd "$(dirname "$0")" && pwd -P)
. "$DIR/lib.sh"
pass=0; fail=0   # re-assigned by lib.sh's helpers (shellcheck cannot follow the source)
CLANKSHOP_SCRIPTS=$(CDPATH='' cd "$DIR/.." && pwd -P)
BACKLOG_SCRIPTS=$(CDPATH='' cd "$DIR/../../../backlog/scripts" && pwd -P)

TMP=$(mktemp -d "${TMPDIR:-/tmp}/clankshop-backlog.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

R="$TMP/proj"
mkdir -p "$R/.records/trackers/bugs" "$R/.records/trackers/notes"
( cd "$R" && git init -q . )

# ---- unstamped refusal (before any installation block exists) ----
out=$(sh "$BACKLOG_SCRIPTS/done-entry.sh" "$R" T-001 "done" "gist")
expect_eq "unstamped root refuses" "unstamped=1" "$out"

# ---- stamp the root, seed the trackers ----
printf '# Front door\n' > "$R/AGENTS.md"
sh "$CLANKSHOP_SCRIPTS/install-block.sh" write "$R" 1 clankshop 1 > /dev/null

cat > "$R/.records/trackers/tasks.md" <<'EOF'
# Tasks

## Loose ends

- T-001 — first task · added 2026-08-07
- T-002 — second task [⇧ TK-2026-08-07-pause] · added 2026-08-07

## Future scope

- T-003 — future task · added 2026-08-07
EOF

cat > "$R/.records/trackers/issues.md" <<'EOF'
# Issues

## Problems / limitations

### I-001 — first problem (HIGH)

**What's wrong** first body.

### I-002 — second problem (LOW)

**What's wrong** second body.

### I-003 — third problem (MEDIUM)

**What's wrong** third body, last in a NON-final category.

## Risks / concerns

### I-004 — a risk (LOW)

**What's wrong** risk body, at EOF.
EOF

cat > "$R/.records/trackers/bugs/2026-08-07-crash.md" <<'EOF'
---
type: bug
id: B-001
status: open
updated: 2026-08-07
---

# Bug — crash
EOF

# ---- bullet removal: one line gone, neighbors + headers intact, log line written ----
out=$(sh "$BACKLOG_SCRIPTS/done-entry.sh" "$R" T-001 "done" "shipped the first task" abc1234)
printf '%s\n' "$out" > "$TMP/out"
expect "bullet removal reports removed" "mutation=removed" "$TMP/out"
expect_absent "T-001 gone from live file" "T-001" "$R/.records/trackers/tasks.md"
expect "sibling bullet survives" "T-002" "$R/.records/trackers/tasks.md"
expect "section headers survive" "## Future scope" "$R/.records/trackers/tasks.md"
expect "log line format" "$(date +%Y-%m-%d) · T-001 · shipped the first task · commits: abc1234 · done" "$R/.records/done/log.md"
expect "log created with header" "# Done log" "$R/.records/done/log.md"

# ---- heading removal, middle entry: span ends at the next ### ----
sh "$BACKLOG_SCRIPTS/done-entry.sh" "$R" I-002 "done" "fixed second" def5678 > /dev/null
expect_absent "I-002 heading gone" "I-002" "$R/.records/trackers/issues.md"
expect_absent "I-002 body gone" "second body" "$R/.records/trackers/issues.md"
expect "I-001 survives" "I-001" "$R/.records/trackers/issues.md"
expect "I-003 survives" "I-003" "$R/.records/trackers/issues.md"

# ---- last-in-a-non-final-category: the following ## category header survives ----
sh "$BACKLOG_SCRIPTS/done-entry.sh" "$R" I-003 "done" "fixed third" > /dev/null
expect_absent "I-003 gone" "I-003" "$R/.records/trackers/issues.md"
expect "equal-or-higher-rank rule preserves the next category" "## Risks / concerns" "$R/.records/trackers/issues.md"
expect "the next category's entry survives" "I-004" "$R/.records/trackers/issues.md"

# ---- EOF entry ----
sh "$BACKLOG_SCRIPTS/done-entry.sh" "$R" I-004 "wontfix" "not a real risk" > /dev/null
expect_absent "EOF entry gone" "I-004 — a risk" "$R/.records/trackers/issues.md"
expect "wontfix logged with no commits" "· I-004 · not a real risk · commits: - · wontfix" "$R/.records/done/log.md"

# ---- refusals: absent, completed, paused (no mutation, no extra log line) ----
out=$(sh "$BACKLOG_SCRIPTS/done-entry.sh" "$R" T-099 "done" "gist")
expect_eq "absent id refuses" "refused=absent id=T-099" "$out"
out=$(sh "$BACKLOG_SCRIPTS/done-entry.sh" "$R" T-001 "done" "again")
expect_eq "completed id refuses" "refused=completed id=T-001" "$out"
expect_eq "no duplicate log line" "1" "$(grep -c '· T-001 ·' "$R/.records/done/log.md")"
out=$(sh "$BACKLOG_SCRIPTS/done-entry.sh" "$R" T-002 "done" "paused one")
expect_eq "paused id refuses" "refused=paused id=T-002" "$out"
expect "paused entry still live" "T-002" "$R/.records/trackers/tasks.md"

# ---- store-dir advance: file retained, frontmatter advanced; re-run refuses ----
sh "$BACKLOG_SCRIPTS/done-entry.sh" "$R" B-001 "done" "fixed the crash" fed4321 > /dev/null
expect "bug file retained + resolved" "status: resolved" "$R/.records/trackers/bugs/2026-08-07-crash.md"
expect "bug updated stamped" "updated: $(date +%Y-%m-%d)" "$R/.records/trackers/bugs/2026-08-07-crash.md"
expect "bug completion logged" "· B-001 · fixed the crash" "$R/.records/done/log.md"
out=$(sh "$BACKLOG_SCRIPTS/done-entry.sh" "$R" B-001 "done" "again")
expect_eq "resolved store-dir refuses" "refused=completed id=B-001" "$out"

# ---- scaffold: trackers land under trackers/, declarations parse, idempotent ----
S="$TMP/scaffold"; mkdir -p "$S"; printf '# Door\n' > "$S/AGENTS.md"
sh "$BACKLOG_SCRIPTS/scaffold-records.sh" "$S" > "$TMP/sc1"
expect "scaffold creates tasks" "created=trackers/tasks.md" "$TMP/sc1"
parsed=$(sh "$CLANKSHOP_SCRIPTS/spine-parse.sh" "$S/.records/trackers/tasks.md")
printf '%s\n' "$parsed" > "$TMP/parsed"
expect "tasks declaration parses" "kind=tasks" "$TMP/parsed"
expect "tasks declares its ids" "ids=T" "$TMP/parsed"
expect "tasks declares the pause pattern" "paused=" "$TMP/parsed"
sh "$BACKLOG_SCRIPTS/scaffold-records.sh" "$S" > "$TMP/sc2"
expect "scaffold idempotent" "exists=trackers/tasks.md" "$TMP/sc2"
expect_absent "no re-create on second run" "created=trackers/" "$TMP/sc2"

# ---- RECORDS projection: backlog is the sole schema-facing writer ----
P="$TMP/proj2"; mkdir -p "$P"
DOCTRINE=$(CDPATH='' cd "$DIR/../../doctrine" && pwd -P)
sh "$BACKLOG_SCRIPTS/records-projection.sh" "$P" "$DOCTRINE" "gate=make test" "trunk=main" > "$TMP/rp"
expect "projection reports its stamp" "stamp=clankshop-doctrine@" "$TMP/rp"
expect "deployed RECORDS carries the doctrine stamp" "built-against: clankshop-doctrine@" "$P/.handbook/rules/RECORDS.md"
expect_absent "doctrine-side keys dropped from the projection" "doctrine-version:" "$P/.handbook/rules/RECORDS.md"
SKILLS_ROOT=$(CDPATH='' cd "$DIR/../../.." && pwd -P)
writers=$(grep -rl 'clankshop-doctrine@' "$SKILLS_ROOT" --include='*.sh' | grep -v '/tests/' || true)
expect_eq "no other writer produces the schema stamp" "$SKILLS_ROOT/backlog/scripts/records-projection.sh" "$writers"

echo "backlog: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
