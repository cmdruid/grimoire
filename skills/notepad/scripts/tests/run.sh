#!/usr/bin/env bash
# run.sh — notepad test entrypoint. Throwaway fixtures only.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
rc=0
/bin/bash "$DIR/note-mint-test.sh" || rc=1
exit "$rc"
