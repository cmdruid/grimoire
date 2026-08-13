#!/bin/sh
# context.sh — render a station's load set on demand (the handbook's one deployed tool).
#
#   context.sh <station|persona>          render the load set: each file prefixed by a
#                                         `===> <path>` header (paths relative to .handbook/)
#   context.sh <station|persona> --list   the reading list only (paths, in load order)
#   context.sh --check                    contract test: every station's load set resolves
#
# Personas alias their stations: architect→design, foreman→build, guardian→test, admin→review.
# Load rule (stated in README.md): core/* then <station>/POLICY.md; workflows load lazily.
# Exit codes: 0 ok · 1 usage · 2 broken load set.
# Agent-facing: plain deterministic output, no color; errors on stderr.
set -eu

HB="$(cd "$(dirname "$0")/.." && pwd)"
STATIONS="design build test review"
CORE_ORDER="POLICY.md INVARIANTS.md GOTCHAS.md ROUTING.md"

usage() {
  echo "usage: context.sh <station|persona> [--list] | context.sh --check" >&2
  echo "stations: $STATIONS (aliases: architect foreman guardian admin)" >&2
  exit 1
}

station_for() {
  case "$1" in
    design|architect)  echo design ;;
    build|foreman)     echo build ;;
    test|guardian)     echo test ;;
    review|admin)      echo review ;;
    *) return 1 ;;
  esac
}

load_set() { # stdout: the load-order paths for station $1, relative to the handbook root
  for f in $CORE_ORDER; do echo "core/$f"; done
  echo "$1/POLICY.md"
}

check_all() {
  rc=0
  for st in $STATIONS; do
    for rel in $(load_set "$st"); do
      [ -f "$HB/$rel" ] || { echo "missing: $rel (station: $st)" >&2; rc=2; }
    done
  done
  [ "$rc" -eq 0 ] && echo "load sets: OK ($STATIONS)"
  return "$rc"
}

[ $# -ge 1 ] || usage

if [ "$1" = "--check" ]; then
  [ $# -eq 1 ] || usage
  check_all
  exit $?
fi

st="$(station_for "$1")" || usage

if [ "${2:-}" = "--list" ]; then
  load_set "$st"
  exit 0
fi
[ $# -eq 1 ] || usage

rc=0
for rel in $(load_set "$st"); do
  if [ -f "$HB/$rel" ]; then
    printf '===> %s\n' "$rel"
    cat "$HB/$rel"
    echo
  else
    echo "missing: $rel" >&2
    rc=2
  fi
done
exit "$rc"
