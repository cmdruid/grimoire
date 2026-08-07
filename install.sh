#!/usr/bin/env bash
# install.sh -- wire grimoire skills into an agent harness via symlinks.
#
# Usage:
#   ./install.sh <skill> [<skill>...]      install named skills
#   ./install.sh --pack <name>             install every skill in packs/<name>.md
#   ./install.sh --remove <skill>...       remove installed symlinks (only ones owned by this clone)
#   ./install.sh --list                    show skills, packs, and install state
#   ./install.sh --target <dir> ...        override target dir (default: ~/.claude/skills)
#
# Symlinks only: the clone stays canonical, edits here are live immediately.
# Codex (and other dir-scanning harnesses): point the harness at <clone>/skills
# directly (e.g. ln -s <clone>/skills ~/.agents/skills) -- no per-skill wiring.
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
target="$HOME/.claude/skills"
mode="install"
names=()
pack_name=""
pack_manifest=""

while [ $# -gt 0 ]; do
  case "$1" in
    --pack)
      [ $# -ge 2 ] || { echo "error: --pack needs a name" >&2; exit 2; }
      manifest="$root/packs/$2.md"
      [ -f "$manifest" ] || { echo "error: no pack manifest at packs/$2.md" >&2; exit 2; }
      pack_skills="$(sed -n 's/^skills:[[:space:]]*//p' "$manifest" | head -1)"
      [ -n "$pack_skills" ] || { echo "error: packs/$2.md has no skills: line" >&2; exit 2; }
      for s in $pack_skills; do names+=("$s"); done
      pack_name="$2"
      pack_manifest="$manifest"
      shift ;;
    --remove) mode="remove" ;;
    --list)   mode="list" ;;
    --target)
      [ $# -ge 2 ] || { echo "error: --target needs a directory" >&2; exit 2; }
      target="$2"; shift ;;
    -h|--help) sed -n 's/^# \{0,1\}//p;13q' "$0"; exit 0 ;;
    -*) echo "error: unknown flag: $1 (try --help)" >&2; exit 2 ;;
    *) names+=("$1") ;;
  esac
  shift
done

if [ "$mode" = "list" ]; then
  echo "skills ($root/skills), target: $target"
  for sk in "$root"/skills/*/; do
    name="$(basename "$sk")"
    state="-"
    [ -L "$target/$name" ] && state="installed -> $(readlink "$target/$name")"
    printf '  %-14s %s\n' "$name" "$state"
  done
  echo "packs:"
  for p in "$root"/packs/*.md; do
    [ -e "$p" ] || continue
    printf '  %-14s %s\n' "$(basename "${p%.md}")" "$(sed -n 's/^skills:[[:space:]]*//p' "$p" | head -1)"
  done
  exit 0
fi

[ ${#names[@]} -gt 0 ] || { echo "error: no skills named (try --list)" >&2; exit 2; }

# ---- transactional pack install (the lock preflights; never a partial pack) ----
# Preflight the whole member set against the lock (packs/<name>.md frontmatter): every
# member present on disk, no destination collision, helper version checks (a bare-listed
# helper is a presence check; a range-declared helper `name>=N` must carry frontmatter
# `version: <int>` within range -- missing/malformed aborts, never a silent pass). Any
# failure aborts with the fact before a single link is made; a mid-flight link error
# rolls back what this run created. Bare single-skill install (below) is untouched.
if [ "$mode" = "install" ] && [ -n "$pack_name" ]; then
  helpers_line="$(sed -n 's/^helpers:[[:space:]]*//p' "$pack_manifest" | head -1)"
  fail=0
  for name in "${names[@]}"; do
    src="$root/skills/$name"
    link="$target/$name"
    if [ ! -f "$src/SKILL.md" ]; then
      echo "preflight: missing-member $name (no skills/$name/SKILL.md)" >&2; fail=1
    fi
    if [ -L "$link" ]; then
      if [ "$(readlink "$link")" != "$src" ]; then
        echo "preflight: collision $name ($link -> $(readlink "$link"))" >&2; fail=1
      fi
    elif [ -e "$link" ]; then
      echo "preflight: collision $name ($link exists and is not a symlink)" >&2; fail=1
    fi
  done
  for h in $helpers_line; do
    case "$h" in
      *'>='*)
        hn="${h%%>=*}"; hmin="${h##*>=}"
        hv="$(awk '
          NR == 1 && $0 != "---" { exit }
          NR > 1 && /^---$/ { exit }
          sub(/^version:[[:space:]]*/, "") { print; exit }
        ' "$root/skills/$hn/SKILL.md" 2>/dev/null || true)"
        if ! printf '%s' "$hv" | grep -qE '^[0-9]+$'; then
          echo "preflight: helper-version $hn requires >=$hmin but version: key is missing or malformed" >&2; fail=1
        elif [ "$hv" -lt "$hmin" ]; then
          echo "preflight: helper-version $hn version $hv < required $hmin" >&2; fail=1
        fi ;;
      *)
        echo "preflight: helper $h bare-listed (presence check only)" ;;
    esac
  done
  if [ "$fail" != 0 ]; then
    echo "abort: pack $pack_name preflight failed -- no partial install" >&2
    exit 1
  fi
  mkdir -p "$target"
  created=()
  for name in "${names[@]}"; do
    src="$root/skills/$name"
    link="$target/$name"
    if [ -L "$link" ]; then echo "ok       $name (already installed)"; continue; fi
    if ln -s "$src" "$link" 2>/dev/null; then
      created+=("$link")
      echo "installed $name -> $link"
    else
      echo "error: link failed for $name -- rolling back this run's links" >&2
      if [ ${#created[@]} -gt 0 ]; then
        for c in "${created[@]}"; do rm -f "$c"; done
      fi
      exit 1
    fi
  done
  echo "pack $pack_name: ${#names[@]} members installed or already present"
  exit 0
fi

mkdir -p "$target"
for name in "${names[@]}"; do
  src="$root/skills/$name"
  link="$target/$name"
  if [ "$mode" = "remove" ]; then
    if [ -L "$link" ]; then
      case "$(readlink "$link")" in
        "$root"/*) rm "$link"; echo "removed  $name" ;;
        *) echo "skip     $name: $link points outside this clone" ;;
      esac
    else
      echo "skip     $name: no symlink at $link"
    fi
    continue
  fi
  [ -f "$src/SKILL.md" ] || { echo "error: no skill at skills/$name" >&2; exit 2; }
  if [ -L "$link" ]; then
    if [ "$(readlink "$link")" = "$src" ]; then echo "ok       $name (already installed)"; continue; fi
    echo "skip     $name: $link already points at $(readlink "$link") -- remove it first" >&2
    continue
  elif [ -e "$link" ]; then
    echo "skip     $name: $link exists and is not a symlink -- move it aside first" >&2
    continue
  fi
  ln -s "$src" "$link"
  echo "installed $name -> $link"
done
