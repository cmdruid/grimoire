#!/usr/bin/env bash
# run.sh — gcloud-operator test harness. Throwaway fixtures only.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
rc=0
for test in session-test.sh quoting-test.sh mfa-test.sh open-mfa-test.sh contract-test.sh skill-doc-test.sh; do
  echo "== $test"
  /bin/bash "$DIR/$test" || rc=1
done
if [ "$rc" -eq 0 ]; then
  echo "gcloud-operator tests: ALL GREEN"
else
  echo "gcloud-operator tests: FAILURES" >&2
fi
exit "$rc"
