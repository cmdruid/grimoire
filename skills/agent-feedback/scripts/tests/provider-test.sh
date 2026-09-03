#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/agent-feedback-provider.XXXXXX")"
trap 'rm -rf "$T"' EXIT

# The Slice 2 tracer is deliberately end-to-end: an empty home, one explicit
# human submission, the default page, one close, then the closed page.
H="$T/lifecycle"; new_home "$H"
capture_human "$H" >"$T/capture"
id="$(sed -n 's/^captured=//p' "$T/capture")"
case "$id" in AF-*) pass ;; *) fail 'capture did not return an AF- ID' ;; esac
printf 'captured=%s\ncount=1\nredacted=no\n' "$id" >"$T/capture.expected"
same "$T/capture" "$T/capture.expected"
F="$(store_for "$H")"
[ "$(sed -n '1p' "$F")" = "$HEADER" ] && pass || fail 'wrong canonical header'
[ "$(awk -F '\t' 'NR==2{print NF}' "$F")" = 20 ] && pass || fail 'capture row is not 20 columns'

HOME="$H" "$PROVIDER" query >"$T/open"
created="$(awk -F '\t' 'NR==2{print $2}' "$F")"
printf '%s\n' "id=$id" "created_at=$created" "updated_at=$created" 'origin=human' \
  'subject_type=skill' 'subject=architect' 'subject_ref=unknown' \
  'invocation=/agent-feedback capture' 'kind=request' \
  'summary=Please clarify the ambiguous setup step.' \
  'statement=Please clarify the ambiguous setup step.' 'incident=' 'consequence=' 'suggestion=' \
  'redacted=no' 'status=open' 'disposition=' 'resolution=' 'result_ref=' '--' >"$T/open.expected"
same "$T/open" "$T/open.expected"
if grep -q '^count=' "$T/open"; then fail 'query emitted a count trailer'; else pass; fi

# Closing changes lifecycle fields only, and an exact repeat is idempotent.
awk -F '\t' 'BEGIN{OFS="\t"}NR==2{for(i=1;i<=20;i++)if(i!=3&&i<17)printf "%s%s",$i,(i==16?"\n":OFS)}' "$F" >"$T/nonlife.before"
HOME="$H" "$PROVIDER" close --id "$id" --as declined --reason 'Deferred intentionally.' >"$T/close"
printf 'closed=%s\ncount=1\n' "$id" >"$T/close.expected"
same "$T/close" "$T/close.expected"
awk -F '\t' 'BEGIN{OFS="\t"}NR==2{for(i=1;i<=20;i++)if(i!=3&&i<17)printf "%s%s",$i,(i==16?"\n":OFS)}' "$F" >"$T/nonlife.after"
same "$T/nonlife.before" "$T/nonlife.after"
HOME="$H" "$PROVIDER" query --status closed >"$T/closed"
for line in "id=$id" 'status=closed' 'disposition=declined' 'resolution=Deferred intentionally.'; do has "$T/closed" "$line"; done
if grep -q '^count=' "$T/closed"; then fail 'closed query emitted a count trailer'; else pass; fi
cp "$F" "$T/before-repeat"
HOME="$H" "$PROVIDER" close --id "$id" --as declined --reason 'Deferred intentionally.' >"$T/repeat"
printf 'unchanged=%s\ncount=1\n' "$id" >"$T/repeat.expected"
same "$T/repeat" "$T/repeat.expected"; same "$F" "$T/before-repeat"
no env HOME="$H" "$PROVIDER" close --id "$id" --as stale --reason Different
same "$F" "$T/before-repeat"

# Describe is exact and side-effect free; invalid grammar is rejected before
# path resolution or initialization.
NOHOME="$T/not-created"
HOME="$NOHOME" "$PROVIDER" describe >"$T/describe"
printf '%s\n' 'schema=agent-feedback@1' \
  'store=.agents/skilldata/agent-feedback/feedback.tsv' \
  'commands=describe,init,capture,query,close' >"$T/describe.expected"
