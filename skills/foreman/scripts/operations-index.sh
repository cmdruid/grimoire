#!/usr/bin/env bash
# List/search direct project operations without printing their bodies.
set -u

usage() {
  echo "usage: operations-index.sh list|search --root <root> [--query <text>] [--include-deprecated]" >&2
  exit 2
}

mode="${1:-}"; [ -n "$mode" ] || usage; shift
case "$mode" in list|search) ;; *) usage ;; esac
root=""; skilldata=.agents/skilldata; query=""; include_deprecated=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) [ "$#" -ge 2 ] || usage; root="$2"; shift 2 ;;
    --query) [ "$#" -ge 2 ] || usage; query="$2"; shift 2 ;;
    --include-deprecated) include_deprecated=true; shift ;;
    *) usage ;;
  esac
done
[ -n "$root" ] || usage
[ -d "$root" ] || usage
root="$(CDPATH='' cd -P "$root" && pwd)"

checker="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)/operation-check.sh"
skilldata_dir="$root/$skilldata"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/foreman-index.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
files="$tmp/files"; : >"$files"

echo "skilldata=$skilldata"
echo "operations_dir=$skilldata_dir/*/operations"
if [ -L "$root/.agents" ] || [ -L "$skilldata_dir" ]; then
  echo "state=unsafe"; echo "reason=symlink-skilldata-root"
  exit 1
fi
if [ -e "$root/.agents" ] && [ ! -d "$root/.agents" ]; then
  echo "state=unsafe"; echo "reason=non-directory-agents-root"
  exit 1
fi
if [ -e "$skilldata_dir" ] && [ ! -d "$skilldata_dir" ]; then
  echo "state=unsafe"; echo "reason=non-directory-skilldata-root"
  exit 1
fi
if [ ! -d "$skilldata_dir" ]; then
  echo "state=absent"
  echo "matches=0"; echo "malformed=0"; echo "stale=0"; echo "native_candidates=0"
  exit 0
fi
echo "state=present"

# Validate only the owner/operations paths this reader consumes. Unrelated sibling
# kinds are deliberately inert; there is no whole-tree skilldata validator.
for owner_dir in "$skilldata_dir"/*; do
  [ -e "$owner_dir" ] || [ -L "$owner_dir" ] || continue
  owner="${owner_dir##*/}"
  printf '%s\n' "$owner" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || continue
  if [ -L "$owner_dir" ]; then
    printf '%s\n' "$owner|symlink-owner" >>"$tmp/unsafe-dirs"
    continue
  fi
  [ -d "$owner_dir" ] || continue
  operations="$owner_dir/operations"
  [ -e "$operations" ] || [ -L "$operations" ] || continue
  if [ -L "$operations" ]; then
    printf '%s\n' "$owner|symlink-operations-dir" >>"$tmp/unsafe-dirs"
    continue
  fi
  if [ ! -d "$operations" ]; then
    printf '%s\n' "$owner|non-directory-operations" >>"$tmp/unsafe-dirs"
    continue
  fi
  find "$operations" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) -name '*.md' -print >>"$files"
done
LC_ALL=C sort "$files" -o "$files"

matches=0; malformed=0; stale=0; natives=0
if [ -f "$tmp/unsafe-dirs" ]; then
  while IFS='|' read -r owner reason; do
    malformed=$((malformed + 1))
    echo "malformed_operations_dir=$owner|reason=$reason"
  done <"$tmp/unsafe-dirs"
fi
while IFS= read -r file; do
  [ -n "$file" ] || continue
  rel="${file#"$skilldata_dir"/}"; owner="${rel%%/*}"; base="${file##*/}"; stem="${base%.md}"
  identity="$owner/$stem"
  printf '%s\n' "$identity" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*/[a-z0-9]+(-[a-z0-9]+)*$' || {
    malformed=$((malformed + 1)); echo "malformed_operation=$identity|reason=bad-identity"; continue;
  }
  facts="$tmp/facts"
  if ! "$checker" --root "$root" --operation "$identity" >"$facts"; then
    if ! grep -q '^schema:[[:space:]]*foreman/operation@1[[:space:]]*$' "$file" 2>/dev/null; then
      natives=$((natives + 1)); echo "native_candidate=$rel"
    else
      malformed=$((malformed + 1))
      reason="$(sed -n 's/^reason=//p' "$facts" | head -n 1)"
      echo "malformed_operation=$identity|reason=${reason:-invalid}"
    fi
    continue
  fi
  title="$(sed -n 's/^title=//p' "$facts")"; use_when="$(sed -n 's/^use_when=//p' "$facts")"
  shape="$(sed -n 's/^shape=//p' "$facts")"; status="$(sed -n 's/^status=//p' "$facts")"
  areas="$(sed -n 's/^areas=//p' "$facts")"; tags="$(sed -n 's/^tags=//p' "$facts")"
  digest="$(sed -n 's/^digest=//p' "$facts")"; verification="$(sed -n 's/^verification=//p' "$facts")"
  if [ "$status" = active ] && [ "$verification" != current ]; then
    stale=$((stale + 1)); echo "stale_operation=$identity|digest=$digest|verification=$verification"
  fi
  [ "$status" != deprecated ] || [ "$include_deprecated" = true ] || continue
  if [ "$mode" = search ]; then
    [ -n "$query" ] || continue
    haystack="$(printf '%s' "$identity $title $use_when $areas $tags" | tr '[:upper:]' '[:lower:]')"
    ok=true
    for token in $query; do
      token="$(printf '%s' "$token" | tr '[:upper:]' '[:lower:]')"
      case "$haystack" in *"$token"*) ;; *) ok=false; break ;; esac
    done
    [ "$ok" = true ] || continue
  fi
  matches=$((matches + 1))
  echo "operation=$identity|title=$title|use-when=$use_when|shape=$shape|status=$status|areas=$areas|tags=$tags|digest=$digest|verification=$verification"
done <"$files"

echo "matches=$matches"
echo "malformed=$malformed"
echo "stale=$stale"
echo "native_candidates=$natives"
