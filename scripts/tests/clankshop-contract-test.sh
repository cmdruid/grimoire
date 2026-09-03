#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PACK="$ROOT/PACK.md"
pass=0
fail=0

require(){
  if grep -qF -- "$2" "$1"; then
    pass=$((pass + 1))
  else
    echo "FAIL: missing pack contract: $2" >&2
    fail=$((fail + 1))
  fi
}

require "$PACK" 'Workstream may submit a bounded queue unit to Delegate'
require "$PACK" 'Delegate may use Mailbox'
require "$PACK" "Workstream's"
require "$PACK" 'main session remains the sole writer'
require "$PACK" 'the unit runs inline'
require "$PACK" '/workspace check'
require "$ROOT/README.md" 'findings stay in the audit report and promote through the host capture lane'
require "$ROOT/docs/boundary-audit.md" 'fails=0 warns=4'
require "$ROOT/docs/boundary-audit.md" "Workstream's \`resource-claim\` is legal repository-local leaf state"
require "$ROOT/docs/boundary-audit.md" 'Foreman'
require "$ROOT/docs/boundary-audit.md" 'goal-pursuit'
require "$ROOT/docs/boundary-audit.md" 'session-evidence'
require "$ROOT/docs/boundary-audit.md" 'are external-runtime edges'
# Backticks are literal inventory text.
# shellcheck disable=SC2016
require "$ROOT/README.md" '| `chiropractor` | audit documentation-spine discoverability'
# shellcheck disable=SC2016
require "$ROOT/AGENTS.md" '`chiropractor` the'
require "$PACK" 'Chiropractor audits and confirmation-gates documentation-spine topology'
require "$PACK" 'It owns no setup and never repairs scripts or workflows'
require "$PACK" 'project-owned byproduct'
require "$PACK" 'affected skill tag'
require "$ROOT/README.md" 'Five skills sit outside the pack'
require "$ROOT/README.md" '| `skill-feedback` |'
require "$ROOT/README.md" 'Open a GitHub issue tagged with the skill'
require "$ROOT/README.md" 'standalone `/skill-feedback` skill'

skill_feedback_boundary_ok(){
  local pack="$1" readme="$2" agents="$3"
  ! grep -qF 'skill-feedback' "$pack" &&
    ! grep -qF '.agents/skilldata/skill-feedback' "$pack" &&
    grep -qF 'project-owned byproduct' "$pack" &&
    grep -qF 'affected skill tag' "$pack" &&
    grep -qF 'Five skills sit outside the pack' "$readme" &&
    grep -qF '| `skill-feedback` |' "$readme" &&
    grep -qF 'standalone `/skill-feedback` skill' "$readme" &&
    ! grep -qF '<!-- skill:skill-feedback BEGIN' "$agents"
}

public_workspace_check_ok(){
  local pack="$1"
  grep -qF '/workspace check' "$pack" &&
    ! grep -qF 'scripts/workspace-check.sh' "$pack"
}

chiropractor_contract_ok(){
  local pack="$1"
  awk '
    /^---$/ { fence++; next }
    fence == 1 && /^optional:[[:space:]]*$/ { optional=1; next }
    fence == 1 && optional && /^  - [a-z0-9][a-z0-9-]*[[:space:]]*$/ {
      member=$0
      sub(/^  - /, "", member)
      sub(/[[:space:]]*$/, "", member)
      if (member == "chiropractor") found=1
      next
    }
    fence == 1 && optional && !/^  - / { optional=0 }
    END { exit !found }
  ' "$pack" &&
    grep -qF 'Chiropractor audits and confirmation-gates documentation-spine topology' "$pack" &&
    grep -qF 'It owns no setup and never repairs scripts or workflows' "$pack" &&
    ! grep -Eq 'Chiropractor (runs|owns) project setup|Chiropractor repairs (scripts|workflows)' "$pack"
}

if public_workspace_check_ok "$PACK"; then
  pass=$((pass + 1))
else
  echo 'FAIL: pack bypasses the public Workspace procedure' >&2
  fail=$((fail + 1))
fi

# Red-proof the direct-script absence guard in a disposable PACK copy.
tmp="$(mktemp -d "${TMPDIR:-/tmp}/clankshop-contract.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
fixture="$tmp/PACK.md"
cp "$PACK" "$fixture"
cp "$fixture" "$tmp/PACK.before"
plant="Run each advertised owner check, then Workspace's package-local \`scripts/workspace-check.sh\` against the resolved roots."
printf '\n%s\n' "$plant" >> "$fixture"
count="$(grep -cFx -- "$plant" "$fixture")"
if [ "$count" = 1 ]; then
  pass=$((pass + 1))