same "$T/describe" "$T/describe.expected"
[ ! -e "$NOHOME" ] && pass || fail 'describe touched HOME'
for args in 'bogus' 'init extra' 'query --status' 'query --status open --status closed' \
  'query --format human --include-project-ref' \
  'capture --origin human --origin agent' \
  'close --id nope --id nope --as stale --reason x'; do
  # Word splitting is intentional: these fixtures contain no spaces in values.
  # shellcheck disable=SC2086
  if HOME="$NOHOME" "$PROVIDER" $args >"$T/out" 2>"$T/err"; then fail "accepted grammar: $args"; else pass; fi
  has "$T/err" 'reason=usage action=check-command'
done
[ ! -e "$NOHOME" ] && pass || fail 'invalid grammar initialized HOME'

# Init is absent-only, byte preserving, and tightens only owned modes.
I="$T/init"; new_home "$I"; mkdir -m 755 "$I/.agents" "$I/.agents/skilldata"
HOME="$I" "$PROVIDER" init >"$T/init.out"
has "$T/init.out" 'status=ready'
IF="$(store_for "$I")"; cp "$IF" "$T/header-only"
HOME="$I" "$PROVIDER" init >/dev/null; same "$IF" "$T/header-only"
[ "$(mode_of "$I/.agents")" = 755 ] && pass || fail 'init changed shared .agents mode'
[ "$(mode_of "$I/.agents/skilldata")" = 755 ] && pass || fail 'init changed shared skilldata mode'
[ "$(mode_of "$I/.agents/skilldata/agent-feedback")" = 700 ] && pass || fail 'wrong owned mode'
[ "$(mode_of "$IF")" = 600 ] && pass || fail 'wrong store mode'

# TSV output hides project provenance by default and exposes it only through
# the explicit TSV-only flag. Filters and page order stay provider-owned.
P="$T/provenance"; new_home "$P"
AGENT_FEEDBACK_TEST_UTC_NOW=2026-09-03T10:00:00Z capture_agent "$P" architect friction local-sha256:0123456789abcdef >"$T/p1"
AGENT_FEEDBACK_TEST_UTC_NOW=2026-09-03T11:00:00Z capture_human "$P" debugger win >"$T/p2"
HOME="$P" "$PROVIDER" query --format tsv --limit 100 >"$T/public.tsv"
[ "$(awk -F '\t' 'NR>1&&$16!=""{n++}END{print n+0}' "$T/public.tsv")" = 0 ] && pass || fail 'project ref leaked'
HOME="$P" "$PROVIDER" query --format tsv --include-project-ref --origin agent >"$T/private.tsv"
[ "$(awk -F '\t' 'NR==2{print $16}' "$T/private.tsv")" = local-sha256:0123456789abcdef ] && pass || fail 'project ref missing'
HOME="$P" "$PROVIDER" query --subject debugger --order oldest >"$T/filter"
has "$T/filter" 'subject=debugger'; no grep -qF 'subject=architect' "$T/filter"

# Missing, conditional, malformed, and conflicting close requests never mutate.
cp "$(store_for "$P")" "$T/close-refusal.before"
agent_id="$(sed -n 's/^captured=//p' "$T/p1")"
no env HOME="$P" "$PROVIDER" close --id "$agent_id" --as addressed --reason Done
no env HOME="$P" "$PROVIDER" close --id AF-20000101T000000Z-deadbeef --as stale --reason Missing
no env HOME="$P" "$PROVIDER" close --id "$agent_id" --as declined --reason Done --result-ref /private/result
same "$(store_for "$P")" "$T/close-refusal.before"

# A predecessor store is inert and malformed incumbents are preserved.
O="$T/old-store"; new_home "$O"; old_prefix=skill; old_suffix=feedback; old_owner="$old_prefix-$old_suffix"
mkdir -p "$O/.agents/skilldata/$old_owner"
printf 'predecessor bytes\n' >"$O/.agents/skilldata/$old_owner/feedback.tsv"
HOME="$O" "$PROVIDER" init >/dev/null
has "$O/.agents/skilldata/$old_owner/feedback.tsv" 'predecessor bytes'
M="$T/malformed"; new_home "$M"; mkdir -p "$M/.agents/skilldata/agent-feedback"
printf 'bad\n' >"$(store_for "$M")"; cp "$(store_for "$M")" "$T/malformed.before"
no env HOME="$M" "$PROVIDER" init
same "$(store_for "$M")" "$T/malformed.before"

