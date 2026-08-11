#!/bin/sh
# face-test.sh -- the face-shape fixtures (plan Task 3): every verb path the SKILL.md
# router table cites resolves to a real file or directory, every verbs/**/*.md file is
# reachable from some row, every verb file living under a directory the router pairs
# with a hat opens with a resolving Hat: pointer, and roles/ holds exactly the hats the
# router names -- no extra, no missing. Reads the live bundle read-only, resolved
# relative to this script (never a hardcoded path), so the phantom-prep class (a router
# row naming a file that was never created) is now mechanically caught.
set -eu
DIR=$(CDPATH='' cd "$(dirname "$0")" && pwd -P)
. "$DIR/lib.sh"
pass=0; fail=0   # re-assigned by lib.sh's helpers (shellcheck cannot follow the source)
BUNDLE=$(CDPATH='' cd "$DIR/../.." && pwd -P)
SKILL_MD="$BUNDLE/SKILL.md"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/clankshop-face.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# ---- parse the router table only (the "| verb | hat | does |" table -- SKILL.md has a
# second, unrelated "| asset | where | is |" table further down) ----
awk '
  /^\| verb \| hat \| does \|/ { on = 1; next }
  on && /^\|---/ { next }
  on && /^\|/ { print; next }
  on { exit }
' "$SKILL_MD" > "$TMP/rows"

# For every row: collect every backtick span starting with "verbs/" (the row-cited
# paths), and pair any that name a DIRECTORY (trailing "/") with that row's hat column.
# An escaped pipe inside a backticked verb token (`verify tend\|judge`) would otherwise
# split into extra fields -- neutralize it before field-splitting.
: > "$TMP/paths"
: > "$TMP/dirhats"
: > "$TMP/hats"
while IFS= read -r row; do
  safe=$(printf '%s\n' "$row" | sed 's/\\|/@PIPE@/g')
  hat=$(printf '%s\n' "$safe" | awk -F'|' '{print $3}' | sed 's/^ *//; s/ *$//')
  printf '%s\n' "$hat" >> "$TMP/hats"
  for p in $(printf '%s\n' "$row" | grep -oE '`verbs/[^`]*`' | tr -d '`'); do
    printf '%s\n' "$p" >> "$TMP/paths"
    case "$p" in
      */) printf '%s\t%s\n' "$p" "$hat" >> "$TMP/dirhats" ;;
    esac
  done
done < "$TMP/rows"

# ---- assertion 1: no phantom routes -- every cited path exists on disk ----
missing=""
while IFS= read -r p; do
  [ -e "$BUNDLE/$p" ] || missing="$missing $p"
done < "$TMP/paths"
expect_eq "face: no phantom routes" "" "$missing"

# ---- assertion 2: no orphan verb files -- every verbs/**/*.md is reachable from some
# row, either named directly or living under a directory a row names ----
find "$BUNDLE/verbs" -name '*.md' | sort > "$TMP/verbfiles"
orphans=""
while IFS= read -r f; do
  rel=${f#"$BUNDLE"/}
  reachable=0
  grep -qxF "$rel" "$TMP/paths" && reachable=1
  if [ "$reachable" -eq 0 ]; then
    d=$(dirname "$rel")/
    grep -qxF "$d" "$TMP/paths" && reachable=1
  fi
  [ "$reachable" -eq 1 ] || orphans="$orphans $rel"
done < "$TMP/verbfiles"
expect_eq "face: no orphan verb files" "" "$orphans"

# ---- assertion 3: hat pointers resolve -- every verb file under a directory the router
# pairs with a hat opens with a "Hat: \`roles/<role>.md\`" line in its first 5 lines, and
# that roles/<role>.md exists. System verbs (setup/migrate/check -- no directory row, no
# hat) are never in $TMP/dirhats, so they are never required to carry one. ----
badhats=""
while IFS="$(printf '\t')" read -r d hat; do
  case "$hat" in
    ''|'—'|*' '*) continue ;;  # no hat, or a multi-word non-role value (e.g. ask's "the named hat")
  esac
  for vf in "$BUNDLE/$d"*.md; do
    [ -f "$vf" ] || continue
    relvf=${vf#"$BUNDLE"/}
    head -5 "$vf" | grep -qF "Hat: \`roles/$hat.md\`" || badhats="$badhats $relvf"
    [ -f "$BUNDLE/roles/$hat.md" ] || badhats="$badhats $relvf(roles/$hat.md-missing)"
  done
done < "$TMP/dirhats"
expect_eq "face: hatted verb files carry a resolving Hat pointer" "" "$badhats"

# ---- assertion 4: the hat set is closed -- roles/ holds exactly the router's hats ----
awk '$0 !~ /^(—)?$/ && $0 !~ / /' "$TMP/hats" | sort -u > "$TMP/hats.expected"
expected_hats=$(tr '\n' ' ' < "$TMP/hats.expected" | sed 's/ *$//')
actual_hats=$(for f in "$BUNDLE"/roles/*.md; do [ -f "$f" ] && basename "$f" .md; done | sort | tr '\n' ' ' | sed 's/ *$//')
expect_eq "face: hat set is closed" "$expected_hats" "$actual_hats"

echo "face: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
