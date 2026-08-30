#!/usr/bin/env bash
set -u
D="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$D/../.." && pwd)"
RULE="$SKILL/rules/complexity.md"
READ="$SKILL/rules/readability.md"
BOOT="$SKILL/BOOTSTRAP.md"
SETUP="$SKILL/verbs/setup.md"
DRIVER="$SKILL/SKILL.md"
T="$(mktemp -d "${TMPDIR:-/tmp}/auditor-complexity.XXXXXX")"
trap 'rm -rf "$T"' EXIT
p=0 f=0

ok(){ if "$@";then p=$((p+1));else echo "FAIL: $*" >&2;f=$((f+1));fi;}
no(){ if "$@";then echo "FAIL: expected rejection: $*" >&2;f=$((f+1));else p=$((p+1));fi;}
eq(){ if [ "$2" = "$3" ];then p=$((p+1));else echo "FAIL: $1 — want $2 got $3" >&2;f=$((f+1));fi;}
has(){ if grep -qF -- "$2" "$1" 2>/dev/null;then p=$((p+1));else echo "FAIL: $3" >&2;f=$((f+1));fi;}

for heading in '# Complexity -- audit rule' '## Why it matters' '## Scoring anchors (1-5)' \
  '## Decision logic' '## Anti-patterns (greppable smells)' '## Calibrated examples' \
  '## Known false-positives' '## How to quantify' '## Exemplars';do
  has "$RULE" "$heading" "complexity rule shape missing: $heading"
done
for needle in 'Issue theme: `CPLX`' 'Analyzer unavailability' 'generated or vendored code' \
  'exhaustive' 'lookup tables' 'parser' 'state machine' 'sequential tests' \
  '<score><TAB><repo-relative-path><TAB><line><TAB><symbol>' \
  'Test code is excluded by default' \
  'A threshold crossing is a candidate, not a finding';do
  has "$RULE" "$needle" "complexity rule contract missing: $needle"
done
has "$READ" '`READ` owns legibility' 'readability side of ownership seam missing'
has "$READ" '`CPLX` owns independent-path count' 'complexity side of ownership seam missing'
has "$READ" 'one primary finding' 'duplicate-finding guard missing'
has "$BOOT" '13 portable dimensions' 'bootstrap portable count is stale'
has "$BOOT" '| Complexity | `CPLX` |' 'bootstrap dimension table lacks Complexity'
has "$BOOT" '| Complexity | `rules/complexity.md` | `CPLX` |' 'GUIDE skeleton lacks Complexity'
has "$BOOT" '# complexity-summary begin' 'summary body start marker missing'
has "$BOOT" '# complexity-summary end' 'summary body end marker missing'
has "$BOOT" 'already pinned by the host toolchain' 'pinned-tool boundary missing'
has "$BOOT" 'Include test code only when the host deliberately audits test maintainability' \
  'test-code population decision missing'
has "$BOOT" 'complexity_exclusions="generated,vendor,tests,<host exclusions>"' \
  'default complexity exclusions omit tests'
check_line="$(grep -n 'if \[ "${1:-}" = "--check" \]' "$BOOT" | cut -d: -f1)"
summary_line="$(grep -n '^complexity_summary "\$complexity_rows"$' "$BOOT" | cut -d: -f1)"
if [ -n "$check_line" ] && [ -n "$summary_line" ] && [ "$check_line" -lt "$summary_line" ];then
  p=$((p+1))
else
  echo 'FAIL: Complexity summary must remain outside the default --check gate' >&2;f=$((f+1))
fi
has "$SETUP" 'owner explicitly approves adoption' 'brownfield adoption boundary missing'
has "$SETUP" 'report the seeded leaf as inactive' 'brownfield inactive disposition missing'
has "$DRIVER" 'indexed by the host GUIDE' 'unindexed-rule audit guard missing'
has "$DRIVER" 'generic, language-neutral rule-set for the 13 portable dimensions' \
  'driver portable count is stale'

sed -n '/^# complexity-summary begin$/,/^# complexity-summary end$/p' "$BOOT" >"$T/body.sh"
# shellcheck disable=SC1090 # The extracted shipped body is the subject under test.
. "$T/body.sh"
awk '
  /^## 13[.] metrics[.]sh stub$/ { section=1; next }
  section && /^```bash$/ { code=1; next }
  code && /^```$/ { exit }
  code { print }
