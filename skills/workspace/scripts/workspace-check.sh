#!/usr/bin/env bash
# Read-only validator for .spaces/<owner>/<kind>/...
set -u

root=""
workspace=.spaces
fails=0
warnings=0

usage() {
  echo "usage: workspace-check.sh --root <root>" >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      [ "$#" -ge 2 ] || usage
      root="$2"
      shift ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
  shift
done

[ -n "$root" ] || usage
[ -d "$root" ] || { echo "error: root is not a directory: $root" >&2; exit 2; }
root="$(CDPATH='' cd -P "$root" && pwd)"

rel() {
  case "$1" in "$root"/*) printf '%s\n' "${1#"$root"/}" ;; *) printf '%s\n' "$1" ;; esac
}

failure() {
  echo "fail path=$(rel "$1") reason=$2"
  fails=$((fails + 1))
}

is_kind() {
  case "$1" in doctrine|drafts|hooks|operations|scripts|templates) return 0 ;; *) return 1 ;; esac
}

valid_owner() {
  is_kind "$1" && return 1
  printf '%s' "$1" | grep -Eq '^[a-z0-9-]+$'
}

safe_stem() {
  printf '%s' "$1" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$'
}

safe_markdown() {
  printf '%s' "$1" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*\.md$'
}

validate_tree_markdown() {
  local dir="$1" entry base
  while IFS= read -r -d '' entry; do
    base="$(basename "$entry")"
    if [ -L "$entry" ]; then
      failure "$entry" symlink-entry
    elif [ -d "$entry" ]; then
      safe_stem "$base" || failure "$entry" unsafe-entry-name
    elif [ -f "$entry" ]; then
      safe_markdown "$base" || failure "$entry" markdown-required
    else
      failure "$entry" unsupported-entry
    fi
  done < <(find "$dir" -mindepth 1 -print0)
}

validate_direct_kind() {
  local kind="$1" dir="$2" entry base
  while IFS= read -r -d '' entry; do
    base="$(basename "$entry")"
    if [ -L "$entry" ]; then
      failure "$entry" symlink-entry
    elif [ -d "$entry" ]; then
      failure "$entry" direct-files-only
    elif [ ! -f "$entry" ]; then
      failure "$entry" unsupported-entry
    else
      case "$kind" in
        hooks|operations)
          safe_markdown "$base" || failure "$entry" markdown-required ;;
        scripts)
          printf '%s' "$base" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*\.sh$' \
            || failure "$entry" shell-required
          [ -x "$entry" ] || failure "$entry" script-not-executable ;;
      esac
    fi
  done < <(find "$dir" -mindepth 1 -maxdepth 1 -print0)
}

validate_kind() {
  case "$1" in
    doctrine|drafts|templates) validate_tree_markdown "$2" ;;
    hooks|operations|scripts) validate_direct_kind "$1" "$2" ;;
  esac
}

validate_owner_dir() {
  local owner_dir="$1" entry kind
  while IFS= read -r -d '' entry; do
    kind="$(basename "$entry")"
    if [ -L "$entry" ]; then
      if is_kind "$kind"; then
        failure "$entry" symlink-kind
      else
        failure "$entry" unknown-kind
      fi
    elif [ -f "$entry" ]; then
      failure "$entry" direct-owner-file
    elif [ ! -d "$entry" ]; then
      failure "$entry" unsupported-entry
    elif ! is_kind "$kind"; then
      failure "$entry" unknown-kind
    else
      validate_kind "$kind" "$entry"
    fi
  done < <(find "$owner_dir" -mindepth 1 -maxdepth 1 -print0)
}

workspace_path="$root/$workspace"
echo "workspace=$workspace"
echo "mode=fixed"

prefix="$root"
old_ifs="$IFS"
IFS='/'
read -r -a workspace_components <<< "$workspace"
IFS="$old_ifs"
for component in "${workspace_components[@]}"; do
  prefix="$prefix/$component"
  if [ -L "$prefix" ]; then
    failure "$prefix" symlink-workspace
    echo "state=invalid"
    echo "fails=$fails"
    echo "warnings=$warnings"
    exit 1
  fi
done

if [ ! -e "$workspace_path" ]; then
  echo "state=absent"
  echo "fails=0"
  echo "warnings=0"
  exit 0
fi
if [ ! -d "$workspace_path" ]; then
  failure "$workspace_path" workspace-not-directory
  echo "state=invalid"
  echo "fails=$fails"
  echo "warnings=$warnings"
  exit 1
fi
echo "state=present"

while IFS= read -r -d '' entry; do
  owner="$(basename "$entry")"
  if is_kind "$owner"; then
    failure "$entry" retired-top-level-kind
    continue
  fi

  if [ -L "$entry" ]; then
    failure "$entry" symlink-owner
  elif [ ! -d "$entry" ]; then
    failure "$entry" direct-workspace-file
  elif ! valid_owner "$owner"; then
    failure "$entry" invalid-owner
  else
    validate_owner_dir "$entry"
  fi
done < <(find "$workspace_path" -mindepth 1 -maxdepth 1 -print0)

echo "fails=$fails"
echo "warnings=$warnings"
[ "$fails" -eq 0 ]
