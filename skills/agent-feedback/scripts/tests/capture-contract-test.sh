#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/agent-feedback-capture-contract.XXXXXX")"
trap 'rm -rf "$T"' EXIT
D="$SKILL/verbs/capture.md"; S="$SKILL/SKILL.md"; C="$HERE/fixtures/capture-cases.tsv"

for phrase in 'Explicit human capture' 'Agent-selected capture' '**Reuse ownership:**' \
  '**Change-worthiness:**' '**Incident and consequence:**' '**Response:**' '**Privacy:**' \
  'origin=human' 'origin=agent' 'skipped=no-change-worthy-feedback' \
  'skipped=subject-ambiguous' 'at most once' 'at most one row' \
  '`friction`, `gap`' '`win`, or `request`' 'ask one concise question' \
  'nearly verbatim' 'whitespace' 'normalization' 'safe restatement' \
  'repository commit never substitutes for subject identity'; do
  has "$D" "$phrase"
done
for phrase in 'after qualifying agent work' 'There is no tune' 'performed no' 'remediation'; do has "$S" "$phrase"; done

# Both origins, every reusable subject class, and all kinds have a qualifying
# behavioral case. Agent skip cases name the exact silent reason and never ask.
[ "$(awk -F '\t' 'NR>1{seen[$2]=1}END{print seen["agent"]+seen["human"]}' "$C")" = 2 ] && pass || fail 'origin matrix incomplete'
for origin in agent human; do
  for subject_type in skill agent harness tool workflow; do
    [ "$(awk -F '\t' -v o="$origin" -v t="$subject_type" 'NR>1&&$2==o&&$3==t&&$6=="capture"{n++}END{print n+0}' "$C")" -ge 1 ] && pass || fail "$origin/$subject_type missing"
  done
done
for kind in friction gap win request; do
  [ "$(awk -F '\t' -v k="$kind" 'NR>1&&$7==k&&$6=="capture"{n++}END{print n+0}' "$C")" -ge 1 ] && pass || fail "$kind missing"
done
for case_name in agent-ordinary-success agent-generic-praise agent-rating agent-speculation \
  agent-project-owned agent-local-process agent-self-suppression; do
  [ "$(awk -F '\t' -v c="$case_name" 'NR>1&&$1==c{print $6":"$8":"$11":"$12}' "$C")" = 'skip:no-change-worthy-feedback:0:0' ] && pass || fail "$case_name contract"
done
for case_name in agent-private-redaction agent-raw-prompt-redaction agent-environment-redaction \
  agent-proprietary-redaction agent-person-project-redaction agent-excerpt-redaction; do
  [ "$(awk -F '\t' -v c="$case_name" 'NR>1&&$1==c{print $6":"$10":"$11":"$12}' "$C")" = 'capture:yes:0:1' ] && pass || fail "$case_name privacy contract"
done
[ "$(awk -F '\t' 'NR>1&&$1=="agent-subject-ambiguous"{print $6":"$8":"$11":"$12}' "$C")" = 'skip:subject-ambiguous:0:0' ] && pass || fail 'agent ambiguity contract'
[ "$(awk -F '\t' 'NR>1&&$2=="agent"&&$11!=0{n++}END{print n+0}' "$C")" = 0 ] && pass || fail 'agent path asks follow-up'
[ "$(awk -F '\t' 'NR>1&&$6=="capture"&&$12!=1{n++}END{print n+0}' "$C")" = 0 ] && pass || fail 'capture is not one row'
[ "$(awk -F '\t' 'NR>1&&$6!="capture"&&$12!=0{n++}END{print n+0}' "$C")" = 0 ] && pass || fail 'noncapture writes a row'

# Human authority explicitly covers praise, omitted detail, transparent
# redaction, explicit self-feedback, ambiguity, and privacy-destroyed input.
for case_name in human-agent-praise human-harness-omitted-detail human-tool-redaction \
  human-self-explicit human-omitted-positional human-subject-ambiguous human-message-missing \
  human-privacy-destroyed; do
  [ "$(awk -F '\t' -v c="$case_name" 'NR>1&&$1==c{print $1}' "$C")" = "$case_name" ] && pass || fail "$case_name missing"
done
[ "$(awk -F '\t' 'NR>1&&$1=="human-agent-praise"{print $7":"$9":"$12}' "$C")" = 'win:empty-allowed:1' ] && pass || fail 'human praise/empty suggestion contract'
[ "$(awk -F '\t' 'NR>1&&$1=="human-tool-redaction"{print $10}' "$C")" = yes ] && pass || fail 'human redaction contract'
[ "$(awk -F '\t' 'NR>1&&$1=="human-privacy-destroyed"{print $6":"$8":"$11":"$12}' "$C")" = 'ask:safe-restatement-required:1:0' ] && pass || fail 'privacy restatement contract'

# Red-prove one procedure guard without changing the source document.
cp "$D" "$T/original.md"
sed '/\*\*Reuse ownership:\*\*/d' "$D" >"$T/broken.md"
if grep -qF '**Reuse ownership:**' "$T/broken.md"; then fail 'red proof retained removed guard'; else pass; fi
same "$D" "$T/original.md"

finish capture-contract-test
