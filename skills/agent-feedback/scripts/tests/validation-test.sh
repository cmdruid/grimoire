#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/agent-feedback-validation.XXXXXX")"
trap 'rm -rf "$T"' EXIT

repeat_text() {
  local text="$1" count="$2" result="" i
  for ((i=0; i<count; i++)); do result+="$text"; done
  printf '%s' "$result"
}

capture_fields() {
  local home="$1" origin="$2" invocation="$3" summary="$4" statement="$5"
  local incident="$6" consequence="$7" suggestion="$8"
  HOME="$home" "$PROVIDER" capture --origin "$origin" --subject-type skill --subject architect \
    --subject-ref unknown --invocation "$invocation" --kind friction --summary "$summary" \
    --statement "$statement" --incident "$incident" --consequence "$consequence" \
    --suggestion "$suggestion" --redacted no
}

# Every text maximum is inclusive, byte-based, and rejects one byte beyond it
# without changing the store.
H="$T/limits"; new_home "$H"
short_max="$(repeat_text x 240)"; statement_max="$(repeat_text x 4000)"; detail_max="$(repeat_text x 2000)"
capture_fields "$H" agent "$short_max" "$short_max" "$statement_max" "$detail_max" "$detail_max" "$detail_max" >/dev/null
F="$(store_for "$H")"; [ "$(awk 'END{print NR-1}' "$F")" = 1 ] && pass || fail 'maximum capture count'
for field in invocation summary statement incident consequence suggestion; do
  cp "$F" "$T/$field.before"
  invocation=x; summary=x; statement=x; incident=x; consequence=x; suggestion=x
  case "$field" in
    invocation|summary) printf -v "$field" '%s' "$(repeat_text x 241)" ;;
    statement) printf -v "$field" '%s' "$(repeat_text x 4001)" ;;
    *) printf -v "$field" '%s' "$(repeat_text x 2001)" ;;
  esac
  no capture_fields "$H" agent "$invocation" "$summary" "$statement" "$incident" "$consequence" "$suggestion"
  same "$F" "$T/$field.before"
done

H="$T/multibyte"; new_home "$H"
utf8_240="$(repeat_text 'é' 120)"
capture_fields "$H" agent x "$utf8_240" x x x x >/dev/null
F="$(store_for "$H")"; cp "$F" "$T/multibyte.before"
no capture_fields "$H" agent x "${utf8_240}a" x x x x
same "$F" "$T/multibyte.before"

subject_max="$(repeat_text a 120)"; subject_long="${subject_max}a"
ok env HOME="$H" "$PROVIDER" capture --origin human --subject-type skill --subject "$subject_max" \
  --subject-ref unknown --invocation x --kind request --summary x --statement x \
  --incident '' --consequence '' --suggestion '' --redacted no
F="$(store_for "$H")"; cp "$F" "$T/subject.before"
no env HOME="$H" "$PROVIDER" capture --origin human --subject-type skill --subject "$subject_long" \
  --subject-ref unknown --invocation x --kind request --summary x --statement x \
  --incident '' --consequence '' --suggestion '' --redacted no
same "$F" "$T/subject.before"

# Human details may be empty; agent details may not. Every enum is enforced.
H="$T/conditional"; new_home "$H"; capture_fields "$H" human x x x '' '' '' >/dev/null
F="$(store_for "$H")"; cp "$F" "$T/conditional.before"
no capture_fields "$H" agent x x x '' x x
for bad in bot HUMAN; do no env HOME="$H" "$PROVIDER" capture --origin "$bad" --subject-type skill --subject architect --subject-ref unknown --invocation x --kind friction --summary x --statement x --incident x --consequence x --suggestion x --redacted no; done
for bad in package project other; do no env HOME="$H" "$PROVIDER" capture --origin human --subject-type "$bad" --subject architect --subject-ref unknown --invocation x --kind friction --summary x --statement x --incident '' --consequence '' --suggestion '' --redacted no; done
old_kind="new-${SKILL##*-}"
for bad in "$old_kind" praise other; do no env HOME="$H" "$PROVIDER" capture --origin human --subject-type skill --subject architect --subject-ref unknown --invocation x --kind "$bad" --summary x --statement x --incident '' --consequence '' --suggestion '' --redacted no; done
same "$F" "$T/conditional.before"