' "$BOOT" >"$T/metrics.sh"
ok bash -n "$T/metrics.sh"
if bash "$T/metrics.sh" >"$T/stub.out" 2>"$T/stub.err";then p=$((p+1));else f=$((f+1));cat "$T/stub.err" >&2;fi
has "$T/stub.out" 'complexity.status=unavailable' 'default stub must report unavailable'
if bash "$T/metrics.sh" --check >"$T/check.out" 2>"$T/check.err";then p=$((p+1));else f=$((f+1));cat "$T/check.err" >&2;fi
has "$T/check.out" 'invariant_smells=0' 'default check output changed'
eq "default check excludes Complexity" 0 "$(grep -c '^complexity[.]' "$T/check.out")"

write_rows(){ local file="$1" row;shift;: >"$file";for row in "$@";do printf '%b\n' "$row" >>"$file";done;}
run_summary(){
  complexity_analyzer=fake-analyzer complexity_version=2.4 complexity_status="$1" \
  complexity_population='src/**/*.go' complexity_exclusions='vendor,generated,tests' \
  complexity_expected_files="$2" complexity_analyzed_files="$3" \
  complexity_skipped_files="$4" complexity_parse_errors="$5" \
  complexity_threshold="$6" complexity_summary "$7"
}
summary_rejects(){ run_summary "$@" >/dev/null 2>&1; }
missing_identity_rejects(){
  complexity_analyzer=-- complexity_version=-- complexity_status=available \
  complexity_population=src complexity_exclusions=vendor complexity_expected_files=0 \
  complexity_analyzed_files=0 complexity_skipped_files=0 complexity_parse_errors=0 \
  complexity_threshold='' complexity_summary "$1" >/dev/null 2>&1
}

if command -v complexity_summary >/dev/null 2>&1;then
  ROWS="$T/rows.tsv"
  write_rows "$ROWS" '8\tsrc/z.go\t40\tZulu' '20\tsrc/b.go\t9\tBeta' \
    '12\tsrc/a.go\t20\tZulu' '12\tsrc/a.go\t3\tZulu' '12\tsrc/a.go\t3\tAlpha' \
    '12\tsrc/b.go\t4\tAble' \
    '1\tsrc/c.go\t1\tC' \
    '2\tsrc/d.go\t2\tD' '3\tsrc/e.go\t3\tE' '4\tsrc/f.go\t4\tF' \
    '5\tsrc/g.go\t5\tG' '6\tsrc/h.go\t6\tH' '7\tsrc/i.go\t7\tI' \
    '10\tsrc/j.go\t10\tJ'
  if run_summary available 11 11 0 0 7 "$ROWS" >"$T/out" 2>"$T/err";then p=$((p+1));else f=$((f+1));cat "$T/err" >&2;fi
  for fact in 'complexity.analyzer=fake-analyzer' 'complexity.version=2.4' \
    'complexity.status=available' 'complexity.population=src/**/*.go' \
    'complexity.exclusions=vendor,generated,tests' 'complexity.expected_files=11' \
    'complexity.analyzed_files=11' 'complexity.skipped_files=0' \
    'complexity.parse_errors=0' 'complexity.authored_functions=14' \
    'complexity.maximum=20' 'complexity.p90=12' 'complexity.above_threshold=7';do
    has "$T/out" "$fact" "available summary missing: $fact"
  done
  eq "p90 fixture separates percentile from maximum" $'complexity.maximum=20\ncomplexity.p90=12' \
    "$(grep -E '^complexity[.](maximum|p90)=' "$T/out")"
  eq "highest hotspot first" $'20\tsrc/b.go\t9\tBeta' \
    "$(sed -n 's/^complexity.hotspot=//p' "$T/out" | sed -n '1p')"
  eq "ties sort symbol bytewise" $'12\tsrc/a.go\t3\tAlpha' \
    "$(sed -n 's/^complexity.hotspot=//p' "$T/out" | sed -n '2p')"
  eq "ties then sort line numerically" $'12\tsrc/a.go\t3\tZulu' \
    "$(sed -n 's/^complexity.hotspot=//p' "$T/out" | sed -n '3p')"
  eq "later line follows same-path ties" $'12\tsrc/a.go\t20\tZulu' \
    "$(sed -n 's/^complexity.hotspot=//p' "$T/out" | sed -n '4p')"
  eq "ties sort path bytewise" $'12\tsrc/b.go\t4\tAble' \
    "$(sed -n 's/^complexity.hotspot=//p' "$T/out" | sed -n '5p')"
  eq "only ten hotspots" 10 "$(grep -c '^complexity.hotspot=' "$T/out")"

  : >"$ROWS"
  if run_summary available 3 3 0 0 9 "$ROWS" >"$T/out" 2>"$T/err";then p=$((p+1));else f=$((f+1));cat "$T/err" >&2;fi
  for fact in 'complexity.authored_functions=0' 'complexity.maximum=--' \
    'complexity.p90=--' 'complexity.above_threshold=0';do
    has "$T/out" "$fact" "zero-function summary missing: $fact"
  done
  eq "zero-function hotspot list empty" 0 "$(grep -c '^complexity.hotspot=' "$T/out")"
  if run_summary available 3 3 0 0 '' "$ROWS" >"$T/out" 2>"$T/err";then p=$((p+1));else f=$((f+1));cat "$T/err" >&2;fi
  has "$T/out" 'complexity.above_threshold=--' 'missing threshold must not synthesize a count'

  write_rows "$ROWS" '9\tsrc/partial.go\t4\tPartial'
  if run_summary partial 4 3 1 0 7 "$ROWS" >"$T/out" 2>"$T/err";then p=$((p+1));else f=$((f+1));cat "$T/err" >&2;fi
  has "$T/out" 'complexity.status=partial' 'partial status missing'
  has "$T/out" 'complexity.maximum=9' 'partial maximum missing'
  has "$T/out" 'complexity.p90=--' 'partial p90 must be unavailable'
  has "$T/out" 'complexity.above_threshold=--' 'partial threshold count must be unavailable'
  no summary_rejects partial 4 4 0 0 7 "$ROWS"

  : >"$ROWS"
  if run_summary unavailable -- -- -- -- '' "$ROWS" >"$T/out" 2>"$T/err";then p=$((p+1));else f=$((f+1));cat "$T/err" >&2;fi
  has "$T/out" 'complexity.status=unavailable' 'unavailable status missing'
  has "$T/out" 'complexity.authored_functions=--' 'unavailable count must be unavailable'
  has "$T/out" 'complexity.maximum=--' 'unavailable maximum must be unavailable'

  write_rows "$ROWS" '7\tsrc/a.go\t2\tA' 'bad\tsrc/b.go\t3\tB'
  no summary_rejects available 2 2 0 0 7 "$ROWS"
  write_rows "$ROWS" '7\tsrc/a.go\t2\tA' '8\tsrc/a.go\t2\tA'
  no summary_rejects available 2 2 0 0 7 "$ROWS"
  write_rows "$ROWS" '7\tsrc/a.go\t02\tA' '8\tsrc/a.go\t2\tA'
  no summary_rejects available 2 2 0 0 7 "$ROWS"
  write_rows "$ROWS" '7\t../escape.go\t2\tA'
  no summary_rejects available 1 1 0 0 7 "$ROWS"
  write_rows "$ROWS" '7\tsrc/a.go\t0\tA'
  no summary_rejects available 1 1 0 0 7 "$ROWS"
  write_rows "$ROWS" '7\tsrc//a.go\t2\tA'
  no summary_rejects available 1 1 0 0 7 "$ROWS"
  : >"$ROWS"
  no missing_identity_rejects "$ROWS"
