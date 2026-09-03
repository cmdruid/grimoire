#!/usr/bin/env bash
set -u

HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
DOC="$SKILL/SKILL.md" TUNE="$SKILL/verbs/tune.md" CUSTODY="$SKILL/scripts/source-custody.sh"
pass=0 fail=0

has(){ if grep -Fq -- "$2" "$1"; then pass=$((pass+1)); else echo "FAIL: missing [$2] in $1" >&2; fail=$((fail+1)); fi; }
absent(){ if grep -Fq -- "$2" "$1"; then echo "FAIL: found forbidden [$2] in $1" >&2; fail=$((fail+1)); else pass=$((pass+1)); fi; }

# Literal Markdown code spans; expansion would execute the backticks.
# shellcheck disable=SC2016
has "$DOC" '`tune`'
# shellcheck disable=SC2016
has "$DOC" '`verbs/tune.md`'
has "$TUNE" '/skill-builder tune <skill-source> [<input-path>]'
has "$TUNE" 'current conversation'
has "$TUNE" 'scripts/source-custody.sh inspect'
for fact in physical-package-root declared-name git-root head package-sha256; do has "$TUNE" "$fact"; done
for disposition in current 'already addressed' stale project-specific false 'preservation constraint' 'out of scope' unsupported; do has "$TUNE" "$disposition"; done
has "$TUNE" 'explicit human acceptance'
has "$TUNE" 're-run custody'
has "$TUNE" 'exact identity equality'
has "$TUNE" 'selected skill package'
has "$TUNE" 'focused check'
has "$TUNE" 'host library'
has "$TUNE" 'no record, commit, issue, publication, or global write'
has "$TUNE" 'Slice 6'
has "$TUNE" 'refuse a supplied `<input-path>` without reading it or editing the package'

for forbidden in '--installed' '--feedback' '.agents/skilldata' 'apply=' 'action='; do absent "$CUSTODY" "$forbidden"; done
if grep -R -Fq -- 'skill-feedback' "$SKILL/SKILL.md" "$SKILL/verbs" "$SKILL/scripts/source-custody.sh" 2>/dev/null; then
  echo 'FAIL: skill-builder names a feedback collector' >&2; fail=$((fail+1))
else
  pass=$((pass+1))
fi

printf 'tune-contract-test: pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
