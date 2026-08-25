#!/usr/bin/env bash
# backlog-setup.sh — stage the engine, apply builtin choices, and register Backlog.
set -euo pipefail

die() { echo "reason=$1${2:+ detail=$2}" >&2; exit 2; }
ROOT="${1:-}"; [ -n "$ROOT" ] || die usage; shift
WS=""; mode=""; stems=(); custom=()
while [ $# -gt 0 ]; do case "$1" in
  --workspace) WS="${2:-}"; shift 2;; --list) mode=list; shift;;
  --apply)
    mode=apply; shift; target=builtin
    while [ $# -gt 0 ]; do
      if [ "$1" = --custom ]; then target=custom; shift; continue; fi
      if [ "$target" = builtin ]; then stems+=("$1"); else custom+=("$1"); fi
      shift
    done
    ;;
  *) die usage;; esac; done
case "$ROOT" in /*) ;; *) die unsafe-root;; esac; [ -d "$ROOT" ] || die unsafe-root; ROOT="$(cd "$ROOT" && pwd)"
[ -n "$WS" ] || die unsafe-workspace; case "$WS" in /*) die unsafe-workspace;; esac; case "/$WS/" in */../*) die unsafe-workspace;; esac
[ -n "$mode" ] || die usage
SKILL="$(cd "$(dirname "$0")/.." && pwd)"; SRC="$SKILL/scripts/trackers.sh"; DEST="$ROOT/$WS/backlog/scripts/trackers.sh"; REG="$SKILL/scripts/register-route.sh"
"$REG" preflight --root "$ROOT" --workspace "$WS" >/dev/null

safe_tree() {
  current="$ROOT"; old_ifs="$IFS"; IFS=/
  for segment in $1; do [ -n "$segment" ] || continue; current="$current/$segment"; [ ! -L "$current" ] || die symlink "$current"; [ ! -e "$current" ] || [ -d "$current" ] || die incompatible-entry "$current"; [ -d "$current" ] || mkdir "$current"; done
  IFS="$old_ifs"
}
safe_tree "$WS/backlog/scripts"; [ ! -L "$DEST" ] || die symlink "$DEST"; [ ! -e "$DEST" ] || [ -f "$DEST" ] || die incompatible-entry "$DEST"
if [ ! -f "$DEST" ] || ! cmp -s "$SRC" "$DEST"; then cp "$SRC" "$DEST"; chmod +x "$DEST"; echo "wrote=${DEST#"$ROOT"/}"; elif [ ! -x "$DEST" ]; then chmod +x "$DEST"; echo "wrote=${DEST#"$ROOT"/}"; fi

RUN=("$DEST" --root "$ROOT" --workspace "$WS")
if [ "$mode" = list ]; then "${RUN[@]}" setup --list; exit; fi
[ "${#stems[@]}" -gt 0 ] || [ "${#custom[@]}" -gt 0 ] || die usage
if [ "${#stems[@]}" -gt 0 ]; then "${RUN[@]}" setup --apply "${stems[@]}"; fi
if [ "${#custom[@]}" -gt 0 ]; then for stem in "${custom[@]}"; do "${RUN[@]}" tracker-add "$stem"; done; fi
if [ -n "$("${RUN[@]}" list)" ]; then
  stamp="$(git -C "$SKILL" log -1 --format=%h -- . 2>/dev/null || true)"; [ -n "$stamp" ] || stamp="v0-$(date +%Y-%m-%d)"
  "$REG" ensure --root "$ROOT" --workspace "$WS" --stamp "$stamp"
fi
