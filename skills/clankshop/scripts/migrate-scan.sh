#!/bin/sh
# migrate-scan.sh — brownfield preflight: inventory the artifacts a migration must map.
#
#   migrate-scan.sh <root>
#
# Facts only — classification is the migrate verb's judgment. Output, grep/awk-friendly:
#   a `key=value` summary block, then one TSV line per candidate markdown doc:
#     path <TAB> created <TAB> updated <TAB> lines <TAB> first-heading
# Dates come from git where available (%as of first/last commit touching the path), else `-`.
# Skips: .git, .handbook, .records, node_modules, target, vendor, dist, hidden dirs.
# Exit codes: 0 ok · 1 usage · 2 bad root.
set -eu

[ $# -eq 1 ] || { echo "usage: migrate-scan.sh <root>" >&2; exit 1; }
root="$1"
[ -d "$root" ] || { echo "no such directory: $root" >&2; exit 2; }
root="$(cd "$root" && pwd)"

in_git=false
git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 && in_git=true

echo "root=$root"
echo "git=$in_git"
[ -e "$root/.handbook" ] && echo "handbook=present" || echo "handbook=absent"
[ -e "$root/.records" ]  && echo "records=present"  || echo "records=absent"
for door in AGENTS.md CLAUDE.md; do
  [ -f "$root/$door" ] && echo "door=$door"
done
[ -d "$root/.github/workflows" ] && echo "ci=.github/workflows"
for legacy in dev docs doc notes wiki; do
  [ -d "$root/$legacy" ] && echo "docroot=$legacy/"
done
for tr in TODO.md BACKLOG.md ISSUES.md ROADMAP.md; do
  [ -f "$root/$tr" ] && echo "tracker-shaped=$tr"
done

echo "---"

find "$root" -name '*.md' -type f \
    -not -path '*/.*' \
    -not -path '*/node_modules/*' -not -path '*/target/*' \
    -not -path '*/vendor/*' -not -path '*/dist/*' \
  | LC_ALL=C sort | while IFS= read -r f; do
    rel="${f#"$root"/}"
    created="-"; updated="-"
    if [ "$in_git" = true ]; then
      created="$(git -C "$root" log --follow --diff-filter=A --format=%as -1 -- "$rel" 2>/dev/null || true)"
      updated="$(git -C "$root" log --format=%as -1 -- "$rel" 2>/dev/null || true)"
      [ -n "$created" ] || created="-"
      [ -n "$updated" ] || updated="-"
    fi
    lines="$(wc -l < "$f" | tr -d ' ')"
    heading="$(grep -m1 '^#' "$f" 2>/dev/null | cut -c1-100 || true)"
    printf '%s\t%s\t%s\t%s\t%s\n' "$rel" "$created" "$updated" "$lines" "${heading:--}"
  done
