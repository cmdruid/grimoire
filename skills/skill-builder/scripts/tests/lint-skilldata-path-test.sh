#!/usr/bin/env bash
# Prove the project skilldata grammar, custody, and retired-root hard cut.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
LINT="$(cd "$DIR/.." && pwd)/skills-lint.sh"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/sb-lint-skilldata.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
LIB="$TMP/lib"
OUT="$TMP/out"

reset_lib() {
  rm -rf "$LIB"
  mkdir -p "$LIB/skills/widget"
  printf '%s\n' '# fixture library' '`widget`' >"$LIB/README.md"
}

write_skill() {
  declaration="${2:-}"
  {
    printf '%s\n' '---' 'name: widget' \
      'description: "A throwaway project-skilldata lint fixture."' '---' '' '# widget' '' "$1"
    if [ -n "$declaration" ]; then
      printf '%s\n' '' '## Global skilldata' '' "$declaration"
    fi
    printf '%s\n' '' '## Edges' '<!-- edges:widget -->' \
      '- produces: — (none)' '- handoff: — (none)' '- consumes: — (none)' \
      '<!-- /edges:widget -->'
  } >"$LIB/skills/widget/SKILL.md"
}

lint() { bash "$LINT" "$LIB" >"$OUT" 2>&1 || true; }

reset_lib
write_skill 'Owned paths are `.agents/skilldata/widget/doctrine/policy.md`, `.agents/skilldata/widget/drafts/idea.md`, `.agents/skilldata/widget/hooks/after.md`, `.agents/skilldata/widget/operations/run.md`, `.agents/skilldata/widget/scripts/run.sh`, and `.agents/skilldata/widget/templates/item.md`.'
lint
for needle in 'invalid skilldata owner' 'kind-first skilldata path' 'unknown project skilldata kind' 'foreign skilldata owner'; do
  expect_absent "six owner-first kinds avoid $needle" "$needle" "$OUT"
done

reset_lib
write_skill 'Read `.agents/skilldata/Bad_Owner/hooks/after.md`.'
lint
expect 'invalid owner fails' 'invalid skilldata owner `Bad_Owner`' "$OUT"

reset_lib
write_skill 'Read `.agents/skilldata/doctrine/widget/policy.md`.'
lint
expect 'kind-first path fails' 'kind-first skilldata path' "$OUT"

reset_lib
write_skill 'Read `.agents/skilldata/widget/cache/item.md`.'
lint
expect 'unknown kind fails' 'unknown project skilldata kind `cache`' "$OUT"

reset_lib
write_skill 'Read `.agents/skilldata/widget/trackers/tasks.tsv`.'
lint
expect 'owner-local tracker fails grammar' 'unknown project skilldata kind `trackers`' "$OUT"
expect 'owner-local tracker names public alternative' 'owner-local tracker path -- use .trackers' "$OUT"

reset_lib
write_skill 'Read another publisher at `.agents/skilldata/other/operations/run.md`.'
lint
expect_absent 'documented cross-owner reads remain review judgment' 'foreign skilldata owner' "$OUT"

reset_lib
write_skill 'This fixture has an obvious foreign write.'
mkdir -p "$LIB/skills/widget/scripts"
printf '%s\n' '#!/usr/bin/env bash' 'mkdir -p "$root/.agents/skilldata/other/hooks"' >"$LIB/skills/widget/scripts/write.sh"
lint
expect 'obvious foreign writes fail' 'obvious write beneath foreign skilldata owner `other`' "$OUT"

reset_lib
write_skill 'This fixture improperly mutates installed package bytes.'
mkdir -p "$LIB/skills/widget/scripts"
printf '%s\n' '#!/usr/bin/env bash' 'mkdir -p "$root/.agents/skills/widget/data"' >"$LIB/skills/widget/scripts/write.sh"
lint
expect 'installed packages reject mutable writes' 'mutable write beneath installed package path .agents/skills' "$OUT"

retired='.spaces' # lint: allow retired-skilldata-rejection
reset_lib
write_skill "Read \`$retired/widget/hooks/after.md\`."
lint
expect 'retired project root fails' 'retired project skilldata root' "$OUT"

