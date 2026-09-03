#!/usr/bin/env bash
# Validate and read Foreman's optional user-global operation templates.
set -eu

usage() {
  cat >&2 <<'EOF'
usage:
  operation-template-index.sh catalog
  operation-template-index.sh read --stem <stem>
EOF
  exit 2
}

mode="${1:-}"
[ -n "$mode" ] || usage
shift
stem=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --stem) [ "$#" -ge 2 ] || usage; stem="$2"; shift 2 ;;
    *) usage ;;
  esac
done
case "$mode" in
  catalog) [ -z "$stem" ] || usage ;;
  read) [ -n "$stem" ] || usage ;;
  *) usage ;;
esac

valid_stem() {
  printf '%s\n' "$1" | grep -Eq '^[a-z0-9][a-z0-9-]*$'
}

encode_scalar() {
  LC_ALL=C awk '
    BEGIN { ORS="" }
    {
      if (NR > 1) printf "%%0A"
      gsub(/%/, "%25")
      gsub(/\t/, "%09")
      gsub(/\r/, "%0D")
      printf "%s", $0
    }
  '
}

resolve_root() {
  ROOT_STATE=unsafe
  ROOT_REASON=bad-home
  [ -n "${HOME:-}" ] && [ -d "$HOME" ] || return 0
  home="$(CDPATH='' cd -P "$HOME" 2>/dev/null && pwd)" || return 0
  root="$home"
  for component in .agents skilldata foreman templates operations; do
    root="$root/$component"
    if [ -L "$root" ]; then ROOT_REASON=symlink-root; return 0; fi
    if [ -e "$root" ]; then
      [ -d "$root" ] || { ROOT_REASON=non-directory-root; return 0; }
    else
      ROOT_STATE=absent
      ROOT_REASON=missing-root
      TEMPLATE_ROOT="$root"
      return 0
    fi
  done
  ROOT_STATE=present
  ROOT_REASON=""
  TEMPLATE_ROOT="$root"
}

fm_value() {
  awk -v key="$2" '
    NR == 1 && $0 == "---" { fm=1; next }
    fm && $0 == "---" { exit }
    fm && index($0, key ":") == 1 {
      value=substr($0, length(key)+2)
      sub(/^[ \t]*/, "", value)
      sub(/[ \t]*$/, "", value)
      if (value ~ /^".*"$/) value=substr(value, 2, length(value)-2)
      printf "%s", value
      exit
    }
  ' "$1"
}

validate_array() {
  value="$1"
  case "$value" in \[*\]) ;; *) return 1 ;; esac
  value="${value#\[}"
  value="${value%\]}"
  [ -n "$value" ] || return 1
  oldifs="$IFS"
  IFS=,
  for item in $value; do
    item="$(printf '%s' "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    valid_stem "$item" || { IFS="$oldifs"; return 1; }
  done
  IFS="$oldifs"
}

section_shape_valid() {
  body="$1"
  shape="$2"
  awk -v shape="$shape" '
    /^## / {
      heading=substr($0, 4)
      if (heading !~ /^(Preconditions|Procedure|Steps|Outputs|Verification|Recovery)$/) exit 1
      count[heading]++
      current=heading
      next
    }
    current != "" && $0 !~ /^[[:space:]]*$/ { content[current]=1 }
    END {
      if (count["Preconditions"] != 1 || count["Outputs"] != 1 ||
          count["Verification"] != 1 || count["Recovery"] != 1) exit 1
      if (!content["Preconditions"] || !content["Outputs"] ||
          !content["Verification"] || !content["Recovery"]) exit 1
      if (shape == "procedure") {
        if (count["Procedure"] != 1 || count["Steps"] != 0) exit 1
        if (!content["Procedure"]) exit 1
      } else {
        if (count["Steps"] != 1 || count["Procedure"] != 0) exit 1
        if (!content["Steps"]) exit 1
      }
    }
  ' "$body"
}

workflow_steps_valid() {
  body="$1"
  awk '
    $0 == "## Steps" { in_steps=1; next }
    in_steps && /^## / { in_steps=0 }
    !in_steps || /^[[:space:]]*$/ { next }
    {
      if ($0 !~ /^[0-9]+\.[[:space:]]+[^[:space:]].*$/) exit 1
      line=$0
      sub(/\..*$/, "", line)
      if (line != expected+1) exit 1
      expected=line
    }
    END { if (expected < 1) exit 1 }
  ' "$body" || return 1
  # shellcheck disable=SC2016  # Backticks are literal Markdown delimiters.
  if awk '
    $0 == "## Steps" { in_steps=1; next }
    in_steps && /^## / { in_steps=0 }
    in_steps { print }
  ' "$body" | grep -Eq '`[a-z0-9]+(-[a-z0-9]+)*/[a-z0-9]+(-[a-z0-9]+)*`'; then
    return 1
  fi
}