# Declared escapes and UTF-8 round-trip exactly; undeclared controls and
# malformed UTF-8 refuse atomically.
H="$T/encoding"; new_home "$H"; special=$'\\\t\r\né'
capture_fields "$H" agent "$special" x "$special" x x x >/dev/null
F="$(store_for "$H")"
HOME="$H" "$PROVIDER" query >"$T/encoding.out"
has "$T/encoding.out" "invocation=$special"
has "$T/encoding.out" "statement=$special"
bad_control=$'\001'; cp "$F" "$T/control.before"
no capture_fields "$H" agent "$bad_control" x x x x x
invalid_utf8="$(printf '\377')"
no capture_fields "$H" agent x "$invalid_utf8" x x x x
same "$F" "$T/control.before"

# References reject absolute/traversal forms and conditional close references
# are enforced.
for ref in /private/path '..' ../path path/../secret 'C:\Users\name' '\\server\share'; do
  no env HOME="$H" "$PROVIDER" capture --origin human --subject-type skill --subject architect \
    --subject-ref "$ref" --invocation x --kind request --summary x --statement x \
    --incident '' --consequence '' --suggestion '' --redacted no
done
safe_ref="$(repeat_text r 512)"; long_ref="${safe_ref}r"
ok env HOME="$H" "$PROVIDER" capture --origin human --subject-type skill --subject architect \
  --subject-ref "$safe_ref" --invocation x --kind request --summary x --statement x \
  --incident '' --consequence '' --suggestion '' --redacted no
cp "$F" "$T/ref.before"
no env HOME="$H" "$PROVIDER" capture --origin human --subject-type skill --subject architect \
  --subject-ref "$long_ref" --invocation x --kind request --summary x --statement x \
  --incident '' --consequence '' --suggestion '' --redacted no
no env HOME="$H" "$PROVIDER" capture --origin human --subject-type skill --subject architect \
  --subject-ref unknown --invocation x --kind request --summary x --statement x \
  --incident '' --consequence '' --suggestion '' --redacted maybe
no env HOME="$H" "$PROVIDER" capture --origin human --subject-type skill --subject architect \
  --subject-ref unknown --invocation x --kind request --summary x --statement x \
  --incident '' --consequence '' --suggestion '' --redacted no --project-ref local-sha256:short
same "$F" "$T/ref.before"
id="$(awk -F '\t' 'NR==2{print $1}' "$F")"
no env HOME="$H" "$PROVIDER" close --id "$id" --as duplicate --reason Same
ok env HOME="$H" "$PROVIDER" close --id "$id" --as duplicate --reason Same --result-ref AF-20260903T120000Z-deadbeef

H="$T/close-limits"; new_home "$H"; capture_human "$H" >"$T/close-limit-capture"
id="$(sed -n 's/^captured=//p' "$T/close-limit-capture")"; F="$(store_for "$H")"
result_max="$(repeat_text r 2000)"; result_long="${result_max}r"; resolution_max="$(repeat_text x 2000)"
ok env HOME="$H" "$PROVIDER" close --id "$id" --as declined --reason "$resolution_max" --result-ref "$result_max"
H="$T/close-over"; new_home "$H"; capture_human "$H" >"$T/close-over-capture"
id="$(sed -n 's/^captured=//p' "$T/close-over-capture")"; F="$(store_for "$H")"; cp "$F" "$T/close-over.before"
no env HOME="$H" "$PROVIDER" close --id "$id" --as declined --reason "${resolution_max}x"
no env HOME="$H" "$PROVIDER" close --id "$id" --as declined --reason x --result-ref "$result_long"
same "$F" "$T/close-over.before"

