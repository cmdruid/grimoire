#!/usr/bin/env bash
# flows-index.sh list|search --root <abs> --workspace <rel> [--query <text>]
#
# Facts over regular *.md in one directory of <root>/<workspace>/flows/.
# No LLM. Missing dir → flows_dir=missing matches=0 exit 0.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: flows-index.sh list|search --root <abs> --workspace <rel> [--query <text>]
EOF
  exit 2
}

is_abs() {
  case "$1" in /*) return 0 ;; *) return 1 ;; esac
}

# Parse title= / use_when= / fm= from a flow file. Missing keys print empty.
parse_crawl() {
  awk '
    NR == 1 {
      if ($0 != "---") { print "fm=missing"; print "title="; print "use_when="; exit }
      infm = 1
      next
    }
    infm && $0 == "---" {
      print "fm=ok"
      if (!tset) print "title="
      if (!uset) print "use_when="
      closed = 1
      exit
    }
    infm && match($0, /^title:[ \t]*/) {
      val = substr($0, RLENGTH + 1)
      if (val ~ /^".*"$/) {
        val = substr(val, 2, length(val) - 2)
        gsub(/\\\\/, "\001", val)
        gsub(/\\"/, "\"", val)
        gsub(/\001/, "\\", val)
      }
      print "title=" val
      tset = 1
      next
    }
    infm && match($0, /^use-when:[ \t]*/) {
      val = substr($0, RLENGTH + 1)
      if (val ~ /^".*"$/) {
        val = substr(val, 2, length(val) - 2)
        gsub(/\\\\/, "\001", val)
        gsub(/\\"/, "\"", val)
        gsub(/\001/, "\\", val)
      }
      print "use_when=" val
      uset = 1
      next
    }
    END {
      if (infm && !closed) {
        print "fm=malformed"
        if (!tset) print "title="
        if (!uset) print "use_when="
      }
    }
  ' "$1"
}

first_h1() {
  awk '/^# / { print substr($0, 3); exit }' "$1"
}

lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

cmd="${1:-}"
[ -n "$cmd" ] || usage
shift

root=""
ws=""
query=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root)      [ $# -ge 2 ] || usage; root="$2";   shift 2 ;;
    --workspace) [ $# -ge 2 ] || usage; ws="$2";     shift 2 ;;
    --query)     [ $# -ge 2 ] || usage; query="$2";  shift 2 ;;
    *) usage ;;
  esac
done

[ -n "$root" ] && [ -n "$ws" ] || usage
is_abs "$root" || usage
case "$ws" in
  .|"") echo "refusing: --workspace '.' " >&2; exit 2 ;;
  /*)   echo "refusing: --workspace must be repo-relative" >&2; exit 2 ;;
esac

case "$cmd" in
  list|search) ;;
  *) usage ;;
esac

flows_dir="$root/$ws/flows"

echo "workspace=$ws"

if [ ! -d "$flows_dir" ]; then
  echo "flows_dir=missing"
  echo "matches=0"
  echo "stems="
  echo "paths="
  echo "titles="
  exit 0
fi

echo "flows_dir=$flows_dir"

# Collect regular *.md, one level, skip dotfiles, sorted by stem.
files=""
# shellcheck disable=SC2044
for f in $(find "$flows_dir" -maxdepth 1 -type f -name '*.md' ! -name '.*' | sort); do
  files="$files
$f"
done

stems=""
paths=""
titles=""
n=0

IFS='
'
for f in $files; do
  [ -n "$f" ] || continue
  base=$(basename "$f")
  stem=${base%.md}

  facts=$(parse_crawl "$f")
  title=$(printf '%s\n' "$facts" | sed -n 's/^title=//p' | head -n 1)
  use_when=$(printf '%s\n' "$facts" | sed -n 's/^use_when=//p' | head -n 1)
  h1=$(first_h1 "$f")

  if [ "$cmd" = search ]; then
    if [ -z "$query" ]; then
      continue
    fi
    haystack=$(lower "$stem $title $use_when $h1")
    ok=1
    # shellcheck disable=SC2086
    set -- $query
    for tok in "$@"; do
      ltok=$(lower "$tok")
      case "$haystack" in
        *"$ltok"*) ;;
        *) ok=0; break ;;
      esac
    done
    [ "$ok" = 1 ] || continue
  fi

  if [ "$n" -eq 0 ]; then
    stems="$stem"
    paths="$f"
    titles="$title"
  else
    stems="$stems,$stem"
    paths="$paths,$f"
    titles="$titles,$title"
  fi
  n=$((n + 1))
done
unset IFS

echo "matches=$n"
echo "stems=$stems"
echo "paths=$paths"
echo "titles=$titles"
exit 0
