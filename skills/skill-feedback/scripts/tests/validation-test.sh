#!/usr/bin/env bash
set -euo pipefail

HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/skill-feedback-validation.XXXXXX")"
trap 'rm -rf "$T"' EXIT

repeat_text() {
  local text="$1" count="$2" result="" i
  for ((i=0; i<count; i++)); do result+="$text"; done
  printf '%s' "$result"
}

capture_fields() {
  local home="$1" invocation="$2" summary="$3" incident="$4" consequence="$5" suggestion="$6"
  HOME="$home" "$PROVIDER" capture --skill architect --skill-ref unknown \
    --invocation "$invocation" --kind friction --summary "$summary" --incident "$incident" \
    --consequence "$consequence" --suggestion "$suggestion"
}

# Exact field maxima are accepted together; one byte beyond each maximum is
# rejected without changing the initialized store.
H="$T/field-limits"; new_home "$H"
short_max="$(repeat_text x 240)"
long_max="$(repeat_text x 2000)"
capture_fields "$H" "$short_max" "$short_max" "$long_max" "$long_max" "$long_max" >/dev/null
F="$(store_for "$H")"
[ "$(awk 'END{print NR-1}' "$F")" = 1 ] && pass || fail 'maximum field capture count'

for field in invocation summary incident consequence suggestion; do
  cp "$F" "$T/before-$field"
  invocation=x; summary=x; incident=x; consequence=x; suggestion=x
  case "$field" in
    invocation|summary) printf -v "$field" '%s' "$(repeat_text x 241)" ;;
    *) printf -v "$field" '%s' "$(repeat_text x 2001)" ;;
  esac
  no capture_fields "$H" "$invocation" "$summary" "$incident" "$consequence" "$suggestion"
  same "$F" "$T/before-$field"
done

# Limits are UTF-8 byte limits, not character counts.
H="$T/multibyte-limits"; new_home "$H"
utf8_240="$(repeat_text 'é' 120)"
capture_fields "$H" x "$utf8_240" x x x >/dev/null
F="$(store_for "$H")"
cp "$F" "$T/multibyte-before"
no capture_fields "$H" x "${utf8_240}a" x x x
same "$F" "$T/multibyte-before"

# Backslash, tab, CR, LF, and non-ASCII text round-trip exactly.
H="$T/encoding"; new_home "$H"
special=$'\\\t\r\né'
capture_fields "$H" "$special" x x x x >/dev/null
F="$(store_for "$H")"
encoded='\\\t\r\né'
[ "$(awk -F '\t' 'NR==2{print $6}' "$F")" = "$encoded" ] && pass || fail 'special text encoding'
HOME="$H" "$PROVIDER" query --format human >"$T/encoding-human"
id="$(awk -F '\t' 'NR==2{print $1}' "$F")"
created="$(awk -F '\t' 'NR==2{print $2}' "$F")"
{
  printf 'id=%s\n' "$id"
  printf 'created_at=%s\n' "$created"
  printf 'skill=architect\nskill_ref=unknown\n'
  printf 'invocation=%s\n' "$special"
  printf 'kind=friction\nsummary=x\nincident=x\nconsequence=x\nsuggestion=x\nstatus=open\n--\ncount=1\n'
} >"$T/encoding-expected"
same "$T/encoding-human" "$T/encoding-expected"

# Every raw text input rejects a non-encodable control byte while allowing the
# four characters with a declared escape.
bad_control=$'\001'
for field in invocation summary incident consequence suggestion; do
  H="$T/control-$field"; new_home "$H"
  HOME="$H" "$PROVIDER" init >/dev/null
  F="$(store_for "$H")"; cp "$F" "$T/control-$field.before"
  invocation=x; summary=x; incident=x; consequence=x; suggestion=x
  printf -v "$field" '%s' "$bad_control"
  no capture_fields "$H" "$invocation" "$summary" "$incident" "$consequence" "$suggestion"
  same "$F" "$T/control-$field.before"
done

# The encoded physical-row ceiling is inclusive at 8,192 bytes.
H="$T/row-limit"; new_home "$H"
backslash=$'\\'
slashes_240="$(repeat_text "$backslash" 240)"
slashes_2000="$(repeat_text "$backslash" 2000)"
slashes_1799="$(repeat_text "$backslash" 1799)"
capture_fields "$H" x "$slashes_240" "$slashes_2000" "$slashes_1799" x >/dev/null
F="$(store_for "$H")"
[ "$(tail -n 1 "$F" | wc -c | tr -d '[:space:]')" = 8192 ] && pass || fail '8,192-byte row rejected or mis-sized'
cp "$F" "$T/row-limit-before"
no capture_fields "$H" x "$slashes_240" "$slashes_2000" "${slashes_1799}x" x
same "$F" "$T/row-limit-before"

# Whole-file validation refuses representative malformed rows and preserves
# each incumbent byte-for-byte.
for mutation in bad-id-date bad-slug bad-kind overlong-summary inconsistent-resolved missing-column extra-column; do
  H="$T/malformed-$mutation"; new_home "$H"; capture_one "$H" architect friction >/dev/null
  F="$(store_for "$H")"
  case "$mutation" in
    bad-id-date)
      LC_ALL=C awk -F '\t' 'BEGIN{OFS="\t"}NR==1{print;next}{$1="SF-20261340T250061Z-12345678";print}' "$F" >"$T/mutant"
      ;;
    bad-slug)
      LC_ALL=C awk -F '\t' 'BEGIN{OFS="\t"}NR==1{print;next}{$4="Bad";print}' "$F" >"$T/mutant"
      ;;
    bad-kind)
      LC_ALL=C awk -F '\t' 'BEGIN{OFS="\t"}NR==1{print;next}{$7="other";print}' "$F" >"$T/mutant"
      ;;
    overlong-summary)
      LC_ALL=C awk -F '\t' -v bad="$(repeat_text x 241)" 'BEGIN{OFS="\t"}NR==1{print;next}{$8=bad;print}' "$F" >"$T/mutant"
      ;;
    inconsistent-resolved)
      LC_ALL=C awk -F '\t' 'BEGIN{OFS="\t"}NR==1{print;next}{$13="resolved";print}' "$F" >"$T/mutant"
      ;;
    missing-column)
      LC_ALL=C awk -F '\t' 'BEGIN{OFS="\t"}NR==1{print;next}{NF=15;print}' "$F" >"$T/mutant"
      ;;
    extra-column)
      LC_ALL=C awk 'NR==1{print;next}{print $0 "\textra"}' "$F" >"$T/mutant"
      ;;
  esac
  mv "$T/mutant" "$F"
  cp "$F" "$T/$mutation.before"
  no env HOME="$H" "$PROVIDER" query
  same "$F" "$T/$mutation.before"
done

# A physical NUL in an incumbent row is invalid even though shell arguments
# cannot carry NUL bytes.
H="$T/nul-store"; new_home "$H"; capture_one "$H" architect friction >/dev/null
F="$(store_for "$H")"
row="$(tail -n 1 "$F")"
prefix="${row%%A concrete*}"
suffix="${row#*A concrete}"
{ printf '%s\n' "$HEADER"; printf '%s' "$prefix"; printf '\0'; printf 'A concrete%s\n' "$suffix"; } >"$T/nul.tsv"
mv "$T/nul.tsv" "$F"
cp "$F" "$T/nul.before"
no env HOME="$H" "$PROVIDER" query
same "$F" "$T/nul.before"

finish validation-test
