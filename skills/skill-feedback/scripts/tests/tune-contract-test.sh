#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/skill-feedback-tune-contract.XXXXXX")"
trap 'rm -rf "$T"' EXIT
D="$SKILL/verbs/tune.md"
for phrase in 'oldest open' 'Feedback is evidence' 'apply=eligible' 'immutable=unknown' \
  'analysis only' 'already-addressed' 'project-specific' 'preservation win' \
  'explicit human acceptance' 'invalidates the proposal' 'Do not edit an installation' \
  'Do not commit, publish, open issues, or push' 'exactly four arguments' \
  'Only after successful verification'; do has "$D" "$phrase"; done

cp "$D" "$T/original.md"
count="$(grep -cF 'invalidates the proposal' "$T/original.md")"; [ "$count" = 1 ] || { printf 'FAIL mutation target count\n' >&2; exit 1; }
sed 's/invalidates the proposal/keeps the proposal/' "$T/original.md" > "$T/broken.md"
if grep -qF 'invalidates the proposal' "$T/broken.md"; then fail 're-grounding red proof did not break'; else pass; fi
same "$D" "$T/original.md"

count="$(grep -cF 'explicit human acceptance' "$T/original.md")"; [ "$count" = 1 ] || { printf 'FAIL confirmation mutation count\n' >&2; exit 1; }
sed 's/explicit human acceptance/human awareness/' "$T/original.md" > "$T/broken-confirm.md"
if grep -qF 'explicit human acceptance' "$T/broken-confirm.md"; then fail 'confirmation red proof did not break'; else pass; fi

finish tune-contract-test