else
  echo 'FAIL: extracted complexity_summary function unavailable' >&2;f=$((f+1))
fi

contract_clean(){
  ! grep -qF 'Count branch keywords with grep and emit those counts as cyclomatic complexity.' "$1" \
    && ! grep -qF 'Every function above the threshold is automatically a finding.' "$1" \
    && ! grep -qF 'Complexity failures are part of --check by default.' "$1" \
    && ! grep -qF 'Test code is included in the main population by default.' "$1"
}

unique_primary_findings(){
  awk -F '\t' '{ if (seen[$1]++) exit 1 }' "$1"
}
printf '%b\n' 'branch-policy\tREAD' >"$T/findings.tsv"
ok unique_primary_findings "$T/findings.tsv"
cp "$T/findings.tsv" "$T/findings.original"
printf '%b\n' 'branch-policy\tCPLX' >>"$T/findings.tsv"
no unique_primary_findings "$T/findings.tsv"
cp "$T/findings.original" "$T/findings.tsv"
ok cmp -s "$T/findings.tsv" "$T/findings.original"
if [ -f "$RULE" ];then
  cp "$RULE" "$T/rule.original"
  for defect in \
    'Count branch keywords with grep and emit those counts as cyclomatic complexity.' \
    'Every function above the threshold is automatically a finding.' \
    'Complexity failures are part of --check by default.' \
    'Test code is included in the main population by default.';do
    cp "$T/rule.original" "$T/rule.broken";printf '%s\n' "$defect" >>"$T/rule.broken"
    no contract_clean "$T/rule.broken"
  done
  ok cmp -s "$RULE" "$T/rule.original"
fi

echo "auditor complexity-test: $p passed, $f failed";[ "$f" -eq 0 ]
