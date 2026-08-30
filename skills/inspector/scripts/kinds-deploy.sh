#!/usr/bin/env bash
# kinds-deploy.sh --root <root>
# Copy every bundled Inspector kind absent-only into inspector/doctrine/.
set -euo pipefail

die() { echo "kinds-deploy.sh: $1${2:+: $2}" >&2; exit 2; }

ROOT=""
WORKSPACE=.spaces
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) [ "$#" -ge 2 ] || die usage; ROOT="$2"; shift 2 ;;
    *) die usage "$1" ;;
  esac
done

[ -n "$ROOT" ] || die usage
[ -d "$ROOT" ] || die "root is not a directory" "$ROOT"
ROOT="$(CDPATH='' cd -P "$ROOT" && pwd)"

valid_relative() {
  local value="$1" component old_ifs="$IFS"
  [ -n "$value" ] || return 1
  case "$value" in .|/*) return 1 ;; esac
  IFS='/'
  read -r -a components <<< "$value"
  IFS="$old_ifs"
  for component in "${components[@]}"; do
    [ -n "$component" ] && [ "$component" != "." ] && [ "$component" != ".." ] || return 1
  done
}

SKILL="$(CDPATH='' cd -P "$(dirname "$0")/.." && pwd)"
BUNDLED="$SKILL/kinds"
[ -d "$BUNDLED" ] && [ ! -L "$BUNDLED" ] || die "missing bundled kinds" "$BUNDLED"

safe_tree() {
  local rel="$1" current="$ROOT" component old_ifs="$IFS"
  valid_relative "$rel" || die "unsafe destination path" "$rel"
  IFS='/'
  read -r -a components <<< "$rel"
  IFS="$old_ifs"
  for component in "${components[@]}"; do
    current="$current/$component"
    [ ! -L "$current" ] || die "symlinked destination parent" "$current"
    [ ! -e "$current" ] || [ -d "$current" ] \
      || die "destination parent is not a directory" "$current"
    if [ ! -d "$current" ]; then
      mkdir "$current"
      [ -d "$current" ] && [ ! -L "$current" ] \
        || die "destination parent changed during setup" "$current"
    fi
  done
}

check_tree() {
  local rel="$1" current="$ROOT" component old_ifs="$IFS"
  valid_relative "$rel" || die "unsafe destination path" "$rel"
  IFS='/'; read -r -a components <<< "$rel"; IFS="$old_ifs"
  for component in "${components[@]}"; do
    current="$current/$component"
    [ ! -L "$current" ] || die "symlinked destination parent" "$current"
    if [ -e "$current" ]; then
      [ -d "$current" ] || die "destination parent is not a directory" "$current"
    else
      break
    fi
  done
}

# Whole-set preflight: validate every bundled kind and incumbent before any
# owner directory is created.
found=0
check_tree "$WORKSPACE/inspector/doctrine"
for source in "$BUNDLED"/*.md; do
  [ -f "$source" ] && [ ! -L "$source" ] || continue
  found=$((found + 1)); base="$(basename "$source")"
  case "$base" in [A-Za-z0-9]*.md) ;; *) die "unsafe bundled kind name" "$base" ;; esac
  dest="$ROOT/$WORKSPACE/inspector/doctrine/$base"
  [ ! -L "$dest" ] || die "incompatible destination" "$dest"
  [ ! -e "$dest" ] || [ -f "$dest" ] || die "incompatible destination" "$dest"
done
[ "$found" -gt 0 ] || die "no bundled kinds found" "$BUNDLED"
[ -z "${INSPECTOR_SETUP_TEST_AFTER_PREFLIGHT:-}" ] || {
  [ -x "$INSPECTOR_SETUP_TEST_AFTER_PREFLIGHT" ] || die "test hook is not executable"
  "$INSPECTOR_SETUP_TEST_AFTER_PREFLIGHT" "$ROOT" "$WORKSPACE"
}

deployed=0
kept=0
for source in "$BUNDLED"/*.md; do
  [ -f "$source" ] && [ ! -L "$source" ] || continue
  base="$(basename "$source")"
  case "$base" in
    [A-Za-z0-9]*.md) ;;
    *) die "unsafe bundled kind name" "$base" ;;
  esac

  safe_tree "$WORKSPACE/inspector/doctrine"
  dest="$ROOT/$WORKSPACE/inspector/doctrine/$base"
  if [ -L "$dest" ]; then
    die "incompatible destination" "$dest"
  elif [ -e "$dest" ]; then
    [ -f "$dest" ] || die "incompatible destination" "$dest"
    kept=$((kept + 1))
    echo "kept=${dest#"$ROOT"/}"
  else
    safe_tree "$WORKSPACE/inspector/doctrine"
    [ ! -e "$dest" ] && [ ! -L "$dest" ] || die "destination changed during setup" "$dest"
    cp "$source" "$dest"
    cmp -s "$source" "$dest" || die "copy verification failed" "$dest"
    deployed=$((deployed + 1))
    echo "deployed=${dest#"$ROOT"/}"
    if [ -n "${INSPECTOR_SETUP_TEST_AFTER_WRITE:-}" ]; then
      [ -x "$INSPECTOR_SETUP_TEST_AFTER_WRITE" ] || die "test post-write hook is not executable"
      "$INSPECTOR_SETUP_TEST_AFTER_WRITE" "$ROOT" "$WORKSPACE" "${dest#"$ROOT"/}" "$deployed"
    fi
  fi
done

echo "dest=$WORKSPACE/inspector/doctrine"
echo "deployed_count=$deployed"
echo "kept_count=$kept"
