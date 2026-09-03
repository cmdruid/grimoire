#!/usr/bin/env bash
# analyst-deploy.sh <root> — explicitly deploy the bundled template catalog.
#
# Copies any actively used bundled template absent from
# .agents/skilldata/analyst/templates/. A previous-home copy requires explicit migration.
# Never overwrites: a deployed template is the project's, customized or not, and
# silently replacing it would discard the customization this deploy exists to
# enable. An upgrade of a customized template is a judgment-assisted diff a human
# runs, never a copy this script performs.
#
# Idempotent: re-running deploys nothing new and reports what it found.
# Explicit deploy may create only Analyst's owner namespace. It refuses
# symlinked or non-directory parents before writing. The destination is a
# skilldata subpath, so a records directory is not a deploy gate.
set -euo pipefail

valid_rel() {
  [ -n "$1" ] || return 1
  case "$1" in /*) return 1 ;; esac
  case "/$1/" in */../*) return 1 ;; esac
  return 0
}

check_tree() {
  local base="$1" rel="$2" current="$1" segment old_ifs
  valid_rel "$rel" || { echo "analyst-deploy.sh: unsafe skilldata path: $rel" >&2; exit 2; }
  old_ifs="$IFS"; IFS=/
  for segment in $rel; do
    [ -n "$segment" ] || continue
    current="$current/$segment"
    if [ -L "$current" ]; then
      echo "analyst-deploy.sh: symlinked destination parent: $current" >&2; exit 2
    elif [ -e "$current" ] && [ ! -d "$current" ]; then
      echo "analyst-deploy.sh: destination parent is not a directory: $current" >&2; exit 2
    elif [ ! -e "$current" ]; then
      break
    fi
  done
  IFS="$old_ifs"
}

ensure_tree() {
  local rel="$2" current="$1" segment old_ifs
  old_ifs="$IFS"; IFS=/
  for segment in $rel; do
    [ -n "$segment" ] || continue
    current="$current/$segment"
    if [ -L "$current" ]; then
      echo "analyst-deploy.sh: symlinked destination parent: $current" >&2; exit 2
    elif [ -e "$current" ] && [ ! -d "$current" ]; then
      echo "analyst-deploy.sh: destination parent is not a directory: $current" >&2; exit 2
    elif [ ! -d "$current" ]; then
      mkdir "$current"
    fi
  done
  IFS="$old_ifs"
}

ROOT="${1:-}"
[ -n "$ROOT" ] || { echo "usage: analyst-deploy.sh <root>" >&2; exit 1; }
[ -d "$ROOT" ] || { echo "analyst-deploy.sh: no such directory: $ROOT" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd)"

RR_REL=.records
SKILLDATA_REL=.agents/skilldata
valid_rel "$RR_REL" || { echo "analyst-deploy.sh: unsafe records path: $RR_REL" >&2; exit 2; }
valid_rel "$SKILLDATA_REL" || { echo "analyst-deploy.sh: unsafe skilldata path: $SKILLDATA_REL" >&2; exit 2; }
RR="$ROOT/$RR_REL"
SKILLDATA="$ROOT/$SKILLDATA_REL"
BUNDLED="$(cd "$(dirname "$0")/../templates" && pwd)"
DEST="$SKILLDATA/analyst/templates"
PREV="$RR/templates/analyst"

check_tree "$ROOT" "$SKILLDATA_REL/analyst/templates"
if [ -d "$PREV" ] && [ "$PREV" != "$DEST" ]; then
  for f in "$PREV"/*.md; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    [ -e "$DEST/$base" ] || {
      echo "analyst-deploy.sh: legacy template requires /analyst migrate $f" >&2
      exit 2
    }
  done
fi

# Preflight every active source and incumbent before creating the owner tree.
for f in "$BUNDLED"/*.md; do
  [ -f "$f" ] && [ ! -L "$f" ] || continue
  base="$(basename "$f")"
  target="$DEST/$base"
  [ ! -L "$target" ] || { echo "analyst-deploy.sh: incompatible destination: $target" >&2; exit 2; }
  [ ! -e "$target" ] || [ -f "$target" ] || { echo "analyst-deploy.sh: incompatible destination: $target" >&2; exit 2; }
  if [ -f "$target" ] && awk 'NR==1 && $0=="---"{fm=1;next} fm && $0=="---"{exit} fm && /^schema:/{found=1} END{exit !found}' "$target"; then
    echo "analyst-deploy.sh: project template cannot select a schema: $target" >&2
    exit 2
  fi
done

if [ -n "${ANALYST_SETUP_TEST_AFTER_PREFLIGHT:-}" ]; then
  [ -x "$ANALYST_SETUP_TEST_AFTER_PREFLIGHT" ] || { echo "analyst-deploy.sh: test hook is not executable" >&2; exit 2; }
  "$ANALYST_SETUP_TEST_AFTER_PREFLIGHT" "$ROOT" "$SKILLDATA_REL"
fi
ensure_tree "$ROOT" "$SKILLDATA_REL/analyst/templates"

deployed=0 kept=0
for f in "$BUNDLED"/*.md; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  if [ -e "$DEST/$base" ]; then
    awk 'NR==1 && $0=="---"{fm=1;next} fm && $0=="---"{exit} fm && /^schema:/{found=1} END{exit !found}' "$DEST/$base" && {
      echo "analyst-deploy.sh: project template cannot select a schema: $DEST/$base" >&2
      exit 2
    }
    kept=$((kept + 1))
    echo "kept=$base"        # already the project's -- untouched
  else
    check_tree "$ROOT" "$SKILLDATA_REL/analyst/templates"
    [ ! -L "$DEST/$base" ] && [ ! -e "$DEST/$base" ] || {
      echo "analyst-deploy.sh: destination changed after preflight: $DEST/$base" >&2
      exit 2
    }
    cp "$f" "$DEST/$base"
    deployed=$((deployed + 1))
    echo "deployed=$base"
    if [ -n "${ANALYST_SETUP_TEST_AFTER_WRITE:-}" ]; then
      [ -x "$ANALYST_SETUP_TEST_AFTER_WRITE" ] || {
        echo "analyst-deploy.sh: test post-write hook is not executable" >&2; exit 2;
      }
      "$ANALYST_SETUP_TEST_AFTER_WRITE" "$ROOT" "$SKILLDATA_REL" "$base" "$deployed"
    fi
  fi
done

echo "skilldata=present"
echo "dest=${DEST#"$ROOT"/}"
echo "deployed_count=$deployed"
echo "kept_count=$kept"
