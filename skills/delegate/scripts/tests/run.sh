#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; rc=0
for test in contract-test.sh setup-test.sh; do echo "== $test"; bash "$HERE/$test" || rc=1; done
[ "$rc" -eq 0 ] && echo 'delegate tests: ALL GREEN' || echo 'delegate tests: FAILURES' >&2
exit "$rc"
