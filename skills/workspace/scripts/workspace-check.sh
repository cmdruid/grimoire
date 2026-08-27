#!/usr/bin/env bash
# Read-only validator for <agent-workspace>/<owner>/<kind>/...
set -u

root=""
workspace=""
records_root=""
fails=0
warnings=0

usage() {
  echo "usage: workspace-check.sh --root <root> --workspace <repo-relative-W> --records-root <repo-relative-R>" >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root|--workspace|--records-root)
      [ "$#" -ge 2 ] || usage
      case "$1" in
        --root) root="$2" ;;
        --workspace) workspace="$2" ;;
        --records-root) records_root="$2" ;;
      esac
      shift ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
  shift
done

[ -n "$root" ] && [ -n "$workspace" ] && [ -n "$records_root" ] || usage
[ -d "$root" ] || { echo "error: root is not a directory: $root" >&2; exit 2; }
root="$(CDPATH='' cd -P "$root" && pwd)"

valid_relative() {
  local value="$1" allow_dot="$2" component old_ifs="$IFS"
  [ -n "$value" ] || return 1
  case "$value" in /*) return 1 ;; esac
  [ "$allow_dot" = true ] || [ "$value" != "." ] || return 1
  IFS='/'
  read -r -a components <<< "$value"
  IFS="$old_ifs"
  for component in "${components[@]}"; do
    [ -n "$component" ] && [ "$component" != "." ] && [ "$component" != ".." ] || return 1
  done
}

valid_relative "$workspace" false \
  || { echo "error: invalid workspace path: $workspace" >&2; exit 2; }
valid_relative "$records_root" true \
  || { echo "error: invalid records-root path: $records_root" >&2; exit 2; }

rel() {
  case "$1" in "$root"/*) printf '%s\n' "${1#"$root"/}" ;; *) printf '%s\n' "$1" ;; esac
}

failure() {
  echo "fail path=$(rel "$1") reason=$2"
  fails=$((fails + 1))
}

warning() {
  echo "warn path=$(rel "$1") reason=$2"
  warnings=$((warnings + 1))
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

has_kind_child() {
  local dir="$1" entry
  while IFS= read -r -d '' entry; do
    is_kind "$(basename "$entry")" && return 0
  done < <(find "$dir" -mindepth 1 -maxdepth 1 -print0)
  return 1
}

workspace_path="$root/$workspace"
echo "workspace=$workspace"
echo "records_root=$records_root"
if [ "$workspace" = "$records_root" ]; then mode="coincident"; else mode="split"; fi
echo "mode=$mode"

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

  if [ "$mode" = "coincident" ]; then
    if [ -L "$entry" ]; then
      if valid_owner "$owner"; then failure "$entry" symlink-owner; else warning "$entry" coincident-unknown; fi
    elif [ -d "$entry" ] && has_kind_child "$entry"; then
      if valid_owner "$owner"; then
        validate_owner_dir "$entry"
      else
        failure "$entry" invalid-owner
      fi
    else
      warning "$entry" coincident-unknown
    fi
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
