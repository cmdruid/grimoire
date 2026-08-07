#!/bin/sh
# migrate-preflight.sh <root> -- precondition facts for the brownfield onramp (mechanics
# section 8): stamped state, clean tree, active workstreams (linked worktrees AND in-place
# streams -- a linked-worktree check alone is insufficient), and the whole-installation
# duplicate-ID scan. Facts only; the migrate verb judges them. The unclassifiable-artifact
# triage is verb judgment over the inventory, not a script fact.
set -eu
ROOT=${1:-.}
ROOT=$(CDPATH='' cd "$ROOT" && pwd)
DIR=$(CDPATH='' cd "$(dirname "$0")" && pwd)
cd "$ROOT"

# emit_capped <key> <cap>: newline-delimited items on stdin -> "<key>_count=" (true total)
# + "<key>=" (first <cap>, comma-joined, "+N more" marker). spine-scan precedent.
emit_capped() {
  awk -v key="$1" -v cap="$2" '
    $0 != "" { n++; if (n <= cap) s = (s == "" ? $0 : s "," $0) }
    END {
      print key "_count=" n+0
      if (n > cap) s = s " ...(+" n-cap " more)"
      print key "=" s
    }'
}

# --- stamped state (migrate runs once: a stamped root is never re-migrated) ---
sh "$DIR/install-block.sh" read "$ROOT" | grep -E '^(door|stamped|malformed)=' || true

# --- clean tree ---
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "git_repo=1"
  porcelain=$(git status --porcelain 2>/dev/null || true)
  if [ -z "$porcelain" ]; then echo "tree_clean=1"; else echo "tree_clean=0"; fi
  echo "dirty_count=$(printf '%s' "$porcelain" | awk 'NF{n++} END{print n+0}')"
  # --- linked worktrees (any beyond the main checkout) ---
  git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10)}' \
    | awk -v main="$ROOT" '$0 != main' | emit_capped linked_worktrees 20
else
  echo "git_repo=0"
  echo "tree_clean="
  echo "dirty_count="
  echo "linked_worktrees_count=0"
  echo "linked_worktrees="
fi

# --- active in-place streams (workstream registry: .workstreams/<stream>/WORKSTREAM.md) ---
for f in "$ROOT"/.workstreams/*/WORKSTREAM.md; do
  [ -f "$f" ] || continue
  if grep -qE '^- isolation: *in-place' "$f"; then
    basename "$(dirname "$f")"
  fi
done | emit_capped inplace_streams 20

# --- whole-installation duplicate-ID scan ---
# Definition-shaped occurrences of typed-ID tokens (heading line, bullet start, or an
# `id:`/`alias:` frontmatter key) across tracked markdown, archives included. An ID
# "defined" in two or more files is a collision fact the mapping table must resolve
# before aliases are minted. Citations mid-prose are not definitions and do not count.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git ls-files --cached --others --exclude-standard -- '*.md' 2>/dev/null \
    | while IFS= read -r mf; do [ -f "$mf" ] && printf '%s\n' "$mf"; done \
    | tr '\n' '\0' | xargs -0 awk '
      function scan(s,   pre) {
        if (match(s, /(INV|POL|TK|G|T|I|B|N|F)-[0-9A-Za-z][0-9A-Za-z-]*/)) {
          pre = (RSTART > 1) ? substr(s, RSTART - 1, 1) : " "
          if (pre !~ /[0-9A-Za-z-]/) print substr(s, RSTART, RLENGTH) "\t" FILENAME
        }
      }
      /^#/            { scan($0) }
      /^- /           { scan($0) }
      /^(id|alias): / { scan($0) }
    ' 2>/dev/null | sort -u | awk -F'\t' '
      { if (files[$1] != "") dup[$1] = 1; files[$1] = files[$1] (files[$1] == "" ? "" : "+") $2 }
      END { for (id in dup) print id ":" files[id] }
    ' | sort | emit_capped dup_ids 20
else
  echo "dup_ids_count=0"
  echo "dup_ids="
fi