# Whole-store validation precedes filtering and mutation. Representative
# malformed 20-column rows, the encoded row ceiling, and invalid UTF-8 leave
# incumbent bytes untouched.
for mutation in bad-id bad-created bad-subject bad-kind bad-lifecycle open-time-drift \
  unknown-detail-escape dangling-detail-escape duplicate-id missing-column extra-column \
  missing-final-newline over-row invalid-utf8 control-byte; do
  M="$T/malformed-$mutation"; new_home "$M"; capture_human "$M" >/dev/null; MF="$(store_for "$M")"
  case "$mutation" in
    bad-id) awk -F '\t' 'BEGIN{OFS="\t"}NR==1{print;next}{$1="AF-20261340T250061Z-deadbeef";print}' "$MF" >"$T/mutant" ;;
    bad-created) awk -F '\t' 'BEGIN{OFS="\t"}NR==1{print;next}{$2="2023-02-29T12:00:00Z";$3=$2;print}' "$MF" >"$T/mutant" ;;
    bad-subject) awk -F '\t' 'BEGIN{OFS="\t"}NR==1{print;next}{$6="Bad";print}' "$MF" >"$T/mutant" ;;
    bad-kind) awk -F '\t' 'BEGIN{OFS="\t"}NR==1{print;next}{$9="other";print}' "$MF" >"$T/mutant" ;;
    bad-lifecycle) awk -F '\t' 'BEGIN{OFS="\t"}NR==1{print;next}{$17="closed";print}' "$MF" >"$T/mutant" ;;
    open-time-drift) awk -F '\t' 'BEGIN{OFS="\t"}NR==1{print;next}{$3="2000-01-01T00:00:00Z";print}' "$MF" >"$T/mutant" ;;
    unknown-detail-escape) awk -F '\t' 'BEGIN{OFS="\t"}NR==1{print;next}{$12="bad\\q";print}' "$MF" >"$T/mutant" ;;
    dangling-detail-escape) awk -F '\t' 'BEGIN{OFS="\t"}NR==1{print;next}{$12="bad\\";print}' "$MF" >"$T/mutant" ;;
    duplicate-id) cat "$MF" >"$T/mutant"; tail -n 1 "$MF" >>"$T/mutant" ;;
    missing-column) awk -F '\t' 'BEGIN{OFS="\t"}NR==1{print;next}{NF=19;print}' "$MF" >"$T/mutant" ;;
    extra-column) awk 'NR==1{print;next}{print $0 "\textra"}' "$MF" >"$T/mutant" ;;
    missing-final-newline) sed -n '1p' "$MF" >"$T/mutant"; printf '%s' "$(tail -n 1 "$MF")" >>"$T/mutant" ;;
    over-row) { printf '%s\n' "$HEADER"; printf 'AF-20260903T120000Z-deadbeef\t2026-09-03T12:00:00Z\t2026-09-03T12:00:00Z\thuman\tskill\tarchitect\tunknown\tx\trequest\tx\t'; repeat_text x 32600; printf '\t\t\t\tno\t\topen\t\t\t\n'; } >"$T/mutant" ;;
    invalid-utf8) cp "$MF" "$T/mutant"; printf '\377' >>"$T/mutant" ;;
    control-byte)
      row="$(tail -n 1 "$MF")"
      { sed -n '1p' "$MF"; printf '%s' "${row%%Please*}"; printf '\001'; printf '%s\n' "Please${row#*Please}"; } >"$T/mutant"
      ;;
  esac
  mv "$T/mutant" "$MF"; cp "$MF" "$T/$mutation.before"
  no env HOME="$M" "$PROVIDER" query
  no env HOME="$M" "$PROVIDER" close --id AF-20260903T120000Z-deadbeef --as stale --reason x
  same "$MF" "$T/$mutation.before"
done

finish validation-test
