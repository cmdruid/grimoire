#!/usr/bin/env bash
# Repository guard for Backlog's canonical provider and recovery boundaries.
set -euo pipefail
REPO="$(CDPATH='' cd -P "$(dirname "$0")/../.."&&pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/backlog-provider-contract.XXXXXX")";trap 'rm -rf "$T"' EXIT
fail(){ echo "FAIL: $*" >&2;return 1;}

validate(){
  local root="$1" owners repair_defs legacy_hits unexpected legacy_count
  legacy_hits="$(rg -n 'tracker-api\.sh|tracker-api' "$root/skills" "$root/scripts" "$root/README.md" --glob '!**/scripts/tests/backlog-provider-contract-test.sh'||true)"
  legacy_count="$(printf '%s\n' "$legacy_hits"|sed '/^$/d'|wc -l|tr -d ' ')"
  unexpected="$(printf '%s\n' "$legacy_hits"|awk '
    /skills\/backlog\/scripts\/tests\/skill-doc-test\.sh:/ && /\[ ! -e / {next}
    /skills\/backlog\/scripts\/tests\/hard-cut-test\.sh:/ && /\[ ! -e / {next}
    /skills\/backlog\/scripts\/tests\/deploy-test\.sh:/ && (/\[ ! -e / || /legacy residue/) {next}
    /scripts\/tests\/configure-clankshop-test\.sh:/ && /\[ ! -e / {next}
    NF {print}
  ')"
  [ "$legacy_count" -eq 7 ]&&[ -z "$unexpected" ]||{ fail 'live source or unnamed fixture names the pre-cut provider';return 1;}
  [ -x "$root/skills/backlog/scripts/trackers.sh" ]||{ fail 'canonical package provider missing';return 1;}
  [ ! -e "$root/skills/backlog/scripts/tracker-api.sh" ]||{ fail 'pre-cut package provider remains';return 1;}
  if rg -n 'tracker@1|receipts\.tsv|receipt-[1-9]' \
    "$root/skills/backlog/scripts/trackers.sh" \
    "$root/skills/backlog/scripts/backlog-setup.sh" \
    "$root/skills/backlog/scripts/tracker-layer-status.sh" >/dev/null;then
    fail 'live tracker runtime retains tracker@1 compatibility';return 1
  fi
  for retired in scripts/register-route.sh scripts/route-status.sh templates/debrief-anchor.md;do
    [ ! -e "$root/skills/backlog/$retired" ]||{ fail "retired Backlog route surface remains: $retired";return 1;}
  done
  if rg -n 'AGENTS\.md|CLAUDE\.md|register-route|route-status|debrief-anchor|skill:backlog' \
    "$root/skills/backlog/scripts" --glob '!**/tests/**' >/dev/null;then
    fail 'Backlog production scripts retain front-door ownership';return 1
  fi
  grep -qF 'tracker@2' "$root/skills/analyst/SKILL.md"||{ fail 'Analyst does not require tracker@2';return 1;}
  grep -qF 'tracker@2' "$root/skills/foreman/SKILL.md"||{ fail 'Foreman does not require tracker@2';return 1;}
  repair_defs="$(rg -o '^install_provider\(\)' "$root/skills/backlog/scripts" --glob '!**/tests/**'|wc -l|tr -d ' ')"
  [ "$repair_defs" -eq 1 ]||{ fail 'provider reconciliation is not singular';return 1;}
  grep -qF 'scripts/backlog-setup.sh' "$root/skills/backlog/verbs/repair.md"||{ fail 'repair bypasses shared setup reconciler';return 1;}
  for owners in analyst foreman;do
    if rg -n '/backlog repair|backlog-setup\.sh|backlog/scripts/trackers\.sh' "$root/skills/$owners" --glob '!**/tests/**' >/dev/null;then fail "$owners depends on Backlog recovery or bundled provider";return 1;fi
  done
  if rg -n '<!-- skill:backlog BEGIN|agent-trackers:' "$root/AGENTS.md" >/dev/null;then fail 'patient-zero front door contains deployed Backlog state';return 1;fi
  [ "$(rg -l '<!-- backlog:trackers-tool BEGIN -->' "$root/skills/backlog/templates"|wc -l|tr -d ' ')" -eq 1 ]||{ fail 'managed README block has more than one template owner';return 1;}
}

validate "$REPO"

# Red-prove each absence guard in an isolated copy, restoring each mutation byte-for-byte.
FIX="$T/repo";mkdir -p "$FIX";cp -R "$REPO/skills" "$FIX/skills";cp -R "$REPO/scripts" "$FIX/scripts";cp "$REPO/README.md" "$FIX/README.md";cp "$REPO/AGENTS.md" "$FIX/AGENTS.md"
mutations=0
red_proof(){
  local file="$1" line="$2" before="$T/before"
  cp "$file" "$before";printf '%s\n' "$line">>"$file"
  if validate "$FIX" >/dev/null 2>&1;then echo "FAIL: mutation survived: $line" >&2;exit 1;fi
  cp "$before" "$file";cmp -s "$before" "$file"||{ echo 'FAIL: fixture restoration drifted' >&2;exit 1;}
  mutations=$((mutations+1))
}
red_proof "$FIX/skills/analyst/SKILL.md" 'forbidden tracker-api.sh caller'
red_proof "$FIX/skills/backlog/scripts/tests/run.sh" 'bash "$DIR/tracker-api.sh"'
red_proof "$FIX/scripts/tests/configure-clankshop-test.sh" '"$root/.trackers/tracker-api.sh" catalog'
red_proof "$FIX/skills/foreman/SKILL.md" 'invoke /backlog repair'
red_proof "$FIX/AGENTS.md" '<!-- skill:backlog BEGIN -->'
red_proof "$FIX/skills/backlog/scripts/backlog-setup.sh" 'install_provider(){ :; }'
red_proof "$FIX/skills/backlog/scripts/trackers.sh" '# tracker@1 compatibility'
red_proof "$FIX/skills/backlog/scripts/tracker-layer-status.sh" '# receipts.tsv fallback'
red_proof "$FIX/skills/backlog/scripts/backlog-setup.sh" '# inspect AGENTS.md before setup'
validate "$FIX"
[ "$mutations" -eq 9 ]||{ echo 'FAIL: mutation count drifted' >&2;exit 1;}
echo "backlog-provider-contract-test: $mutations red proofs passed"