# Every origin, subject type, and kind crosses the provider without inference.
capture_matrix() {
  local home="$1" origin="$2" subject_type="$3" subject="$4" kind="$5" now="$6"
  HOME="$home" AGENT_FEEDBACK_TEST_UTC_NOW="$now" "$PROVIDER" capture \
    --origin "$origin" --subject-type "$subject_type" --subject "$subject" \
    --subject-ref "version/$subject" --invocation "matrix/$subject" --kind "$kind" \
    --summary "Summary for $subject." --statement "Statement for $subject." \
    --incident "Incident for $subject." --consequence "Consequence for $subject." \
    --suggestion "Suggestion for $subject." --redacted no
}
Q="$T/query-matrix"; new_home "$Q"
capture_matrix "$Q" agent skill architect friction 2026-09-03T01:00:00Z >"$T/q1"
capture_matrix "$Q" human agent coding-agent gap 2026-09-03T02:00:00Z >"$T/q2"
capture_matrix "$Q" agent harness codex-harness win 2026-09-03T03:00:00Z >"$T/q3"
capture_matrix "$Q" human tool patch-tool request 2026-09-03T04:00:00Z >"$T/q4"
capture_matrix "$Q" agent workflow release-workflow friction 2026-09-03T05:00:00Z >"$T/q5"
QF="$(store_for "$Q")"
[ "$(awk -F '\t' 'NR>1{origins[$4]=1;types[$5]=1;kinds[$9]=1}END{for(x in origins)o++;for(x in types)t++;for(x in kinds)k++;print o,t,k}' "$QF")" = '2 5 4' ] && pass || fail 'origin/subject/kind matrix'

# Query defaults, every filter, both orders and bounds, and exact empty forms.
HOME="$Q" "$PROVIDER" query --format tsv --limit 100 >"$T/q-newest.tsv"
[ "$(awk -F '\t' 'NR==2{print $6}' "$T/q-newest.tsv")" = release-workflow ] && pass || fail 'newest order'
HOME="$Q" "$PROVIDER" query --format tsv --order oldest --limit 1 >"$T/q-oldest.tsv"
[ "$(awk -F '\t' 'NR==2{print $6}' "$T/q-oldest.tsv")" = architect ] && [ "$(wc -l <"$T/q-oldest.tsv" | tr -d '[:space:]')" = 2 ] && pass || fail 'oldest/limit one'
for filter in '--origin human' '--origin agent' '--subject-type harness' '--subject patch-tool' '--status open'; do
  # shellcheck disable=SC2086 # Fixed test grammar with no spaced values.
  HOME="$Q" "$PROVIDER" query --format tsv --limit 100 $filter >"$T/q-filter.tsv"
  [ "$(awk 'END{print NR-1}' "$T/q-filter.tsv")" -ge 1 ] && pass || fail "empty filter: $filter"
done
for subject_type in skill agent harness tool workflow; do
  HOME="$Q" "$PROVIDER" query --subject-type "$subject_type" --format tsv >"$T/q-type.tsv"
  [ "$(awk -F '\t' -v t="$subject_type" 'NR>1&&$5==t{n++}END{print n+0}' "$T/q-type.tsv")" = 1 ] && pass || fail "$subject_type filter"
done
HOME="$Q" "$PROVIDER" query --subject no-such-subject >"$T/empty.human"
[ ! -s "$T/empty.human" ] && pass || fail 'empty human result was not empty'
HOME="$Q" "$PROVIDER" query --subject no-such-subject --format tsv >"$T/empty.tsv"
[ "$(wc -l <"$T/empty.tsv" | tr -d '[:space:]')" = 1 ] && [ "$(sed -n '1p' "$T/empty.tsv")" = "$HEADER" ] && pass || fail 'empty TSV result'
no env HOME="$Q" "$PROVIDER" query --limit 0
ok env HOME="$Q" "$PROVIDER" query --limit 100
no env HOME="$Q" "$PROVIDER" query --limit 101
long_subject="$(printf '%0121d' 0 | tr 0 a)"
query_refuses() {
  if HOME="$Q" "$PROVIDER" query "$@" >"$T/out" 2>"$T/err"; then
    fail "accepted invalid query: $*"
  else
    pass
  fi
  has "$T/err" 'reason=usage action=check-command'
}
query_refuses --origin ''
query_refuses --subject-type ''
query_refuses --subject ''
query_refuses --limit nope
query_refuses --order sideways
query_refuses --format csv
query_refuses --status pending
no env HOME="$Q" "$PROVIDER" query --subject "$long_subject"

