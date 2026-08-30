#!/usr/bin/env bash
# tracker-runtime-check.sh — resolve Backlog's one runtime recovery decision.
set -euo pipefail

die(){ echo "reason=$1${2:+ detail=$2}" >&2;exit 2;}

ROOT="";TR=.trackers
while [ $# -gt 0 ];do case "$1" in
  --root)ROOT="${2:-}";shift 2;;*)die usage;;esac;done

SKILL="$(CDPATH='' cd -P "$(dirname "$0")/.."&&pwd)"
facts="$("$SKILL/scripts/tracker-layer-status.sh" runtime --root "$ROOT")"
ROOT="$(CDPATH='' cd -P "$ROOT"&&pwd)"
fact(){ printf '%s\n' "$facts"|sed -n "s/^$1=//p"|head -n1;}
layer="$(fact layer_status)";provider="$(fact provider_status)";action="$(fact recovery_action)"
[ -n "$layer" ]&&[ -n "$provider" ]&&[ -n "$action" ]||die classifier

if [ "$layer" = initialized ]&&[ "$provider" = current ];then
  printf 'provider=%s/%s/trackers.sh\n' "$ROOT" "$TR"
elif [ "$layer" = initialized ];then
  echo 'reason=repair-required action=/backlog repair' >&2;exit 2
elif [ "$layer" = ledger-loss ];then
  echo "reason=ledger-recovery-required action=$action" >&2;exit 2
elif [ "$layer" = absent ]||[ "$layer" = resumable-prefix ];then
  echo 'reason=setup-required action=/backlog setup' >&2;exit 2
else
  echo 'reason=ledger-recovery-required action=human-review' >&2;exit 2
fi
