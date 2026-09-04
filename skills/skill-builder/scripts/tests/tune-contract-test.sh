#!/usr/bin/env bash
set -u

HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
DOC="$SKILL/SKILL.md"
TUNE="$SKILL/verbs/tune.md"
CUSTODY="$SKILL/scripts/source-custody.sh"
pass=0 fail=0

has() {
  if grep -Fq -- "$2" "$1"; then
    pass=$((pass + 1))
  else
    echo "FAIL: missing [$2] in $1" >&2
    fail=$((fail + 1))
  fi
}

absent() {
  if grep -Fq -- "$2" "$1"; then
    echo "FAIL: found obsolete ceremony [$2] in $1" >&2
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
}

line_of() { awk -v wanted="$2" 'index($0, wanted) { print NR; exit }' "$1"; }
ordered() {
  left="$(line_of "$TUNE" "$1")"
  right="$(line_of "$TUNE" "$2")"
  if [ -n "$left" ] && [ -n "$right" ] && [ "$left" -lt "$right" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL: procedure order [$1] before [$2]" >&2
    fail=$((fail + 1))
  fi
}

# Literal Markdown code spans; expansion would execute the backticks.
# shellcheck disable=SC2016
has "$DOC" '`tune`'
# shellcheck disable=SC2016
has "$DOC" '`verbs/tune.md`'
has "$TUNE" '/skill-builder tune <skill-source> [<input-path>]'
has "$TUNE" 'current conversation'
has "$TUNE" 'caller names'
has "$TUNE" 'untrusted evidence'
has "$TUNE" 'Never scan'
has "$TUNE" 'scripts/source-custody.sh inspect'
for fact in physical-package-root declared-name git-root tracked immutable custodied; do
  has "$TUNE" "$fact"
done
has "$TUNE" 'Inspect the package status and diff'
has "$TUNE" 'pre-existing changes'
has "$TUNE" 'authorizes the bounded package edit'
has "$TUNE" 'approval merely because'
has "$TUNE" 'Ask before editing only when'
has "$TUNE" 'materially expand the requested scope'
has "$TUNE" 'conflict with existing work'
has "$TUNE" 'delete or replace a material artifact'
has "$TUNE" 'selected package'
has "$TUNE" 'focused package check'
has "$TUNE" 'host library skill lint'
has "$TUNE" 'Do not commit'

for obsolete in \
  package-sha256 input-sha256 claim-set-sha256 material-claim-set \
  'exact byte equality' 'length frames' '32 distinct claims' \
  'Obtain explicit human acceptance' 'Immediately before mutation'; do
  absent "$TUNE" "$obsolete"
done
absent "$CUSTODY" 'package-sha256'
absent "$CUSTODY" 'Digest::SHA'

ordered '## Resolve the target' '## Understand the change'
ordered '## Understand the change' '## Edit'
ordered '## Edit' '## Verify and report'

printf 'tune-contract-test: pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
