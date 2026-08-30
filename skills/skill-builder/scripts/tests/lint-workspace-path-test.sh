#!/usr/bin/env bash
# lint-workspace-path-test.sh — prove the retired kind-first workspace-path guard.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
LINT="$(cd "$DIR/.." && pwd)/skills-lint.sh"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/sb-lint-workspace.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
LIB="$TMP/lib"
OUT="$TMP/out"

write_skill() { # write_skill <body>
  mkdir -p "$LIB/skills/widget"
  {
    printf '%s\n' '---' 'name: widget' \
      'description: "A throwaway workspace-path lint fixture."' '---' '' '# widget' ''
    printf '%s\n' "$1"
    printf '%s\n' '' '## Edges' '<!-- edges:widget -->' \
      '- produces: — (none)' '- handoff: — (none)' '- consumes: — (none)' \
      '<!-- /edges:widget -->'
  } > "$LIB/skills/widget/SKILL.md"
}

lint() {
  bash "$LINT" "$LIB" > "$OUT" 2>&1 || true
}

old_angle=".spaces"'/doctrine/widget.md'
old_default='.spaces'"/hooks/widget.md"
old_operation=".spaces"'/operations/widget.md'
old_draft=".spaces"'/drafts/widget.md'
needle='kind-first workspace path'
tracker_needle='owner-local tracker path'

mkdir -p "$LIB/skills"
write_skill "Read \`$old_angle\`."
lint
expect "angle-bracket kind-first path FAILs" "$needle" "$OUT"

rm -rf "$LIB"
mkdir -p "$LIB/skills"
write_skill "Read \`$old_default\`."
lint
expect "default kind-first path FAILs" "$needle" "$OUT"

rm -rf "$LIB"
mkdir -p "$LIB/skills"
write_skill "Read \`$old_operation\`."
lint
expect "operation kind-first path FAILs" "$needle" "$OUT"

rm -rf "$LIB"
mkdir -p "$LIB/skills"
write_skill "Read \`$old_draft\`."
lint
expect "draft kind-first path FAILs" "$needle" "$OUT"

rm -rf "$LIB"
mkdir -p "$LIB/skills"
write_skill 'Read `.spaces/widget/doctrine/policy.md`, `.spaces/widget/drafts/idea.md`, and `.spaces/widget/operations/run.md`, by default `.spaces/widget/doctrine/policy.md`.'
lint
expect_absent "owner-first paths stay green" "$needle" "$OUT"

rm -rf "$LIB"
mkdir -p "$LIB/skills"
old_tracker=".spaces"'/widget/'"trackers"'/tasks.tsv'
write_skill "Read \`$old_tracker\`."
lint
expect "owner-local tracker path FAILs" "$tracker_needle" "$OUT"

rm -rf "$LIB"
mkdir -p "$LIB/skills"
write_skill 'Read `.trackers/tasks.tsv` through the staged provider.'
lint
expect_absent "first-class tracker path stays green" "$tracker_needle" "$OUT"

report "lint-workspace-path-test"
