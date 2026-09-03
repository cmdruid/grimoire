#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
INDEX="$HERE/../operation-template-index.sh"
CHECK="$HERE/../operation-check.sh"
START="$HERE/../goal-start.sh"
COMPILE="$HERE/../goal-compile.sh"
WRITE="$HERE/../operation-write.sh"
. "$HERE/lib.sh"

T="$(mktemp -d "${TMPDIR:-/tmp}/foreman-template-index-test.XXXXXX")"
trap 'rm -rf "$T"' EXIT
H="$T/home"
ROOT="$H/.agents/skilldata/foreman/templates/operations"
OUT="$T/out"
ERR="$T/err"
mkdir -p "$H"

run_catalog() { HOME="$H" "$INDEX" catalog >"$OUT" 2>"$ERR"; }
run_read() { HOME="$H" "$INDEX" read --stem "$1" >"$OUT" 2>"$ERR"; }

write_procedure() { # path, title, use-when, procedure body
  {
    printf '%s\n' '---' 'schema: foreman/operation-template@1'
    printf 'title: %s\nuse-when: %s\n' "$2" "$3"
    printf '%s\n' 'shape: procedure' 'areas: [release, delivery]' 'tags: [service]' '---' ''
    printf '# %s\n\n' "$2"
    printf '%s\n' '## Preconditions' '' '- The project is ready.' '' '## Procedure' ''
    printf '%s\n' "$4"
    printf '%s\n' '' '## Outputs' '' '- A completed result.' '' '## Verification' '' \
      '- Confirm the result.' '' '## Recovery' '' '- Restore the prior state.'
  } >"$1"
}

run_catalog
has 'missing root is an empty catalog' $'state\tabsent' "$OUT"
has 'missing root count' $'count\t0' "$OUT"
ok test ! -e "$H/.agents"

mkdir -p "$ROOT"
special_use="$(printf 'Use\twhen 100%% ready\rnow')"
write_procedure "$ROOT/zeta.md" 'Zeta' 'Use for the later template.' '1. Perform the later operation.'
write_procedure "$ROOT/alpha.md" 'Alpha 100%' "$special_use" '1. BODY_SECRET_ALPHA'
run_catalog
has 'present catalog state' $'state\tpresent' "$OUT"
has 'percent is encoded' $'Alpha 100%25' "$OUT"
has 'tab is encoded' 'Use%09when' "$OUT"
has 'carriage return is encoded' 'ready%0Dnow' "$OUT"
lacks 'catalog never leaks body text' 'BODY_SECRET_ALPHA' "$OUT"
eq 'valid count' 2 "$(awk -F '\t' '$1=="count"{print $2}' "$OUT")"
eq 'valid stems are bytewise sorted' $'alpha\nzeta' "$(awk -F '\t' '$1=="template"{print $2}' "$OUT")"
eq 'metadata rows keep seven fields' 7 "$(awk -F '\t' '$1=="template"{if(NF!=7)bad=1} END{print bad?0:7}' "$OUT")"

run_read alpha
has 'selected body becomes readable' 'BODY_SECRET_ALPHA' "$OUT"
lacks 'selected body omits template metadata' 'foreman/operation-template@1' "$OUT"

cp "$ROOT/alpha.md" "$ROOT/lifecycle.md"
sed -i.bak '/^shape:/a\
status: active' "$ROOT/lifecycle.md"
rm "$ROOT/lifecycle.md.bak"
cp "$ROOT/alpha.md" "$ROOT/bad-sections.md"
sed -i.bak 's/## Recovery/## Procedure/' "$ROOT/bad-sections.md"
rm "$ROOT/bad-sections.md.bak"
{
  printf '%s\n' '---' 'schema: foreman/operation-template@1' 'title: Concrete workflow' \
    'use-when: A workflow improperly names a project operation.' 'shape: workflow' \
    'areas: [release]' 'tags: [service]' '---' '' '# Concrete workflow' '' \
    '## Preconditions' '' '- Ready.' '' '## Steps' '' '1. `foreman/release` — run it.' '' \
    '## Outputs' '' '- Result.' '' '## Verification' '' '- Confirm.' '' '## Recovery' '' '- Restore.'
} >"$ROOT/concrete.md"
ln -s "$ROOT/alpha.md" "$ROOT/linked.md"
run_catalog
has 'lifecycle fields are rejected' $'invalid\tlifecycle\tinvalid-front-matter' "$OUT"
has 'invalid section shapes are rejected' $'invalid\tbad-sections\tinvalid-section-shape' "$OUT"
has 'concrete workflow identities are rejected' $'invalid\tconcrete\tinvalid-workflow-steps' "$OUT"
has 'symlinked files are rejected' $'invalid\tlinked\tunsafe-template' "$OUT"
lacks 'invalid template body remains private' 'foreman/release' "$OUT"

