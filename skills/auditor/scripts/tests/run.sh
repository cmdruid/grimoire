#!/usr/bin/env bash
set -u
D="$(cd "$(dirname "$0")"&&pwd)";rc=0
echo "== setup-test.sh";bash "$D/setup-test.sh"||rc=1
echo "== complexity-test.sh";bash "$D/complexity-test.sh"||rc=1
if [ "$rc" -eq 0 ];then echo "auditor tests: ALL GREEN";else echo "auditor tests: FAILURES" >&2;fi
exit "$rc"
