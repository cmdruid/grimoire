#!/usr/bin/env bash
# contract-test.sh — Journal dispatch, runtime recovery, README, and provider gate.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

STANDUP="$SKILL/scripts/standup.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/journal-contract-test.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

setup_layer() {
  contract_root="$1"
  mkdir -p "$contract_root"
  "$STANDUP" setup "$contract_root" --records-root .records --workspace-root .spaces \
    >"$OUT" 2>"$ERR"
  "$STANDUP" finalize "$contract_root" --records-root .records --workspace-root .spaces
}

runtime_contract() {
  contract_skill="$1"
  grep -qF 'reason=setup-required action=/journal setup' "$contract_skill/SKILL.md" || return 1
  grep -qF 'reason=repair-required action=/journal repair' "$contract_skill/SKILL.md" || return 1
  grep -qF '| `/journal repair` | `verbs/repair.md` |' "$contract_skill/SKILL.md" || return 1
  for contract_verb in search "done" curate; do
    grep -qF 'ordered runtime preflight' "$contract_skill/verbs/$contract_verb.md" || return 1
  done
  if grep -E 'scripts/records[.]sh.*--root' \
    "$contract_skill/verbs/search.md" "$contract_skill/verbs/done.md" \
    "$contract_skill/verbs/curate.md" >/dev/null; then
    return 1
  fi
}

if runtime_contract "$SKILL"; then pass=$((pass + 1)); else
  echo "FAIL: live Journal runtime contract is incomplete" >&2; fail=$((fail + 1)); fi

# Red-prove the absence scan with a recognizable bundled-runtime canary.
runtime_copy="$TMP/runtime-copy"
mkdir -p "$runtime_copy/verbs"
cp "$SKILL/SKILL.md" "$runtime_copy/SKILL.md"
cp "$SKILL/verbs/search.md" "$SKILL/verbs/done.md" "$SKILL/verbs/curate.md" \
  "$runtime_copy/verbs/"
canary='"$SKILL/scripts/records.sh" --root "$root" --records-root "$records" list'
expect_eq "bundled-runtime canary starts absent" "0" \
  "$(grep -Fhc -- "$canary" "$runtime_copy/verbs/"*.md | awk '{ total += $1 } END { print total + 0 }')"
printf '%s\n' "$canary" >>"$runtime_copy/verbs/search.md"
expect_eq "bundled-runtime canary mutation count" "1" \
  "$(grep -Fhc -- "$canary" "$runtime_copy/verbs/"*.md | awk '{ total += $1 } END { print total + 0 }')"
if runtime_contract "$runtime_copy"; then
  echo "FAIL: runtime absence scan missed the bundled-provider canary" >&2; fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# Red-prove repair dispatch as an absence check.
dispatch_copy="$TMP/dispatch-copy"
cp -R "$runtime_copy" "$dispatch_copy"
sed -i.bak '/| `\/journal repair` | `verbs\/repair.md` |/d' "$dispatch_copy/SKILL.md"
rm "$dispatch_copy/SKILL.md.bak"
rm -f "$dispatch_copy/verbs/search.md"
cp "$SKILL/verbs/search.md" "$dispatch_copy/verbs/search.md"
expect_eq "repair dispatch mutation removed one row" "0" \
  "$(grep -Fc '| `/journal repair` | `verbs/repair.md` |' "$dispatch_copy/SKILL.md")"
if runtime_contract "$dispatch_copy"; then
  echo "FAIL: runtime contract missed absent repair dispatch" >&2; fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# The rendered README is independently usable and every representative command
# form executes against a throwaway records layer.
root="$TMP/project"
setup_layer "$root"
README="$root/.records/README.md"
RS="$root/.records/records.sh"
expect_eq "README begin marker unique" "1" \
  "$(grep -Fc '<!-- journal:records-tool BEGIN -->' "$README")"
expect_eq "README end marker unique" "1" \
  "$(grep -Fc '<!-- journal:records-tool END -->' "$README")"
for readme_text in 'YYYY-MM-DD-<slug>.md' '`doctype`, `status`, `schema`, and `tags`' \
  'live crawl at' 'history.tsv' 'list [filters]' 'grep [filters]' 'show <path>' \
  'history [filters]' '`check` validates' 'new <doctype>' 'touch <path>' 'done <path>' \
  'relocate <source>' 'Run `/journal repair`' 'do not run a bundled Journal copy'; do
  expect "README contract: $readme_text" "$readme_text" "$README"
done

snippet="$(sed -n '/^    records_root=/,/^    "\$records_root\/records.sh"/p' "$README" | \
  sed 's/^    //' | sed "s#<absolute-project-root>#$root#")"
