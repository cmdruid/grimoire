#!/usr/bin/env bash
# Prime exactly three sections of one validated Workstream hand-off.
set -euo pipefail
usage() { echo "usage: workstream-prime.sh --handoff <absolute> --source <pointer> --unit <sentence> --next <literal-action>" >&2; exit 2; }
die() { echo "status=refused"; echo "reason=$1"; exit 1; }
handoff=""; source_pointer=""; unit=""; next_action=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --handoff) [ "$#" -ge 2 ]||usage; handoff="$2"; shift 2;;
    --source) [ "$#" -ge 2 ]||usage; source_pointer="$2"; shift 2;;
    --unit) [ "$#" -ge 2 ]||usage; unit="$2"; shift 2;;
    --next) [ "$#" -ge 2 ]||usage; next_action="$2"; shift 2;;
    *) usage;;
  esac
done
[ -n "$handoff" ] && [ -n "$source_pointer" ] && [ -n "$unit" ] && [ -n "$next_action" ] || usage
case "$handoff" in /*) ;; *) die handoff-not-absolute;; esac
[ -f "$handoff" ] && [ ! -L "$handoff" ] || die unsafe-handoff
for value in "$source_pointer" "$unit" "$next_action"; do case "$value" in *$'\n'*|*$'\r'*) die multiline-value;; esac; done

for heading in '## TL;DR' '## Queue state' "## What's next"; do
  [ "$(grep -cFx -- "$heading" "$handoff" || true)" -eq 1 ] || die malformed-sections
done
tldr_line="$(grep -nFx -- '## TL;DR' "$handoff"|cut -d: -f1)"; queue_line="$(grep -nFx -- '## Queue state' "$handoff"|cut -d: -f1)"; next_line="$(grep -nFx -- "## What's next" "$handoff"|cut -d: -f1)"
[ "$tldr_line" -lt "$queue_line" ] && [ "$queue_line" -lt "$next_line" ] || die malformed-section-order
recorded_handoff="$(sed -n -E 's/^- this hand-off:[[:space:]]*//p' "$handoff"|head -n1|sed 's/[[:space:]]*$//')"
[ "$recorded_handoff" = "$handoff" ] || die wrong-handoff
recorded_source="$(sed -n -E 's/^- source:[[:space:]]*//p' "$handoff"|head -n1|sed 's/[[:space:]]*$//')"
[ "$recorded_source" = "$source_pointer" ] || die wrong-source

tmp="$(mktemp "${handoff%/*}/.workstream-prime.XXXXXX")"; trap 'rm -f "$tmp"' EXIT HUP INT TERM
awk -v unit="$unit" -v action="$next_action" -v source="$source_pointer" '
  function emit(which) {
    if (which=="tldr") { print ""; print unit; print action; print "" }
    else if (which=="queue") {
      print ""; print "Current unit: " unit; print "Source: " source
      for(i=1;i<=control_n;i++) print control[i]
      print ""
    }
    else { print ""; print action; print "" }
  }
  skip=="queue"&&/^## / {emit("queue"); skip=""}
  skip=="queue" {if(/^(Parked:|Phase:|Open PR:)/) control[++control_n]=$0; next}
  $0=="## TL;DR" {print; emit("tldr"); skip=1; next}
  $0=="## Queue state" {print; skip="queue"; next}
  $0=="## What'"'"'s next" {print; emit("next"); skip=1; next}
  skip&&/^## / {skip=0}
  !skip {print}
  END {if(skip=="queue") emit("queue")}
' "$handoff" >"$tmp"
if cmp -s "$tmp" "$handoff"; then rm -f "$tmp"; trap - EXIT HUP INT TERM; echo 'status=unchanged'; echo 'sections=3'; exit 0; fi
mv "$tmp" "$handoff"; trap - EXIT HUP INT TERM
echo 'status=primed'; echo 'sections=3'; echo "handoff=$handoff"
