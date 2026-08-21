#!/usr/bin/env bash
# hooks-glue.sh <subcommand> [args...]
#
# Face-local project-hooks glue for /clankshop. Does NOT invoke
# skills/workstream/scripts/hooks.sh (independence floor). Duplicate the
# empty-body strip so a " \n" body is empty (parity with hooks.sh parse).
#
#   presence --clankshop-dir <abs>
#   fill     --file <abs> --skeleton <abs>
#   check    --file <abs> --presence true|false
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: hooks-glue.sh <subcommand> [args...]

  presence --clankshop-dir <abs>
  fill     --file <abs> --skeleton <abs>
  check    --file <abs> --presence true|false
EOF
}

KNOWN_FC="Feature completion"
KNOWN_AE="After eventful ship"

# Same surrounding-whitespace strip as workstream hooks.sh parse (space, tab, newline).
strip_ws() {
  local s="$1"
  local ws=$' \t\n\r'
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

is_abs() {
  case "$1" in /*) return 0 ;; *) return 1 ;; esac
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

is_known() {
  [ "$1" = "$KNOWN_FC" ] || [ "$1" = "$KNOWN_AE" ]
}

clankshop_dir=""
file=""
skeleton=""
presence_flag=""

cmd="${1:-}"
[ -n "$cmd" ] || { usage; exit 2; }
shift

while [ $# -gt 0 ]; do
  case "$1" in
    --clankshop-dir)
      [ $# -ge 2 ] || { usage; exit 2; }
      clankshop_dir="$2"; shift 2
      ;;
    --file)
      [ $# -ge 2 ] || { usage; exit 2; }
      file="$2"; shift 2
      ;;
    --skeleton)
      [ $# -ge 2 ] || { usage; exit 2; }
      skeleton="$2"; shift 2
      ;;
    --presence)
      [ $# -ge 2 ] || { usage; exit 2; }
      presence_flag="$2"; shift 2
      ;;
    *) usage; exit 2 ;;
  esac
done

sibling_skeleton() {
  local parent
  parent=$(cd "$clankshop_dir/.." && pwd)
  printf '%s\n' "$parent/workstream/templates/hooks.md"
}

do_presence() {
  [ -n "$clankshop_dir" ] || { usage; exit 2; }
  local sk
  sk=$(sibling_skeleton)
  if [ -f "$sk" ]; then
    echo "presence=true"
  else
    echo "presence=false"
  fi
}

# Walk --file; for each known H2, print "heading<TAB>empty|filled"
scan_known() {
  local in_fence=0 cur_h2="" cur_body="" line
  flush() {
    [ -z "$cur_h2" ] && return 0
    if is_known "$cur_h2"; then
      if [ -z "$(strip_ws "$cur_body")" ]; then
        printf '%s\tempty\n' "$cur_h2"
      else
        printf '%s\tfilled\n' "$cur_h2"
      fi
    fi
    cur_h2=""
    cur_body=""
  }
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
  done < "$1"
  flush
}

rewrite_empty_known() {
  local dest="$1" tmp in_fence=0 cur_h2="" cur_h2_line="" cur_body="" wrote=0 line
  tmp=$(mktemp)
  flush() {
    [ -z "$cur_h2" ] && return 0
    printf '%s\n' "$cur_h2_line" >> "$tmp"
    if is_known "$cur_h2" && [ -z "$(strip_ws "$cur_body")" ]; then
      printf '%s\n' "/backlog debrief" >> "$tmp"
      wrote=1
    else
      printf '%s' "$cur_body" >> "$tmp"
    fi
    cur_h2=""
    cur_h2_line=""
    cur_body=""
  }
  while IFS= read -r line || [ -n "$line" ]; do
    if is_fence_line "$line"; then
      if [ "$in_fence" -eq 1 ]; then in_fence=0; else in_fence=1; fi
      if [ -n "$cur_h2" ]; then
        cur_body="${cur_body}${line}"$'\n'
      else
        printf '%s\n' "$line" >> "$tmp"
      fi
      continue
    fi
    if [ "$in_fence" -eq 0 ] && is_h2_line "$line"; then
      flush
      cur_h2=$(heading_text "$line")
      cur_h2_line="$line"
      cur_body=""
      continue
    fi
    if [ -n "$cur_h2" ]; then
      cur_body="${cur_body}${line}"$'\n'
    else
      printf '%s\n' "$line" >> "$tmp"
    fi
  done < "$dest"
  flush
  mv "$tmp" "$dest"
  echo "$wrote"
}

do_fill() {
  [ -n "$file" ] && [ -n "$skeleton" ] || { usage; exit 2; }
  is_abs "$file" || { usage; exit 2; }
  if [ ! -f "$skeleton" ]; then
    echo "file=$file"
    echo "status=noop"
    exit 0
  fi
  if [ -e "$file" ]; then
    wrote=$(rewrite_empty_known "$file")
    echo "file=$file"
    if [ "$wrote" = 1 ]; then
      echo "status=filled"
    else
      echo "status=skipped"
    fi
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
  rewrite_empty_known "$file" >/dev/null
  echo "file=$file"
  echo "status=filled"
}

do_check() {
  [ -n "$file" ] || { usage; exit 2; }
  [ "$presence_flag" = true ] || [ "$presence_flag" = false ] || { usage; exit 2; }
  if [ "$presence_flag" != true ]; then
    echo "finding=false"
    exit 0
  fi
  if [ ! -f "$file" ]; then
    echo "finding=true"
    echo "name=/clankshop setup"
    exit 0
  fi
  local h state unfinished=0
  while IFS="$(printf '\t')" read -r h state; do
    [ -n "$h" ] || continue
    if [ "$state" = empty ]; then
      unfinished=1
    fi
  done <<EOF
$(scan_known "$file")
EOF
  if [ "$unfinished" -eq 1 ]; then
    echo "finding=true"
    echo "name=/clankshop setup"
  else
    echo "finding=false"
  fi
}

case "$cmd" in
  presence) do_presence ;;
  fill) do_fill ;;
  check) do_check ;;
  *) usage; exit 2 ;;
esac