# Default paging is exactly the 20 newest open rows.
D="$T/default-page"; new_home "$D"
for n in $(seq 1 21); do
  printf -v second '%02d' "$n"
  capture_matrix "$D" human skill "item-$n" request "2026-09-03T06:00:${second}Z" >/dev/null
done
HOME="$D" "$PROVIDER" query >"$T/default-page.out"
[ "$(grep -c '^--$' "$T/default-page.out")" = 20 ] && pass || fail 'default page is not 20 rows'
has "$T/default-page.out" 'subject=item-21'
if grep -q '^subject=item-1$' "$T/default-page.out"; then fail 'default page retained oldest row'; else pass; fi

# Equal timestamps use the immutable ID as the deterministic tie-breaker.
E="$T/tie-order"; new_home "$E"
low="$T/low-random.sh"; high="$T/high-random.sh"
printf '%s\n' '#!/bin/sh' 'printf aaaaaaaa' >"$low"; printf '%s\n' '#!/bin/sh' 'printf bbbbbbbb' >"$high"
chmod +x "$low" "$high"
HOME="$E" AGENT_FEEDBACK_TEST_UTC_NOW=2026-09-03T07:00:00Z AGENT_FEEDBACK_TEST_RANDOM_SOURCE="$low" capture_human "$E" low request >/dev/null
HOME="$E" AGENT_FEEDBACK_TEST_UTC_NOW=2026-09-03T07:00:00Z AGENT_FEEDBACK_TEST_RANDOM_SOURCE="$high" capture_human "$E" high request >/dev/null
HOME="$E" "$PROVIDER" query --format tsv --order newest >"$T/tie-new.tsv"
HOME="$E" "$PROVIDER" query --format tsv --order oldest >"$T/tie-old.tsv"
[ "$(awk -F '\t' 'NR==2{print $6}' "$T/tie-new.tsv")" = high ] && pass || fail 'newest tie-break'
[ "$(awk -F '\t' 'NR==2{print $6}' "$T/tie-old.tsv")" = low ] && pass || fail 'oldest tie-break'

# Every close disposition succeeds with its required reference shape.
C="$T/close-matrix"; new_home "$C"
for disposition in addressed preserved declined stale duplicate; do
  capture_human "$C" architect request >"$T/c-$disposition"
  close_id="$(sed -n 's/^captured=//p' "$T/c-$disposition")"
  args=(close --id "$close_id" --as "$disposition" --reason "Reason for $disposition.")
  case "$disposition" in
    addressed|preserved|duplicate) args+=(--result-ref "results/$disposition") ;;
  esac
  HOME="$C" "$PROVIDER" "${args[@]}" >"$T/closed-$disposition"
  has "$T/closed-$disposition" "closed=$close_id"
  [ "$(awk -F '\t' -v id="$close_id" '$1==id{print $17":"$18}' "$(store_for "$C")")" = "closed:$disposition" ] && pass || fail "$disposition close"
done
cp "$(store_for "$C")" "$T/required-repeat.before"
HOME="$C" "$PROVIDER" "${args[@]}" >"$T/required-repeat"
has "$T/required-repeat" "unchanged=$close_id"
same "$(store_for "$C")" "$T/required-repeat.before"
HOME="$C" "$PROVIDER" query --status closed --format tsv --limit 100 >"$T/all-closed.tsv"
[ "$(awk 'END{print NR-1}' "$T/all-closed.tsv")" = 5 ] && pass || fail 'closed status filter'

finish provider-test
