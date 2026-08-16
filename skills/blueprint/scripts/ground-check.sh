#!/usr/bin/env bash
# ground-check.sh <root> <doc> [<doc>...]
#
# Re-grounding aid for /blueprint spec/review. A design ages well but the
# literal code it references ages fast (a renamed type, a moved file). This
# extracts the rooted path / `file:line` references a design or plan doc points
# at and reports which no longer resolve at the worktree's HEAD -- so
# re-grounding focuses on what actually drifted instead of re-reading everything.
#
# DOCTRINE: facts, not verdicts. It lists unresolved references; the plan prose
# decides what to re-read or re-measure (and `Re-measure before you size` still
# means running the real host tool -- this resolves paths, it does not measure).
# Read-only. Bash-3.2 safe. A reference is checked ONLY when its first path
# segment is a real top-level dir of <root>, so prose mentions, globs, and
# frontmatter examples can't manufacture false drift.
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: ground-check.sh <root> <doc> [<doc>...]" >&2
  exit 2
fi
root="$1"; shift

# space-padded list of dotless top-level dir names, e.g. " src dev tests ".
top_level_dirs() {
  local d name out=" "
  for d in "$1"/*/; do
    [ -d "$d" ] || continue   # zero subdirs -> the unexpanded glob itself
    name="$(basename "$d")"; case "$name" in .*) continue;; esac
    out="$out$name "
  done
  printf '%s' "$out"
}

# backticked, unambiguous repo-ROOT path tokens (multi-segment, optional :line);
# spaces/globs/URLs dropped.
extract_refs() {
  # shellcheck disable=SC2016  # literal backticks are intentional (markdown code spans)
  grep -hoE '`[^`]+`' "$@" 2>/dev/null \
    | tr -d '`' \
    | sed -E 's/[),.;]+$//' \
    | grep -E '^[A-Za-z0-9._/-]+(:[0-9]+)?$' \
    | grep -E '/' \
    | sort -u || true
}

tlds="$(top_level_dirs "$root")"
refs="$(extract_refs "$@")"

total=0; bad=0
echo "unresolved:"
while IFS= read -r r; do
  [ -z "$r" ] && continue
  path="${r%%:*}"; line=""
  case "$r" in *:[0-9]*) line="${r##*:}";; esac
  first="${path%%/*}"
  case "$tlds" in *" $first "*) ;; *) continue;; esac
  total=$((total + 1))
  if [ ! -e "$root/$path" ]; then
    bad=$((bad + 1)); echo "  $r  (missing)"
  elif [ -n "$line" ] && [ -f "$root/$path" ]; then
    n="$(grep -c '' "$root/$path")"   # counts lines even without a trailing newline
    if [ "$line" -gt "$n" ]; then bad=$((bad + 1)); echo "  $r  (file has $n lines)"; fi
  fi
done <<< "$refs"
[ "$bad" -eq 0 ] && echo "  (none)"
echo "checked=$total"
echo "unresolved_count=$bad"
