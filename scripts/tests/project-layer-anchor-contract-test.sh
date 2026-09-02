#!/usr/bin/env bash
# Cross-package proof for explicit project-layer discovery and standalone use.
set -euo pipefail
REPO="$(CDPATH='' cd -P "$(dirname "$0")/../.."&&pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/project-layer-anchor-contract.XXXXXX")";trap 'rm -rf "$T"' EXIT
fail(){ echo "FAIL: $*" >&2;exit 1;}

copy_packages(){
  local destination="$1"
  mkdir -p "$destination"
  cp -R "$REPO/skills/journal" "$destination/journal"
  cp -R "$REPO/skills/backlog" "$destination/backlog"
}

init_project(){
  local root="$1" package="$2" authored="$3"
  mkdir -p "$root";git -C "$root" init -q
  git -C "$root" config user.name Fixture;git -C "$root" config user.email fixture@example.invalid
  printf 'seed\n'>"$root/.seed"
  if [ "$authored" = yes ];then printf '# Existing instructions\n\nPROJECT_PROSE_CANARY' >"$root/AGENTS.md";fi
  git -C "$root" add .;git -C "$root" commit -qm seed
  "$package/journal/scripts/standup.sh" setup "$root" >/dev/null
  "$package/backlog/scripts/backlog-setup.sh" "$root" --apply >/dev/null
  git -C "$root" add .records .trackers;git -C "$root" commit -qm layers
}

install_one(){
  local root="$1" package="$2" owner="$3" script scoped output
  script="$package/$owner/scripts/$([ "$owner" = journal ]&&printf records||printf trackers)-anchor.sh"
  scoped="$package/$owner/scripts/scoped-commit.sh";output="$T/$owner-anchor.out"
  "$script" apply --root "$root" --confirmed>"$output"
  grep -qxF 'wrote=AGENTS.md' "$output"||fail "$owner anchor did not report AGENTS.md"
  "$scoped" "$root" "Add $owner layer pointer" AGENTS.md >/dev/null
  [ "$(git -C "$root" diff-tree --no-commit-id --name-only -r HEAD)" = AGENTS.md ]||
    fail "$owner anchor commit escaped AGENTS.md"
}

exercise_order(){
  local label="$1" first="$2" second="$3" authored="$4" package root
  package="$T/package-$label";root="$T/project-$label"
  copy_packages "$package";init_project "$root" "$package" "$authored"
  [ "$authored" = no ]||cp "$root/AGENTS.md" "$T/$label.before"
  install_one "$root" "$package" "$first";install_one "$root" "$package" "$second"
  [ "$(grep -cFx '## Project records' "$root/AGENTS.md")" -eq 1 ]||fail "$label records section count"
  [ "$(grep -cFx '## Project trackers' "$root/AGENTS.md")" -eq 1 ]||fail "$label tracker section count"
  grep -qF "Read \`.records/README.md\`" "$root/AGENTS.md"||fail "$label records pointer missing"
  grep -qF "Read \`.trackers/README.md\`" "$root/AGENTS.md"||fail "$label tracker pointer missing"
  ! grep -qE '<!-- (journal|backlog|skill:)|debrief cadence|/backlog (setup|repair)' "$root/AGENTS.md"||
    fail "$label installed marker, route, or cadence prose"
  if [ "$authored" = yes ];then
    bytes="$(wc -c <"$T/$label.before"|tr -d '[:space:]')"
    head -c "$bytes" "$root/AGENTS.md">"$T/$label.prefix"
    cmp -s "$T/$label.before" "$T/$label.prefix"||fail "$label changed authored prefix"
  fi
  first_line="$(grep -nFx "## Project $([ "$first" = journal ]&&printf records||printf trackers)" "$root/AGENTS.md"|cut -d: -f1)"
  second_line="$(grep -nFx "## Project $([ "$second" = journal ]&&printf records||printf trackers)" "$root/AGENTS.md"|cut -d: -f1)"
  [ "$first_line" -lt "$second_line" ]||fail "$label anchor order changed"
  for owner in journal backlog;do
    script="$package/$owner/scripts/$([ "$owner" = journal ]&&printf records||printf trackers)-anchor.sh"
    "$script" apply --root "$root" --confirmed>"$T/$label-$owner-rerun"
    grep -qxF 'action=noop' "$T/$label-$owner-rerun"||fail "$label $owner rerun is not a no-op"
    ! grep -q '^wrote=' "$T/$label-$owner-rerun"||fail "$label $owner rerun wrote"
  done
  [ -z "$(git -C "$root" status --porcelain)" ]||fail "$label rerun left a diff"
}

# Both orders work over both front-door starting states.
exercise_order missing-journal-first journal backlog no
exercise_order missing-backlog-first backlog journal no
exercise_order authored-journal-first journal backlog yes
exercise_order authored-backlog-first backlog journal yes

