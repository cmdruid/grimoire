#!/usr/bin/env bash
# Prove the machine-detectable global-skilldata declaration and its red arm.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
LINT="$(cd "$DIR/.." && pwd)/skills-lint.sh"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/sb-lint-global-skilldata.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
LIB="$TMP/lib"
OUT="$TMP/out"

reset_lib() {
  rm -rf "$LIB"
  mkdir -p "$LIB/skills/widget"
  printf '%s\n' '# fixture library' '`widget`' >"$LIB/README.md"
}

write_skill() { # body, optional global declaration body
  body="$1"
  declaration="${2:-}"
  {
    printf '%s\n' '---' 'name: widget' \
      'description: "A throwaway global-skilldata lint fixture."' '---' '' '# widget' '' "$body"
    if [ -n "$declaration" ]; then
      printf '%s\n' '' '## Global skilldata' '' "$declaration"
    fi
    printf '%s\n' '' '## Edges' '<!-- edges:widget -->' \
      '- produces: — (none)' '- handoff: — (none)' '- consumes: — (none)' \
      '<!-- /edges:widget -->'
  } >"$LIB/skills/widget/SKILL.md"
}

good_declaration='- Scope: user-global, private templates.
- Path: `~/.agents/skilldata/widget/templates/`.
- Access: read-only; initialized by the user.
- Safety: unsafe parents refuse and sensitive values are never stored.
- Justification: the templates span projects and cannot live in package bytes.'

lint() { bash "$LINT" "$LIB" >"$OUT" 2>&1 || true; }
declaration_failure='global skilldata use requires exactly one `## Global skilldata` declaration'

reset_lib
write_skill 'Read `.agents/skilldata/widget/templates/item.md` when present.'
lint
expect_absent 'project-only packages need no global declaration' 'Global skilldata' "$OUT"

reset_lib
write_skill 'Read `~/.agents/skilldata/widget/templates/item.md`; this global-only package writes no project data.' "$good_declaration"
lint
expect_absent 'complete own-owner declaration passes' 'FAIL: widget: Global skilldata' "$OUT"

reset_lib
write_skill 'Project templates at `.agents/skilldata/widget/templates/item.md` win over global `~/.agents/skilldata/widget/templates/item.md`; selected global bytes are materialized only through a complete project preview.' \
  "$good_declaration
- Precedence and materialization: project content wins; selected global input becomes reviewed project bytes."
lint
expect_absent 'project-plus-global declaration with precedence passes' 'FAIL: widget: Global skilldata' "$OUT"

reset_lib
write_skill 'Read `~/.agents/skilldata/widget/templates/item.md`.'
lint
expect 'missing declaration fails' "$declaration_failure" "$OUT"

reset_lib
write_skill 'Read `~/.agents/skilldata/other/templates/item.md`.' "$good_declaration"
lint
expect 'cross-owner global use fails' 'global skilldata use names owner `other`' "$OUT"

reset_lib
write_skill 'Read `~/.agents/skilldata/widget/templates/item.md`.' \
  '- Scope: user-global, private templates.
- Path: `~/.agents/skilldata/other/templates/`.
- Access: read-only; initialized by the user.
- Safety: unsafe parents refuse.
- Justification: the templates span projects.'
lint
expect 'contradictory declaration path fails' 'Path must name its own fixed global owner' "$OUT"

reset_lib
write_skill 'Read `~/.agents/skilldata/widget/templates/item.md`.' \
  '- Scope: user-global, private templates.
- Path: `~/.agents/skilldata/widget/templates/`.
- Access: execute; initialized by the user.
- Justification: the templates span projects.'
lint
expect 'missing safety bullet fails' 'needs exactly one nonempty `- Safety:` bullet' "$OUT"
expect 'invalid access fails' 'Access must begin with read-only or read-write' "$OUT"

reset_lib
write_skill 'Read the private catalog.' "$good_declaration"
mkdir -p "$LIB/skills/widget/scripts"
printf '%s\n' '#!/usr/bin/env bash' 'catalog="$HOME/.agents/skilldata/widget/templates"' >"$LIB/skills/widget/scripts/read.sh"
lint
expect_absent 'HOME-based construction is covered by a declaration' 'FAIL: widget: Global skilldata' "$OUT"

# Skill-builder's placeholder teaching forms stay inert, but a concrete global owner in those same
# files remains gated; there is no whole-file self-hosting exemption.
reset_lib
write_skill 'Skill-builder teaches placeholder forms without owning global data.'
mv "$LIB/skills/widget" "$LIB/skills/skill-builder"
sed -i.bak 's/name: widget/name: skill-builder/' "$LIB/skills/skill-builder/SKILL.md"; rm "$LIB/skills/skill-builder/SKILL.md.bak"
printf '%s\n' '# fixture library' '`skill-builder`' >"$LIB/README.md"
mkdir -p "$LIB/skills/skill-builder/verbs"
printf '%s\n' 'Teach `~/.agents/skilldata/<new-skill>/<owned-tail>/`.' >"$LIB/skills/skill-builder/verbs/new.md"
lint
expect_absent 'placeholder self-hosting form is inert' 'global skilldata use requires' "$OUT"
printf '%s\n' 'Bad concrete teaching path: `~/.agents/skilldata/other/cache/`.' >>"$LIB/skills/skill-builder/verbs/new.md"
lint
expect 'concrete self-hosting path remains gated' 'global skilldata use requires exactly one' "$OUT"

