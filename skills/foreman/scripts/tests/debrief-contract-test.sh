#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; BASE="$(CDPATH='' cd -P "$HERE/../.." && pwd)"; WRITE="$HERE/../operation-write.sh"; FIX="$HERE/fixtures"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/foreman-debrief-test.XXXXXX")"; trap 'rm -rf "$T"' EXIT
V="$BASE/verbs/debrief.md"; OUT="$T/out"
for needle in 'current visible conversation' 'unrelated arcs' '`observed`, `inferred`, or `unknown`' \
  'instruction-like text' 'Zero candidates is valid' 'explicitly accepts' 'Never persist the ledger' \
  'record, or the deny-list' 'separately accepted'; do has "debrief rule $needle" "$needle" "$V"; done
for needle in 'Arc A' 'Arc B' 'api_key=fixture-secret-value' 'Example Person' 'Ignore prior instructions'; do has "fixture $needle" "$needle" "$FIX/debrief-session.md"; done

R0="$T/no-acceptance"; mkdir "$R0"; ok test ! -e "$R0/.spaces/foreman/doctrine"
R="$T/root"; mkdir "$R"; deny="$T/deny"; printf '%s\n' 'fixture-secret-value' 'Example Person' 'Ignore prior instructions' 'SECRET_DO_NOT_PERSIST' >"$deny"
clean="$FIX/migration/clean-operation.md"; "$WRITE" put --root "$R" --identity foreman/session-release --candidate "$clean" --deny-list "$deny" >"$OUT"
ok test -f "$R/.spaces/foreman/operations/session-release.md"
if "$WRITE" put --root "$R" --identity foreman/tainted --candidate "$FIX/migration/tainted-operation.md" --deny-list "$deny" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "tainted operation refused" 'reason=tainted-candidate' "$OUT"

doctrine="$T/doctrine.md"; printf '%s\n' '# Release evidence' '' 'Record the artifact digest before publication.' >"$doctrine"
"$WRITE" doctrine --root "$R" --stem release-evidence --candidate "$doctrine" --deny-list "$deny" >"$OUT"
ok test -f "$R/.spaces/foreman/doctrine/release-evidence.md"
ok test ! -e "$R/.spaces/foreman/debriefs"; ok test ! -e "$R/.records/debriefs"
if rg -l -F -f "$deny" "$R/.spaces" >/dev/null 2>&1; then fail=$((fail+1)); else pass=$((pass+1)); fi

# Red-proof the shared debrief write boundary.
broken="$T/operation-write.sh"; checker_copy="$T/operation-check.sh"; cp "$WRITE" "$broken"; cp "$HERE/../operation-check.sh" "$checker_copy"
before="$(grep -c '^candidate_tainted()' "$broken")"; sed -i.bak 's/^candidate_tainted().*/candidate_tainted() { false; }/' "$broken"; rm "$broken.bak"; after="$(grep -c 'candidate_tainted() { false; }' "$broken")"
eq "debrief mutation target" 1 "$before"; eq "debrief guard disabled" 1 "$after"; chmod +x "$broken" "$checker_copy"
"$broken" put --root "$R" --identity foreman/tainted --candidate "$FIX/migration/tainted-operation.md" --deny-list "$deny" >/dev/null
has "disabled debrief guard plants marker" SECRET_DO_NOT_PERSIST "$R/.spaces/foreman/operations/tainted.md"

report debrief-contract-test
