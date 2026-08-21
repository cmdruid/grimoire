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
# mkdir a missing parent. compile projects a `## Hooks (compiled)` snapshot
# into --handoff (exclusive span; insert after Coordinates if absent).
# compiled-get / compiled-put preserve that span across a template rewrite.
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
(refuse overwrite; no mkdir of a missing parent). compile writes the
exclusive ## Hooks (compiled) span into --handoff. compiled-get prints
that span; compiled-put replaces or inserts it (empty stdin + span
present = no-op).
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

# Exclusive compiled span: from `## Hooks (compiled)` up to but not
# including the next structural H2, or EOF. Prints "start end" (1-based,
# end exclusive). "0 0" if absent.
locate_compiled_span() {
  awk '
    BEGIN { start=0; end=0 }
    $0 ~ /^##[ \t]+Hooks \(compiled\)/ {
      if (start == 0) start = NR
      next
    }
    start > 0 && end == 0 && $0 ~ /^##[ \t]+[^ \t]/ { end = NR }
    END {
      if (start == 0) print "0 0"
      else if (end == 0) print start, NR+1
      else print start, end
    }
  ' "$1"
}

# Line number of the first structural H2 after `## Coordinates` (insert-before).
# NR+1 if Coordinates is the last heading (append).
locate_insert_line() {
  awk '
    $0 ~ /^##[ \t]+Coordinates/ { seen=1; next }
    seen && $0 ~ /^##[ \t]+[^ \t]/ { print NR; found=1; exit }
    END { if (!found) print NR+1 }
  ' "$1"
}

ensure_nl() { # ensure file ends with a newline; do not add a second
  [ -s "$1" ] || { printf '\n' > "$1"; return 0; }
  local hex
  hex=$(tail -c 1 "$1" | od -An -tx1 | tr -d ' \n')
  [ "$hex" = 0a ] && return 0
  printf '\n' >> "$1"
}

# apply_span <dest> <spanfile>
# nonempty span + present → exclusive-replace; nonempty + absent → insert
# after Coordinates; empty span → no-op (do not insert, do not delete).
apply_span() {
  local dest="$1" span="$2" start end ins tmp
  if [ ! -s "$span" ]; then
    return 0
  fi
  ensure_nl "$span"
  tmp=$(mktemp)
  # shellcheck disable=SC2046
  set -- $(locate_compiled_span "$dest")
  start=$1; end=$2
  if [ "$start" -gt 0 ]; then
    head -n $((start - 1)) "$dest" > "$tmp"
    cat "$span" >> "$tmp"
    tail -n +"$end" "$dest" >> "$tmp"
  else
    ins=$(locate_insert_line "$dest")
    if [ "$ins" -le 1 ]; then
      cat "$span" > "$tmp"
      cat "$dest" >> "$tmp"
    else
      head -n $((ins - 1)) "$dest" > "$tmp"
      cat "$span" >> "$tmp"
      tail -n +"$ins" "$dest" >> "$tmp"
    fi
  fi
  mv "$tmp" "$dest"
}

hooks_rel() {
  if [ -n "$root_arg" ]; then
    case "$file" in
      "$root_arg"/*) printf '%s\n' "${file#"$root_arg"/}" ;;
      *) echo none ;;
    esac
  else
    local s
    s=$(printf '%s' "$file" | grep -oE '[^/]+/hooks/workstream\.md$' || true)
    if [ -n "$s" ]; then printf '%s\n' "$s"; else echo none; fi
  fi
}

extract_hook_body() { # extract_hook_body <slug> <parse-out>
  awk -v s="$2" '
    $0 == "--HOOK-BODY-BEGIN-- " s { grab=1; next }
    $0 == "--HOOK-BODY-END-- " s { grab=0; next }
    grab { print }
  ' "$1"
}

do_compile() {
  [ -n "$handoff" ] || { usage; exit 2; }
  [ -f "$handoff" ] || { echo "hooks.sh: --handoff is not a file: $handoff" >&2; exit 2; }

  local parse_out parse_rc=0 known_args=() i
  parse_out=$(mktemp)
  if [ "${#slugs[@]}" -gt 0 ]; then
    for i in "${!slugs[@]}"; do
      known_args+=(--known "${slugs[$i]}=${h2s[$i]}")
    done
  fi
  "$0" parse --file "$file" "${known_args[@]}" >"$parse_out" || parse_rc=$?
  if [ "$parse_rc" -eq 2 ]; then
    rm -f "$parse_out"
    exit 2
  fi

  local h h12 rel key val body span i
  h=$(sed -n 's/^hash=//p' "$parse_out" | head -n 1)
  if [ -z "$h" ] || [ "$h" = none ]; then
    h12=none
  else
    h12=$(printf '%s' "$h" | cut -c1-12)
  fi
  rel=$(hooks_rel)
  span=$(mktemp)
  {
    echo "## Hooks (compiled)"
    echo "hooks-compiled: ${rel} @ ${h12}"
    echo
    if [ "${#slugs[@]}" -gt 0 ]; then
      for i in "${!slugs[@]}"; do
        key="hook_$(fact_key "${slugs[$i]}")"
        val=$(sed -n "s/^${key}=//p" "$parse_out" | head -n 1)
        echo "${slugs[$i]}:"
        if [ "$val" = filled ]; then
          extract_hook_body "$parse_out" "${slugs[$i]}"
        else
          echo "(empty)"
        fi
        echo
      done
    fi
  } > "$span"
  apply_span "$handoff" "$span"
  rm -f "$parse_out" "$span"
}

do_compiled_get() {
  [ -n "$handoff" ] || { usage; exit 2; }
  [ -f "$handoff" ] || exit 0
  local start end
  # shellcheck disable=SC2046
  set -- $(locate_compiled_span "$handoff")
  start=$1; end=$2
  [ "$start" -gt 0 ] || exit 0
  sed -n "${start},$((end - 1))p" "$handoff"
}

do_compiled_put() {
  # COMPILED_PUT_SITE
  COMPILED_PUT=1
  [ -n "$handoff" ] || { usage; exit 2; }
  [ -f "$handoff" ] || { usage; exit 2; }
  local span
  span=$(mktemp)
  cat > "$span"
  if [ "${COMPILED_PUT:-1}" != 1 ]; then
    rm -f "$span"
    exit 0
  fi
  apply_span "$handoff" "$span"
  rm -f "$span"
}

case "$cmd" in
  parse) do_parse ;;
  materialize) do_materialize ;;
  compile) do_compile ;;
  compiled-get) do_compiled_get ;;
  compiled-put) do_compiled_put ;;
  *) usage; exit 2 ;;
esac
