#!/usr/bin/env bash
# hooks.sh <subcommand> [args...]
# Read, seed, and compile Workstream's owner-first one-file-per-seam hooks.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: hooks.sh <subcommand> [args...]

  parse        --dir <abs> --known <slug> [--known ...]
  materialize  --root <abs> --dir <abs> --skeleton-dir <abs> --known <slug> [...]
  compile      --dir <abs> --handoff <abs> [--root <abs>] --known <slug> [...]
  compiled-get --handoff <abs>
  compiled-put --handoff <abs>

parse is read-only and reads only <dir>/<known>.md. materialize safely
creates the owner/kind directory and copies absent skeletons. compile writes
the exclusive ## Hooks (compiled) snapshot into the handoff.
EOF
}

is_abs() { case "$1" in /*) return 0 ;; *) return 1 ;; esac; }
fact_key() { printf '%s' "$1" | tr '-' '_'; }

file_hash() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

strip_ws() {
  local s="$1" first last ws=$' \t\n\r'
  while [ -n "$s" ]; do
    first="${s%"${s#?}"}"
    case "$ws" in *"$first"*) s="${s#?}" ;; *) break ;; esac
  done
  while [ -n "$s" ]; do
    last="${s#"${s%?}"}"
    case "$ws" in *"$last"*) s="${s%?}" ;; *) break ;; esac
  done
  printf '%s' "$s"
}

hook_body() { # first H1 is the optional label, not overlay content
  awk 'NR == 1 && /^#[ \t]+/ { next } { print }' "$1"
}

dir=""
skeleton_dir=""
handoff=""
root_arg=""
slugs=()

cmd="${1:-}"
[ -n "$cmd" ] || { usage; exit 2; }
shift
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)
      [ $# -ge 2 ] || { usage; exit 2; }
      dir="$2"; shift 2
      ;;
    --skeleton-dir)
      [ $# -ge 2 ] || { usage; exit 2; }
      skeleton_dir="$2"; shift 2
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
      slug="$2"; shift 2
      case "$slug" in
        ''|*[!a-z0-9-]*|-*|*-) echo "hooks.sh: invalid seam: $slug" >&2; exit 2 ;;
      esac
      case " ${slugs[*]-} " in *" $slug "*) echo "hooks.sh: duplicate seam: $slug" >&2; exit 2 ;; esac
      slugs+=("$slug")
      ;;
    *) usage; exit 2 ;;
  esac
done

require_dir_arg() {
  [ -n "$dir" ] && is_abs "$dir" || { usage; exit 2; }
  [ "${#slugs[@]}" -gt 0 ] || { usage; exit 2; }
}

population_hash() {
  local list pop slug path
  list=$(mktemp)
  pop=$(mktemp)
  printf '%s\n' "${slugs[@]}" | sort > "$list"
  while IFS= read -r slug; do
    path="$dir/$slug.md"
    printf 'seam=%s\n' "$slug" >> "$pop"
    if [ -f "$path" ] && [ ! -L "$path" ]; then
      printf 'state=present\n' >> "$pop"
      cat "$path" >> "$pop"
      printf '\n--END--\n' >> "$pop"
    else
      printf 'state=missing\n--END--\n' >> "$pop"
    fi
  done < "$list"
  file_hash "$pop"
  rm -f "$list" "$pop"
}

emit_parse() {
  require_dir_arg
  local status=ok slug path body state hash
  if [ -L "$dir" ] || { [ -e "$dir" ] && [ ! -d "$dir" ]; }; then
    status=fail
  elif [ ! -d "$dir" ]; then
    status=missing
  fi
  hash=$(population_hash)
  echo "dir=$dir"
  echo "hash=$hash"
  echo "status=$status"
  for slug in "${slugs[@]}"; do
    path="$dir/$slug.md"
    state=empty
    body=""
    if [ "$status" != fail ] && [ -f "$path" ] && [ ! -L "$path" ]; then
      body=$(strip_ws "$(hook_body "$path")")
      [ -z "$body" ] || state=filled
    elif [ -L "$path" ] || { [ -e "$path" ] && [ ! -f "$path" ]; }; then
      status=fail
      state=invalid
    fi
    echo "hook_$(fact_key "$slug")=$state"
    if [ "$state" = filled ]; then
      echo "--HOOK-BODY-BEGIN-- $slug"
      printf '%s\n' "$body"
      echo "--HOOK-BODY-END-- $slug"
    fi
  done
  [ "$status" != fail ] || exit 2
}

safe_mkdir_tree() { # safe_mkdir_tree <root> <absolute-target>
  local root="$1" target="$2" rel current part old_ifs
  is_abs "$root" && is_abs "$target" || return 1
  [ -d "$root" ] && [ ! -L "$root" ] || return 1
  case "$target" in "$root"/*) rel="${target#"$root"/}" ;; *) return 1 ;; esac
  case "/$rel/" in *'/../'*|*'/./'*|*'//'*) return 1 ;; esac
  current="$root"
  old_ifs=$IFS
  IFS='/'
  set -- $rel
  IFS=$old_ifs
  for part in "$@"; do
    [ -n "$part" ] || return 1
    current="$current/$part"
    if [ -L "$current" ]; then
      return 1
    elif [ -e "$current" ]; then
      [ -d "$current" ] || return 1
    else
      mkdir "$current" || return 1
      [ -d "$current" ] && [ ! -L "$current" ] || return 1
    fi
  done
}

do_materialize() {
  require_dir_arg
  [ -n "$root_arg" ] && is_abs "$root_arg" || { usage; exit 2; }
  [ -n "$skeleton_dir" ] && is_abs "$skeleton_dir" && [ -d "$skeleton_dir" ] \
    || { usage; exit 2; }
  local slug src dst created=0
  for slug in "${slugs[@]}"; do
    src="$skeleton_dir/$slug.md"
    [ -f "$src" ] && [ ! -L "$src" ] || {
      echo "hooks.sh: skeleton is not a regular file: $src" >&2; exit 2; }
  done
  safe_mkdir_tree "$root_arg" "$dir" || {
    echo "hooks.sh: unsafe hook directory: $dir" >&2; exit 2; }
  for slug in "${slugs[@]}"; do
    dst="$dir/$slug.md"
    if [ -L "$dst" ] || { [ -e "$dst" ] && [ ! -f "$dst" ]; }; then
      echo "hooks.sh: unsafe hook entry: $dst" >&2
      exit 2
    fi
  done
  for slug in "${slugs[@]}"; do
    src="$skeleton_dir/$slug.md"
    dst="$dir/$slug.md"
    if [ ! -e "$dst" ]; then
      cp "$src" "$dst"
      created=$((created + 1))
    fi
  done
  echo "dir=$dir"
  echo "created=$created"
  echo "status=ok"
}

locate_compiled_span() {
  awk '
    BEGIN { start=0; end=0 }
    $0 ~ /^##[ \t]+Hooks \(compiled\)/ { if (start == 0) start = NR; next }
    start > 0 && end == 0 && $0 ~ /^##[ \t]+[^ \t]/ { end = NR }
    END {
      if (start == 0) print "0 0"
      else if (end == 0) print start, NR+1
      else print start, end
    }
  ' "$1"
}

locate_insert_line() {
  awk '
    $0 ~ /^##[ \t]+Coordinates/ { seen=1; next }
    seen && $0 ~ /^##[ \t]+[^ \t]/ { print NR; found=1; exit }
    END { if (!found) print NR+1 }
  ' "$1"
}

ensure_nl() {
  [ -s "$1" ] || { printf '\n' > "$1"; return 0; }
  local hex
  hex=$(tail -c 1 "$1" | od -An -tx1 | tr -d ' \n')
  [ "$hex" = 0a ] || printf '\n' >> "$1"
}

apply_span() {
  local dest="$1" span="$2" start end ins tmp
  [ -s "$span" ] || return 0
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
    head -n $((ins - 1)) "$dest" > "$tmp"
    cat "$span" >> "$tmp"
    tail -n +"$ins" "$dest" >> "$tmp"
  fi
  mv "$tmp" "$dest"
}

extract_hook_body() {
  awk -v s="$2" '
    $0 == "--HOOK-BODY-BEGIN-- " s { grab=1; next }
    $0 == "--HOOK-BODY-END-- " s { grab=0; next }
    grab { print }
  ' "$1"
}

do_compile() {
  require_dir_arg
  [ -n "$handoff" ] && [ -f "$handoff" ] || {
    echo "hooks.sh: --handoff is not a file: $handoff" >&2; exit 2; }
  local parsed span hash h12 rel slug key state self
  parsed=$(mktemp)
  span=$(mktemp)
  self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  args=()
  for slug in "${slugs[@]}"; do args+=(--known "$slug"); done
  "$self" parse --dir "$dir" "${args[@]}" > "$parsed"
  hash=$(sed -n 's/^hash=//p' "$parsed" | head -n 1)
  h12=$(printf '%s' "$hash" | cut -c1-12)
  if [ -n "$root_arg" ]; then
    case "$dir" in "$root_arg"/*) rel="${dir#"$root_arg"/}" ;; *) rel=none ;; esac
  else
    rel="$dir"
  fi
  {
    echo "## Hooks (compiled)"
    echo "hooks-compiled: $rel @ $h12"
    echo
    for slug in "${slugs[@]}"; do
      key="hook_$(fact_key "$slug")"
      state=$(sed -n "s/^$key=//p" "$parsed" | head -n 1)
      echo "$slug:"
      if [ "$state" = filled ]; then
        extract_hook_body "$parsed" "$slug"
      else
        echo "(empty)"
      fi
      echo
    done
  } > "$span"
  apply_span "$handoff" "$span"
  rm -f "$parsed" "$span"
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
  [ -n "$handoff" ] && [ -f "$handoff" ] || { usage; exit 2; }
  local span
  span=$(mktemp)
  cat > "$span"
  apply_span "$handoff" "$span"
  rm -f "$span"
}

case "$cmd" in
  parse) emit_parse ;;
  materialize) do_materialize ;;
  compile) do_compile ;;
  compiled-get) do_compiled_get ;;
  compiled-put) do_compiled_put ;;
  *) usage; exit 2 ;;
esac
