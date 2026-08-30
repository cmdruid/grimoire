#!/usr/bin/env bash
# route-status.sh <template> <front-door> — classify Backlog's bounded root route.
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: route-status.sh <template> <front-door>" >&2
  exit 2
fi

template="$1"
front_door="$2"
current_begin='<!-- skill:backlog BEGIN built-against:debrief-anchor@1 -->'
end_marker='<!-- skill:backlog END -->'
reserved_heading='/backlog — project follow-up trackers'

template_error() { echo 'route_error=invalid-template'; exit 2; }
target_error() { echo "route_error=$1"; exit 1; }

reserved_heading_lines() {
  awk -v wanted="$reserved_heading" '
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
    BEGIN { fence_marker = ""; fence_width = 0 }
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
      # Four-space or tab-indented lines are code, not structural headings or fences.
      if (substr(line, 1, 1) == " " || substr(line, 1, 1) == "\t") next
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
      # Markdown ATX H3: exactly three hashes after up to three spaces. Strip
      # the required separator and an optional closing hash sequence before
      # comparing the heading text.
      if (substr(line, 1, 3) == "###" &&
          (substr(line, 4, 1) == " " || substr(line, 4, 1) == "\t")) {
        content = substr(line, 4)
        sub(/^[ \t]+/, "", content)
        sub(/[ \t]+$/, "", content)
        if (content ~ /[ \t]+#+$/) {
          sub(/[ \t]+#+$/, "", content)
          sub(/[ \t]+$/, "", content)
        }
        if (content == wanted) print NR
      }
    }
  ' "$1"
}

if [ ! -f "$template" ] || [ -L "$template" ] || [ ! -r "$template" ]; then
  template_error
fi
template_begin="$(sed -n '1p' "$template")"
template_begin_count="$(grep -c '^<!-- skill:backlog BEGIN' "$template" || true)"
template_end_count="$(grep -Fxc "$end_marker" "$template" || true)"
template_heading_lines="$(reserved_heading_lines "$template")"
template_heading_count="$(printf '%s\n' "$template_heading_lines" | awk 'NF { count++ } END { print count + 0 }')"
template_end_line="$(grep -Fn "$end_marker" "$template" | cut -d: -f1 || true)"
template_lines="$(awk 'END { print NR }' "$template")"
if [ "$template_begin" != "$current_begin" ] ||
  [ "$template_begin_count" -ne 1 ] ||
  [ "$template_end_count" -ne 1 ] ||
  [ "$template_heading_count" -ne 1 ] ||
  [ "$template_heading_lines" -ne 2 ] ||
  [ "$template_end_line" -ne "$template_lines" ]; then
  template_error
fi

if [ ! -e "$front_door" ] && [ ! -L "$front_door" ]; then
  echo 'route_status=absent'
  echo 'route_target_missing=true'
  exit 0
fi
if [ ! -f "$front_door" ] || [ -L "$front_door" ] || [ ! -r "$front_door" ]; then
  target_error invalid-target
fi

begin_lines="$(grep -n '^<!-- skill:backlog BEGIN' "$front_door" | cut -d: -f1 || true)"
end_lines="$(grep -Fn "$end_marker" "$front_door" | cut -d: -f1 || true)"
heading_lines="$(reserved_heading_lines "$front_door")"
begins="$(printf '%s\n' "$begin_lines" | awk 'NF { count++ } END { print count + 0 }')"
ends="$(printf '%s\n' "$end_lines" | awk 'NF { count++ } END { print count + 0 }')"
heading_count="$(printf '%s\n' "$heading_lines" | awk 'NF { count++ } END { print count + 0 }')"

if [ "$begins" -eq 0 ] && [ "$ends" -eq 0 ]; then
  if [ "$heading_count" -eq 0 ]; then
    echo 'route_status=absent'
    exit 0
  fi
  target_error reserved-heading
fi
if [ "$begins" -ne 1 ] || [ "$ends" -ne 1 ]; then target_error marker-structure; fi

begin_line="$begin_lines"
end_line="$end_lines"
[ "$begin_line" -lt "$end_line" ] || target_error marker-order
outside_headings="$(printf '%s\n' "$heading_lines" |
  awk -v begin="$begin_line" -v end="$end_line" 'NF && ($1 < begin || $1 > end) { count++ } END { print count + 0 }')"
[ "$outside_headings" -eq 0 ] || target_error reserved-heading

block="$(mktemp "${TMPDIR:-/tmp}/backlog-route-block.XXXXXX")"
trap 'rm -f "$block"' EXIT
sed -n "${begin_line},${end_line}p" "$front_door" > "$block"
block_begin="$(sed -n '1p' "$block")"
if [ "$block_begin" = "$current_begin" ]; then
  if cmp -s "$template" "$block"; then route_status=current
  else route_status=drifted-current; fi
else
  route_status=replaceable-managed
fi

echo "route_status=$route_status"
echo "route_begin_line=$begin_line"
echo "route_end_line=$end_line"
