#!/usr/bin/env bash
# notepad-setup.sh [--write-only] <root>
# Deploy Notepad's one active project template absent-only. Standalone mode
# commits exactly the created template; a declared configuration sweep uses
# --write-only and leaves commit custody with its caller.
set -euo pipefail

usage() { echo "usage: notepad-setup.sh [--write-only] <root>" >&2; exit 2; }
err() { echo "notepad-setup.sh: $*" >&2; exit 2; }

write_only=no
case "${1:-}" in --write-only) write_only=yes; shift ;; esac
[ "$#" -eq 1 ] || usage
root="$1"
[ -d "$root" ] || err "root is not a directory: $root"
root="$(cd "$root" && pwd -P)"

valid_rel() {
  [ -n "$1" ] || return 1
  [ "$1" != . ] || return 1
  case "$1" in /*) return 1 ;; esac
  case "/$1/" in */../*) return 1 ;; esac
}

check_chain() {
  local rel="$1" current="$root" segment old_ifs missing=no
  valid_rel "$rel" || err "unsafe relative path: $rel"
  old_ifs="$IFS"; IFS=/
  for segment in $rel; do
    [ -n "$segment" ] || continue
    current="$current/$segment"
    if [ "$missing" = yes ]; then continue; fi
    [ ! -L "$current" ] || err "symlinked destination parent: $current"
    if [ -e "$current" ]; then
      [ -d "$current" ] || err "destination parent is not a directory: $current"
    else
      missing=yes
    fi
  done
  IFS="$old_ifs"
}

ensure_chain() {
  local rel="$1" current="$root" segment old_ifs
  old_ifs="$IFS"; IFS=/
  for segment in $rel; do
    [ -n "$segment" ] || continue
    current="$current/$segment"
    [ ! -L "$current" ] || err "symlinked destination parent: $current"
    if [ -e "$current" ]; then
      [ -d "$current" ] || err "destination parent is not a directory: $current"
    else
      mkdir "$current"
    fi
  done
  IFS="$old_ifs"
}

skilldata_rel=.agents/skilldata
records_rel=.records

asset="${NOTEPAD_SETUP_TEST_ASSET:-notes.md}"
[ "$asset" = notes.md ] || err "asset is not declared for project deployment: $asset"
dest_rel="${NOTEPAD_SETUP_TEST_DEST_REL:-$skilldata_rel/notepad/templates/notes.md}"
case "$dest_rel" in "$skilldata_rel/notepad/templates/notes.md") ;; *) err "destination escapes notepad ownership: $dest_rel" ;; esac

skill_dir="$(cd "$(dirname "$0")/.." && pwd)"
bundled="$skill_dir/templates/$asset"
[ -f "$bundled" ] && [ ! -L "$bundled" ] || err "bundled template is not a regular file: $bundled"
if awk 'NR==1 && $0=="---"{fm=1;next} fm && $0=="---"{exit} fm && /^schema:/{found=1} END{exit !found}' "$bundled"; then
  err "bundled project template cannot select a schema: $bundled"
fi

parent_rel="${dest_rel%/*}"
dest="$root/$dest_rel"
legacy_owner="$root/$records_rel/templates/notepad/notes.md"
legacy_flat="$root/$records_rel/templates/notes.md"

# Whole-set preflight. No directory is created above this line.
check_chain "$parent_rel"
[ ! -L "$dest" ] || err "destination is a symlink: $dest"
if [ -e "$dest" ] && [ ! -f "$dest" ]; then err "destination is not a regular file: $dest"; fi
if [ ! -e "$dest" ]; then
  [ ! -L "$legacy_owner" ] && [ ! -e "$legacy_owner" ] || err "legacy notes template found; run /notepad migrate $legacy_owner"
  [ ! -L "$legacy_flat" ] && [ ! -e "$legacy_flat" ] || err "legacy notes template found; run /notepad migrate $legacy_flat"
fi
if [ "$write_only" = no ]; then
  git_root="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$git_root" ] && [ "$(cd "$git_root" && pwd -P)" = "$root" ] || err "standalone setup root must be a Git top level"
fi

# Test-only exchange seam: fixtures can replace a parent after preflight and
# prove the immediate recheck catches it. Ordinary runs never set this.
if [ -n "${NOTEPAD_SETUP_TEST_AFTER_PREFLIGHT:-}" ]; then
  [ -x "$NOTEPAD_SETUP_TEST_AFTER_PREFLIGHT" ] || err "test preflight hook is not executable"
  "$NOTEPAD_SETUP_TEST_AFTER_PREFLIGHT" "$root" "$skilldata_rel"
fi

if [ -f "$dest" ] && [ ! -L "$dest" ]; then
  if awk 'NR==1 && $0=="---"{fm=1;next} fm && $0=="---"{exit} fm && /^schema:/{found=1} END{exit !found}' "$dest"; then
    err "project template cannot select a schema: $dest"
  fi
  printf 'preserved=%s\n' "$dest_rel"
  printf 'writes=0\n'
  exit 0
fi

ensure_chain "$parent_rel"
check_chain "$parent_rel"
[ ! -L "$dest" ] && [ ! -e "$dest" ] || err "destination changed after preflight: $dest"
cp "$bundled" "$dest"
printf 'created=%s\n' "$dest_rel"
printf 'writes=1\n'

if [ "$write_only" = no ]; then
  "$skill_dir/scripts/scoped-commit.sh" "$root" "Notepad: setup" "$dest_rel"
  printf 'committed=%s\n' "$dest_rel"
else
  printf 'commit=caller\n'
fi
