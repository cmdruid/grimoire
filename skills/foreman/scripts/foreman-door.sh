#!/usr/bin/env bash
# Check or apply Foreman's bounded project route.
set -euo pipefail

BEGIN='<!-- skill:foreman BEGIN -->'
END='<!-- skill:foreman END -->'

usage() {
  echo "usage: foreman-door.sh check|apply --root <root> [--allow-create]" >&2
  exit 2
}

mode="${1:-}"; [ -n "$mode" ] || usage; shift
root=""; workspace=.spaces; allow_create=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) [ "$#" -ge 2 ] || usage; root="$2"; shift 2 ;;
    --allow-create) allow_create=true; shift ;;
    *) usage ;;
  esac
done
[ -n "$root" ] || usage
[ -d "$root" ] || usage
root="$(CDPATH='' cd -P "$root" && pwd)"
door="$root/AGENTS.md"
route="Route project operations through \`/foreman inventory\`; identities are \`<owner>/<stem>\` under \`$workspace/<owner>/operations/<stem>.md\`."

door_class=absent
[ -f "$root/CLAUDE.md" ] && door_class=claude-only
[ -f "$door" ] && door_class=agents
[ ! -L "$door" ] || { echo "status=refused"; echo "reason=symlink-door"; exit 1; }

begin_n=0; end_n=0; begin_line=0; end_line=0; block=missing
if [ -f "$door" ]; then
  begin_n="$(grep -cF -- "$BEGIN" "$door" || true)"; end_n="$(grep -cF -- "$END" "$door" || true)"
  if [ "$begin_n" -eq 1 ] && [ "$end_n" -eq 1 ]; then
    begin_line="$(grep -nF -- "$BEGIN" "$door" | cut -d: -f1)"
    end_line="$(grep -nF -- "$END" "$door" | cut -d: -f1)"
    [ "$begin_line" -lt "$end_line" ] && block=ok || block=malformed
  elif [ "$begin_n" -ne 0 ] || [ "$end_n" -ne 0 ]; then block=malformed
  fi
fi

drift=true
if [ "$block" = ok ]; then
  body="$(awk -v b="$begin_line" -v e="$end_line" 'NR>b && NR<e {print}' "$door")"
  [ "$body" = "$route" ] && drift=false
fi
echo "workspace=$workspace"; echo "door=$door"; echo "door_class=$door_class"
echo "block=$block"; echo "drift=$drift"

if [ "$mode" = check ]; then
  [ "$door_class" = agents ] && [ "$block" = ok ] && [ "$drift" = false ]
  exit
fi
[ "$mode" = apply ] || usage
[ "$block" != malformed ] || { echo "status=refused"; echo "reason=malformed-block"; exit 1; }
if [ "$door_class" != agents ]; then
  [ "$allow_create" = true ] || { echo "status=refused"; echo "reason=front-door-creation-not-authorized"; exit 1; }
  [ "$door_class" != claude-only ] || { echo "status=refused"; echo "reason=claude-front-door-present"; exit 1; }
  : >"$door"
fi
[ "$drift" = true ] || { echo "status=unchanged"; exit 0; }
tmp="$(mktemp "${TMPDIR:-/tmp}/foreman-door.XXXXXX")"
trap 'rm -f "$tmp"' EXIT HUP INT TERM
if [ "$block" = missing ]; then
  cp "$door" "$tmp"
  if [ -s "$tmp" ] && [ "$(tail -c 1 "$tmp" | od -An -tx1 | tr -d ' \n')" != 0a ]; then printf '\n' >>"$tmp"; fi
  printf '%s\n%s\n%s\n' "$BEGIN" "$route" "$END" >>"$tmp"
  status=appended
else
  awk -v b="$begin_line" -v e="$end_line" -v begin="$BEGIN" -v route="$route" -v end="$END" '
    NR==b {print begin; print route; print end; next}
    NR>b && NR<=e {next}
    {print}
  ' "$door" >"$tmp"
  status=rewritten
fi
mv "$tmp" "$door"
trap - EXIT HUP INT TERM
echo "status=$status"
