#!/usr/bin/env bash
# hooks.sh <subcommand> [args...]
#
# Project-hooks parser and materializer for /workstream.
# Resolve from this skill's own base directory (same as workstream-git.sh).
#
# Subcommands:
#   parse        --file <abs> --known <slug>=<H2> [--known ...]
#   materialize  --file <abs> --skeleton <abs>
#   compile      --file <abs> --handoff <abs> [--root <abs>] --known <slug>=<H2> [...]
#   compiled-get --handoff <abs>
#   compiled-put --handoff <abs>
#
# parse is read-only and never writes --file. materialize is a seed.sh-class
# writer: copy --skeleton onto --file if absent; refuse overwrite; do not
# mkdir a missing parent. compile / compiled-get / compiled-put stub usage
# and exit 2 until the compile slice.
#
# --file for materialize (and compile) must be an absolute path (starts with
# /). Relative → usage, exit 2. Never reads cwd for the destination.
#
# Fact keys: --known slugs may contain hyphens (feature-completion); printed
# hook_<key> transliterates '-' → '_' so the fact is hook_feature_completion=.
#
# Body delimiter (parse, filled hooks only; <slug> is the --known slug with
# hyphens intact):
#   --HOOK-BODY-BEGIN-- <slug>
#   <body bytes, post-strip>
#   --HOOK-BODY-END-- <slug>
#
# Hash: shasum -a 256 if present, else sha256sum; print hex (first field).
# Missing file → hash=none.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: hooks.sh <subcommand> [args...]

  parse        --file <abs> --known <slug>=<H2> [--known ...]
  materialize  --file <abs> --skeleton <abs>
  compile      --file <abs> --handoff <abs> [--root <abs>] --known <slug>=<H2> [...]
  compiled-get --handoff <abs>
  compiled-put --handoff <abs>

parse is read-only. materialize copies --skeleton onto --file if absent
(refuse overwrite; no mkdir of a missing parent). compile / compiled-get /
compiled-put are not implemented in this slice (exit 2).
EOF
}

fact_key() { printf '%s' "$1" | tr '-' '_'; }

