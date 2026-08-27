#!/usr/bin/env bash
# debugger-setup.sh [--write-only] <root> — deploy active Debugger project assets.
set -euo pipefail
usage() { echo "usage: debugger-setup.sh [--write-only] <root>" >&2; exit 2; }
err() { echo "debugger-setup.sh: $*" >&2; exit 2; }
write_only=no; case "${1:-}" in --write-only) write_only=yes; shift ;; esac
[ "$#" -eq 1 ] || usage
root="$1"; [ -d "$root" ] || err "root is not a directory: $root"; root="$(cd "$root" && pwd -P)"
skill_dir="$(cd "$(dirname "$0")/.." && pwd -P)"

resolve() {
  local kind="$1" fallback="$2" fd value=""
  for fd in "$root/AGENTS.md" "$root/CLAUDE.md"; do
    if [ -z "$value" ] && [ -f "$fd" ]; then
      case "$kind" in
        workspace) value="$(sed -n -E 's/^agent-workspace:[[:space:]]*//p' "$fd" | head -n1 | sed 's/[[:space:]]*$//')" ;;
        records) value="$(sed -n -E 's/^(agent-records|records-root):[[:space:]]*//p' "$fd" | head -n1 | sed 's/[[:space:]]*$//')" ;;
      esac
    fi
  done
  printf '%s\n' "${value:-$fallback}"
}
valid_rel() { [ -n "$1" ] && [ "$1" != . ] || return 1; case "$1" in /*) return 1;; esac; case "/$1/" in */../*) return 1;; esac; }
check_chain() {
  local rel="$1" cur="$root" part old="$IFS" missing=no
  valid_rel "$rel" || err "unsafe relative path: $rel"; IFS=/
  for part in $rel; do
    [ -n "$part" ] || continue; cur="$cur/$part"; [ "$missing" = no ] || continue
    [ ! -L "$cur" ] || err "symlinked destination parent: $cur"
    if [ -e "$cur" ]; then [ -d "$cur" ] || err "destination parent is not a directory: $cur"; else missing=yes; fi
  done
  IFS="$old"
}
ensure_chain() {
  local rel="$1" cur="$root" part old="$IFS"; IFS=/
  for part in $rel; do
    [ -n "$part" ] || continue; cur="$cur/$part"
    [ ! -L "$cur" ] || err "symlinked destination parent: $cur"
    if [ -e "$cur" ]; then [ -d "$cur" ] || err "destination parent is not a directory: $cur"; else mkdir "$cur"; fi
  done
  IFS="$old"
}
schema_free() { ! awk 'NR==1&&$0=="---"{fm=1;next} fm&&$0=="---"{exit} fm&&/^schema:/{x=1} END{exit !x}' "$1"; }

ws="$(resolve workspace .spaces)"; rr="$(resolve records .records)"
valid_rel "$ws" || err "unsafe workspace path: $ws"; valid_rel "$rr" || err "unsafe records path: $rr"
assets="templates/bugs.md
templates/investigation.md
operations/diagnostics.md"
[ -z "${DEBUGGER_SETUP_TEST_ASSET:-}" ] || assets="$assets
$DEBUGGER_SETUP_TEST_ASSET"
created=(); write_count=0

# Whole-set preflight. Nothing above this point creates project paths.
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  case "$rel" in templates/bugs.md|templates/investigation.md|operations/diagnostics.md) ;; *) err "asset is not declared for project deployment: $rel" ;; esac
  src="$skill_dir/$rel"; [ -f "$src" ] && [ ! -L "$src" ] || err "bundled asset is not a regular file: $src"
  case "$rel" in templates/*) schema_free "$src" || err "bundled project template selects a schema: $src" ;; esac
  dest_rel="$ws/debugger/$rel"; [ -z "${DEBUGGER_SETUP_TEST_DEST_REL:-}" ] || dest_rel="$DEBUGGER_SETUP_TEST_DEST_REL"
  case "$dest_rel" in "$ws/debugger/$rel") ;; *) err "destination escapes debugger ownership: $dest_rel" ;; esac
  check_chain "${dest_rel%/*}"; dest="$root/$dest_rel"
  [ ! -L "$dest" ] || err "destination is a symlink: $dest"
  [ ! -e "$dest" ] || [ -f "$dest" ] || err "destination is not a regular file: $dest"
  if [ ! -e "$dest" ]; then
    case "$rel" in templates/*)
      base="${rel##*/}"
      for legacy in "$root/$rr/templates/debugger/$base" "$root/$rr/templates/$base"; do
        [ ! -L "$legacy" ] && [ ! -e "$legacy" ] || err "legacy template found; run /debugger migrate $legacy"
      done
    esac
  else
    case "$rel" in templates/*) schema_free "$dest" || err "project template selects a schema: $dest" ;; esac
  fi
done <<EOF
$assets
EOF
if [ "$write_only" = no ]; then
  gr="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$gr" ] && [ "$(cd "$gr" && pwd -P)" = "$root" ] || err "standalone setup root must be a Git top level"
fi
[ -z "${DEBUGGER_SETUP_TEST_AFTER_PREFLIGHT:-}" ] || "$DEBUGGER_SETUP_TEST_AFTER_PREFLIGHT" "$root" "$ws"

while IFS= read -r rel; do
  [ -n "$rel" ] || continue; src="$skill_dir/$rel"; dest_rel="$ws/debugger/$rel"; dest="$root/$dest_rel"
  if [ -f "$dest" ] && [ ! -L "$dest" ]; then printf 'preserved=%s\n' "$dest_rel"; continue; fi
  ensure_chain "${dest_rel%/*}"; check_chain "${dest_rel%/*}"
  [ ! -L "$dest" ] && [ ! -e "$dest" ] || err "destination changed after preflight: $dest"
  cp "$src" "$dest"; created+=("$dest_rel"); write_count=$((write_count + 1)); printf 'created=%s\n' "$dest_rel"
  if [ -n "${DEBUGGER_SETUP_TEST_AFTER_WRITE:-}" ]; then
    "$DEBUGGER_SETUP_TEST_AFTER_WRITE" "$root" "$ws" "$dest_rel" "$write_count"
  fi
done <<EOF
$assets
EOF
printf 'writes=%s\n' "${#created[@]}"
if [ "${#created[@]}" -gt 0 ]; then
  if [ "$write_only" = yes ]; then printf 'commit=caller\n'; else
    git -C "$root" add -- "${created[@]}"
    git -C "$root" commit -m "Debugger: setup" -- "${created[@]}"
    printf 'committed_count=%s\n' "${#created[@]}"
  fi
fi
