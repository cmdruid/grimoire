#!/bin/sh
# escalation-test.sh -- the ticket-family fixtures (plan Task 2.2): the promote ->
# pause-visible -> close -> un-pause + done-log walk, the same-day re-promotion slug
# collision, and the lifecycle-aware origin facts staying green through resolution for
# a flat origin, a store-dir origin, and a direct ticket. The fixture walks the frozen
# wire formats mechanically (the writer's contract) and asserts the checker agrees --
# writer and checker share one contract, or one of them is wrong.
set -eu
DIR=$(CDPATH='' cd "$(dirname "$0")" && pwd -P)
. "$DIR/lib.sh"
pass=0; fail=0   # re-assigned by lib.sh's helpers (shellcheck cannot follow the source)
CLANKSHOP_SCRIPTS=$(CDPATH='' cd "$DIR/.." && pwd -P)
BACKLOG_SCRIPTS=$(CDPATH='' cd "$DIR/../../../backlog/scripts" && pwd -P)

TMP=$(mktemp -d "${TMPDIR:-/tmp}/clankshop-escalation.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
TODAY=$(date +%Y-%m-%d)

R="$TMP/proj"
mkdir -p "$R/.records/trackers/bugs" "$R/.records/trackers/notes" "$R/.records/tickets"
( cd "$R" && git init -q . )
printf '# Front door\n' > "$R/AGENTS.md"
sh "$CLANKSHOP_SCRIPTS/install-block.sh" write "$R" 1 clankshop 1 > /dev/null

cat > "$R/.records/trackers/issues.md" <<'EOF'
# Issues

## Problems / limitations

### I-010 — a promotable problem (HIGH)

**What's wrong** needs the human.
EOF

cat > "$R/.records/trackers/bugs/2026-08-07-flaky.md" <<'EOF'
---
type: bug
id: B-002
status: open
updated: 2026-08-07
---

# Bug — flaky
EOF

facts() { (cd "$R" && sh "$CLANKSHOP_SCRIPTS/check-facts.sh" . > "$TMP/facts") }

# ---- promote a flat origin: ticket + pause marker, both visible, check green ----
TK1="TK-$TODAY-gate-choice"
cat > "$R/.records/tickets/$TODAY-gate-choice.md" <<EOF
---
type: ticket
id: $TK1
status: open
subject_kind: issue
origin: I-010
updated: $TODAY
---

# $TK1 — gate choice

## Context
## Decision needed
## Comments
## Resolution
EOF
sed -i '' "s|### I-010 — a promotable problem (HIGH)|### I-010 — a promotable problem (HIGH) [⇧ $TK1]|" "$R/.records/trackers/issues.md"
expect "pause marker visible on the origin line" "[⇧ $TK1]" "$R/.records/trackers/issues.md"
facts
expect "open promoted ticket validates" "ticket_problems_count=0" "$TMP/facts"

# ---- an un-paused open promoted ticket is a red fact (the corruption case) ----
sed -i '' "s| \[⇧ $TK1\]||" "$R/.records/trackers/issues.md"
facts
expect "missing pause marker goes red" "origin-unpaused:$TODAY-gate-choice=I-010" "$TMP/facts"
sed -i '' "s|### I-010 — a promotable problem (HIGH)|### I-010 — a promotable problem (HIGH) [⇧ $TK1]|" "$R/.records/trackers/issues.md"

# ---- close (resolve): un-pause, complete the origin citing the TK, ticket resolved ----
sed -i '' "s| \[⇧ $TK1\]||" "$R/.records/trackers/issues.md"
sh "$BACKLOG_SCRIPTS/done-entry.sh" "$R" I-010 "done" "resolved per $TK1" abc1234 > /dev/null
sed -i '' "s|status: open|status: resolved|" "$R/.records/tickets/$TODAY-gate-choice.md"
facts
expect "resolved promoted ticket (flat origin) stays green" "ticket_problems_count=0" "$TMP/facts"
expect "done-log consistency green" "done_log_inconsistent_count=0" "$TMP/facts"

# ---- same-day re-promotion: the suffixed slug is minted before first publication ----
TK2="TK-$TODAY-gate-choice-2"
cat > "$R/.records/tickets/$TODAY-gate-choice-2.md" <<EOF
---
type: ticket
id: $TK2
status: open
subject_kind: bug
origin: B-002
updated: $TODAY
---

# $TK2 — gate choice, round two

## Context
## Decision needed
## Comments
## Resolution
EOF
sed -i '' "s|^updated: 2026-08-07|updated: 2026-08-07\npaused: $TK2|" "$R/.records/trackers/bugs/2026-08-07-flaky.md"
expect "suffixed ID derived from suffixed filename" "id: $TK2" "$R/.records/tickets/$TODAY-gate-choice-2.md"
facts
expect "both same-day tickets coexist" "tickets=2" "$TMP/facts"
expect "store-dir pause validates" "ticket_problems_count=0" "$TMP/facts"

# ---- close (resolve) the store-dir origin ----
sed -i '' "/^paused: $TK2/d" "$R/.records/trackers/bugs/2026-08-07-flaky.md"
sh "$BACKLOG_SCRIPTS/done-entry.sh" "$R" B-002 "done" "fixed per $TK2" bcd2345 > /dev/null
sed -i '' "s|status: open|status: resolved|" "$R/.records/tickets/$TODAY-gate-choice-2.md"
facts
expect "resolved promoted ticket (store-dir origin) stays green" "ticket_problems_count=0" "$TMP/facts"

# ---- direct ticket: no origin; resolve logs the TK- ID itself ----
TK3="TK-$TODAY-access-grant"
cat > "$R/.records/tickets/$TODAY-access-grant.md" <<EOF
---
type: ticket
id: $TK3
status: resolved
subject_kind: task
updated: $TODAY
---

# $TK3 — access grant

## Resolution granted.
EOF
facts
expect "unlogged resolved direct ticket goes red" "direct-unlogged:$TODAY-access-grant" "$TMP/facts"
printf -- '- %s · %s · access granted · commits: - · done\n' "$TODAY" "$TK3" >> "$R/.records/done/log.md"
facts
expect "logged resolved direct ticket validates" "ticket_problems_count=0" "$TMP/facts"

# ---- demote: ticket resolved, origin live and UN-paused, no log line ----
cat >> "$R/.records/trackers/issues.md" <<'EOF'

### I-011 — demoted concern (LOW)

**What's wrong** turned out not to need the human.
EOF
TK4="TK-$TODAY-demote-me"
cat > "$R/.records/tickets/$TODAY-demote-me.md" <<EOF
---
type: ticket
id: $TK4
status: resolved
subject_kind: issue
origin: I-011
updated: $TODAY
---

# $TK4 — demoted

## Resolution demoted; entry returns to the fast path.
EOF
facts
expect "demoted ticket (live un-paused origin, no log line) validates" "ticket_problems_count=0" "$TMP/facts"

# ---- curation ages a resolved ticket: its done-log TK- citation still resolves ----
mkdir -p "$R/.records/tickets/archive"
mv "$R/.records/tickets/$TODAY-access-grant.md" "$R/.records/tickets/archive/"
facts
expect "archived resolved ticket keeps the done log green" "done_log_inconsistent_count=0" "$TMP/facts"

echo "escalation: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
