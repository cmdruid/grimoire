#!/usr/bin/env bash
# anchor-status.sh <current-template> <front-door>
# Classify one front door without mutating it.
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: anchor-status.sh <current-template> <front-door>" >&2
  exit 2
fi

template="$1"
front_door="$2"
current_begin='<!-- checkpoint:recovery-anchor@2 -->'
end_marker='<!-- /checkpoint:recovery-anchor -->'
begin_re='^<!-- checkpoint:recovery-anchor@[^[:space:]]+ -->$'
current_heading='## Checkpoint lifecycle and recovery'

template_error() { echo "anchor_error=invalid-template"; exit 2; }
target_error() { echo "anchor_error=$1"; exit 1; }

reserved_heading_lines() {
  awk '
    function deindent(line,    count) {
      count = 0
      while (count < 3 && substr(line, 1, 1) == " ") {
        line = substr(line, 2)
        count++
      }
      return line
    }
    function marker_width(line, marker,    count) {
      count = 0
      while (substr(line, count + 1, 1) == marker) count++
      return count
    }
    function begins_checkpoint(text) {
      sub(/^[ \t]+/, "", text)
      return substr(text, 1, 10) == "Checkpoint"
    }
    BEGIN {
      fence_marker = ""
      fence_width = 0
    }
    {
      line = deindent($0)

      if (fence_marker != "") {
        width = marker_width(line, fence_marker)
        rest = substr(line, width + 1)
        if (width >= fence_width && rest ~ /^[ \t]*$/) {
          fence_marker = ""
          fence_width = 0
        }
        next
      }

      # Four-space or tab-indented lines are code, not top-level headings or fences.
      if (substr(line, 1, 1) == " " || substr(line, 1, 1) == "\t") {
        next
      }

      marker = substr(line, 1, 1)
      if (marker == "`" || marker == "~") {
        width = marker_width(line, marker)
        rest = substr(line, width + 1)
        if (width >= 3 && (marker == "~" || index(rest, "`") == 0)) {
          fence_marker = marker
          fence_width = width
          next
        }
      }

      # ATX H2: up to three leading spaces were removed above; exactly two hashes
      # must be followed by whitespace or end-of-line.
      if (substr(line, 1, 2) == "##" &&
          (substr(line, 3, 1) == "" || substr(line, 3, 1) == " " ||
           substr(line, 3, 1) == "\t")) {
        content = substr(line, 3)
        if (begins_checkpoint(content)) print NR
      }
    }
  ' "$1"
}

if [ ! -f "$template" ] || [ -L "$template" ] || [ ! -r "$template" ]; then
  template_error
fi
template_begin="$(sed -n '1p' "$template")"
template_begin_count="$(grep -Ec "$begin_re" "$template" || true)"
template_end_count="$(grep -Fxc "$end_marker" "$template" || true)"
template_heading_count="$(grep -Fxc "$current_heading" "$template" || true)"
template_end_line="$(grep -Fn "$end_marker" "$template" | cut -d: -f1 || true)"
template_lines="$(awk 'END { print NR }' "$template")"
if [ "$template_begin" != "$current_begin" ] ||
  [ "$template_begin_count" -ne 1 ] ||
  [ "$template_end_count" -ne 1 ] ||
  [ "$template_heading_count" -ne 1 ] ||
  [ "$template_end_line" -ne "$template_lines" ]; then
  template_error
fi

if [ ! -e "$front_door" ] && [ ! -L "$front_door" ]; then
  echo "anchor_status=absent"
  echo "anchor_target_missing=true"
  exit 0
fi
if [ ! -f "$front_door" ] || [ -L "$front_door" ] || [ ! -r "$front_door" ]; then
  target_error invalid-target
fi

begins="$(grep -Ec "$begin_re" "$front_door" || true)"
ends="$(grep -Fxc "$end_marker" "$front_door" || true)"
heading_lines="$(reserved_heading_lines "$front_door")"
heading_count="$(printf '%s\n' "$heading_lines" | awk 'NF { count++ } END { print count + 0 }')"

if [ "$begins" -eq 0 ] && [ "$ends" -eq 0 ]; then
  if [ "$heading_count" -eq 0 ]; then
    echo "anchor_status=absent"
    exit 0
  fi
  target_error reserved-heading
fi

if [ "$begins" -ne 1 ] || [ "$ends" -ne 1 ]; then
  target_error marker-structure
fi

begin_line="$(grep -En "$begin_re" "$front_door" | cut -d: -f1)"
end_line="$(grep -Fn "$end_marker" "$front_door" | cut -d: -f1)"
[ "$begin_line" -lt "$end_line" ] || target_error marker-order

outside_headings="$(printf '%s\n' "$heading_lines" |
  awk -v begin="$begin_line" -v end="$end_line" 'NF && ($1 < begin || $1 > end) { count++ } END { print count + 0 }')"
[ "$outside_headings" -eq 0 ] || target_error mixed-heading

block="$(mktemp)"
trap 'rm -f "$block"' EXIT
sed -n "${begin_line},${end_line}p" "$front_door" > "$block"
block_begin="$(sed -n '1p' "$block")"

if [ "$block_begin" = "$current_begin" ]; then
  if cmp -s "$template" "$block"; then status=current
  else status=drifted-current; fi
else
  status=conflict
fi

echo "anchor_status=$status"
echo "anchor_begin_line=$begin_line"
echo "anchor_end_line=$end_line"
