#!/usr/bin/env bash
# Report which existing surface owns mutable progress for one goal.
set -euo pipefail
usage() { echo "usage: runtime-context.sh --root <root> --goal <record-path> [--checkpoint <file>] [--workstream <file>]" >&2; exit 2; }
root=""; goal=""; checkpoint=""; workstream=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) [ "$#" -ge 2 ]||usage;root="$2";shift 2;;
    --goal) [ "$#" -ge 2 ]||usage;goal="$2";shift 2;;
    --checkpoint) [ "$#" -ge 2 ]||usage;checkpoint="$2";shift 2;;
    --workstream) [ "$#" -ge 2 ]||usage;workstream="$2";shift 2;;
    *) usage;;
  esac
done
[ -n "$root" ] && [ -n "$goal" ] && [ -d "$root" ] || usage; root="$(CDPATH='' cd -P "$root"&&pwd)"
[ -n "$checkpoint" ] || checkpoint="$root/CHECKPOINT.md"; [ -n "$workstream" ] || workstream="$root/WORKSTREAM.md"
cp_has=false; ws_has=false
[ -f "$checkpoint" ] && [ ! -L "$checkpoint" ] && grep -qF -- "$goal" "$checkpoint" && cp_has=true
[ -f "$workstream" ] && [ ! -L "$workstream" ] && grep -qF -- "$goal" "$workstream" && ws_has=true
echo "goal=$goal"; echo "checkpoint=$checkpoint"; echo "workstream=$workstream"
if [ "$cp_has" = true ] && [ "$ws_has" = true ]; then echo 'owner=conflict'; echo 'reason=dual-runtime-state'; exit 1; fi
if [ "$ws_has" = true ]; then echo 'owner=workstream'; echo 'recovery=available'; exit 0; fi
if [ "$cp_has" = true ]; then echo 'owner=checkpoint'; echo 'recovery=available'; exit 0; fi
echo 'owner=none'; echo 'recovery=unavailable'; echo 'warning=project-level recovery across a reset is unavailable'