red_proof_global_guard() { # label, target fragment, fixture
  label="$1"
  fragment="$2"
  fixture="$3"
  broken_guard="$TMP/skills-lint-$label.sh"
  before_guard="$TMP/skills-lint-$label.before"
  cp "$LINT" "$broken_guard"
  cp "$LINT" "$before_guard"
  expect_eq "$label mutation target is unique" 1 "$(grep -cF "$fragment" "$broken_guard")"
  awk -v fragment="$fragment" '
    index($0, fragment) { sub(/fail .*/, ": # guard disabled"); changed++ }
    { print }
    END { if (changed != 1) exit 1 }
  ' "$broken_guard" >"$broken_guard.next"
  mv "$broken_guard.next" "$broken_guard"
  expect_eq "$label mutation applied once" 1 "$(grep -cF '# guard disabled' "$broken_guard")"

  reset_lib
  case "$fixture" in
    missing-section) write_skill 'Read `~/.agents/skilldata/widget/templates/item.md`.' ;;
    missing-field)
      write_skill 'Read `~/.agents/skilldata/widget/templates/item.md`.' \
        '- Scope: user-global, private templates.
- Path: `~/.agents/skilldata/widget/templates/`.
- Access: read-only; initialized by the user.
- Justification: the templates span projects.'
      ;;
    bad-scope)
      write_skill 'Read `~/.agents/skilldata/widget/templates/item.md`.' \
        '- Scope: project-local, private templates.
- Path: `~/.agents/skilldata/widget/templates/`.
- Access: read-only; initialized by the user.
- Safety: unsafe parents refuse.
- Justification: the templates span projects.'
      ;;
    bad-access)
      write_skill 'Read `~/.agents/skilldata/widget/templates/item.md`.' \
        '- Scope: user-global, private templates.
- Path: `~/.agents/skilldata/widget/templates/`.
- Access: execute; initialized by the user.
- Safety: unsafe parents refuse.
- Justification: the templates span projects.'
      ;;
    bad-path)
      write_skill 'Read `~/.agents/skilldata/widget/templates/item.md`.' \
        '- Scope: user-global, private templates.
- Path: `~/.agents/skilldata/other/templates/`.
- Access: read-only; initialized by the user.
- Safety: unsafe parents refuse.
- Justification: the templates span projects.'
      ;;
    foreign-use) write_skill 'Read `~/.agents/skilldata/other/templates/item.md`.' "$good_declaration" ;;
  esac
  if [ "$fixture" = bad-path ]; then
    bash "$broken_guard" "$LIB" >"$OUT" 2>&1 || true
    expect_absent "$label disabled guard removes its diagnostic" 'Path must name its own fixed global owner' "$OUT"
  elif bash "$broken_guard" "$LIB" >"$OUT" 2>&1; then
    pass=$((pass + 1))
  else
    echo "FAIL: $label disabled guard did not make its isolated fixture green" >&2
    fail=$((fail + 1))
  fi
  cp "$before_guard" "$broken_guard"
  if cmp -s "$before_guard" "$broken_guard"; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
}

red_proof_global_guard missing-section 'fail "$name: global skilldata use requires exactly one' missing-section
red_proof_global_guard missing-field 'fail "$name: Global skilldata declaration needs exactly one nonempty' missing-field
red_proof_global_guard bad-scope 'fail "$name: Global skilldata Scope must be user-global' bad-scope
red_proof_global_guard bad-access 'fail "$name: Global skilldata Access must begin with read-only or read-write' bad-access
red_proof_global_guard bad-path 'fail "$name: Global skilldata Path must name its own fixed global owner' bad-path
red_proof_global_guard foreign-use 'fail "$name: global skilldata use names owner' foreign-use

# Red proof: disabling the unique global-prefix recognizer makes the missing-declaration case pass.
broken="$TMP/skills-lint.sh"
before_copy="$TMP/skills-lint.before"
cp "$LINT" "$broken"
cp "$LINT" "$before_copy"
before="$(grep -c '^global_skilldata_prefix=' "$broken")"
sed -i.bak "s#^global_skilldata_prefix=.*#global_skilldata_prefix='THIS_PATTERN_CANNOT_MATCH'#" "$broken"
rm "$broken.bak"
after="$(grep -c "^global_skilldata_prefix='THIS_PATTERN_CANNOT_MATCH'" "$broken")"
expect_eq 'global guard mutation target is unique' 1 "$before"
expect_eq 'global guard mutation applied once' 1 "$after"
reset_lib
write_skill 'Read `~/.agents/skilldata/widget/templates/item.md`.'
if bash "$broken" "$LIB" >"$OUT" 2>&1; then
  expect_absent 'disabled global guard misses the declaration defect' "$declaration_failure" "$OUT"
else
  echo 'FAIL: broken lint did not isolate the global declaration guard' >&2
  fail=$((fail + 1))
fi
cp "$before_copy" "$broken"
if cmp -s "$before_copy" "$broken"; then pass=$((pass + 1)); else fail=$((fail + 1)); fi

report lint-global-skilldata-test
