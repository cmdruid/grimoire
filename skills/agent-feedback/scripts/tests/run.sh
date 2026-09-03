#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
for test in provider-test.sh validation-test.sh path-safety-test.sh concurrency-test.sh skill-content-ref-test.sh capture-contract-test.sh boundary-test.sh anchor-test.sh; do
  printf '== %s\n' "$test"
  bash "$HERE/$test"
done
printf 'agent-feedback tests: ALL GREEN\n'
