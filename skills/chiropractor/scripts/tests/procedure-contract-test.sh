#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
BASE="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
SCAN="$HERE/../spine-scan.sh"
TEST_NAME=procedure-contract-test
export TEST_NAME
# shellcheck source=/dev/null
. "$HERE/lib.sh"

skill="$BASE/SKILL.md"; audit="$BASE/verbs/audit.md"; adjust="$BASE/verbs/adjust.md"; rubric="$BASE/docs/RUBRIC.md"
cases="$HERE/fixtures/walkthroughs/cases.tsv"
case_inputs="$HERE/fixtures/walkthroughs/case-inputs.tsv"

validate_audit_contract() {
  local file="$1"
  grep -Fq 'Return exactly these sections in order' "$file" &&
    grep -Fq 'Do not include a diff' "$file" &&
    ! grep -Fq 'AUDIT-PATCH-PLANT' "$file"
}

validate_adjust_contract() {
  local file="$1"
  grep -Fq 'Stop and wait for explicit approval' "$file" &&
    grep -Fq 'saved digest' "$file" &&
    grep -Fq 'absent preimage' "$file" &&
    grep -Fq 'is still absent' "$file" &&
    grep -Fq 'byte-identical' "$file" &&
    grep -Fq 'invalidates approval' "$file" &&
    ! grep -Fq 'GENERAL-REQUEST-IS-APPROVAL' "$file"
}

validate_physical() {
  local ledger_file="$1" expected="$2"
  [ "$(awk -F'\t' '{sum+=$2} END{print sum+0}' "$ledger_file")" = "$expected" ] &&
    awk -F'\t' '
      NF!=8 || $1=="" || $2=="" || $3=="" || $4=="" || $5=="" || $6=="" || $7=="" || $8=="" {bad=1}
      $2>1 && ($3=="" || $4=="" || $5!="grouped" || $6=="none") {bad=1}
      END{exit bad}
    ' "$ledger_file"
}

if [ "$(wc -l <"$cases" | awk '{print $1+0}')" -eq 15 ]; then ok; else not_ok "walkthrough case population is not 15"; fi
if awk -F'\t' 'NF!=3 || $1=="" || $2=="" || $3==""{bad=1} END{exit bad}' "$cases"; then ok; else not_ok "walkthrough case evidence incomplete"; fi
if [ "$(cut -f1 "$cases" | sort -u | wc -l | awk '{print $1+0}')" -eq 15 ]; then ok; else not_ok "walkthrough case ids are not unique"; fi
if [ "$(wc -l <"$case_inputs" | awk '{print $1+0}')" -eq 15 ] && awk -F'\t' 'NF!=2 || $1=="" || $2==""{bad=1} END{exit bad}' "$case_inputs"; then ok; else not_ok "walkthrough inputs are incomplete"; fi
if cmp -s <(cut -f1 "$cases" | sort) <(cut -f1 "$case_inputs" | sort); then ok; else not_ok "walkthrough input ids do not match expected evidence ids"; fi
# Backticks are literal rubric labels in the searched prose.
# shellcheck disable=SC2016
for phrase in 'physical population' 'semantic surfaces' 'candidate_count' 'task-route matrix' 'solid`, `drift`, or `gap' 'Do not include a diff'; do
  if grep -Fq "$phrase" "$audit" "$rubric"; then ok; else not_ok "audit contract missing: $phrase"; fi
done
for phrase in 'Stop and wait for explicit approval' 'saved digest' 'byte-identical' 'symlink' 'scripts, workflows, manifests' 'two deliberate confirmation points'; do
  if grep -Fq "$phrase" "$adjust"; then ok; else not_ok "adjust contract missing: $phrase"; fi
done
if grep -Fq 'in-place steward' "$skill"; then ok; else not_ok "tier missing"; fi
if grep -Fq -- '- produces: —' "$skill" && grep -Fq -- '- handoff: —' "$skill" && grep -Fq -- '- consumes: —' "$skill"; then ok; else not_ok "all-empty edges missing"; fi