reset_lib
write_skill 'Read `.trackers/tables/tasks.tsv` through its adjacent provider.'
lint
expect_absent 'first-class tracker path remains valid' 'owner-local tracker path' "$OUT"

reset_lib
write_skill 'This global-only package writes no project data, but incorrectly reads `.agents/skilldata/widget/cache/item.md`.' \
  '- Scope: user-global, writes no project data.
- Path: `~/.agents/skilldata/widget/cache/`.
- Access: read-only; initialized by the user.
- Safety: unsafe parents refuse.
- Justification: the data spans projects.'
lint
expect 'global-only declaration does not exempt a project path' 'unknown project skilldata kind `cache`' "$OUT"

reset_lib
write_skill 'Read global `~/.agents/skilldata/widget/cache/item.md` and project `.agents/skilldata/widget/cache/item.md`.' \
  '- Scope: user-global, writes no project data.
- Path: `~/.agents/skilldata/widget/cache/`.
- Access: read-only; initialized by the user.
- Safety: unsafe parents refuse.
- Justification: the data spans projects.'
lint
expect 'scope classification masks only the global occurrence' 'unknown project skilldata kind `cache`' "$OUT"

reset_lib
write_skill 'This global-only package reports its resolved global store.' \
  '- Scope: user-global, writes no project data.
- Path: `~/.agents/skilldata/widget/feedback.tsv`.
- Access: read-only; initialized by the user.
- Safety: unsafe parents refuse.
- Justification: the data spans projects.'
mkdir -p "$LIB/skills/widget/scripts"
printf '%s\n' '#!/usr/bin/env bash' "printf '%s\\n' 'store=.agents/skilldata/widget/feedback.tsv'" >"$LIB/skills/widget/scripts/describe.sh"
lint
expect_absent 'declared global-only store report is not a project kind' 'unknown project skilldata kind `feedback.tsv`' "$OUT"

protocol_broken="$TMP/skills-lint-global-store.sh"
cp "$LINT" "$protocol_broken"
cp "$LINT" "$TMP/skills-lint-global-store.before"
protocol_target='grep -Eq "['"'"'\"]store=\.agents/skilldata/$name/"'
expect_eq 'global store exception target is unique' 1 "$(grep -cF "$protocol_target" "$protocol_broken")"
sed -i.bak '/store=.*skilldata.*name/ s/grep -Eq .*/grep -Eq NEVER_MATCH; then/' "$protocol_broken"
rm "$protocol_broken.bak"
expect_eq 'global store exception mutation applied once' 1 "$(grep -cF 'grep -Eq NEVER_MATCH; then' "$protocol_broken")"
if bash "$protocol_broken" "$LIB" >"$OUT" 2>&1; then
  echo 'FAIL: disabling the global store exception left its valid fixture green' >&2
  fail=$((fail + 1))
else
  expect 'disabled global store exception exposes project-kind misclassification' 'unknown project skilldata kind `feedback.tsv`' "$OUT"
fi
cp "$TMP/skills-lint-global-store.before" "$protocol_broken"
if cmp -s "$TMP/skills-lint-global-store.before" "$protocol_broken"; then pass=$((pass + 1)); else fail=$((fail + 1)); fi

red_proof_project_guard() { # label, target fragment, fixture kind
  label="$1"
  fragment="$2"
  fixture="$3"
  broken_guard="$TMP/skills-lint-$label.sh"
  before_guard="$TMP/skills-lint-$label.before"
  cp "$LINT" "$broken_guard"
  cp "$LINT" "$before_guard"
  count="$(grep -cF "$fragment" "$broken_guard")"
  expect_eq "$label mutation target is unique" 1 "$count"
  awk -v fragment="$fragment" '
    index($0, fragment) { sub(/fail .*/, ": # guard disabled"); changed++ }
    { print }
    END { if (changed != 1) exit 1 }
  ' "$broken_guard" >"$broken_guard.next"
  mv "$broken_guard.next" "$broken_guard"
  expect_eq "$label mutation applied once" 1 "$(grep -cF '# guard disabled' "$broken_guard")"

  reset_lib
  case "$fixture" in
    invalid-owner) write_skill 'Read `.agents/skilldata/Bad_Owner/hooks/after.md`.' ;;
    kind-first) write_skill 'Read `.agents/skilldata/doctrine/widget/policy.md`.' ;;
    unknown-kind)
      write_skill 'This global-only package writes no project data, but reads `.agents/skilldata/widget/cache/item.md`.' \
        '- Scope: user-global, writes no project data.
