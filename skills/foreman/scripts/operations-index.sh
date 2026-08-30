#!/usr/bin/env bash
# List/search direct project operations without printing their bodies.
set -u

usage() {
  echo "usage: operations-index.sh list|search --root <root> [--query <text>] [--include-deprecated]" >&2
  exit 2
}

mode="${1:-}"; [ -n "$mode" ] || usage; shift
case "$mode" in list|search) ;; *) usage ;; esac
root=""; workspace=.spaces; query=""; include_deprecated=false
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
workspace_dir="$root/$workspace"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/foreman-index.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
files="$tmp/files"; : >"$files"

echo "workspace=$workspace"
echo "operations_dir=$workspace_dir/*/operations"
if [ ! -d "$workspace_dir" ]; then
  echo "matches=0"; echo "malformed=0"; echo "stale=0"; echo "native_candidates=0"
  exit 0
fi

# Workspace names are validated elsewhere and operation identities forbid whitespace/newlines.
find "$workspace_dir" -mindepth 3 -maxdepth 3 \( -type f -o -type l \) -name '*.md' \
  -path '*/operations/*.md' -print | LC_ALL=C sort >"$files"

matches=0; malformed=0; stale=0; natives=0
while IFS= read -r file; do
  [ -n "$file" ] || continue
  rel="${file#"$workspace_dir"/}"; owner="${rel%%/*}"; base="${file##*/}"; stem="${base%.md}"
  identity="$owner/$stem"
  case "$owner" in doctrine|drafts|hooks|operations|scripts|templates) continue ;; esac
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
