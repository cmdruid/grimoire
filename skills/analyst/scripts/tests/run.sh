#!/usr/bin/env bash
# run.sh — the analyst test suite. Every test builds throwaway fixtures in a
# mktemp dir; nothing here touches the library's own tree or any real project.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
rc=0

for t in facts-test.sh deploy-test.sh; do
  echo "== $t"
  bash "$HERE/$t" || rc=1
done

if [ "$rc" -eq 0 ]; then
  echo "analyst tests: ALL GREEN"
else
  echo "analyst tests: FAILURES ABOVE" >&2
fi
exit "$rc"
