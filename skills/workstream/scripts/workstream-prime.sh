#!/usr/bin/env bash
# Compatibility bridge: define the first unit through the guarded runtime.
set -euo pipefail
if [ "$#" -ne 4 ]; then
  echo 'usage: workstream-prime.sh <canonical-root> <stream> <slug> <summary>' >&2
  exit 2
fi
DIR="$(cd "$(dirname "$0")" && pwd -P)"
exec "$DIR/workstream.sh" "$1" unit-begin "$2" "$3" "$4"
