#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")"&&pwd)";SKILL="$(CDPATH='' cd -P "$HERE/../.."&&pwd)"
SETUP="$SKILL/scripts/backlog-setup.sh";RUNTIME="$SKILL/scripts/tracker-runtime-check.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/backlog-runtime-recovery.XXXXXX")";trap 'rm -rf "$T"' EXIT
pass=0;fail=0
eq(){ if [ "$2" = "$3" ];then pass=$((pass+1));else echo "FAIL $1 want=[$2] got=[$3]" >&2;fail=$((fail+1));fi;}
newroot(){ mkdir -p "$1";git -C "$1" init -q;}
diagnostic(){ "$RUNTIME" --root "$1" 2>&1||true;}

R="$T/ready";newroot "$R";"$SETUP" "$R" --apply >/dev/null
R_CANON="$(CDPATH='' cd -P "$R"&&pwd)";eq ready "provider=$R_CANON/.trackers/trackers.sh" "$(diagnostic "$R")"
for damage in missing nonexec drifted;do
  D="$T/$damage";cp -R "$R" "$D"
  case "$damage" in missing) rm "$D/.trackers/trackers.sh";;nonexec) chmod -x "$D/.trackers/trackers.sh";;drifted) printf '\nexit 99\n'>"$D/.trackers/trackers.sh";;esac
  eq "$damage" 'reason=repair-required action=/backlog repair' "$(diagnostic "$D")"
done

G="$T/git-loss";newroot "$G";"$SETUP" "$G" --apply >/dev/null;git -C "$G" add .;git -C "$G" -c user.name=test -c user.email=test@example.invalid commit -qm initialized;rm "$G/.trackers/receipts.tsv"
eq git-loss 'reason=ledger-recovery-required action=git-restore' "$(diagnostic "$G")"
H="$T/readme-loss";cp -R "$R" "$H";rm "$H/.trackers/receipts.tsv";eq readme-loss 'reason=ledger-recovery-required action=human-review' "$(diagnostic "$H")"
A="$T/absent";newroot "$A";eq absent 'reason=setup-required action=/backlog setup' "$(diagnostic "$A")"
P="$T/prefix";newroot "$P";mkdir -p "$P/.trackers";printf 'id\tcreated\ttext\tevidence\n'>"$P/.trackers/tasks.tsv";eq prefix 'reason=setup-required action=/backlog setup' "$(diagnostic "$P")"
M="$T/ambiguous";newroot "$M";mkdir -p "$M/.trackers";printf 'bad\n'>"$M/.trackers/tasks.tsv";eq ambiguous 'reason=ledger-recovery-required action=human-review' "$(diagnostic "$M")"

# Every provider-using entrypath binds to the executable runtime helper, and each binding is red-proved.
entrypaths_valid(){ local root="$1" verb;for verb in tracker file query debrief curate;do grep -qF 'scripts/tracker-runtime-check.sh' "$root/verbs/$verb.md"||return 1;done;}
entrypaths_valid "$SKILL"&&pass=$((pass+1))||{ echo 'FAIL runtime helper binding' >&2;fail=$((fail+1));}
COPY="$T/skill";mkdir -p "$COPY";cp -R "$SKILL/verbs" "$COPY/verbs"
for verb in tracker file query debrief curate;do
  cp "$COPY/verbs/$verb.md" "$T/$verb.before";sed 's,scripts/tracker-runtime-check\.sh,scripts/bypass.sh,' "$T/$verb.before">"$COPY/verbs/$verb.md"
  if entrypaths_valid "$COPY";then echo "FAIL $verb bypass survived" >&2;fail=$((fail+1));else pass=$((pass+1));fi
  cp "$T/$verb.before" "$COPY/verbs/$verb.md"
done
entrypaths_valid "$COPY"&&pass=$((pass+1))||{ echo 'FAIL entrypath restoration drifted' >&2;fail=$((fail+1));}

# Classification is read-only and a drifted executable is never run for discovery.
X="$T/no-exec";cp -R "$R" "$X";printf '%s\n' '#!/bin/sh' 'touch "$(dirname "$0")/EXECUTED"' 'echo schema=tracker@1'>"$X/.trackers/trackers.sh";chmod +x "$X/.trackers/trackers.sh"
eq no-exec 'reason=repair-required action=/backlog repair' "$(diagnostic "$X")";[ ! -e "$X/.trackers/EXECUTED" ]&&pass=$((pass+1))||{ echo 'FAIL classifier executed drifted provider' >&2;fail=$((fail+1));}

echo "runtime-recovery-test: $pass passed, $fail failed";[ "$fail" -eq 0 ]