file_hash() {
  if [ ! -f "$1" ]; then
    echo none
    return 0
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

is_abs() {
  case "$1" in /*) return 0 ;; *) return 1 ;; esac
}

# STRIP_WS_SITE — surrounding space, tab, newline. Identity when STRIP_WS!=1.
STRIP_WS=1
strip_ws() {
  local s="$1"
  local ws=$' \t\n\r'
  if [ "${STRIP_WS:-1}" != 1 ]; then
    printf '%s' "$s"
    return 0
  fi
  while [ -n "$s" ]; do
    local first="${s%"${s#?}"}"
    case "$ws" in
      *"$first"*) s="${s#?}" ;;
      *) break ;;
    esac
  done
  while [ -n "$s" ]; do
    local last="${s#"${s%?}"}"
    case "$ws" in
      *"$last"*) s="${s%?}" ;;
      *) break ;;
    esac
  done
  printf '%s' "$s"
}

is_fence_line() {
  case "$1" in
    '```') return 0 ;;
  esac
  printf '%s' "$1" | grep -qE '^```[A-Za-z0-9_+-]+$'
}

is_h2_line() {
  printf '%s' "$1" | grep -qE '^##[ \t]+\S'
}

heading_text() {
  printf '%s' "$1" | sed -E 's/^##[ \t]+//;s/[ \t]+$//'
}

slugs=()
h2s=()
file=""
skeleton=""
handoff=""
root_arg=""

cmd="${1:-}"
[ -n "$cmd" ] || { usage; exit 2; }
shift

while [ $# -gt 0 ]; do
  case "$1" in
    --file)
      [ $# -ge 2 ] || { usage; exit 2; }
      file="$2"; shift 2
      ;;
    --skeleton)
      [ $# -ge 2 ] || { usage; exit 2; }
      skeleton="$2"; shift 2
      ;;
    --handoff)
      [ $# -ge 2 ] || { usage; exit 2; }
      handoff="$2"; shift 2
      ;;
    --root)
      [ $# -ge 2 ] || { usage; exit 2; }
      root_arg="$2"; shift 2
      ;;
    --known)
      [ $# -ge 2 ] || { usage; exit 2; }
      pair="$2"; shift 2
      # H2 text may contain spaces; join until the next --flag so
      # `--known feature-completion=Feature completion` is one pair.
      while [ $# -gt 0 ]; do
        case "$1" in
          --*) break ;;
          *) pair="$pair $1"; shift ;;
        esac
      done
      case "$pair" in
        *=*) ;;
        *) usage; exit 2 ;;
      esac
      slugs+=("${pair%%=*}")
      h2s+=("${pair#*=}")
      ;;
    *) usage; exit 2 ;;
  esac
done

known_index() { # known_index <heading-text> → prints 0-based index or empty
  local want="$1" i
  [ "${#h2s[@]}" -gt 0 ] || return 1
  for i in "${!h2s[@]}"; do
    if [ "${h2s[$i]}" = "$want" ]; then
      printf '%s' "$i"
      return 0
    fi
  done
  return 1
}

emit_missing() {
  echo "file=$file"
  echo "hash=none"
  echo "status=missing"
  local i
  if [ "${#slugs[@]}" -gt 0 ]; then
    for i in "${!slugs[@]}"; do
      echo "hook_$(fact_key "${slugs[$i]}")=empty"
    done
  fi
  echo "unknown="
}

do_parse() {
  # MISSING_FILE_BRANCH
  HANDLE_MISSING=1
  if [ "${HANDLE_MISSING:-1}" = 1 ] && { [ -z "$file" ] || [ ! -f "$file" ]; }; then
    emit_missing
    exit 0
  fi

  local n=0 cur_h2="" cur_body="" in_fence=0
  # Global: EXIT/set -u cannot see a `local` pdir from the trap.
  _hooks_parse_dir=$(mktemp -d)
  pdir=$_hooks_parse_dir

  flush() {
    [ -z "$cur_h2" ] && return 0
    n=$((n + 1))
    printf '%s' "$cur_h2" > "$pdir/h2.$n"
    printf '%s' "$cur_body" > "$pdir/body.$n"
    cur_h2=""
    cur_body=""
  }

  local line
  while IFS= read -r line || [ -n "$line" ]; do
    if is_fence_line "$line"; then
      if [ "$in_fence" -eq 1 ]; then in_fence=0; else in_fence=1; fi
      if [ -n "$cur_h2" ]; then
        cur_body="${cur_body}${line}"$'\n'
      fi
      continue
    fi
    if [ "$in_fence" -eq 0 ] && is_h2_line "$line"; then
      flush
      cur_h2=$(heading_text "$line")
      cur_body=""
      continue
    fi
    if [ -n "$cur_h2" ]; then
      cur_body="${cur_body}${line}"$'\n'
    fi
  done < "$file"
  flush

  local status="ok" dup=0 seen=$'\n' unknown="" i h body idx filled
  # bodies_by_known_index files
  for i in $(seq 1 "$n"); do
    h=$(cat "$pdir/h2.$i")
    case "$seen" in
      *$'\n'"$h"$'\n'*) dup=1 ;;
    esac
    seen="${seen}${h}"$'\n'
    if idx=$(known_index "$h"); then
      if [ ! -f "$pdir/known.$idx" ]; then
        cp "$pdir/body.$i" "$pdir/known.$idx"
      fi
    else
      if [ -z "$unknown" ]; then
        unknown="$h"
      else
        case ",$unknown," in
          *",$h,"*) ;;
          *) unknown="${unknown},${h}" ;;
        esac
      fi
    fi
  done
  [ "$dup" -eq 1 ] && status="fail"

  echo "file=$file"
  echo "hash=$(file_hash "$file")"
  echo "status=$status"
  if [ "${#slugs[@]}" -gt 0 ]; then
    for i in "${!slugs[@]}"; do
      filled=empty
      if [ -f "$pdir/known.$i" ]; then
        body=$(strip_ws "$(cat "$pdir/known.$i")")
        if [ -n "$body" ]; then
          filled=filled
        fi
        printf '%s' "$body" > "$pdir/stripped.$i"
      fi
      echo "hook_$(fact_key "${slugs[$i]}")=$filled"
    done
  fi
  echo "unknown=$unknown"
  if [ "${#slugs[@]}" -gt 0 ]; then
    for i in "${!slugs[@]}"; do
      if [ -f "$pdir/stripped.$i" ] && [ -s "$pdir/stripped.$i" ]; then
        echo "--HOOK-BODY-BEGIN-- ${slugs[$i]}"
        cat "$pdir/stripped.$i"
        echo
        echo "--HOOK-BODY-END-- ${slugs[$i]}"
      fi
    done
  fi

  rm -rf "$pdir"
  _hooks_parse_dir=""
  if [ "$status" = fail ]; then
    exit 2
  fi
}

do_materialize() {
  [ -n "$file" ] && [ -n "$skeleton" ] || { usage; exit 2; }
  is_abs "$file" || { usage; exit 2; }
  [ -f "$skeleton" ] || { echo "hooks.sh: skeleton is not a file: $skeleton" >&2; exit 2; }

  if [ -e "$file" ]; then
    echo "file=$file"
    echo "status=present"
    exit 0
  fi
  local parent
  parent=$(dirname "$file")
  if [ ! -d "$parent" ]; then
    echo "file=$file"
    echo "status=no-parent"
    exit 0
  fi
  cp "$skeleton" "$file"
  echo "file=$file"
  echo "status=created"
}

case "$cmd" in
  parse) do_parse ;;
  materialize) do_materialize ;;
  compile|compiled-get|compiled-put) usage; exit 2 ;;
  *) usage; exit 2 ;;
esac
