#!/bin/sh
# run.sh -- the clankshop fixture harness (plan Task 1.8): every committed test in
# scripts/tests/, one command. Fixture instances are temp-dir-local and destroyed;
# patient-zero holds -- nothing runs against the library's own tree.
set -eu
DIR=$(CDPATH='' cd "$(dirname "$0")" && pwd -P)
rc=0
for t in onramp-test.sh backlog-test.sh escalation-test.sh mirror-test.sh calibrate-test.sh spine-scan-test.sh; do
  echo "== $t"
  bash "$DIR/$t" || rc=1
done
if [ "$rc" -eq 0 ]; then echo "clankshop tests: ALL GREEN"; else echo "clankshop tests: FAILURES"; fi
exit "$rc"
