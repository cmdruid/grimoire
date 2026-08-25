#!/usr/bin/env bash
# flows-upkeep.sh check|apply --root <abs> --workspace <rel>
#
# Fill missing title / use-when on <workspace>/*/flows/*.md.
# Missing workspace → no-op 0. Does not create or delete files.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: flows-upkeep.sh check|apply --root <abs> --workspace <rel>
EOF
  exit 2
}

is_abs() {
  case "$1" in /*) return 0 ;; *) return 1 ;; esac
}

yaml_quote() {
  YAML_VAL="$1" awk 'BEGIN {
    s = ENVIRON["YAML_VAL"]
    gsub(/\\/, "\\\\", s)
    gsub(/"/, "\\\"", s)
    printf "\"%s\"", s
  }'
}

NL=$(printf '\n/'); NL="${NL%/}"

first_h1() {
  awk '/^# / { print substr($0, 3); exit }' "$1"
}

# Prints: fm= title_set=0|1 use_when_set=0|1 title= use_when=
parse_fm() {
  awk '
    NR == 1 {
      if ($0 != "---") {
        print "fm=missing"
        print "title_set=0"
        print "use_when_set=0"
        print "title="
        print "use_when="
        exit
      }
      infm = 1
      next
    }
    infm && $0 == "---" {
      print "fm=ok"
      if (!tset) { print "title_set=0"; print "title=" }
      if (!uset) { print "use_when_set=0"; print "use_when=" }
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
      print "title_set=1"
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
      print "use_when_set=1"
      print "use_when=" val
      uset = 1
      next
    }
    END {
      if (infm && !closed) {
        print "fm=malformed"
        if (!tset) { print "title_set=0"; print "title=" }
        if (!uset) { print "use_when_set=0"; print "use_when=" }
      }
    }
  ' "$1"
}

fact_from() {
  printf '%s\n' "$2" | sed -n "s/^$1=//p" | head -n 1
}

insert_leading_fm() {
  local file="$1" qtitle="$2" quse="$3"
  local tmp
  tmp=$(mktemp)
  {
    printf '%s\n' '---'
    printf 'title: %s\n' "$qtitle"
    printf 'use-when: %s\n' "$quse"
    printf '%s\n' '---'
    cat "$file"
  } > "$tmp"
  mv "$tmp" "$file"
}

add_missing_key() {
  local file="$1" key="$2" qval="$3"
  local tmp
  tmp=$(mktemp)
  KEY="$key" VAL="$qval" awk '
    BEGIN { infm = 0; added = 0 }
    NR == 1 && $0 == "---" { infm = 1; print; next }
    infm && $0 == "---" && !added {
      print ENVIRON["KEY"] ": " ENVIRON["VAL"]
      print
      infm = 0
      added = 1
      next
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

cmd="${1:-}"
[ -n "$cmd" ] || usage
shift

root=""
ws=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root)      [ $# -ge 2 ] || usage; root="$2"; shift 2 ;;
    --workspace) [ $# -ge 2 ] || usage; ws="$2";   shift 2 ;;
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
  check|apply) ;;
  *) usage ;;
esac

workspace_dir="$root/$ws"

echo "workspace=$ws"

if [ ! -d "$workspace_dir" ]; then
  echo "flows_dir=missing"
  echo "need="
  echo "malformed="
  exit 0
fi

echo "flows_dir=$workspace_dir/*/flows"

need=""
malformed=""

# shellcheck disable=SC2044
for f in $(find "$workspace_dir" -mindepth 3 -maxdepth 3 -type f -name '*.md' ! -name '.*' -path '*/flows/*.md' | sort); do
  [ -n "$f" ] || continue
  rel=${f#"$workspace_dir"/}
  owner=${rel%%/*}
  printf '%s' "$owner" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' || continue
  case "$owner" in doctrine|hooks|scripts|templates|trackers|flows) continue ;; esac
  base=$(basename "$f")
  stem=${base%.md}
  facts=$(parse_fm "$f")
  fm=$(fact_from fm "$facts")
  title_set=$(fact_from title_set "$facts")
  use_when_set=$(fact_from use_when_set "$facts")
  h1=$(first_h1 "$f")

  title_state=missing
  use_state=missing
  [ "$title_set" = 1 ] && title_state=ok
  [ "$use_when_set" = 1 ] && use_state=ok

  echo "file.$owner.$stem.fm=$fm"
  echo "file.$owner.$stem.title=$title_state"
  echo "file.$owner.$stem.use_when=$use_state"

  if [ "$fm" = malformed ]; then
    if [ -z "$malformed" ]; then malformed="$owner/$stem"; else malformed="$malformed,$owner/$stem"; fi
    continue
  fi

  fully_ok=0
  if [ "$fm" = ok ] && [ "$title_state" = ok ] && [ "$use_state" = ok ]; then
    fully_ok=1
  fi
  if [ "$fully_ok" -eq 1 ]; then
    continue
  fi

  if [ -z "$need" ]; then need="$owner/$stem"; else need="$need,$owner/$stem"; fi

  [ "$cmd" = apply ] || continue

  if [ "$fm" = missing ]; then
    case "$h1" in
      *"$NL"*|*"---"*) echo "skip=$stem"; continue ;;
    esac
    if [ -n "$h1" ]; then
      tdef=$h1
    else
      tdef=$stem
    fi
    insert_leading_fm "$f" "$(yaml_quote "$tdef")" "$(yaml_quote "$stem")"
    continue
  fi

  # fm=ok with a missing key — add only that key.
  if [ "$title_state" = missing ]; then
    case "$h1" in
      *"$NL"*|*"---"*) echo "skip=$stem"; continue ;;
    esac
    if [ -n "$h1" ]; then
      tdef=$h1
    else
      tdef=$stem
    fi
    add_missing_key "$f" "title" "$(yaml_quote "$tdef")"
  fi
  if [ "$use_state" = missing ]; then
    add_missing_key "$f" "use-when" "$(yaml_quote "$stem")"
  fi
done

echo "need=$need"
echo "malformed=$malformed"

if [ "$cmd" = check ]; then
  if [ -z "$need" ] && [ -z "$malformed" ]; then
    exit 0
  fi
  exit 1
fi
exit 0
