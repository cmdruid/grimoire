#!/usr/bin/env bash
# Read-only, content-free census of one explicit brownfield source.
set -euo pipefail
usage() { echo "usage: migration-census.sh --root <root> --source <file-or-directory>" >&2; exit 2; }
protocol_safe_path() {
  [ -n "$1" ] || return 1
  case "$1" in *'|'*|*$'\n'*) return 1 ;; esac
  if LC_ALL=C printf '%s' "$1" | grep -q '[[:cntrl:]]'; then return 1; fi
  return 0
}
sha256_stream() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  else sha256sum | awk '{print $1}'
  fi
}
sha256_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else sha256sum "$1" | awk '{print $1}'
  fi
}
root=""; skilldata=.agents/skilldata; source_arg=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) [ "$#" -ge 2 ] || usage; root="$2"; shift 2 ;;
    --source) [ "$#" -ge 2 ] || usage; source_arg="$2"; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$root" ] && [ -n "$source_arg" ] || usage
[ -d "$root" ] || usage; root="$(CDPATH='' cd -P "$root" && pwd)"
protocol_safe_path "$source_arg" || { echo 'status=refused'; echo 'reason=unsafe-source-path'; exit 1; }
case "$source_arg" in /*) source="$source_arg" ;; *) source="$root/$source_arg" ;; esac
[ ! -L "$source" ] || { echo 'status=refused'; echo 'reason=symlink-source'; exit 1; }
[ -f "$source" ] || [ -d "$source" ] || { echo 'status=refused'; echo 'reason=missing-source'; exit 1; }
if [ -d "$source" ]; then
  source="$(CDPATH='' cd -P "$source" && pwd)"
else
  source="$(CDPATH='' cd -P "$(dirname "$source")" && pwd)/$(basename "$source")"
fi
case "$source" in "$root"|"$root"/*) ;; *) echo 'status=refused'; echo 'reason=source-outside-root'; exit 1 ;; esac
checker="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)/operation-check.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/foreman-census.XXXXXX")"; trap 'rm -rf "$tmp"' EXIT HUP INT TERM
raw_paths="$tmp/raw-paths"; paths="$tmp/paths"; unsafe="$tmp/unsafe"; : >"$raw_paths"; : >"$unsafe"
items=0; skipped=0; conforming=0
if [ -f "$source" ]; then
  rel="${source#"$root"/}"
  if protocol_safe_path "$rel"; then
    printf '%s\n' "$source" >"$raw_paths"
  else
    printf 'sha256:%s\n' "$(printf '%s' "$rel" | sha256_stream)" >"$unsafe"
  fi
else
  while IFS= read -r -d '' file; do
    rel="${file#"$root"/}"
    if protocol_safe_path "$rel"; then
      printf '%s\n' "$file" >>"$raw_paths"
    else
      printf 'sha256:%s\n' "$(printf '%s' "$rel" | sha256_stream)" >>"$unsafe"
    fi
  done < <(find "$source" -mindepth 1 \( -type f -o -type l \) -print0)
fi
LC_ALL=C sort "$raw_paths" >"$paths"
LC_ALL=C sort "$unsafe" | while IFS= read -r token; do
  [ -n "$token" ] && echo "skipped=$token|reason=unsafe-path"
done
skipped="$(wc -l <"$unsafe" | tr -d ' ')"
while IFS= read -r file; do
  rel="${file#"$root"/}"
  if [ -L "$file" ]; then echo "skipped=$rel|reason=symlink"; skipped=$((skipped+1)); continue; fi
  case "/$rel/" in */.git/*|*/node_modules/*|*/vendor/*|*/vendors/*) echo "skipped=$rel|reason=vendored"; skipped=$((skipped+1)); continue ;; esac
  case "$rel" in */dist/*|dist/*|*/build/*|build/*|*.min.js|*.min.css) echo "skipped=$rel|reason=generated"; skipped=$((skipped+1)); continue ;; esac
  [ -r "$file" ] || { echo "skipped=$rel|reason=unreadable"; skipped=$((skipped+1)); continue; }
  if head -n 5 "$file" | grep -Eiq '(generated file|do not edit)'; then echo "skipped=$rel|reason=generated"; skipped=$((skipped+1)); continue; fi
  if grep -Eiq '(BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY|api[_-]?key[[:space:]]*[:=][[:space:]]*[^[:space:]]+|secret[[:space:]]*[:=][[:space:]]*[^[:space:]]+|password[[:space:]]*[:=][[:space:]]*[^[:space:]]+)' "$file"; then
    echo "skipped=$rel|reason=secret-bearing"; skipped=$((skipped+1)); continue
  fi
  if [ -s "$file" ] && ! LC_ALL=C grep -Iq . "$file"; then echo "skipped=$rel|reason=binary"; skipped=$((skipped+1)); continue; fi
  digest="sha256:$(sha256_file "$file")"
  case "$rel" in "$skilldata"/*/operations/*.md)
    tail="${rel#"$skilldata"/}"; owner="${tail%%/*}"; stem="${tail##*/}"; stem="${stem%.md}"; identity="$owner/$stem"
    facts="$("$checker" --root "$root" --operation "$identity" 2>/dev/null || true)"
    if printf '%s\n' "$facts" | grep -q '^valid=true$'; then
      status="$(printf '%s\n' "$facts" | sed -n 's/^status=//p')"
      echo "conforming=$rel|identity=$identity|owner=$owner|status=$status|digest=$digest|valid=true"
      conforming=$((conforming+1)); continue
    fi ;;
  esac
  echo "item=$rel|digest=$digest|class=text"
  items=$((items+1))
done <"$paths"
echo "items=$items"; echo "conforming_count=$conforming"; echo "skipped_count=$skipped"; echo 'writes=0'