- Path: `~/.agents/skilldata/widget/cache/`.
- Access: read-only; initialized by the user.
- Safety: unsafe parents refuse.
- Justification: the data spans projects.'
      ;;
    foreign-write)
      write_skill 'This fixture has an obvious foreign write.'
      mkdir -p "$LIB/skills/widget/scripts"
      printf '%s\n' '#!/usr/bin/env bash' 'mkdir -p "$root/.agents/skilldata/other/hooks"' >"$LIB/skills/widget/scripts/write.sh"
      ;;
    installed-write)
      write_skill 'This fixture improperly mutates installed package bytes.'
      mkdir -p "$LIB/skills/widget/scripts"
      printf '%s\n' '#!/usr/bin/env bash' 'mkdir -p "$root/.agents/skills/widget/data"' >"$LIB/skills/widget/scripts/write.sh"
      ;;
    tracker) write_skill 'Read `.agents/skilldata/widget/trackers/tasks.tsv`.' ;;
  esac
  if [ "$fixture" = tracker ]; then
    bash "$broken_guard" "$LIB" >"$OUT" 2>&1 || true
    expect_absent "$label disabled guard removes its diagnostic" 'owner-local tracker path -- use .trackers' "$OUT"
  elif bash "$broken_guard" "$LIB" >"$OUT" 2>&1; then
    pass=$((pass + 1))
  else
    echo "FAIL: $label disabled guard did not make its isolated fixture green" >&2
    fail=$((fail + 1))
  fi
  cp "$before_guard" "$broken_guard"
  if cmp -s "$before_guard" "$broken_guard"; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
}

red_proof_project_guard invalid-owner 'fail "$name: $rel:$line_no: invalid skilldata owner' invalid-owner
red_proof_project_guard kind-first 'fail "$name: $rel:$line_no: kind-first skilldata path' kind-first
red_proof_project_guard unknown-kind 'fail "$name: $rel:$line_no: unknown project skilldata kind' unknown-kind
red_proof_project_guard foreign-write 'fail "$name: $rel:$line_no: obvious write beneath foreign skilldata owner' foreign-write
red_proof_project_guard installed-write 'fail "$name: $rel:${line%%:*}: mutable write beneath installed package path' installed-write
red_proof_project_guard tracker 'fail "$name: $rel:$line: owner-local tracker path' tracker

# Red proof: disable the one retired-root recognizer, prove the bad fixture goes green,
# then restore the temporary linter byte-for-byte.
broken="$TMP/skills-lint.sh"
before_copy="$TMP/skills-lint.before"
cp "$LINT" "$broken"
cp "$LINT" "$before_copy"
before="$(grep -c "^retired_skilldata_root='" "$broken")"
sed -i.bak "s/^retired_skilldata_root=.*/retired_skilldata_root='RETIRED_GUARD_DISABLED'/" "$broken"
rm "$broken.bak"
after="$(grep -c "^retired_skilldata_root='RETIRED_GUARD_DISABLED'" "$broken")"
expect_eq 'retired-root mutation target is unique' 1 "$before"
expect_eq 'retired-root mutation applied once' 1 "$after"
reset_lib
write_skill "Read \`$retired/widget/hooks/after.md\`."
if bash "$broken" "$LIB" >"$OUT" 2>&1; then
  expect_absent 'disabled retired-root guard misses the defect' 'retired project skilldata root' "$OUT"
else
  echo 'FAIL: broken lint did not isolate the retired-root guard' >&2
  fail=$((fail + 1))
fi
cp "$before_copy" "$broken"
if cmp -s "$before_copy" "$broken"; then pass=$((pass + 1)); else fail=$((fail + 1)); fi

report lint-skilldata-path-test
