#!/usr/bin/env bash
# run.sh — code-humanizer test entrypoint. Throwaway fixtures only.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
rc=0
for test in scope-test.sh skill-doc-test.sh; do
  echo "== $test"
  /bin/bash "$DIR/$test" || rc=1
done
if [ "$rc" -eq 0 ]; then
  echo "code-humanizer tests: ALL GREEN"
else
  echo "code-humanizer tests: FAILURES" >&2
fi
exit "$rc"
