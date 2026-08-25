#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
for test in review-test.sh review-close-test.sh refine-test.sh implementation-test.sh setup-test.sh; do
  "$HERE/$test"
done
