#!/usr/bin/env bash
# Prose/decision contract only: this suite does not execute or simulate a hosted model.
set -u

HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
TEMPLATE="$SKILL/templates/debrief-anchor.md"
SCENARIOS="$HERE/fixtures/debrief-anchor-scenarios.tsv"
T="$(mktemp -d "${TMPDIR:-/tmp}/backlog-anchor-contract.XXXXXX")"
trap 'rm -rf "$T"' EXIT
pass=0
fail=0

pass_one() { pass=$((pass + 1)); }
fail_one() { echo "FAIL: $*" >&2; fail=$((fail + 1)); }
require_fixed() { grep -Fq -- "$2" "$1"; }
line_no() { grep -Fn -- "$2" "$1" | cut -d: -f1 | head -n 1; }

check_registration() {
  file="$1"
  [ "$(sed -n '1p' "$file")" = '<!-- skill:backlog BEGIN built-against:debrief-anchor@1 -->' ] &&
    [ "$(tail -n 1 "$file")" = '<!-- skill:backlog END -->' ] &&
    [ "$(grep -Fxc '### /backlog — project follow-up trackers' "$file")" -eq 1 ] &&
    require_fixed "$file" 'Route: Inspect project trackers with `/backlog query` or `/backlog tracker list`; capture' &&
    require_fixed "$file" 'completed-work leftovers with `/backlog debrief`.' &&
    require_fixed "$file" 'Edges: produces `tracker`.'
}
check_applicability() {
  file="$1"
  require_fixed "$file" 'This applies to the custodial main agent performing substantive repository work.'
}
check_triggers() {
  file="$1"
  require_fixed "$file" 'Run `/backlog debrief` automatically, without asking, once at the earliest of:' || return 1
  one="$(line_no "$file" '1. before telling the human that a coherent work unit is complete;')"
  two="$(line_no "$file" '2. before beginning the next coherent work unit after one completes; or')"
  three="$(line_no "$file" '3. before a healthy reset or hand-off would discard substantive context.')"
  [ -n "$one" ] && [ -n "$two" ] && [ -n "$three" ] && [ "$one" -lt "$two" ] && [ "$two" -lt "$three" ]
}
check_coherent_unit() {
  file="$1"
  require_fixed "$file" 'A coherent work unit is an outcome worth reporting: a completed request, feature slice,' &&
    require_fixed "$file" 'is not a work unit. The debrief sweep and any recovery it invokes close the preceding unit; neither' &&
    require_fixed "$file" 'is itself a new work unit.'
}
check_once_and_zero() {
  file="$1"
  require_fixed "$file" 'Sweep only completed-work leftovers since the previous successful debrief in this context.' &&
    require_fixed "$file" 'file the current objective, resume instructions, or ordinary in-flight work. Zero filed rows is' &&
    require_fixed "$file" 'success. Remember the boundary in the current context and do not repeat the same unit.'
}
check_exclusions() {
  file="$1"
  require_fixed "$file" 'to pure Q&A, routine status replies, or child/delegate sessions; those return their byproducts to' &&
    require_fixed "$file" 'the custodial caller.'
}
check_emergency() {
  file="$1"
  require_fixed "$file" 'During involuntary compaction or context-pressure emergencies, preserve and recover the primary work' &&
    require_fixed "$file" 'first; run any deferred debrief at the next safe boundary.'
}
check_recovery() {
  file="$1"
  require_fixed "$file" 'diagnostic when safe and retry once. If it still refuses, keep the boundary pending, report the' &&
    require_fixed "$file" 'refusal, and do not begin another unit or deliberately reset or hand off.' &&
    require_fixed "$file" 'report the primary work complete only when it also states that debrief remains pending. Never' &&
    require_fixed "$file" 'hand-edit tracker data.'
}

check_scenarios() {
  file="$1"
  [ "$(sed -n '1p' "$file")" = $'scenario\tapplicability\tearliest_trigger\tdispatch\tnext_unit_or_reset' ] || return 1
  rows="$(awk -F '\t' 'NR > 1 { if (NF != 5 || seen[$1]++) bad=1; rows++ } END { if (bad || rows != 10) exit 1; print rows }' "$file")" || return 1
  [ "$rows" = 10 ] || return 1
  while IFS= read -r expected; do grep -Fqx -- "$expected" "$file" || return 1; done <<'EOF'
interactive-completed-unit	applies	before-completion-response	once	permit-after-success
autonomous-consecutive-units	applies	before-next-unit	once-per-completed-unit	permit-after-success
healthy-pre-reset	applies	before-healthy-reset	once	permit-after-success
zero-result-success	applies	before-completion-response	once-zero-is-success	permit-after-success
pure-qa	excluded	none	no-dispatch	permitted
routine-status	excluded	none	no-dispatch	permitted
child-delegate-return	excluded	none	return-byproducts-to-caller	caller-decides
debrief-recovery-closure	closure-not-new-unit	none	no-recursive-dispatch-during-setup-repair-retry	permit-after-success
terminal-refusal	applies	active-boundary	retry-once-then-pending	deny-while-pending
involuntary-compaction	deferred	next-safe-boundary	once-after-primary-recovery	no-deliberate-reset-before-success
EOF
}