validate_template() {
  file="$1"
  template_stem="$2"
  VALID_REASON=""
  VALID_TITLE=""
  VALID_USE_WHEN=""
  VALID_SHAPE=""
  VALID_AREAS=""
  VALID_TAGS=""
  VALID_BODY=""

  valid_stem "$template_stem" || { VALID_REASON=bad-stem; return 1; }
  [ -f "$file" ] && [ ! -L "$file" ] || { VALID_REASON=unsafe-template; return 1; }
  [ "$(sed -n '1p' "$file")" = "---" ] || { VALID_REASON=missing-front-matter; return 1; }
  close="$(awk 'NR > 1 && $0 == "---" { print NR; exit }' "$file")"
  [ -n "$close" ] || { VALID_REASON=malformed-front-matter; return 1; }
  if ! awk -v end="$close" '
    NR > 1 && NR < end {
      if ($0 !~ /^[a-z][a-z0-9-]*:[ \t]*[^[:space:]].*$/) exit 1
      key=$0; sub(/:.*/, "", key)
      if (seen[key]++) exit 1
      if (key !~ /^(schema|title|use-when|shape|areas|tags)$/) exit 1
      value=$0; sub(/^[^:]*:[ \t]*/, "", value)
      if (value ~ /[<>]/) exit 1
    }
    END {
      required["schema"]=1; required["title"]=1; required["use-when"]=1
      required["shape"]=1; required["areas"]=1; required["tags"]=1
      for (key in required) if (seen[key] != 1) exit 1
    }
  ' "$file"; then
    VALID_REASON=invalid-front-matter
    return 1
  fi

  schema="$(fm_value "$file" schema)"
  VALID_TITLE="$(fm_value "$file" title)"
  VALID_USE_WHEN="$(fm_value "$file" use-when)"
  VALID_SHAPE="$(fm_value "$file" shape)"
  VALID_AREAS="$(fm_value "$file" areas)"
  VALID_TAGS="$(fm_value "$file" tags)"
  [ "$schema" = foreman/operation-template@1 ] || { VALID_REASON=bad-schema; return 1; }
  [ -n "$VALID_TITLE" ] || { VALID_REASON=missing-title; return 1; }
  [ -n "$VALID_USE_WHEN" ] || { VALID_REASON=missing-use-when; return 1; }
  case "$VALID_SHAPE" in procedure|workflow) ;; *) VALID_REASON=bad-shape; return 1 ;; esac
  validate_array "$VALID_AREAS" || { VALID_REASON=bad-areas; return 1; }
  validate_array "$VALID_TAGS" || { VALID_REASON=bad-tags; return 1; }

  VALID_BODY="$tmp/body.$template_stem"
  tail -n "+$((close + 1))" "$file" >"$VALID_BODY"
  [ -s "$VALID_BODY" ] || { VALID_REASON=empty-body; return 1; }
  section_shape_valid "$VALID_BODY" "$VALID_SHAPE" || { VALID_REASON=invalid-section-shape; return 1; }
  if [ "$VALID_SHAPE" = workflow ]; then
    workflow_steps_valid "$VALID_BODY" || { VALID_REASON=invalid-workflow-steps; return 1; }
  fi
  return 0
}

tmp="$(mktemp -d "${TMPDIR:-/tmp}/foreman-operation-template-index.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir "$tmp/valid"
resolve_root

if [ "$mode" = read ]; then
  valid_stem "$stem" || { echo 'status=refused' >&2; echo 'reason=bad-stem' >&2; exit 1; }
  [ "$ROOT_STATE" = present ] || {
    echo 'status=refused' >&2
    echo "reason=$ROOT_REASON" >&2
    exit 1
  }
  selected="$TEMPLATE_ROOT/$stem.md"
  [ ! -L "$selected" ] && [ -f "$selected" ] || {
    echo 'status=refused' >&2
    echo 'reason=missing-or-unsafe-template' >&2
    exit 1
  }
  if ! validate_template "$selected" "$stem"; then
    echo 'status=refused' >&2
    echo "reason=$VALID_REASON" >&2
    exit 1
  fi
  cat "$VALID_BODY"
  exit 0
fi

printf 'state\t%s\n' "$ROOT_STATE"
if [ "$ROOT_STATE" != present ]; then
  printf 'count\t0\n'
  exit 0
fi

for path in "$TEMPLATE_ROOT"/* "$TEMPLATE_ROOT"/.[!.]* "$TEMPLATE_ROOT"/..?*; do
  [ -e "$path" ] || [ -L "$path" ] || continue
  base="${path##*/}"
  case "$base" in *.md) entry_stem="${base%.md}" ;; *) entry_stem="$base" ;; esac
  if [ -L "$path" ]; then
    printf 'invalid\t%s\tunsafe-template\n' "$(printf '%s' "$entry_stem" | encode_scalar)"
    continue
  fi
  if [ ! -f "$path" ]; then
    printf 'invalid\t%s\tnon-regular-template\n' "$(printf '%s' "$entry_stem" | encode_scalar)"
    continue
  fi
  if [ "${base%.md}" = "$base" ] || ! valid_stem "$entry_stem"; then
    printf 'invalid\t%s\tbad-filename\n' "$(printf '%s' "$entry_stem" | encode_scalar)"
    continue
  fi
  if validate_template "$path" "$entry_stem"; then
    {
      printf 'template\t%s\t' "$(printf '%s' "$entry_stem" | encode_scalar)"
      printf '%s' "$VALID_TITLE" | encode_scalar
      printf '\t'
      printf '%s' "$VALID_USE_WHEN" | encode_scalar
      printf '\t%s\t%s\t%s\n' "$VALID_SHAPE" "$VALID_AREAS" "$VALID_TAGS"
    } >"$tmp/valid/$entry_stem"
  else
    printf 'invalid\t%s\t%s\n' \
      "$(printf '%s' "$entry_stem" | encode_scalar)" \
      "$(printf '%s' "$VALID_REASON" | encode_scalar)"
  fi
done

count=0
for row in "$tmp/valid"/*; do
  [ -f "$row" ] || continue
  count=$((count + 1))
done
if [ "$count" -gt 0 ]; then
  find "$tmp/valid" -mindepth 1 -maxdepth 1 -type f -print | LC_ALL=C sort | while IFS= read -r row; do
    cat "$row"
  done
fi
printf 'count\t%s\n' "$count"