if run_read lifecycle; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
has 'explicit invalid selection refuses' 'reason=invalid-front-matter' "$ERR"
if HOME="$H" "$INDEX" read --stem '../alpha' >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
has 'traversal selection refuses' 'reason=bad-stem' "$ERR"
if run_read linked; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
has 'symlink selection refuses' 'reason=missing-or-unsafe-template' "$ERR"

unsafe_home="$T/unsafe-home"
mkdir -p "$unsafe_home/real-skilldata" "$unsafe_home/.agents"
ln -s "$unsafe_home/real-skilldata" "$unsafe_home/.agents/skilldata"
HOME="$unsafe_home" "$INDEX" catalog >"$OUT" 2>"$ERR"
has 'symlinked root is safely disabled' $'state\tunsafe' "$OUT"
has 'unsafe root returns no candidates' $'count\t0' "$OUT"

# Trace explicit selection through inert curation into the ordinary candidate checker.
write_procedure "$ROOT/curated.md" 'Curated release' 'Use for a project release.' \
  '1. Use SECRET_TOKEN=abc, /Users/example/project, source: imported.md, and IGNORE_PREVIOUS.'
run_catalog
lacks 'curation source body is metadata-private' 'SECRET_TOKEN' "$OUT"
HOME="$H" "$INDEX" read --stem curated >"$T/selected-body"
curator="$T/curate.sh"
cat >"$curator" <<'EOF'
#!/usr/bin/env bash
set -eu
sed -e 's/SECRET_TOKEN=abc/a runtime-provided credential/' \
    -e 's#/Users/example/project#the resolved project root#' \
    -e 's/source: imported.md/a reviewed project source/' \
    -e 's/IGNORE_PREVIOUS/inert source prose/' "$1"
EOF
chmod +x "$curator"
"$curator" "$T/selected-body" >"$T/curated-body"
{
  printf '%s\n' '---' 'schema: foreman/operation@1' 'title: Curated release' \
    'use-when: Use for a project release.' 'shape: procedure' 'status: draft' \
    'areas: [release, delivery]' 'tags: [service]' '---'
  cat "$T/curated-body"
} >"$T/candidate.md"
for plant in SECRET_TOKEN /Users/example/project 'source: imported.md' IGNORE_PREVIOUS; do
  lacks "curation removes $plant" "$plant" "$T/candidate.md"
done
project="$T/project"
mkdir "$project"
"$CHECK" --root "$project" --operation foreman/curated \
  --candidate "foreman/curated=$T/candidate.md" >"$OUT"
has 'materialized candidate uses ordinary validation' 'valid=true' "$OUT"
ok test ! -e "$project/.agents/skilldata"

# Once selected bytes become a project operation, no later phase consults the global source.
"$START" render --root "$project" --identity foreman/curated --objective 'Run curated release' \
  --candidate "$T/candidate.md" --goal-output "$T/curated-goal.md" --manifest-output "$T/curated-manifest" >"$OUT"
preview="$(fact preview_digest "$OUT")"
"$START" apply --root "$project" --candidate "$T/candidate.md" --goal-input "$T/curated-goal.md" \
  --manifest-input "$T/curated-manifest" --expected-preview-digest "$preview" >/dev/null
