#!/usr/bin/env bash
# analyst-deploy.sh <root> — lazily deploy the bundled template catalog.
#
# Copies any bundled template ABSENT from <records-root>/templates/analyst/.
# Never overwrites: a deployed template is the project's, customized or not, and
# silently replacing it would discard the customization this deploy exists to
# enable. An upgrade of a customized template is a judgment-assisted diff a human
# runs, never a copy this script performs.
#
# Idempotent: re-running deploys nothing new and reports what it found.
# Refuses nothing: with no records layer, it reports that and exits 0 -- the
# skill reads its bundled templates in place on such a host.
set -euo pipefail

resolve_records_root() {
  local root="$1" fd decl=""
  for fd in "$root/AGENTS.md" "$root/CLAUDE.md"; do
    if [ -z "$decl" ] && [ -f "$fd" ]; then
      decl="$(sed -n 's/^records-root:[[:space:]]*//p' "$fd" | head -n 1 \
              | sed 's/[[:space:]]*$//')"
    fi
  done
  printf '%s\n' "${decl:-.records}"
}

ROOT="${1:-}"
[ -n "$ROOT" ] || { echo "usage: analyst-deploy.sh <root>" >&2; exit 1; }
[ -d "$ROOT" ] || { echo "analyst-deploy.sh: no such directory: $ROOT" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd)"

RR="$ROOT/$(resolve_records_root "$ROOT")"
BUNDLED="$(cd "$(dirname "$0")/../templates" && pwd)"
DEST="$RR/templates/analyst"

if [ ! -d "$RR" ]; then
  echo "records_layer=absent"
  echo "deployed=0"
  echo "note=no records layer; the skill reads its bundled templates in place"
  exit 0
fi

mkdir -p "$DEST"

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

echo "records_layer=present"
echo "dest=${DEST#"$ROOT"/}"
echo "deployed_count=$deployed"
echo "kept_count=$kept"
