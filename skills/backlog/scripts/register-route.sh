#!/usr/bin/env bash
# register-route.sh — own only Backlog's delimited route block in root AGENTS.md.
set -euo pipefail

die(){ echo "reason=$1${2:+ detail=$2}" >&2; exit 2; }
cmd="${1:-}"; shift || true; ROOT=""; WS=""; TR=""; STAMP=""
while [ $# -gt 0 ]; do case "$1" in
  --root) ROOT="${2:-}"; shift 2;; --workspace) WS="${2:-}"; shift 2;;
  --trackers-root) TR="${2:-}"; shift 2;; --stamp) STAMP="${2:-}"; shift 2;; *) die usage;; esac; done
case "$ROOT" in /*) ;; *) die unsafe-root "$ROOT";; esac
[ -d "$ROOT" ] || die unsafe-root "$ROOT"; ROOT="$(CDPATH='' cd -P "$ROOT"&&pwd)"
[ -n "$WS" ] && [ -n "$TR" ] || die usage
DOOR="$ROOT/AGENTS.md"; [ ! -L "$DOOR" ] || die symlink "$DOOR"; [ ! -e "$DOOR" ] || [ -f "$DOOR" ] || die incompatible-entry "$DOOR"

facts(){
  if [ ! -f "$DOOR" ];then echo 'begin=0 end=0 valid=true';return;fi
  local b e; b="$(grep -c '^<!-- skill:backlog BEGIN' "$DOOR"||true)";e="$(grep -c '^<!-- skill:backlog END -->$' "$DOOR"||true)"
  printf 'begin=%s end=%s valid=%s\n' "$b" "$e" "$([ "$b" -eq "$e" ]&&[ "$b" -le 1 ]&&echo true||echo false)"
  [ "$b" -eq "$e" ]&&[ "$b" -le 1 ]||die malformed-route
}

write_block(){
  printf '%s\n' \
    "<!-- skill:backlog BEGIN built-against:$STAMP -->" \
    '### /backlog — project follow-up trackers' \
    "Route: Tracker queues are under \`$TR/\`; use \`/backlog query\` or \`/backlog tracker list\` to inspect them." \
    'Cadence: After a human-visible work unit completes, and before a healthy reset or hand-off would discard substantive context, run `/backlog debrief` once over the work since the previous debrief.' \
    'Edges: produces `tracker`.' \
    '<!-- skill:backlog END -->'
}

ensure(){
  [ -n "$STAMP" ]||die usage;facts >/dev/null;local tmp="$DOOR.tmp.$$" block="$DOOR.block.$$";write_block >"$block"
  if [ ! -f "$DOOR" ];then
    { printf '# Agent instructions\n\n## Skill routes (self-registered)\n\n';cat "$block";} >"$tmp"
  elif grep -q '^<!-- skill:backlog BEGIN' "$DOOR";then
    awk -v block="$block" '/^<!-- skill:backlog BEGIN/{while((getline l<block)>0)print l;close(block);skip=1;next}/^<!-- skill:backlog END -->$/{skip=0;next}!skip{print}' "$DOOR" >"$tmp"
  else
    cp "$DOOR" "$tmp";grep -q '^## Skill routes (self-registered)$' "$tmp"||printf '\n## Skill routes (self-registered)\n' >>"$tmp";printf '\n' >>"$tmp";cat "$block" >>"$tmp"
  fi
  rm "$block";if [ -f "$DOOR" ]&&cmp -s "$DOOR" "$tmp";then rm "$tmp";return;fi
  mv "$tmp" "$DOOR";echo 'wrote=AGENTS.md'
}

remove(){
  facts >/dev/null;if [ ! -f "$DOOR" ] || ! grep -q '^<!-- skill:backlog BEGIN' "$DOOR";then echo 'reason=no-route';return 1;fi
  local tmp="$DOOR.tmp.$$";awk '/^<!-- skill:backlog BEGIN/{skip=1;next}/^<!-- skill:backlog END -->$/{skip=0;next}!skip{print}' "$DOOR" >"$tmp";mv "$tmp" "$DOOR";echo 'wrote=AGENTS.md'
}

case "$cmd" in preflight)facts;;ensure)ensure;;remove)remove;;*)die usage;;esac
