#!/usr/bin/env bash
# flows-create.sh --root <abs> --workspace <rel> --owner <skill> --stem <kebab> [--title t] [--use-when u]
#
# Mint a host stub at <root>/<workspace>/<owner>/flows/<stem>.md (crawl keys + H1).
# Does not know pack stems. Does not overwrite incumbents.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: flows-create.sh --root <abs> --workspace <rel> --owner <skill> --stem <kebab> [--title t] [--use-when u]
EOF
  exit 2
}

is_abs() {
  case "$1" in /*) return 0 ;; *) return 1 ;; esac
}

yaml_quote() {
  # Double-quoted YAML scalar; backslash-escape \ and ".
  YAML_VAL="$1" awk 'BEGIN {
    s = ENVIRON["YAML_VAL"]
    gsub(/\\/, "\\\\", s)
    gsub(/"/, "\\\"", s)
    printf "\"%s\"", s
  }'
}

is_kebab() {
  printf '%s' "$1" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'
}

bad_value() {
  # Empty/whitespace, newline, or --- substring.
  local v="$1"
  case "$v" in
    *"$NL"*|*"---"*) return 0 ;;
  esac
  local stripped
  stripped=$(printf '%s' "$v" | tr -d ' \t')
  [ -z "$stripped" ]
}

NL=$(printf '\n/'); NL="${NL%/}"

root=""
ws=""
stem=""
owner=""
title_set=0
use_when_set=0
title=""
use_when=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root)      [ $# -ge 2 ] || usage; root="$2";      shift 2 ;;
    --workspace) [ $# -ge 2 ] || usage; ws="$2";        shift 2 ;;
    --owner)     [ $# -ge 2 ] || usage; owner="$2";     shift 2 ;;
    --stem)      [ $# -ge 2 ] || usage; stem="$2";      shift 2 ;;
    --title)     [ $# -ge 2 ] || usage; title="$2"; title_set=1; shift 2 ;;
    --use-when)  [ $# -ge 2 ] || usage; use_when="$2"; use_when_set=1; shift 2 ;;
    *) usage ;;
  esac
done

[ -n "$root" ] && [ -n "$ws" ] && [ -n "$owner" ] && [ -n "$stem" ] || usage
is_abs "$root" || usage
case "$ws" in
  .|"") echo "refusing: --workspace '.' " >&2; exit 2 ;;
  /*)   echo "refusing: --workspace must be repo-relative" >&2; exit 2 ;;
esac

flows_dir="$root/$ws/$owner/flows"
path="$flows_dir/$stem.md"

emit() {
  echo "workspace=$ws"
  echo "owner=$owner"
  echo "flows_dir=$flows_dir"
  echo "stem=$stem"
  echo "path=$path"
  echo "created=$1"
  echo "reason=$2"
}

# Check order: bad-owner, bad-stem, bad-value, unsafe-parent, incumbent, else create.
if ! is_kebab "$owner"; then
  emit false bad-owner
  exit 1
fi
case "$owner" in
  doctrine|hooks|scripts|templates|trackers|flows)
    emit false bad-owner
    exit 1
    ;;
esac

if ! is_kebab "$stem"; then
  emit false bad-stem
  exit 1
fi

if [ "$title_set" -eq 0 ]; then
  title=$(printf '%s' "$stem" | tr '-' ' ')
fi
if [ "$use_when_set" -eq 0 ]; then
  use_when="$stem"
fi

if bad_value "$title" || bad_value "$use_when"; then
  emit false bad-value
  exit 1
fi

if [ -e "$path" ]; then
  emit false incumbent
  exit 1
fi

safe_mkdir_tree() {
  local target="$1" rel current part old_ifs
  [ -d "$root" ] && [ ! -L "$root" ] || return 1
  case "$target" in "$root"/*) rel="${target#"$root"/}" ;; *) return 1 ;; esac
  case "/$rel/" in *'/../'*|*'/./'*|*'//'*) return 1 ;; esac
  current="$root"
  old_ifs=$IFS
  IFS='/'
  set -- $rel
  IFS=$old_ifs
  for part in "$@"; do
    current="$current/$part"
    if [ -L "$current" ]; then
      return 1
    elif [ -e "$current" ]; then
      [ -d "$current" ] || return 1
    else
      mkdir "$current" || return 1
      [ -d "$current" ] && [ ! -L "$current" ] || return 1
    fi
  done
}

if ! safe_mkdir_tree "$flows_dir"; then
  emit false unsafe-parent
  exit 1
fi
{
  printf '%s\n' '---'
  printf 'title: %s\n' "$(yaml_quote "$title")"
  printf 'use-when: %s\n' "$(yaml_quote "$use_when")"
  printf '%s\n' '---'
  printf '\n'
  printf '# %s\n' "$title"
} > "$path"

emit true ok
exit 0