rc=0; (cd "$root" && sh -c "$snippet" >"$OUT" 2>"$ERR") || rc=$?
expect_eq "rendered list invocation rc" "0" "$rc"

rs() { "$RS" --root "$root" --records-root .records "$@"; }
today="$(date +%Y-%m-%d)"
record="$(rs new notes --schema notepad/note@1 --title 'Contract sample' --tag sample)"
printf '%s\n' 'body-search-canary' >>"$record"
rs touch "$record" --status published >/dev/null
rs list --type notes >"$OUT"
expect "rendered list form" "notes" "$OUT"
rs grep --type notes body-search-canary >"$OUT"
expect "rendered grep form" "contract-sample" "$OUT"
rs show "$record" >"$OUT"
expect "rendered show form" "# Contract sample" "$OUT"
rs check >"$OUT"
expect "rendered check form" "records check: OK" "$OUT"
relocated="notes/$today-contract-renamed.md"
rs relocate "$record" --to "$relocated" >/dev/null
rs "done" "$relocated" --as "done" --note 'contract complete' >/dev/null
rs history --type notes >"$OUT"
expect "rendered history form" "$relocated" "$OUT"
rs check >"$OUT"
expect "lifecycle forms leave records green" "records check: OK" "$OUT"

# Independently break each provider publication invariant immediately after
# installation. The hook counts its own target so a failed mutation cannot
# masquerade as a green guard; README publication must not occur.
mutation_hook="$TMP/provider-mutation.sh"
cat >"$mutation_hook" <<'EOF'
#!/bin/sh
set -eu
provider="$1/$2/records.sh"
[ "$3" = "$2/records.sh" ] || exit 0
case "$JOURNAL_PROVIDER_MUTATION" in
  bytes) printf '%s\n' '# provider-byte-canary' >>"$provider" ;;
  mode) chmod -x "$provider" ;;
  exit)
    count=$(grep -Fxc '  exit 1' "$provider")
    [ "$count" -eq 1 ] || exit 91
    awk '$0 == "  exit 1" { print "  exit 0"; changed++; next } { print } END { if (changed != 1) exit 1 }' \
      "$provider" >"$provider.tmp"
    mv "$provider.tmp" "$provider"; chmod +x "$provider"
    ;;
  grep)
    count=$(grep -Ec '^  grep[[:space:]]' "$provider")
    [ "$count" -eq 1 ] || exit 92
    awk '$0 !~ /^  grep[[:space:]]/' "$provider" >"$provider.tmp"
    mv "$provider.tmp" "$provider"; chmod +x "$provider"
    ;;
  *) exit 93 ;;
esac
EOF
chmod +x "$mutation_hook"

for provider_mutation in bytes mode exit grep; do
  invalid_root="$TMP/invalid-$provider_mutation"
  mkdir -p "$invalid_root"
  rc=0
  JOURNAL_PROVIDER_MUTATION="$provider_mutation" \
    JOURNAL_SETUP_TEST_AFTER_WRITE="$mutation_hook" \
    "$STANDUP" setup "$invalid_root" --records-root .records --workspace-root .spaces \
    >"$OUT" 2>"$ERR" || rc=$?
  expect_eq "$provider_mutation provider gate refusal rc" "2" "$rc"
  [ ! -e "$invalid_root/.records/README.md" ] && pass=$((pass + 1)) || {
    echo "FAIL: $provider_mutation provider published README guidance" >&2; fail=$((fail + 1)); }
done

# Repair uses the same gate and must preserve an existing block when the newly
# installed provider is made unusable before README refresh.
repair_gate="$TMP/repair-gate"
setup_layer "$repair_gate"
rm "$repair_gate/.records/records.sh"
sed -i.bak 's/## Use the records tool/## Stale records tool/' "$repair_gate/.records/README.md"
rm "$repair_gate/.records/README.md.bak"
cp "$repair_gate/.records/README.md" "$TMP/repair-gate.before"
rc=0
JOURNAL_PROVIDER_MUTATION=mode JOURNAL_SETUP_TEST_AFTER_WRITE="$mutation_hook" \
  "$STANDUP" repair "$repair_gate" --records-root .records --workspace-root .spaces \
  >"$OUT" 2>"$ERR" || rc=$?
expect_eq "repair provider gate refusal rc" "2" "$rc"
if cmp -s "$TMP/repair-gate.before" "$repair_gate/.records/README.md"; then
  pass=$((pass + 1))
else
  echo "FAIL: repair changed README before provider validation" >&2; fail=$((fail + 1))
fi

report "contract-test"
