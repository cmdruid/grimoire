#!/usr/bin/env bash
set -u
DIR="$(CDPATH='' cd "$(dirname "$0")" && pwd)"

echo "== workspace-check-test.sh"
bash "$DIR/workspace-check-test.sh"
