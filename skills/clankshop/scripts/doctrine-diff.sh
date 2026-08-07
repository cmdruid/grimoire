#!/bin/sh
# doctrine-diff.sh <root> [-d <doctrine-dir>] [key=value ...] -- the three-way differ
# (plan Appendix J). For every provenance-stamped handbook entry, retrieve its base per
# the ratified retrieval rule (doctrine/BASES.md header: oldest qualifying base block,
# else the live entry -- with bump-record coverage so a missing block is a missing-base
# fact, never a silent live fallback), normalize per shape (the canonical comparison
# input: an INV line minus its trailing marker; a heading entry minus its origin lines;
# a whole-file asset minus its entire declaration block), and classify into the six
# states. Facts only -- the calibrator owns the offer/apply judgment.
#
# key=value pairs are the project's parameter-slot values (gate="make test" trunk=main):
# doctrine and base bodies have their <key> slots forward-filled before comparison, so a
# freshly seeded, slot-filled entry classifies *unchanged*.
#
# Output, one line per origin:
#   state:<origin>@v<N>=<unchanged|locally-edited|upstream-updated|conflict|upstream-retired>
#   state:<origin>=locally-deleted        (a seedable origin with no deployed stamp --
#                                          opted-out or deleted; the calibrator judges)
#   missing-base=<origin>@v<N>            (bump-record-covered origin, no base block)
set -eu
ROOT=$1; shift
ROOT=$(CDPATH='' cd "$ROOT" && pwd)
DIR=$(CDPATH='' cd "$(dirname "$0")" && pwd -P)
DOCTRINE=$DIR/../doctrine
if [ "${1:-}" = "-d" ]; then
  DOCTRINE=$(CDPATH='' cd "$2" && pwd); shift 2