# Setup and repair remain front-door neutral without an explicit anchor call.
neutral_package="$T/neutral-package";neutral="$T/neutral";copy_packages "$neutral_package"
mkdir -p "$neutral";git -C "$neutral" init -q
printf 'NEUTRAL_FRONT_DOOR_CANARY\n'>"$neutral/AGENTS.md"
git -C "$neutral" add AGENTS.md;git -C "$neutral" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm seed
cp "$neutral/AGENTS.md" "$T/neutral.before"
"$neutral_package/journal/scripts/standup.sh" setup "$neutral" >/dev/null
"$neutral_package/backlog/scripts/backlog-setup.sh" "$neutral" --apply >/dev/null
"$neutral_package/journal/scripts/standup.sh" repair "$neutral" >/dev/null
"$neutral_package/backlog/scripts/backlog-setup.sh" "$neutral" repair >/dev/null
cmp -s "$T/neutral.before" "$neutral/AGENTS.md"||fail 'setup or repair changed AGENTS.md'

# After installation, remove both source packages and exercise every ordinary
# lifecycle family through only AGENTS.md, the local guides, and adjacent tools.
offline_package="$T/offline-package";offline="$T/offline";copy_packages "$offline_package"
init_project "$offline" "$offline_package" yes
install_one "$offline" "$offline_package" journal;install_one "$offline" "$offline_package" backlog
rm -rf "$offline_package/journal" "$offline_package/backlog"
[ ! -e "$offline_package/journal" ]&&[ ! -e "$offline_package/backlog" ]||fail 'source packages remain available'
grep -qF '.records/README.md' "$offline/AGENTS.md";grep -qF '.trackers/README.md' "$offline/AGENTS.md"
grep -qF "Journal skill isn't available" "$offline/.records/README.md"||fail 'records maintenance stop missing'
grep -qF "Backlog skill isn't available" "$offline/.trackers/README.md"||fail 'tracker maintenance stop missing'

records="$offline/.records/records.sh"
record="$($records new notes --schema project/note@1 --title 'Standalone record')"
printf '\nstandalone-record-body\n'>>"$record"
"$records" touch "$record" --status published >/dev/null
"$records" list --type notes|grep -qF 'standalone-record'
"$records" grep --type notes standalone-record-body|grep -qF 'standalone-record'
"$records" show "$record"|grep -qF '# Standalone record'
relocated="notes/$(date +%Y-%m-%d)-standalone-record-relocated.md"
"$records" relocate "$record" --to "$relocated" >/dev/null
"$records" "done" "$relocated" --as "done" --note 'standalone complete' >/dev/null
"$records" history --type notes|grep -qF "$relocated"
"$records" check|grep -qF 'records check: OK'

trackers="$offline/.trackers/trackers.sh"
"$trackers" describe|grep -qxF 'schema=tracker@2'
"$trackers" catalog|grep -q '^tasks'
"$trackers" create --tracker tasks --text 'Standalone tracker item' --evidence AGENTS.md >/dev/null
"$trackers" update --tracker tasks --id tasks-1 --text 'Standalone tracker item updated' >/dev/null
"$trackers" page --tracker tasks --status open --limit 20|grep -qF 'Standalone tracker item updated'
"$trackers" observe --consumer standalone/review --tracker tasks --ids tasks-1 >/dev/null
if "$trackers" page --tracker tasks --status open --limit 20 --consumer standalone/review --unobserved|grep -qF 'tasks-1';then
  fail 'observed tracker item remained in the consumer unobserved page'
fi
"$trackers" consume --consumer standalone/review --tracker tasks --ids tasks-1 --resolution Resolved --result AGENTS.md >/dev/null
"$trackers" history --limit 20|grep -qF $'tasks-1\tconsumed'

# Red-prove the automatic-call and marker guards in an isolated package copy.
guard_package="$T/guard-package";copy_packages "$guard_package"
boundary_guard(){
  local package="$1"
  ! rg -n 'records-anchor\.sh|trackers-anchor\.sh' "$package/journal/scripts" "$package/backlog/scripts" \
    --glob '!**/tests/**' --glob '!records-anchor.sh' --glob '!trackers-anchor.sh' >/dev/null||return 1
  ! grep -qF '<!--' "$package/journal/templates/agents-pointer.md"||return 1
  ! grep -qF '<!--' "$package/backlog/templates/agents-pointer.md"||return 1
}
boundary_guard "$guard_package"||fail 'live boundary guard fails'
mutations=0
red_proof(){
  local file="$1" line="$2" before="$T/guard.before"
  cp "$file" "$before";printf '%s\n' "$line">>"$file"
  [ "$(grep -Fc -- "$line" "$file")" -eq 1 ]||fail 'guard mutation count is not one'
  if boundary_guard "$guard_package";then fail "guard mutation survived: $line";fi
  cp "$before" "$file";cmp -s "$before" "$file"||fail 'guard restoration drifted'
  mutations=$((mutations+1))
}
red_proof "$guard_package/journal/scripts/standup.sh" "\"\$SKILL/scripts/records-anchor.sh\" apply --root \"\$root\" --confirmed"
red_proof "$guard_package/backlog/scripts/backlog-setup.sh" "\"\$SKILL/scripts/trackers-anchor.sh\" apply --root \"\$ROOT\" --confirmed"
red_proof "$guard_package/journal/templates/agents-pointer.md" '<!-- journal:project-records -->'
red_proof "$guard_package/backlog/templates/agents-pointer.md" '<!-- backlog:project-trackers -->'
boundary_guard "$guard_package"||fail 'restored boundary guard fails'
[ "$mutations" -eq 4 ]||fail 'boundary mutation count drifted'

echo "project-layer-anchor-contract-test: four order/state fixtures, standalone lifecycles, and $mutations red proofs passed"
