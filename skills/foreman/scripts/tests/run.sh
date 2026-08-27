#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; failed=0
for test_file in operation-check-test.sh operations-index-test.sh setup-test.sh operation-write-test.sh \
  migration-test.sh migration-redaction-test.sh lifecycle-test.sh projection-test.sh \
  debrief-contract-test.sh verification-test.sh composition-test.sh goal-compile-test.sh \
  goal-routing-test.sh skill-doc-test.sh; do
  echo "== $test_file"
  bash "$HERE/$test_file" || failed=1
done
if [ "$failed" -eq 0 ]; then echo 'foreman tests: ALL GREEN'; else echo 'foreman tests: FAILURES' >&2; exit 1; fi
