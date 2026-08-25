#!/usr/bin/env bash
# analyst-deploy.sh <root> — lazily deploy the bundled template catalog.
#
# Copies any bundled template ABSENT from
# <agent-workspace>/analyst/templates/. Adopts a previous-home copy at
# <agent-records>/templates/analyst/ when the new dest is empty.
# Never overwrites: a deployed template is the project's, customized or not, and
# silently replacing it would discard the customization this deploy exists to
# enable. An upgrade of a customized template is a judgment-assisted diff a human
# runs, never a copy this script performs.
#
# Idempotent: re-running deploys nothing new and reports what it found.
# Explicit deploy may create only Analyst's owner namespace. It refuses
# symlinked or non-directory parents before writing. The destination is a
# workspace subpath, so a records directory is not a deploy gate.
set -euo pipefail

resolve_records_root() {
  local root="$1" fd decl=""
  for fd in "$root/AGENTS.md" "$root/CLAUDE.md"; do
    if [ -z "$decl" ] && [ -f "$fd" ]; then
      decl="$(sed -n -E 's/^(agent-records|records-root):[[:space:]]*//p' "$fd" \
              | head -n 1 | sed 's/[[:space:]]*$//')"
    fi
  done
  printf '%s\n' "${decl:-.records}"
}

resolve_workspace() {
  local root="$1" fd decl=""
  for fd in "$root/AGENTS.md" "$root/CLAUDE.md"; do
    if [ -z "$decl" ] && [ -f "$fd" ]; then
      decl="$(sed -n -E 's/^agent-workspace:[[:space:]]*//p' "$fd" \
              | head -n 1 | sed 's/[[:space:]]*$//')"
    fi
  done
  printf '%s\n' "${decl:-.dev}"
}

valid_rel() {
  [ -n "$1" ] || return 1
  case "$1" in /*) return 1 ;; esac
  case "/$1/" in */../*) return 1 ;; esac
  return 0
}

safe_tree() {
  local base="$1" rel="$2" current="$1" segment old_ifs
  valid_rel "$rel" || { echo "analyst-deploy.sh: unsafe workspace path: $rel" >&2; exit 2; }
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

RR_REL="$(resolve_records_root "$ROOT")"
WS_REL="$(resolve_workspace "$ROOT")"
valid_rel "$RR_REL" || { echo "analyst-deploy.sh: unsafe records path: $RR_REL" >&2; exit 2; }
valid_rel "$WS_REL" || { echo "analyst-deploy.sh: unsafe workspace path: $WS_REL" >&2; exit 2; }
RR="$ROOT/$RR_REL"
WS="$ROOT/$WS_REL"
BUNDLED="$(cd "$(dirname "$0")/../templates" && pwd)"
DEST="$WS/analyst/templates"
PREV="$RR/templates/analyst"

safe_tree "$ROOT" "$WS_REL/analyst/templates"
if [ -d "$PREV" ] && [ "$PREV" != "$DEST" ]; then
  for f in "$PREV"/*.md; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    [ -e "$DEST/$base" ] || cp "$f" "$DEST/$base"
  done
fi

deployed=0 kept=0
for f in "$BUNDLED"/*.md; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  if [ -e "$DEST/$base" ]; then
    kept=$((kept + 1))
    echo "kept=$base"        # already the project's -- untouched
  else
    cp "$f" "$DEST/$base"
    deployed=$((deployed + 1))
    echo "deployed=$base"
  fi
done

echo "workspace=present"
echo "dest=${DEST#"$ROOT"/}"
echo "deployed_count=$deployed"
echo "kept_count=$kept"