# Exact bytes are pinned separately from the semantic checks below.
read -r checksum bytes _ < <(cksum "$TEMPLATE")
if [ "$checksum $bytes" = '2332704104 1948' ]; then pass_one; else fail_one "template checksum changed: $checksum $bytes"; fi
for requirement in registration applicability triggers coherent_unit once_and_zero exclusions emergency recovery; do
  if "check_$requirement" "$TEMPLATE"; then pass_one; else fail_one "template requirement failed: $requirement"; fi
done
if check_scenarios "$SCENARIOS"; then pass_one; else fail_one 'scenario matrix contract failed'; fi

# Each semantic requirement is red-proved independently on one counted line mutation.
mutate_requirement() {
  label="$1"; checker="$2"; old="$3"; new="$4"
  copy="$T/template-$label.md"
  cp "$TEMPLATE" "$copy"
  count="$(grep -Fxc -- "$old" "$copy" || true)"
  if [ "$count" -eq 1 ]; then pass_one; else fail_one "$label target count want=1 got=$count"; return; fi
  awk -v old="$old" -v new="$new" '{ if ($0 == old) { print new; changed++ } else print } END { if (changed != 1) exit 9 }' "$copy" > "$copy.tmp" || {
    fail_one "$label mutation did not apply exactly once"; return
  }
  mv "$copy.tmp" "$copy"
  if "$checker" "$copy"; then fail_one "$label mutation stayed green"; else pass_one; fi
  cp "$TEMPLATE" "$copy"
  if cmp -s "$TEMPLATE" "$copy"; then pass_one; else fail_one "$label restore was not byte-exact"; fi
}

mutate_requirement registration check_registration \
  '<!-- skill:backlog BEGIN built-against:debrief-anchor@1 -->' \
  '<!-- skill:backlog BEGIN built-against:debrief-anchor@2 -->'
mutate_requirement applicability check_applicability \
  'This applies to the custodial main agent performing substantive repository work. It does not apply' \
  'This applies to an unspecified agent performing substantive repository work. It does not apply'
mutate_requirement triggers check_triggers \
  'Run `/backlog debrief` automatically, without asking, once at the earliest of:' \
  'Consider `/backlog debrief` at one of these moments:'
mutate_requirement coherent-unit check_coherent_unit \
  'A coherent work unit is an outcome worth reporting: a completed request, feature slice,' \
  'A coherent work unit is any individual command or edit:'
mutate_requirement once-zero check_once_and_zero \
  'success. Remember the boundary in the current context and do not repeat the same unit.' \
  'success. Repeat the same boundary whenever another trigger is reached.'
mutate_requirement exclusions check_exclusions \
  'to pure Q&A, routine status replies, or child/delegate sessions; those return their byproducts to' \
  'to child/delegate sessions; those return their byproducts to'
mutate_requirement emergency check_emergency \
  'During involuntary compaction or context-pressure emergencies, preserve and recover the primary work' \
  'During involuntary compaction, mutate trackers before preserving the primary work'
mutate_requirement recovery check_recovery \
  'diagnostic when safe and retry once. If it still refuses, keep the boundary pending, report the' \
  'diagnostic when safe and continue without retrying or retaining the boundary.'

# Red-prove the scenario inventory and field assertions without touching the source table.
cp "$SCENARIOS" "$T/scenarios.tsv"
grep -v '^pure-qa' "$T/scenarios.tsv" > "$T/scenarios.tmp";mv "$T/scenarios.tmp" "$T/scenarios.tsv"
if check_scenarios "$T/scenarios.tsv"; then fail_one 'missing scenario stayed green'; else pass_one; fi
cp "$SCENARIOS" "$T/scenarios.tsv"
if cmp -s "$SCENARIOS" "$T/scenarios.tsv"; then pass_one; else fail_one 'scenario restore was not byte-exact'; fi

echo "debrief-anchor-contract-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
