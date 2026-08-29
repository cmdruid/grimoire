#!/usr/bin/env bash
# scope.sh — list source files a code-humanizer run may touch. Facts only.
#   scope.sh <root> [--path <rel>] [--cap N]
#
# Prints key=value facts and one file=<repo-relative> line per selected path.
# Never edits. Default cap is 20. Non-git roots fail with git=0.
set -euo pipefail

usage() {
  echo "usage: scope.sh <root> [--path <rel>] [--cap N]" >&2
  exit 2
}

err() { echo "scope.sh: $*" >&2; exit 2; }

CAP=20
ROOT=""
REL_PATH=""

[ $# -ge 1 ] || usage
ROOT="$1"; shift
while [ $# -gt 0 ]; do
  case "$1" in
    --path)
      [ $# -ge 2 ] || usage
      REL_PATH="$2"; shift 2
      ;;
    --cap)
      [ $# -ge 2 ] || usage
      CAP="$2"; shift 2
      ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done

case "$CAP" in
  ''|*[!0-9]*) err "cap must be a positive integer, got: $CAP" ;;
  0) err "cap must be a positive integer, got: $CAP" ;;
esac

case "$ROOT" in /*) ;; *) err "root must be absolute: $ROOT" ;; esac
[ -d "$ROOT" ] || err "root is not a directory: $ROOT"
ROOT="$(CDPATH='' cd -P "$ROOT" && pwd)"

valid_rel() {
  [ -n "$1" ] || return 1
  case "$1" in /*) return 1 ;; esac
  case "/$1/" in */../*) return 1 ;; esac
}

is_excluded_path() {
  case "/$1/" in
    */node_modules/*|*/vendor/*|*/target/*|*/dist/*|*/build/*|*/.git/*|\
    */.spaces/*|*/.records/*|*/.trackers/*|*/__pycache__/*|*/.venv/*|*/venv/*)
      return 0 ;;
  esac
  return 1
}

is_code() {
  local base
  base="${1##*/}"
  case "$base" in
    Makefile|makefile|GNUmakefile|Dockerfile|dockerfile|Justfile|justfile|Rakefile|Gemfile)
      return 0 ;;
  esac
  case "$1" in
    *.rs|*.go|*.py|*.js|*.ts|*.tsx|*.jsx|*.mjs|*.cjs|*.c|*.h|*.cc|*.cpp|\
    *.hpp|*.hh|*.java|*.kt|*.kts|*.swift|*.rb|*.php|*.cs|*.scala|*.m|*.mm|\
    *.sh|*.bash|*.zsh|*.lua|*.r|*.pl|*.pm|*.ex|*.exs|*.erl|*.hs|*.ml|*.mli|\
    *.zig|*.nim|*.dart|*.vue|*.svelte|*.sql|*.awk|*.ps1)
      return 0 ;;
  esac
  return 1
}

normalize_rel() {
  local p="$1"
  case "$p" in
    /*)
      case "$p" in
        "$ROOT"|"$ROOT"/*) p="${p#"$ROOT"/}" ;;
        *) return 1 ;;
      esac
      ;;
  esac
  case "$p" in .|./) p="" ;; ./*) p="${p#./}" ;; esac
  printf '%s' "$p"
}

collect_nl="
"
collect=""

add_file() {
  local rel="$1"
  [ -n "$rel" ] || return 0
  is_excluded_path "$rel" && return 0
  is_code "$rel" || return 0
  collect="$collect$rel$collect_nl"
}

if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'git=0\n'
  printf 'root=%s\n' "$ROOT"
  printf 'reason=not-git\n'
  exit 2
fi

SCOPE="diff"
PATH_ARG=""
if [ -n "$REL_PATH" ]; then
  PATH_ARG="$(normalize_rel "$REL_PATH")" || err "path is outside root: $REL_PATH"
  valid_rel "$PATH_ARG" || [ -z "$PATH_ARG" ] || err "unsafe path: $REL_PATH"
  SCOPE="path"
  if [ -z "$PATH_ARG" ]; then
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      add_file "$rel"
    done < <(git -C "$ROOT" ls-files -co --exclude-standard)
  elif [ -f "$ROOT/$PATH_ARG" ]; then
    add_file "$PATH_ARG"
  elif [ -d "$ROOT/$PATH_ARG" ]; then
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      add_file "$rel"
    done < <(git -C "$ROOT" ls-files -co --exclude-standard -- "$PATH_ARG")
  else
    err "path does not exist: $PATH_ARG"
  fi
else
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    add_file "$rel"
  done < <({
    git -C "$ROOT" diff --name-only
    git -C "$ROOT" diff --name-only --cached
    git -C "$ROOT" ls-files --others --exclude-standard
  } | sed '/^$/d')
  if [ -z "$collect" ]; then
    SCOPE="last-commit"
    if git -C "$ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
      while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        add_file "$rel"
      done < <(git -C "$ROOT" diff-tree --root --no-commit-id --name-only -r HEAD)
    fi
  fi
fi

sorted=""
if [ -n "$collect" ]; then
  sorted="$(printf '%s' "$collect" | LC_ALL=C sort -u)"
fi

total=0
if [ -n "$sorted" ]; then
  total="$(printf '%s\n' "$sorted" | sed '/^$/d' | wc -l | tr -d ' ')"
fi

selected=0
omitted=0
if [ "$total" -gt "$CAP" ]; then
  selected="$CAP"
  omitted=$((total - CAP))
else
  selected="$total"
fi

printf 'git=1\n'
printf 'root=%s\n' "$ROOT"
printf 'scope=%s\n' "$SCOPE"
printf 'path_arg=%s\n' "$PATH_ARG"
printf 'cap=%s\n' "$CAP"
printf 'total=%s\n' "$total"
printf 'selected=%s\n' "$selected"
printf 'omitted=%s\n' "$omitted"

n=0
if [ -n "$sorted" ]; then
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    [ "$n" -ge "$CAP" ] && break
    printf 'file=%s\n' "$rel"
    n=$((n + 1))
  done <<EOF
$sorted
EOF
fi