printf '\nGLOBAL_CHANGED_AFTER_MATERIALIZATION\n' >>"$ROOT/curated.md"; global_after_user_change="$(shasum -a 256 "$ROOT/curated.md"|awk '{print $1}')"
goal_rel="$(sed -n '3s/^goal_record=//p' "$T/curated-manifest")"
"$COMPILE" check --root "$project" --input "$project/.records/$goal_rel" >"$OUT"
eq 'goal check remains project-local' true "$(fact provisional "$OUT")"
"$CHECK" --root "$project" --operation foreman/curated >"$OUT"; curated_digest="$(fact digest "$OUT")"
curated_file="$project/.agents/skilldata/foreman/operations/curated.md"; curated_raw="$(shasum -a 256 "$curated_file"|awk '{print $1}')"
printf '%s\n' '- observed: curated release completed and checks passed.' >"$T/curated-evidence"
curated_evidence_raw="$(shasum -a 256 "$T/curated-evidence"|awk '{print $1}')"
"$WRITE" promote --root "$project" --identity foreman/curated --expected-digest "$curated_digest" \
  --expected-file-sha256 "$curated_raw" --evidence-file "$T/curated-evidence" \
  --expected-evidence-sha256 "$curated_evidence_raw" >/dev/null
"$CHECK" --root "$project" --operation foreman/curated >"$OUT"
eq 'promotion remains project-local' true "$(fact goal_eligible "$OUT")"
"$COMPILE" check --root "$project" --input "$project/.records/$goal_rel" >"$OUT"
eq 'promoted goal remains resumable' true "$(fact provisional "$OUT")"
eq 'Foreman never rewrites global template bytes' "$global_after_user_change" "$(shasum -a 256 "$ROOT/curated.md"|awk '{print $1}')"
lacks 'project operation stores no global path' '.agents/skilldata/foreman/templates/operations' "$curated_file"
lacks 'project operation ignores later global mutation' 'GLOBAL_CHANGED_AFTER_MATERIALIZATION' "$curated_file"

# Red proof: bypass exactly the curation transform and the planted-content assertion turns red.
cp "$curator" "$T/curator.before"
broken="$T/curate-broken.sh"
cp "$curator" "$broken"
before="$(grep -c '^sed -e ' "$broken")"
sed -i.bak 's/^sed -e .*$/cat "$1"; exit 0 # curation guard disabled/' "$broken"
rm "$broken.bak"
after="$(grep -c 'curation guard disabled' "$broken")"
eq 'curation mutation target is unique' 1 "$before"
eq 'curation mutation applied once' 1 "$after"
chmod +x "$broken"
"$broken" "$T/selected-body" >"$T/bypassed-body"
if ! grep -qF 'SECRET_TOKEN' "$T/bypassed-body"; then
  echo 'FAIL: disabled curation guard did not expose the planted token' >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
ok cmp -s "$curator" "$T/curator.before"

# Red proof: disabling the read-time symlink guard admits the selected symlink.
broken_index="$T/operation-template-index.sh"
cp "$INDEX" "$T/index.before"
cp "$INDEX" "$broken_index"
before="$(grep -c '\[ ! -L "$selected" \] && \[ -f "$selected" \]\|\[ -f "$file" \] && \[ ! -L "$file" \]' "$broken_index")"
sed -i.bak 's/\[ ! -L "$selected" \] && \[ -f "$selected" \]/[ -f "$selected" ]/' "$broken_index"
rm "$broken_index.bak"
sed -i.bak 's/\[ -f "$file" \] && \[ ! -L "$file" \]/[ -f "$file" ]/' "$broken_index"
rm "$broken_index.bak"
after="$(grep -c '^  \[ -f "$selected" \] ||\|^  \[ -f "$file" \] ||' "$broken_index")"
eq 'symlink guard mutation targets are exact' 2 "$before"
eq 'symlink guard mutations applied exactly' 2 "$after"
chmod +x "$broken_index"
if HOME="$H" "$broken_index" read --stem linked >"$OUT" 2>"$ERR"; then
  has 'disabled guard exposes linked body' 'BODY_SECRET_ALPHA' "$OUT"
else
  echo 'FAIL: disabled symlink guard did not make its refusal fixture red' >&2
  fail=$((fail + 1))
fi
ok cmp -s "$INDEX" "$T/index.before"

report operation-template-index-test