fi
TMP=$(mktemp -d "${TMPDIR:-/tmp}/clankshop-diff.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# Parameter slots: each remaining arg is key=value; store for fill_params.
: > "$TMP/params"
for kv in "$@"; do
  printf '%s\n' "$kv" >> "$TMP/params"
done

SRC=$(awk '/^doctrine: /{print $2; exit}' "$DOCTRINE/README.md")
DV=$(awk '/^doctrine-version: /{print $2; exit}' "$DOCTRINE/README.md")
echo "doctrine=$SRC"
echo "doctrine_version=$DV"

# fill_params: stdin -> stdout with every <key> slot replaced by its project value.
fill_params() {
  awk '
    NR == FNR { eq = index($0, "="); if (eq > 1) { k[++n] = substr($0, 1, eq - 1); v[n] = substr($0, eq + 1) } ; next }
    {
      for (i = 1; i <= n; i++) {
        needle = "<" k[i] ">"
        out = ""
        s = $0
        while ((p = index(s, needle)) > 0) {
          out = out substr(s, 1, p - 1) v[i]
          s = substr(s, p + length(needle))
        }
        $0 = out s
      }
      print
    }
  ' "$TMP/params" -
}

# strip_decl: stdin -> stdout minus the first spine-doc/spine-index HTML comment block,
# minus leading/trailing blank lines (the whole-file canonical comparison input).
strip_decl() {
  awk '
    !cut && /^<!-- spine-(doc|index) v[0-9]+$/ { cut = 1; next }
    cut == 1 { if ($0 == "-->") cut = 2; next }
    { print }
  ' | awk 'NF { go = 1 } go { print }' | awk '{ l[NR] = $0; if (NF) last = NR } END { for (i = 1; i <= last; i++) print l[i] }'
}

# strip_origin_lines: heading-entry canonical input -- minus origin:/origin-version:/
# origin-parent: lines.
strip_origin_lines() { grep -vE '^origin(-version|-parent)?: ' || true; }

# Fence-stripped base archive.
if [ -f "$DOCTRINE/BASES.md" ]; then
  awk '/^[ ]*(```|~~~)/{f=!f;next} f{next} {print}' "$DOCTRINE/BASES.md" > "$TMP/bases"
else
  : > "$TMP/bases"
fi

# base_block <origin> <minversion>: body of the OLDEST base block with version >= min;
# rc 1 if none.
base_block() {
  awk -v o="$1" -v minv="$2" '
    index($0, "<!-- base " o " @v") == 1 {
      v = $0; sub(/^.*@v/, "", v); sub(/ -->.*$/, "", v)
      if (v + 0 >= minv + 0 && (best == 0 || v + 0 < best)) { best = v + 0 }
    }
    END { exit best ? 0 : 1 }
  ' "$TMP/bases" || return 1
  bv=$(awk -v o="$1" -v minv="$2" '
    index($0, "<!-- base " o " @v") == 1 {
      v = $0; sub(/^.*@v/, "", v); sub(/ -->.*$/, "", v)
      if (v + 0 >= minv + 0 && (best == 0 || v + 0 < best)) best = v + 0
    }
    END { print best }
  ' "$TMP/bases")
  awk -v tag="<!-- base $1 @v$bv -->" '
    $0 == tag { f = 1; next }
    f && /^<!-- \/base -->$/ { exit }
    f { print }
  ' "$TMP/bases"
}

# bump_covers <origin> <minversion>: rc 0 if some bump record vK with K > min names it.
bump_covers() {
  awk -v o="$1" -v minv="$2" '
    match($0, /^<!-- bump v[0-9]+:/) {
      v = $0; sub(/^<!-- bump v/, "", v); sub(/:.*$/, "", v)
      if (v + 0 > minv + 0) {
        s = $0; sub(/^<!-- bump v[0-9]+: */, "", s); sub(/ *-->.*$/, "", s)
        n = split(s, os, " ")
        for (i = 1; i <= n; i++) if (os[i] == o) found = 1
      }
    }
    END { exit found ? 0 : 1 }
  ' "$TMP/bases"
}

# get_base <origin> <version> <outfile>: the ratified retrieval -- oldest qualifying
# block; else missing-base when a bump record covers the origin; else the live doctrine
# body (rc 2 = missing-base, rc 1 = no live body either).
get_base() {
  if base_block "$1" "$2" > "$3" 2>/dev/null && [ -s "$3" ]; then return 0; fi
  if bump_covers "$1" "$2"; then return 2; fi
  live_body "$1" > "$3" || return 1
  [ -s "$3" ] || return 1
  return 0
}

# live_body <origin>: the current doctrine body for an origin, canonical form (rc 1 when
# the origin no longer exists upstream).
live_body() {
  short=${1#"$SRC":}
  case "$short" in
    workflows/*|testing/*)
      [ -f "$DOCTRINE/$short.md" ] || return 1
      strip_decl < "$DOCTRINE/$short.md" ;;
    *)
      id=$short
      hit=""
      for f in "$DOCTRINE"/rules/*.md; do
        [ -f "$f" ] || continue
        if grep -qE "^(#+ )?\(?$id\)?:" "$f" 2>/dev/null || grep -qE "^#+ .*\b$id\b" "$f" 2>/dev/null || grep -qE "^$id:" "$f" 2>/dev/null; then hit=$f; break; fi
      done
      [ -n "$hit" ] || return 1
      if grep -qE "^$id:" "$hit"; then
        grep -E "^$id:" "$hit" | head -1
      else
        # heading entry: span from its heading to the next heading of <= rank / EOF
        awk -v id="$id" '
          !on && $0 ~ "^#+ " && index($0, id ":") { on = 1; rank = length($1); print; next }
          on && $0 ~ "^#+ " { r = length($1); if (r <= rank) exit }
          on { print }
        ' "$hit"
      fi ;;
  esac
}

# ---------- enumerate deployed provenance-stamped entries ----------
# Line entries (markers), heading entries (origin keys), whole-file assets (declaration
# keys) across the deployed handbook.
: > "$TMP/deployed"      # lines: <origin>\t<version>\t<shape>\t<file>
for f in "$ROOT"/.handbook/*/*.md "$ROOT"/.handbook/*.md; do
  [ -f "$f" ] || continue
  # whole-file: declaration carries origin: + origin-version:
  ov=$(awk '
    !in_b && /^<!-- spine-(doc|index) v[0-9]+$/ { in_b = 1; next }
    in_b && /^-->$/ { exit }
    in_b && /^origin: /         { o = $2 }
    in_b && /^origin-version: / { v = $2 }
    END { if (o != "" && v != "") print o "\t" v }
  ' "$f")
  if [ -n "$ov" ]; then
    printf '%s\t%s\t%s\n' "$ov" wholefile "$f" >> "$TMP/deployed"
    continue
  fi
  # line entries: provenance markers
  grep -oE "⟨[^ ⟩]+ @v[0-9]+( parent:[^⟩]*)?⟩" "$f" 2>/dev/null \
    | sed -E "s/^⟨([^ ⟩]+) @v([0-9]+).*⟩$/\1	\2/" \
    | while IFS="$(printf '\t')" read -r o v; do
        [ -n "$o" ] && printf '%s\t%s\t%s\t%s\n' "$o" "$v" line "$f"
      done >> "$TMP/deployed"
  # heading entries: origin:/origin-version: lines in the body (not in a declaration)
  awk -v file="$f" '
    /^<!-- spine-(doc|index) v[0-9]+$/ { in_b = 1 }
    in_b && /^-->$/ { in_b = 0; next }
    in_b { next }
    /^#+ / { heading = $0 }
    /^origin: / { o = $2 }
    /^origin-version: / { if (o != "" && heading != "") { print o "\t" $2 "\theading\t" file; o = "" } }
  ' "$f" >> "$TMP/deployed"
done
sort -u "$TMP/deployed" > "$TMP/deployed.s" && mv "$TMP/deployed.s" "$TMP/deployed"

# ---------- classify each deployed entry ----------
while IFS="$(printf '\t')" read -r origin version shape file; do
  [ -n "$origin" ] || continue
  # deployed canonical body
  case "$shape" in
    line)
      grep -F "⟨$origin @v$version" "$file" | head -1 \
        | sed -E "s/ *⟨[^⟩]*⟩//" > "$TMP/d" ;;
    heading)
      id=${origin#"$SRC":}
      awk -v id="$id" '
        !on && $0 ~ "^#+ " && index($0, id ":") { on = 1; rank = length($1); print; next }
        on && $0 ~ "^#+ " { r = length($1); if (r <= rank) exit }
        on { print }
      ' "$file" | strip_origin_lines > "$TMP/d" ;;
    wholefile)
      strip_decl < "$file" > "$TMP/d" ;;
  esac
  # upstream current body (canonical, slots filled)
  if live_body "$origin" > "$TMP/c.raw" 2>/dev/null && [ -s "$TMP/c.raw" ]; then
    fill_params < "$TMP/c.raw" > "$TMP/c"
  else
    echo "state:$origin@v$version=upstream-retired"
    continue
  fi
  # base body per the retrieval rule
  rc=0
  get_base "$origin" "$version" "$TMP/b.raw" || rc=$?
  if [ "$rc" = 2 ]; then
    echo "missing-base=$origin@v$version"
    continue
  elif [ "$rc" != 0 ]; then
    echo "missing-base=$origin@v$version"
    continue
  fi
  fill_params < "$TMP/b.raw" > "$TMP/b"
  if cmp -s "$TMP/d" "$TMP/c"; then
    echo "state:$origin@v$version=unchanged"
  elif cmp -s "$TMP/d" "$TMP/b"; then
    echo "state:$origin@v$version=upstream-updated"
  elif cmp -s "$TMP/c" "$TMP/b"; then
    echo "state:$origin@v$version=locally-edited"
  else
    echo "state:$origin@v$version=conflict"
  fi
done < "$TMP/deployed"

# ---------- locally deleted: seedable doctrine origins with no deployed stamp ----------
{
  # line/heading entries from the entry-bearing rules chapters
  for f in "$DOCTRINE"/rules/*.md; do
    [ -f "$f" ] || continue
    ids=$(awk '
      !in_b && /^<!-- spine-doc v[0-9]+$/ { in_b = 1; next }
      in_b && /^-->$/ { exit }
      in_b && /^ids: / { print $2 }
    ' "$f")
    [ -n "$ids" ] || continue
    grep -oE "^(#+ )?\(?$ids-[0-9A-Za-z][0-9A-Za-z-]*\)?:" "$f" 2>/dev/null \
      | grep -oE "$ids-[0-9A-Za-z][0-9A-Za-z-]*" || true
  done
  # whole-file assets
  for f in "$DOCTRINE"/workflows/*.md "$DOCTRINE"/testing/*.md; do
    [ -f "$f" ] || continue
    rel=${f#"$DOCTRINE"/}
    echo "${rel%.md}"
  done
} | sort -u | while IFS= read -r short; do
  [ -n "$short" ] || continue
  origin=$SRC:$short
  grep -q "^$origin	" "$TMP/deployed" || echo "state:$origin=locally-deleted"
done
