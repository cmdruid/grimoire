#!/usr/bin/env bash
set -euo pipefail

reason(){ printf 'reason=%s action=%s\n' "$1" "$2" >&2; exit 2; }
usage(){ reason usage check-command; }
valid_slug(){ case "$1" in ''|*[!a-z0-9-]*|-*|*-) return 1;; *) return 0;; esac; }
physical_dir(){ [ -d "$1" ] || return 1; (CDPATH='' cd -P -- "$1" 2>/dev/null && pwd -P); }
lexical_abs(){ local parent base; parent="$(dirname -- "$1")"; base="$(basename -- "$1")"; parent="$(physical_dir "$parent")" || return 1; printf '%s/%s\n' "$parent" "$base"; }
contained(){ case "$1/" in "$2/"*) return 0;; *) return 1;; esac; }

[ "${1:-}" = inspect ] || usage; shift
skill=""; installed=""; source=""; seen_skill=no; seen_installed=no; seen_source=no
while [ "$#" -gt 0 ]; do
  [ "$#" -ge 2 ] || usage
  case "$1" in
    --skill) [ "$seen_skill" = no ] || usage; skill="$2"; seen_skill=yes ;;
    --installed) [ "$seen_installed" = no ] || usage; installed="$2"; seen_installed=yes ;;
    --source) [ "$seen_source" = no ] || usage; source="$2"; seen_source=yes ;;
    *) usage ;;
  esac
  shift 2
done
[ "$seen_skill$seen_installed" = yesyes ] || usage
valid_slug "$skill" || reason invalid-skill use-lowercase-kebab-case
installed_lexical="$(lexical_abs "$installed")" || reason invalid-installed select-readable-installation
installed_real="$(physical_dir "$installed")" || reason invalid-installed select-readable-installation
[ -f "$installed_real/SKILL.md" ] && [ ! -L "$installed_real/SKILL.md" ] || reason invalid-installed select-readable-installation
printf 'skill=%s\ninstalled=%s\ninstalled-real=%s\n' "$skill" "$installed_lexical" "$installed_real"
if [ -z "$source" ]; then
  printf '%s\n' 'source=absent' 'immutable=unknown' 'apply=analysis-only' 'reason=source-required'
  exit 0
fi

source_lexical="$(lexical_abs "$source")" || { printf '%s\n' 'source=invalid' 'immutable=unknown' 'apply=analysis-only' 'reason=invalid-source'; exit 0; }
source_real="$(physical_dir "$source")" || { printf '%s\n' "source=$source_lexical" 'immutable=unknown' 'apply=analysis-only' 'reason=invalid-source'; exit 0; }
printf 'source=%s\nsource-real=%s\n' "$source_lexical" "$source_real"
if [ "$source_lexical" = "$installed_lexical" ]; then direct_installed=yes; else direct_installed=no; fi
printf 'direct-installed=%s\n' "$direct_installed"

manifest="$source_real/SKILL.md"
matching=no
if [ -f "$manifest" ] && [ ! -L "$manifest" ]; then
  declared="$(awk '/^---$/{n++;next}n==1 && /^name:[[:space:]]*/{sub(/^name:[[:space:]]*/,"");gsub(/^"|"$/,"");print;exit}' "$manifest")"
  [ "$declared" = "$skill" ] && matching=yes
fi
printf 'matching-skill=%s\n' "$matching"

git_root="$(git -C "$source_real" rev-parse --show-toplevel 2>/dev/null || true)"
tracked=no
if [ -n "$git_root" ]; then
  git_root="$(physical_dir "$git_root")" || git_root=""
  if [ -n "$git_root" ] && contained "$source_real" "$git_root"; then
    rel="${source_real#"$git_root"/}"
    [ "$source_real" = "$git_root" ] && rel=""
    tracked_path="${rel:+$rel/}SKILL.md"
    git -C "$git_root" ls-files --error-unmatch -- "$tracked_path" >/dev/null 2>&1 && tracked=yes
  fi
fi
printf 'git-root=%s\ntracked=%s\n' "${git_root:-absent}" "$tracked"

immutable=unknown
case "${HOME:-}" in
  /*) user_home="$(physical_dir "$HOME" 2>/dev/null || true)" ;;
  *) user_home="" ;;
esac
if [ -n "${GRIMOIRE_HOME:-}" ] && [[ "$GRIMOIRE_HOME" = /* ]]; then manager="$GRIMOIRE_HOME"; else manager="${user_home:+$user_home/.grimoire}"; fi
if [ -z "$manager" ]; then
  immutable=unknown
elif [ ! -e "$manager" ] && [ ! -L "$manager" ]; then
  immutable=no
elif [ -d "$manager" ]; then
  manager_real="$(physical_dir "$manager" 2>/dev/null || true)"
  store="$manager_real/store/checkouts"
  if [ -z "$manager_real" ] || [ -L "$manager/store" ] || [ -L "$manager/store/checkouts" ]; then
    immutable=unknown
  elif [ ! -e "$store" ]; then
    immutable=no
  elif [ -d "$store" ]; then
    store_real="$(physical_dir "$store" 2>/dev/null || true)"
    if [ -n "$store_real" ] && contained "$source_real" "$store_real"; then immutable=yes; elif [ -n "$store_real" ]; then immutable=no; fi
  fi
fi
printf 'immutable=%s\n' "$immutable"

apply=eligible; why=eligible
[ "$direct_installed" = no ] || { apply=analysis-only; why='installed-target'; }
[ "$matching" = yes ] || { apply=analysis-only; why='skill-mismatch'; }
[ "$tracked" = yes ] || { apply=analysis-only; why='untracked-source'; }
[ "$immutable" = no ] || { apply=analysis-only; why="immutable-$immutable"; }
printf 'apply=%s\nreason=%s\n' "$apply" "$why"
