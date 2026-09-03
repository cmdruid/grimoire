#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/skill-feedback-provider.XXXXXX")"
trap 'rm -rf "$T"' EXIT

HOME="$T/no-home" "$PROVIDER" describe > "$T/describe"
has "$T/describe" 'schema=skill-feedback@1'
has "$T/describe" 'store=.agents/skilldata/skill-feedback/feedback.tsv'
[ ! -e "$T/no-home" ] && pass || fail 'describe touched HOME'

H="$T/home"; new_home "$H"
if HOME="$H" "$PROVIDER" bogus >"$T/out" 2>"$T/err"; then fail 'unknown command accepted'; else pass; fi
has "$T/err" 'reason=usage action=check-command'
[ ! -e "$H/.agents" ] && pass || fail 'usage initialized store'

HOME="$H" "$PROVIDER" init > "$T/init"
has "$T/init" 'status=ready'
F="$(store_for "$H")"
[ "$(sed -n '1p' "$F")" = "$HEADER" ] && pass || fail 'wrong header'
[ "$(mode_of "$H/.agents")" = 700 ] && pass || fail 'wrong .agents mode'
[ "$(mode_of "$H/.agents/skilldata")" = 700 ] && pass || fail 'wrong skilldata mode'
[ "$(mode_of "$H/.agents/skilldata/skill-feedback")" = 700 ] && pass || fail 'wrong owned mode'
[ "$(mode_of "$F")" = 600 ] && pass || fail 'wrong file mode'
cp "$F" "$T/header-only"
HOME="$H" "$PROVIDER" init >/dev/null
same "$F" "$T/header-only"

capture_one "$H" architect friction local-sha256:0123456789abcdef > "$T/capture"
has "$T/capture" 'captured=SF-'
has "$T/capture" 'count=1'
[ "$(wc -l < "$F" | tr -d '[:space:]')" = 2 ] && pass || fail 'capture row count'
HOME="$H" "$PROVIDER" query --format tsv > "$T/query.tsv"
[ "$(awk -F '\t' 'NR==2{print $12}' "$T/query.tsv")" = '' ] && pass || fail 'project ref leaked by default'
HOME="$H" "$PROVIDER" query --format tsv --include-project-ref > "$T/query-private.tsv"
[ "$(awk -F '\t' 'NR==2{print $12}' "$T/query-private.tsv")" = local-sha256:0123456789abcdef ] && pass || fail 'explicit project ref missing'
HOME="$H" "$PROVIDER" query --skill architect --status open --limit 1 --order oldest --format human > "$T/query.human"
has "$T/query.human" 'summary=A concrete observation should change the skill.'
has "$T/query.human" 'count=1'

cp "$F" "$T/before-invalid"
if HOME="$H" "$PROVIDER" capture --skill Bad --skill-ref unknown --invocation x --kind gap --summary x --incident x --consequence x --suggestion x >"$T/out" 2>"$T/err"; then fail 'invalid skill accepted'; else pass; fi
same "$F" "$T/before-invalid"
if HOME="$H" "$PROVIDER" query --format human --include-project-ref >"$T/out" 2>"$T/err"; then fail 'incompatible query flags accepted'; else pass; fi
same "$F" "$T/before-invalid"

invalid_utf8="$(printf '\377')"
if HOME="$H" "$PROVIDER" capture --skill architect --skill-ref unknown --invocation x --kind gap \
  --summary "$invalid_utf8" --incident x --consequence x --suggestion x >"$T/out" 2>"$T/err"; then
  fail 'invalid UTF-8 input accepted'
else
  pass
fi
same "$F" "$T/before-invalid"

M="$T/malformed"; new_home "$M"; mkdir -p "$M/.agents/skilldata/skill-feedback"; printf 'bad\n' > "$(store_for "$M")"
cp "$(store_for "$M")" "$T/malformed-before"
if HOME="$M" "$PROVIDER" init >"$T/out" 2>"$T/err"; then fail 'malformed incumbent accepted'; else pass; fi
has "$T/err" 'reason=invalid-store'
same "$(store_for "$M")" "$T/malformed-before"

M="$T/impossible-time"; new_home "$M"; capture_one "$M" architect friction >/dev/null
MF="$(store_for "$M")"
LC_ALL=C awk -F '\t' 'BEGIN{OFS="\t"} NR==1{print;next} {$2="2026-99-99T99:99:99Z";$3=$2;print}' "$MF" >"$T/impossible-time.tsv"
mv "$T/impossible-time.tsv" "$MF"
cp "$MF" "$T/impossible-time-before"
if HOME="$M" "$PROVIDER" query >"$T/out" 2>"$T/err"; then fail 'impossible timestamp accepted'; else pass; fi
has "$T/err" 'reason=invalid-store'
same "$MF" "$T/impossible-time-before"

for invalid_time in 2023-02-29T12:00:00Z 2026-04-31T12:00:00Z 2026-01-01T24:00:00Z 2026-01-01T12:60:00Z 2026-01-01T12:00:61Z 2026-01-01T00:00:60Z; do
  time_key="${invalid_time//[:T-]/}"
  M="$T/invalid-time-$time_key"; new_home "$M"; capture_one "$M" architect friction >/dev/null
  MF="$(store_for "$M")"
  LC_ALL=C awk -F '\t' -v bad="$invalid_time" 'BEGIN{OFS="\t"}NR==1{print;next}{$2=bad;$3=bad;print}' "$MF" >"$T/invalid-time.tsv"
  mv "$T/invalid-time.tsv" "$MF"
  cp "$MF" "$T/invalid-time-before"
  no env HOME="$M" "$PROVIDER" query
  same "$MF" "$T/invalid-time-before"
done

