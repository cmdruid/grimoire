#!/usr/bin/env bash
# delegate-setup.sh [--write-only] <root> — deploy the empty byproducts hook.
set -euo pipefail
die(){ echo "delegate-setup.sh: $*" >&2;exit 2;};wo=no;case "${1:-}" in --write-only)wo=yes;shift;;esac;[ "$#" -eq 1 ]||die "usage: delegate-setup.sh [--write-only] <root>"
root="$1";[ -d "$root" ]||die "root is not a directory: $root";root="$(cd "$root"&&pwd -P)";base="$(cd "$(dirname "$0")/.."&&pwd -P)";src="$base/templates/hooks/byproducts.md";[ -f "$src" ]&&[ ! -L "$src" ]&&[ ! -s "$src" ]||die "bundled hook must be a zero-byte regular file"
ws=.spaces
check(){ local r="$1" c="$root" p o="$IFS" m=no;IFS=/;for p in $r;do [ -n "$p" ]||continue;c="$c/$p";[ "$m" = no ]||continue;[ ! -L "$c" ]||die "symlinked destination parent: $c";if [ -e "$c" ];then [ -d "$c" ]||die "destination parent is not a directory: $c";else m=yes;fi;done;IFS="$o";}
ensure(){ local r="$1" c="$root" p o="$IFS";IFS=/;for p in $r;do [ -n "$p" ]||continue;c="$c/$p";[ ! -L "$c" ]||die "symlinked destination parent: $c";if [ -e "$c" ];then [ -d "$c" ]||die "destination parent is not a directory: $c";else mkdir "$c";fi;done;IFS="$o";}
rel="$ws/delegate/hooks/byproducts.md";[ -z "${DELEGATE_SETUP_TEST_DEST_REL:-}" ]||rel="$DELEGATE_SETUP_TEST_DEST_REL";case "$rel" in "$ws/delegate/hooks/byproducts.md");;*)die "destination escapes delegate ownership: $rel";;esac;check "${rel%/*}";dst="$root/$rel";[ ! -L "$dst" ]||die "destination is a symlink: $dst";[ ! -e "$dst" ]||[ -f "$dst" ]||die "destination is not a regular file: $dst"
if [ "$wo" = no ];then gr="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null||true)";[ -n "$gr" ]&&[ "$(cd "$gr"&&pwd -P)" = "$root" ]||die "standalone setup root must be a Git top level";fi
[ -z "${DELEGATE_SETUP_TEST_AFTER_PREFLIGHT:-}" ]||"$DELEGATE_SETUP_TEST_AFTER_PREFLIGHT" "$root" "$ws"
if [ -f "$dst" ]&&[ ! -L "$dst" ];then printf 'preserved=%s\nwrites=0\n' "$rel";exit 0;fi
ensure "${rel%/*}";check "${rel%/*}";[ ! -L "$dst" ]&&[ ! -e "$dst" ]||die "destination changed after preflight: $dst";cp "$src" "$dst";printf 'created=%s\nwrites=1\n' "$rel"
if [ "$wo" = yes ];then printf 'commit=caller\n';else git -C "$root" add -- "$rel";git -C "$root" commit -m "Delegate: setup" -- "$rel";printf 'committed=%s\n' "$rel";fi
