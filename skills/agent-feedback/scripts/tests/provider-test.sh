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

finish provider-test