M="$T/valid-leap-date"; new_home "$M"; capture_one "$M" architect friction >/dev/null
MF="$(store_for "$M")"
LC_ALL=C awk -F '\t' 'BEGIN{OFS="\t"}NR==1{print;next}{$1="SF-20240229T235959Z-12345678";$2="2024-02-29T23:59:59Z";$3=$2;print}' "$MF" >"$T/valid-leap-date.tsv"
mv "$T/valid-leap-date.tsv" "$MF"
ok env HOME="$M" "$PROVIDER" query

M="$T/invalid-utf8-store"; new_home "$M"; capture_one "$M" architect friction >/dev/null
MF="$(store_for "$M")"
bad_byte="$(printf '\377')"
row="$(tail -n 1 "$MF")"
row="${row/A concrete/$bad_byte concrete}"
{ printf '%s\n' "$HEADER"; printf '%s\n' "$row"; } >"$T/invalid-utf8.tsv"
mv "$T/invalid-utf8.tsv" "$MF"
cp "$MF" "$T/invalid-utf8-before"
if HOME="$M" "$PROVIDER" query >"$T/out" 2>"$T/err"; then fail 'invalid UTF-8 store accepted'; else pass; fi
has "$T/err" 'reason=invalid-store'
same "$MF" "$T/invalid-utf8-before"

# Init tightens only the owned directory and TSV; existing shared parents
# retain their modes and content.
P="$T/permissions"; new_home "$P"
mkdir -m 755 "$P/.agents"
mkdir -m 755 "$P/.agents/skilldata"
mkdir -m 755 "$P/.agents/skilldata/skill-feedback"
printf 'shared-canary\n' >"$P/.agents/canary"
printf '%s\n' "$HEADER" >"$(store_for "$P")"
chmod 644 "$(store_for "$P")"
HOME="$P" "$PROVIDER" init >/dev/null
[ "$(mode_of "$P/.agents")" = 755 ] && pass || fail 'init changed shared .agents mode'
[ "$(mode_of "$P/.agents/skilldata")" = 755 ] && pass || fail 'init changed shared skilldata mode'
[ "$(mode_of "$P/.agents/skilldata/skill-feedback")" = 700 ] && pass || fail 'init did not tighten owned directory'
[ "$(mode_of "$(store_for "$P")")" = 600 ] && pass || fail 'init did not tighten TSV'
has "$P/.agents/canary" 'shared-canary'

S="$T/symlink"; new_home "$S"; mkdir "$T/outside"; ln -s "$T/outside" "$S/.agents"
if HOME="$S" "$PROVIDER" init >"$T/out" 2>"$T/err"; then fail 'symlinked descendant accepted'; else pass; fi
has "$T/err" 'reason=unsafe-path'
[ ! -e "$T/outside/skilldata" ] && pass || fail 'write escaped through symlink'

R="$T/resolve-home"; new_home "$R"
capture_one "$R" architect friction > "$T/r1"
capture_one "$R" architect gap > "$T/r2"
id1="$(sed -n 's/^captured=//p' "$T/r1")"; id2="$(sed -n 's/^captured=//p' "$T/r2")"
RF="$(store_for "$R")"; awk -F '\t' -v id="$id1" 'BEGIN{OFS="\t"}NR>1&&$1==id{for(i=1;i<=12;i++)if(i!=3)printf "%s%s",$i,(i==12?"\n":OFS)}' "$RF" > "$T/nonlife-before"
HOME="$R" "$PROVIDER" resolve --entry "$id1" applied 'Implemented and verified.' skills/architect/SKILL.md --entry "$id2" stale 'The package has moved on.' '' > "$T/resolved"
has "$T/resolved" "resolved=$id1"
has "$T/resolved" "resolved=$id2"
has "$T/resolved" 'count=2'
[ "$(awk -F '\t' 'NR>1&&$13=="resolved"{n++}END{print n+0}' "$RF")" = 2 ] && pass || fail 'heterogeneous resolve count'
awk -F '\t' -v id="$id1" 'BEGIN{OFS="\t"}NR>1&&$1==id{for(i=1;i<=12;i++)if(i!=3)printf "%s%s",$i,(i==12?"\n":OFS)}' "$RF" > "$T/nonlife-after"
same "$T/nonlife-before" "$T/nonlife-after"
HOME="$R" "$PROVIDER" resolve --entry "$id1" applied 'Implemented and verified.' skills/architect/SKILL.md --entry "$id2" stale 'The package has moved on.' '' > "$T/repeat"
has "$T/repeat" "unchanged=$id1"
has "$T/repeat" "unchanged=$id2"
cp "$RF" "$T/resolve-before-refusal"
if HOME="$R" "$PROVIDER" resolve --entry "$id1" applied x path --entry "$id1" applied x path >"$T/out" 2>"$T/err"; then fail 'duplicate resolve ID accepted'; else pass; fi
same "$RF" "$T/resolve-before-refusal"
if HOME="$R" "$PROVIDER" resolve --entry SF-20000101T000000Z-deadbeef stale x '' >"$T/out" 2>"$T/err"; then fail 'missing resolve ID accepted'; else pass; fi
same "$RF" "$T/resolve-before-refusal"
if HOME="$R" "$PROVIDER" resolve --entry "$id1" rejected different '' >"$T/out" 2>"$T/err"; then fail 'conflicting re-resolution accepted'; else pass; fi
same "$RF" "$T/resolve-before-refusal"
if HOME="$R" "$PROVIDER" resolve --entry "$id1" applied x >"$T/out" 2>"$T/err"; then fail 'short resolve group accepted'; else pass; fi
if HOME="$R" "$PROVIDER" resolve --entry "$id1" applied x '' >"$T/out" 2>"$T/err"; then fail 'required result ref omitted'; else pass; fi

finish provider-test
