#!/usr/bin/env bash
# anchor-status.sh <current-template> <front-door>
# Classify one front door without mutating it.
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: anchor-status.sh <current-template> <front-door>" >&2
  exit 2
fi
template="$1"; front_door="$2"
end_marker='<!-- /checkpoint:recovery-anchor -->'
begin_re='^<!--[[:space:]]*checkpoint:recovery-anchor@[^[:space:]]+[[:space:]]*-->$'

if [ ! -f "$template" ] || [ -L "$template" ] || [ ! -r "$template" ]; then
  echo "anchor_status=invalid-template"; exit 2
fi
template_begin="$(sed -n '1p' "$template")"
if ! printf '%s\n' "$template_begin" | grep -Eq "$begin_re" ||
  [ "$(grep -Ec "$begin_re" "$template" || true)" -ne 1 ] ||
  [ "$(grep -Fc "$end_marker" "$template" || true)" -ne 1 ] ||
  [ "$(grep -Ec '^##[[:space:]]+Checkpoint recovery[[:space:]]*$' "$template" || true)" -ne 1 ]; then
  echo "anchor_status=invalid-template"; exit 2
fi
template_begin_line="$(grep -En "$begin_re" "$template" | cut -d: -f1)"
template_end_line="$(grep -Fn "$end_marker" "$template" | cut -d: -f1)"
template_heading_line="$(grep -En '^##[[:space:]]+Checkpoint recovery[[:space:]]*$' "$template" | cut -d: -f1)"
if [ "$template_begin_line" -ne 1 ] || [ "$template_begin_line" -ge "$template_heading_line" ] ||
  [ "$template_heading_line" -ge "$template_end_line" ]; then
  echo "anchor_status=invalid-template"; exit 2
fi

if [ ! -e "$front_door" ] && [ ! -L "$front_door" ]; then echo "anchor_status=missing"; exit 0; fi
if [ ! -f "$front_door" ] || [ -L "$front_door" ] || [ ! -r "$front_door" ]; then
  echo "anchor_status=invalid"; exit 1
fi

begins="$(grep -Ec "$begin_re" "$front_door" || true)"
ends="$(grep -Fc "$end_marker" "$front_door" || true)"
headings="$(grep -Ec '^##[[:space:]]+Checkpoint recovery[[:space:]]*$' "$front_door" || true)"

if [ "$begins" -eq 0 ] && [ "$ends" -eq 0 ]; then
  if [ "$headings" -eq 0 ]; then echo "anchor_status=absent"; exit 0; fi
  if [ "$headings" -eq 1 ]; then
    begin_line="$(grep -En '^##[[:space:]]+Checkpoint recovery[[:space:]]*$' "$front_door" | cut -d: -f1)"
    next_heading="$(awk -v start="$begin_line" 'NR > start && /^##[[:space:]]+/ { print NR; exit }' "$front_door")"
    if [ -n "$next_heading" ]; then end_line=$((next_heading - 1));
    else end_line="$(awk 'END { print NR }' "$front_door")"; fi
    echo "anchor_status=obsolete-unversioned"
    echo "anchor_begin_line=$begin_line"
    echo "anchor_end_line=$end_line"
    exit 0
  fi
  echo "anchor_status=duplicate"; exit 1
fi
if [ "$begins" -gt 1 ] || [ "$ends" -gt 1 ] || [ "$headings" -gt 1 ]; then
  echo "anchor_status=duplicate"; exit 1
fi
if [ "$begins" -ne 1 ] || [ "$ends" -ne 1 ] || [ "$headings" -ne 1 ]; then
  echo "anchor_status=malformed"; exit 1
fi

begin_line="$(grep -En "$begin_re" "$front_door" | cut -d: -f1)"
end_line="$(grep -Fn "$end_marker" "$front_door" | cut -d: -f1)"
heading_line="$(grep -En '^##[[:space:]]+Checkpoint recovery[[:space:]]*$' "$front_door" | cut -d: -f1)"
if [ "$begin_line" -ge "$heading_line" ] || [ "$heading_line" -ge "$end_line" ]; then
  echo "anchor_status=malformed"; exit 1
fi

block="$(mktemp)"; trap 'rm -f "$block"' EXIT
sed -n "${begin_line},${end_line}p" "$front_door" > "$block"

if cmp -s "$template" "$block"; then
  echo "anchor_status=current"
  echo "anchor_begin_line=$begin_line"
  echo "anchor_end_line=$end_line"
  exit 0
fi
block_begin="$(sed -n '1p' "$block")"
if [ "$block_begin" = "$template_begin" ]; then
  echo "anchor_status=drifted-current"
else
  echo "anchor_status=obsolete-versioned"
fi
echo "anchor_begin_line=$begin_line"
echo "anchor_end_line=$end_line"
