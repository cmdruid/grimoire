#!/usr/bin/env bash
# flows-copy.sh copy|check --root <abs> --workspace <rel> [--src <abs>]
#
# Incumbent-safe copy of pack-owned flow files into <root>/<workspace>/flows.
# Never overwrites an incumbent. Never deletes extras. seed.sh is not invoked.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: flows-copy.sh copy|check --root <abs> --workspace <rel> [--src <abs>]
EOF
  exit 2
}

is_abs() {
  case "$1" in /*) return 0 ;; *) return 1 ;; esac
}

cmd="${1:-}"
[ -n "$cmd" ] || usage
shift

root=""
ws=""
src=""
SKILL="$(cd "$(dirname "$0")/.." && pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --root)      [ $# -ge 2 ] || usage; root="$2"; shift 2 ;;
    --workspace) [ $# -ge 2 ] || usage; ws="$2";   shift 2 ;;
    --src)       [ $# -ge 2 ] || usage; src="$2";  shift 2 ;;
    *) usage ;;
  esac
done

[ -n "$root" ] && [ -n "$ws" ] || usage
is_abs "$root" || usage
[ -n "$src" ] || src="$SKILL/flows"
case "$ws" in
  .|"") echo "refusing: --workspace '.'" >&2; exit 2 ;;
  /*)   echo "refusing: --workspace must be repo-relative" >&2; exit 2 ;;
esac

dst="$root/$ws/flows"
home="$root/$ws"

missing_stems() {
  local f stem miss=""
  [ -d "$src" ] || return 0
  for f in "$src"/*.md; do
    [ -f "$f" ] || continue
    stem=$(basename "$f")
    if [ ! -f "$dst/$stem" ]; then
      if [ -n "$miss" ]; then miss="$miss,$stem"; else miss="$stem"; fi
    fi
  done
  printf '%s' "$miss"
}

do_check() {
  echo "workspace=$ws"
  echo "src=$src"
  echo "dst=$dst"
  if [ ! -d "$src" ]; then
    echo "unfinished=false"
    echo "missing="
    echo "finding=false"
    exit 0
  fi
  local miss
  miss=$(missing_stems)
  echo "missing=$miss"
  if [ -n "$miss" ]; then
    echo "unfinished=true"
    echo "finding=true"
    echo "name=/clankshop setup"
    exit 1
  fi
  echo "unfinished=false"
  echo "finding=false"
  exit 0
}

do_copy() {
  echo "workspace=$ws"
  echo "src=$src"
  echo "dst=$dst"
  if [ ! -d "$src" ]; then
    echo "status=skip"
    echo "copied=0"
    exit 0
  fi
  if [ ! -d "$home" ]; then
    if [ "$ws" = ".dev" ]; then
      mkdir -p "$dst"
    else
      echo "status=no-home"
      echo "copied=0"
      exit 0
    fi
  else
    mkdir -p "$dst"
  fi
  local f stem n=0
  for f in "$src"/*.md; do
    [ -f "$f" ] || continue
    stem=$(basename "$f")
    if [ -e "$dst/$stem" ]; then
      continue
    fi
    cp "$f" "$dst/$stem"
    n=$((n + 1))
  done
  echo "status=copied"
  echo "copied=$n"
  exit 0
}

case "$cmd" in
  copy)  do_copy ;;
  check) do_check ;;
  *) usage ;;
esac
