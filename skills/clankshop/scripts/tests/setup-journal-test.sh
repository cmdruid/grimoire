#!/usr/bin/env bash
# setup-journal-test.sh — the setup walk's records seam end to end: seed.sh projects
# the handbook (step 2), journal's standup stands the records layer up in the same
# project (step 3, the delegated seam), and the check verb's two script facts —
# context.sh --check and records.sh check — both come back green (step 5), including
# a live record lifecycle inside the workshop.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
JOURNAL="$(cd "$SKILL/../journal" && pwd)"   # sibling pack member (required: journal)
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/clankshop-setup-journal-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

proj="$TMP/proj"
mkdir -p "$proj"
git init -q "$proj"

# step 2: the face
"$SKILL/scripts/seed.sh" "$proj" --gate 'make test' --trunk main >"$OUT" 2>"$ERR"
expect "seed green" "load sets: OK" "$OUT"

# step 3: the delegated records seam
"$JOURNAL/scripts/standup.sh" "$proj" >"$OUT" 2>"$ERR"
expect "journal stands the records up" "records: $proj/.records (journal)" "$OUT"
expect "records self-check green" "records check: OK (0 records)" "$OUT"

# step 5: the check verb's two script facts, against the same deployed project
"$proj/.dev/doctrine/scripts/context.sh" --check >"$OUT" 2>"$ERR"
expect "doctrine load sets green" "load sets: OK" "$OUT"

RS="$proj/.records/scripts/records.sh"
# standup no longer plants templates/. Mint from the owner's bundled template
# via --template (path may sit outside $RR).
BACKLOG="$(cd "$SKILL/../backlog" && pwd)"
p="$("$RS" new trackers --template "$BACKLOG/templates/trackers.md" --title "Backlog")"
expect "workshop can mint a record" "# Backlog" "$p"
"$RS" 'done' "$p" --as dropped --note "fixture teardown" >/dev/null
"$RS" check >"$OUT"
expect "records lifecycle green inside the workshop" "records check: OK (1 records)" "$OUT"
expect "workshop check surfaces the ticket count" "open tickets: 0" "$OUT"

# proven by breaking: the seam refuses a double standup (upgrade is a diff)
rc=0; "$JOURNAL/scripts/standup.sh" "$proj" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "double standup refused rc" "2" "$rc"

report "setup-journal-test"
