#!/usr/bin/env bash
set -u

reason(){ printf 'reason=%s\n' "$1" >&2; exit 2; }
physical_dir(){ [ -d "$1" ] || return 1; (CDPATH='' cd -P -- "$1" 2>/dev/null && pwd -P); }
contained(){ case "$1/" in "$2/"*) return 0;; *) return 1;; esac; }
valid_slug(){ case "$1" in ''|*[!a-z0-9-]*|-*|*-) return 1;; *) return 0;; esac; }

[ "$#" -eq 2 ] && [ "$1" = inspect ] || reason usage
source_arg="$2"
case "$source_arg" in *'
'*) reason invalid-source;; esac

git_top="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
case "$source_arg" in /*) candidate="$source_arg";; *) candidate="$PWD/$source_arg";; esac

if [ -e "$candidate" ] || [ -L "$candidate" ]; then
  if [ -d "$candidate" ]; then
    package="$(physical_dir "$candidate")" || reason invalid-source
  elif [ "$(basename -- "$candidate")" = SKILL.md ] && [ -f "$candidate" ] && [ ! -L "$candidate" ]; then
    package="$(physical_dir "$(dirname -- "$candidate")")" || reason invalid-source
  else
    reason invalid-source
  fi
elif valid_slug "$source_arg" && [ -n "$git_top" ]; then
  package="$(physical_dir "$git_top/skills/$source_arg")" || reason invalid-source
else
  reason invalid-source
fi

if valid_slug "$source_arg" && [ -n "$git_top" ]; then
  slug_package="$(physical_dir "$git_top/skills/$source_arg" 2>/dev/null || true)"
  [ -z "$slug_package" ] || [ "$slug_package" = "$package" ] || reason ambiguous-source
fi

manifest="$package/SKILL.md"
[ -f "$manifest" ] && [ ! -L "$manifest" ] || reason invalid-manifest
declared_name="$(awk '
  /^---[[:space:]]*$/ { block++; next }
  block == 1 && /^name:[[:space:]]*/ {
    sub(/^name:[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; exit
  }
' "$manifest")"
[ -n "$declared_name" ] || reason invalid-manifest

name_matches=no
if valid_slug "$declared_name" && [ "$declared_name" = "$(basename -- "$package")" ]; then
  name_matches=yes
fi

git_root="$(git -C "$package" rev-parse --show-toplevel 2>/dev/null || true)"
tracked=no
if [ -n "$git_root" ]; then
  git_root="$(physical_dir "$git_root")" || git_root=""
fi
if [ -n "$git_root" ] && contained "$package" "$git_root"; then
  rel="${package#"$git_root"/}"
  [ "$package" = "$git_root" ] && rel=""
  tracked_path="${rel:+$rel/}SKILL.md"
  git -C "$git_root" ls-files --error-unmatch -- "$tracked_path" >/dev/null 2>&1 && tracked=yes
else
  git_root=absent
fi

immutable=unknown
manager=""
if [ -n "${GRIMOIRE_HOME:-}" ] && [ "${GRIMOIRE_HOME#/}" != "$GRIMOIRE_HOME" ]; then
  manager="$GRIMOIRE_HOME"
elif [ -n "${HOME:-}" ] && [ "${HOME#/}" != "$HOME" ]; then
  manager="$HOME/.grimoire"
fi
if [ -n "$manager" ]; then
  if [ ! -e "$manager" ] && [ ! -L "$manager" ]; then
    immutable=no
  elif [ -d "$manager" ]; then
    manager_real="$(physical_dir "$manager" 2>/dev/null || true)"
    if [ -z "$manager_real" ] || [ -L "$manager/store" ] || [ -L "$manager/store/checkouts" ]; then
      immutable=unknown
    elif [ ! -e "$manager_real/store/checkouts" ]; then
      immutable=no
    elif [ -d "$manager_real/store/checkouts" ]; then
      store_real="$(physical_dir "$manager_real/store/checkouts" 2>/dev/null || true)"
      if [ -z "$store_real" ]; then
        immutable=unknown
      elif contained "$package" "$store_real"; then
        immutable=yes
      else
        immutable=no
      fi
    fi
  fi
fi

custodied=no
if [ "$name_matches" = yes ] && [ "$tracked" = yes ] && [ "$immutable" = no ] && [ "$git_root" != absent ]; then
  custodied=yes
fi

printf 'physical-package-root=%s\n' "$package"
printf 'declared-name=%s\n' "$declared_name"
printf 'name-matches-directory=%s\n' "$name_matches"
printf 'git-root=%s\n' "$git_root"
printf 'tracked=%s\n' "$tracked"
printf 'immutable=%s\n' "$immutable"
printf 'custodied=%s\n' "$custodied"