# Reconcile the physical example against the tracer scanner population.
tmp="$(mktemp -d "${TMPDIR:-/tmp}/chiropractor-procedure.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
cp -R "$HERE/fixtures/tracer/." "$tmp/project"
chmod +x "$tmp/project/scripts/release.sh"
"$SCAN" "$tmp/project" --candidates >"$tmp/candidates"
population="$(sed -n 's/^candidate_count=//p' "$tmp/candidates")"
ledger="$HERE/fixtures/walkthroughs/physical-candidates.tsv"
if validate_physical "$ledger" "$population"; then ok; else not_ok "physical ledger does not reconcile to $population"; fi

# Each focused plant fails, then the byte-identical source is restored and passes.
cp "$ledger" "$tmp/physical.before"
sed '$d' "$tmp/physical.before" >"$tmp/physical.bad"
if validate_physical "$tmp/physical.bad" "$population"; then not_ok "missing physical row stayed complete"; else ok; fi
cp "$tmp/physical.before" "$tmp/physical.restored"
if cmp -s "$tmp/physical.before" "$tmp/physical.restored" && validate_physical "$tmp/physical.restored" "$population"; then ok; else not_ok "physical fixture restore failed"; fi

awk -F'\t' 'BEGIN{OFS="\t"} NR==3{$6=""} {print}' "$ledger" >"$tmp/surfaces.bad"
if validate_physical "$tmp/surfaces.bad" "$population"; then not_ok "blank surfaces cell stayed complete"; else ok; fi

printf '%s\n' $'docs/*.md\t2\t\tshared extension\tgrouped\tnone\tinternal\thomogeneous docs' >"$tmp/group.bad"
if validate_physical "$tmp/group.bad" 2; then not_ok "unsupported group stayed complete"; else ok; fi

expected="$HERE/fixtures/walkthroughs/expected-audit.md"
if grep -Fq 'semantic-source.md#setup' "$expected" && grep -Fq 'semantic-source.md#release' "$expected"; then ok; else not_ok "two semantic surfaces missing"; fi
sed '/semantic-source.md#release/d' "$expected" >"$tmp/semantic.bad"
if grep -Fq 'semantic-source.md#setup' "$tmp/semantic.bad" && grep -Fq 'semantic-source.md#release' "$tmp/semantic.bad"; then
  not_ok "semantic omission guard stayed green"
else
  ok
fi

if validate_audit_contract "$audit"; then ok; else not_ok "live audit contract invalid"; fi
cp "$audit" "$tmp/audit.before"; cp "$audit" "$tmp/audit.bad"; printf '\nAUDIT-PATCH-PLANT: include a patch.\n' >>"$tmp/audit.bad"
if validate_audit_contract "$tmp/audit.bad"; then not_ok "audit-time patch plant stayed valid"; else ok; fi
cp "$tmp/audit.before" "$tmp/audit.restored"
if cmp -s "$tmp/audit.before" "$tmp/audit.restored" && validate_audit_contract "$tmp/audit.restored"; then ok; else not_ok "audit contract restore failed"; fi

if validate_adjust_contract "$adjust"; then ok; else not_ok "live adjust contract invalid"; fi
cp "$adjust" "$tmp/adjust.before"
sed '/saved digest/d' "$tmp/adjust.before" >"$tmp/stale.bad"
if validate_adjust_contract "$tmp/stale.bad"; then not_ok "stale-digest apply stayed valid"; else ok; fi
sed '/absent preimage/d' "$tmp/adjust.before" >"$tmp/absence.bad"
if validate_adjust_contract "$tmp/absence.bad"; then not_ok "new-target absence guard stayed valid after removal"; else ok; fi
cp "$tmp/adjust.before" "$tmp/broad.bad"; printf '\nGENERAL-REQUEST-IS-APPROVAL\n' >>"$tmp/broad.bad"
if validate_adjust_contract "$tmp/broad.bad"; then not_ok "broad confirmation stayed valid"; else ok; fi
cp "$tmp/adjust.before" "$tmp/adjust.restored"
if cmp -s "$tmp/adjust.before" "$tmp/adjust.restored" && validate_adjust_contract "$tmp/adjust.restored"; then ok; else not_ok "adjust contract restore failed"; fi

finish