else
  echo "FAIL: direct Workspace script plant count was $count" >&2
  fail=$((fail + 1))
fi
if public_workspace_check_ok "$fixture"; then
  echo 'FAIL: direct Workspace script guard stayed green' >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
cp "$tmp/PACK.before" "$fixture"
if cmp -s "$tmp/PACK.before" "$fixture"; then pass=$((pass + 1)); else echo 'FAIL: PACK fixture restore drifted' >&2; fail=$((fail + 1)); fi
if public_workspace_check_ok "$fixture"; then pass=$((pass + 1)); else echo 'FAIL: restored PACK contract stayed red' >&2; fail=$((fail + 1)); fi

if chiropractor_contract_ok "$PACK"; then pass=$((pass + 1)); else echo 'FAIL: live Chiropractor pack contract invalid' >&2; fail=$((fail + 1)); fi
if skill_feedback_boundary_ok "$PACK" "$ROOT/README.md" "$ROOT/AGENTS.md";then pass=$((pass+1));else echo 'FAIL: skill-feedback pack boundary invalid' >&2;fail=$((fail+1));fi

# Red-prove pack exclusion, inventory presence, and patient-zero front-door absence independently.
readme_fixture="$tmp/README.md";agents_fixture="$tmp/AGENTS.md"
cp "$ROOT/README.md" "$readme_fixture";cp "$ROOT/AGENTS.md" "$agents_fixture"
for boundary_case in pack-member pack-global-path pack-project-wording pack-skill-tag readme-count readme-row patient-zero-anchor;do
  cp "$PACK" "$fixture";cp "$ROOT/README.md" "$readme_fixture";cp "$ROOT/AGENTS.md" "$agents_fixture"
  case "$boundary_case" in
    pack-member) printf '\nskill-feedback\n' >>"$fixture" ;;
    pack-global-path) printf '\nGlobal writer: ~/.agents/skilldata/skill-feedback\n' >>"$fixture" ;;
    pack-project-wording) sed 's/project-owned byproduct/byproduct/' "$fixture" >"$tmp/pack.bad";mv "$tmp/pack.bad" "$fixture" ;;
    pack-skill-tag) sed 's/affected skill tag/affected component tag/' "$fixture" >"$tmp/pack.bad";mv "$tmp/pack.bad" "$fixture" ;;
    readme-count) sed 's/Five skills sit outside the pack/Four skills sit outside the pack/' "$readme_fixture" >"$tmp/readme.bad";mv "$tmp/readme.bad" "$readme_fixture" ;;
    readme-row) sed '/| `skill-feedback` |/d' "$readme_fixture" >"$tmp/readme.bad";mv "$tmp/readme.bad" "$readme_fixture" ;;
    patient-zero-anchor) printf '\n<!-- skill:skill-feedback BEGIN built-against:test -->\n' >>"$agents_fixture" ;;
  esac
  if skill_feedback_boundary_ok "$fixture" "$readme_fixture" "$agents_fixture";then echo "FAIL: $boundary_case guard stayed green" >&2;fail=$((fail+1));else pass=$((pass+1));fi
done

# Red-proof missing membership in the same disposable PACK copy.
cp "$PACK" "$fixture"
cp "$fixture" "$tmp/PACK.member.before"
sed '/^  - chiropractor$/d' "$fixture" >"$tmp/PACK.member.bad"
mv "$tmp/PACK.member.bad" "$fixture"
if chiropractor_contract_ok "$fixture"; then
  echo 'FAIL: Chiropractor contract accepted missing optional membership' >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
cp "$tmp/PACK.member.before" "$fixture"
if cmp -s "$tmp/PACK.member.before" "$fixture" && chiropractor_contract_ok "$fixture"; then pass=$((pass + 1)); else echo 'FAIL: membership fixture restore failed' >&2; fail=$((fail + 1)); fi

# Red-proof a composition seam that falsely grants setup and script repair.
cp "$fixture" "$tmp/PACK.seam.before"
printf '\nChiropractor runs project setup. Chiropractor repairs scripts.\n' >>"$fixture"
if chiropractor_contract_ok "$fixture"; then
  echo 'FAIL: Chiropractor seam accepted setup/script repair ownership' >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
cp "$tmp/PACK.seam.before" "$fixture"
if cmp -s "$tmp/PACK.seam.before" "$fixture" && chiropractor_contract_ok "$fixture"; then pass=$((pass + 1)); else echo 'FAIL: seam fixture restore failed' >&2; fail=$((fail + 1)); fi

echo "clankshop-contract-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
