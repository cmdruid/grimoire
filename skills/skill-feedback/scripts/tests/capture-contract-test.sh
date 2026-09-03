#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/skill-feedback-capture-contract.XXXXXX")"
trap 'rm -rf "$T"' EXIT
D="$SKILL/verbs/capture.md"; C="$HERE/fixtures/capture-cases.tsv"

for phrase in '**Change:**' '**Incident:**' '**Consequence:**' '**Response:**' '**Privacy:**' \
  'skipped=no-change-worthy-feedback' 'skipped=skill-ambiguous' 'exactly once' \
  'friction`, `gap`, `win`, or `new-skill`' 'Never store'; do has "$D" "$phrase"; done
[ "$(awk -F '\t' 'NR>1{seen[$5]=1}END{print seen["friction"]+seen["gap"]+seen["win"]+seen["new-skill"]}' "$C")" = 4 ] && pass || fail 'capture kinds incomplete'
[ "$(awk -F '\t' 'NR>1 && $4 ~ /^skip/{n++}END{print n+0}' "$C")" -ge 3 ] && pass || fail 'skip cases incomplete'
grep -qF 'remove absolute paths' "$C" && grep -qF 'never retain the token or path' "$C" && pass || fail 'privacy cases incomplete'

cp "$D" "$T/original.md"
count="$(grep -cF '**Privacy:**' "$T/original.md")"; [ "$count" = 1 ] || { printf 'FAIL mutation target count\n' >&2; exit 1; }
sed '/\*\*Privacy:\*\*/d' "$T/original.md" > "$T/broken.md"
if grep -qF '**Privacy:**' "$T/broken.md"; then fail 'red proof did not break privacy contract'; else pass; fi
same "$D" "$T/original.md"

finish capture-contract-test
