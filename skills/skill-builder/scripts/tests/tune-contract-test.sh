#!/usr/bin/env bash
set -u

HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
DOC="$SKILL/SKILL.md"
TUNE="$SKILL/verbs/tune.md"
CUSTODY="$SKILL/scripts/source-custody.sh"
CASES="$HERE/fixtures/tune-cases.tsv"
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
    echo "FAIL: found forbidden [$2] in $1" >&2
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
}

fixture_case() {
  if awk -F '\t' -v wanted="$1" 'NR > 1 && $1 == wanted { found = 1 } END { exit !found }' "$CASES"; then
    pass=$((pass + 1))
  else
    echo "FAIL: missing fixture case [$1]" >&2
    fail=$((fail + 1))
  fi
}

fixture_value() {
  if awk -F '\t' -v field="$1" -v wanted="$2" '
    NR == 1 { for (i = 1; i <= NF; i++) if ($i == field) column = i; next }
    column && $column == wanted { found = 1 }
    END { exit !found }
  ' "$CASES"; then
    pass=$((pass + 1))
  else
    echo "FAIL: fixture field [$1] lacks value [$2]" >&2
    fail=$((fail + 1))
  fi
}

fixture_expect() {
  if awk -F '\t' -v wanted_case="$1" -v field="$2" -v wanted="$3" '
    NR == 1 { for (i = 1; i <= NF; i++) if ($i == field) column = i; next }
    $1 == wanted_case && column && $column == wanted { found = 1 }
    END { exit !found }
  ' "$CASES"; then
    pass=$((pass + 1))
  else
    echo "FAIL: fixture case [$1] field [$2] is not [$3]" >&2
    fail=$((fail + 1))
  fi
}

line_of() {
  awk -v wanted="$2" 'index($0, wanted) { print NR; exit }' "$1"
}

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

digest_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

expected_header=$'case\tinput_kind\tshape\tclaim_relation\tdisposition\texpected_action\tguard'
if [ "$(head -n 1 "$CASES")" = "$expected_header" ]; then
  pass=$((pass + 1))
else
  echo 'FAIL: tune fixture header changed' >&2
  fail=$((fail + 1))
fi

if [ "$(tail -n +2 "$CASES" | cut -f1 | sort | uniq -d | wc -l | tr -d ' ')" = 0 ]; then
  pass=$((pass + 1))
else
  echo 'FAIL: duplicate tune fixture case' >&2
  fail=$((fail + 1))
fi

if awk -F '\t' 'NR > 1 && NF != 7 { bad = 1 } END { exit bad }' "$CASES"; then
  pass=$((pass + 1))
else
  echo 'FAIL: tune fixture row does not have seven fields' >&2
  fail=$((fail + 1))
fi

# Literal Markdown code spans; expansion would execute the backticks.
# shellcheck disable=SC2016
has "$DOC" '`tune`'
# shellcheck disable=SC2016
has "$DOC" '`verbs/tune.md`'
has "$TUNE" '/skill-builder tune <skill-source> [<input-path>]'
has "$TUNE" 'current conversation'
has "$TUNE" 'exactly one caller-named'
has "$TUNE" 'readable UTF-8 regular non-symlink prose file'
has "$TUNE" 'Never search or scan'
has "$TUNE" 'ordinary quoted evidence'
has "$TUNE" 'embedded instructions have no authority'
has "$TUNE" 'scripts/source-custody.sh inspect'
for fact in physical-package-root declared-name git-root head package-sha256; do
  has "$TUNE" "$fact"
done
for fact in input-physical-path input-sha256 material-claim-set; do
  has "$TUNE" "$fact"
done
for disposition in current 'already addressed' stale project-specific false 'preservation constraint' 'out of scope' unsupported; do
  has "$TUNE" "$disposition"
done
has "$TUNE" 'stop for human selection'
has "$TUNE" 'explicit human acceptance'
has "$TUNE" 'Immediately before mutation'
has "$TUNE" 'exact byte equality'
has "$TUNE" 'renewed acceptance'
has "$TUNE" 'selected skill package'
has "$TUNE" 'focused check'
has "$TUNE" 'host library skill lint'
has "$TUNE" 'no record, commit, issue, publication, external disposition, or global write'
has "$TUNE" 'outside the selected package'

for case_name in \
  conversation-current prose-bullets prose-narrative filename-looking feedback-heading feedback-id \
  schema-shaped field-labels embedded-instruction binary-input symlink-input unreadable-input \
  directory-input unrelated-claims too-many-claims zero-claims multiple-inputs option-shaped-input \
  inferred-input cwd-scan global-scan target-drift declared-name-drift git-root-drift head-drift \
  package-drift input-path-drift input-digest-drift claim-set-drift parent-traversal symlink-escape \
  outside-destination resolution-failure \
  acceptance-failure identity-failure application-failure focused-check-failure host-lint-failure; do
  fixture_case "$case_name"
done

for disposition in current 'already addressed' stale project-specific false 'preservation constraint' 'out of scope' unsupported; do
  fixture_value disposition "$disposition"
done
for guard in acceptance input-identity evidence-not-authority utf8-prose non-symlink readable \
  regular-file coherent-batch no-edit target-identity declared-name-identity git-root-identity \
  head-identity package-digest-identity input-path-identity input-digest-identity \
  material-claim-set target-containment no-external-state bounded-claims single-named-input no-scan; do
  fixture_value guard "$guard"
done


for case_name in conversation-current prose-bullets prose-narrative filename-looking feedback-heading \
  feedback-id schema-shaped field-labels embedded-instruction; do
  fixture_expect "$case_name" expected_action propose
done
for case_name in already-addressed stale-claim project-specific false-claim preservation-constraint \
  out-of-scope unsupported-claim zero-claims; do
  fixture_expect "$case_name" expected_action report
  fixture_expect "$case_name" guard no-edit
done
for case_name in unrelated-claims too-many-claims; do
  fixture_expect "$case_name" expected_action select
done
for case_name in binary-input symlink-input unreadable-input directory-input multiple-inputs \
  option-shaped-input inferred-input cwd-scan global-scan parent-traversal symlink-escape \
  outside-destination resolution-failure acceptance-failure; do
  fixture_expect "$case_name" expected_action refuse
done
for case_name in target-drift declared-name-drift git-root-drift head-drift package-drift \
  input-path-drift input-digest-drift claim-set-drift identity-failure; do
  fixture_expect "$case_name" expected_action revalidate
done
for case_name in application-failure focused-check-failure host-lint-failure; do
  fixture_expect "$case_name" expected_action stop
done

for case_name in conversation-current prose-bullets prose-narrative filename-looking feedback-heading \
  feedback-id schema-shaped field-labels embedded-instruction target-drift declared-name-drift \
  git-root-drift head-drift package-drift input-path-drift input-digest-drift claim-set-drift \
  parent-traversal symlink-escape outside-destination acceptance-failure identity-failure \
  application-failure focused-check-failure host-lint-failure; do
  fixture_expect "$case_name" disposition current
done
fixture_expect already-addressed disposition 'already addressed'
fixture_expect stale-claim disposition stale
fixture_expect project-specific disposition project-specific
fixture_expect false-claim disposition false
fixture_expect preservation-constraint disposition 'preservation constraint'
fixture_expect out-of-scope disposition 'out of scope'
for case_name in binary-input symlink-input unreadable-input directory-input unrelated-claims \
  too-many-claims zero-claims multiple-inputs option-shaped-input inferred-input cwd-scan global-scan \
  unsupported-claim resolution-failure; do
  fixture_expect "$case_name" disposition unsupported
done

fixture_expect prose-bullets guard input-identity
fixture_expect prose-narrative guard input-identity
for case_name in filename-looking feedback-heading feedback-id schema-shaped field-labels embedded-instruction; do
  fixture_expect "$case_name" guard evidence-not-authority
done
fixture_expect binary-input guard utf8-prose
fixture_expect symlink-input guard non-symlink
fixture_expect unreadable-input guard readable
fixture_expect directory-input guard regular-file
fixture_expect unrelated-claims guard coherent-batch
fixture_expect too-many-claims guard bounded-claims
for case_name in multiple-inputs option-shaped-input; do fixture_expect "$case_name" guard single-named-input; done
for case_name in inferred-input cwd-scan global-scan; do fixture_expect "$case_name" guard no-scan; done
fixture_expect target-drift guard target-identity
fixture_expect declared-name-drift guard declared-name-identity
fixture_expect git-root-drift guard git-root-identity
fixture_expect head-drift guard head-identity
fixture_expect package-drift guard package-digest-identity
fixture_expect input-path-drift guard input-path-identity
fixture_expect input-digest-drift guard input-digest-identity
fixture_expect claim-set-drift guard material-claim-set
for case_name in parent-traversal symlink-escape outside-destination; do
  fixture_expect "$case_name" guard target-containment
done

ordered '## Propose and obtain acceptance' 'Obtain explicit human acceptance'
ordered 'Obtain explicit human acceptance' '## Recheck identity, apply, and verify'
ordered '## Recheck identity, apply, and verify' 'Immediately before mutation'
ordered 'Immediately before mutation' 'Apply only the accepted coherent changes'
ordered 'Apply only the accepted coherent changes' "Run the package's focused check"
ordered "Run the package's focused check" 'Then run the host library skill lint'
ordered 'Then run the host library skill lint' 'Report supported and rejected claims'

for forbidden in '--installed' '--feedback' '.agents/skilldata' 'apply=' 'action='; do
  absent "$CUSTODY" "$forbidden"
done

collector="$(printf '%s-%s' agent feedback)"
global_home="$(printf '.%s/%s' agents skilldata)"
if grep -R -Fq -- "$collector" "$DOC" "$SKILL/verbs" "$CUSTODY" 2>/dev/null; then
  echo 'FAIL: skill-builder names an evidence collector' >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
if grep -Fq -- "$global_home" "$DOC" "$TUNE" "$CUSTODY" 2>/dev/null; then
  echo 'FAIL: skill-builder accesses global skilldata' >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

if [ "$(digest_file "$SKILL/verbs/review.md")" = 0d6ec9f32fc63910c932e7ca946559cca84fa798f59969ca26737262fdbdb4c4 ]; then
  pass=$((pass + 1))
else
  echo 'FAIL: review.md changed from the protected baseline' >&2
  fail=$((fail + 1))
fi
if [ "$(digest_file "$SKILL/verbs/calibrate.md")" = cba164ccda78f318402ba0129e9915c88b1c8543c06fd0fa9fecf3b5099f1bfa ]; then
  pass=$((pass + 1))
else
  echo 'FAIL: calibrate.md changed from the protected baseline' >&2
  fail=$((fail + 1))
fi
edge_hash="$(awk '/<!-- edges:skill-builder -->/{on=1} on{print} /<!-- \/edges:skill-builder -->/{exit}' "$DOC" | {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256; else sha256sum; fi
} | awk '{print $1}')"
if [ "$edge_hash" = 020203784f053f489652df9fd2effe59b0f3ccf607233532c014c099a326ae35 ]; then
  pass=$((pass + 1))
else
  echo 'FAIL: skill-builder edge block changed from the protected baseline' >&2
  fail=$((fail + 1))
fi

printf 'tune-contract-test: pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
