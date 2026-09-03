#!/usr/bin/env bash
set -euo pipefail

HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"

ANCHOR="$SKILL/scripts/feedback-anchor.sh"
VERB="$SKILL/verbs/anchor.md"
TEMPLATE="$SKILL/templates/agents-route.md"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

run_anchor() {
  local home="$1"
  shift
  HOME="$home" "$ANCHOR" "$@"
}

home="$TMP/absent"
new_home "$home"
preview="$TMP/preview"
run_anchor "$home" preview >"$preview"
has "$preview" 'status=change'
has "$preview" 'base-sha256=absent'
has "$preview" '## Skill routes (self-registered)'
has "$preview" '<!-- skill:agent-feedback BEGIN built-against:'
has "$preview" 'Edges: produces `feedback-observation`.'
no test -e "$home/.agents"
no run_anchor "$home" apply --base-sha256 absent
no test -e "$home/.agents"
no run_anchor "$home" apply --confirmed --base-sha256 deadbeef
no test -e "$home/.agents"

apply_out="$TMP/apply"
run_anchor "$home" apply --confirmed --base-sha256 absent >"$apply_out"
has "$apply_out" 'wrote=AGENTS.md'
agents="$home/.agents/AGENTS.md"
ok test -f "$agents"
if [ "$(mode_of "$home/.agents")" = 700 ]; then pass; else fail '.agents mode is not 0700'; fi
if [ "$(mode_of "$agents")" = 600 ]; then pass; else fail 'AGENTS.md mode is not 0600'; fi
has "$agents" '### /agent-feedback — capture reusable agent-system feedback'
has "$agents" 'Edges: produces `feedback-observation`.'

run_anchor "$home" preview >"$preview"
has "$preview" 'status=noop'
base="$(sed -n 's/^base-sha256=//p' "$preview")"
run_anchor "$home" apply --confirmed --base-sha256 "$base" >"$apply_out"
has "$apply_out" 'status=noop'

# A preview token is optimistic concurrency control, not a reusable authorization.
printf '\nconcurrent edit\n' >>"$agents"
no run_anchor "$home" apply --confirmed --base-sha256 "$base"
has "$agents" 'concurrent edit'

# Removal deletes only the owned block and preserves the heading and surrounding bytes.
run_anchor "$home" preview --remove >"$preview"
base="$(sed -n 's/^base-sha256=//p' "$preview")"
cp "$agents" "$TMP/before-remove"
run_anchor "$home" apply --remove --confirmed --base-sha256 "$base" >"$apply_out"
has "$apply_out" 'removed=AGENTS.md'
has "$agents" '## Skill routes (self-registered)'
has "$agents" 'concurrent edit'
no grep -qF '<!-- skill:agent-feedback BEGIN' "$agents"
cp "$agents" "$TMP/after-remove"
run_anchor "$home" preview --remove >"$preview"
has "$preview" 'status=noop'
base="$(sed -n 's/^base-sha256=//p' "$preview")"
run_anchor "$home" apply --remove --confirmed --base-sha256 "$base" >"$apply_out"
has "$apply_out" 'status=noop'
same "$agents" "$TMP/after-remove"

# Existing prose and a single reserved heading are retained around insertion.
home="$TMP/existing"
new_home "$home"
mkdir -p "$home/.agents"
chmod 700 "$home/.agents"
printf '# Personal instructions\n\nKeep this.\n\n## Skill routes (self-registered)\n\nExisting route.\n\n## Tail\n\nKeep tail.\n' >"$home/.agents/AGENTS.md"
chmod 600 "$home/.agents/AGENTS.md"
run_anchor "$home" preview >"$preview"
base="$(sed -n 's/^base-sha256=//p' "$preview")"
run_anchor "$home" apply --confirmed --base-sha256 "$base" >/dev/null
has "$home/.agents/AGENTS.md" 'Existing route.'
has "$home/.agents/AGENTS.md" 'Keep tail.'

# A drifted block is updated without reserializing CRLF or a missing final newline around it.
home="$TMP/drifted"
new_home "$home"
mkdir -p "$home/.agents"
chmod 700 "$home/.agents"
printf 'before\r\n## Skill routes (self-registered)\r\nkeep-before\r\n<!-- skill:agent-feedback BEGIN built-against:old -->\r\nold owned bytes\r\n<!-- skill:agent-feedback END -->\r\nafter-without-newline' >"$home/.agents/AGENTS.md"
chmod 600 "$home/.agents/AGENTS.md"
printf 'before\r\n## Skill routes (self-registered)\r\nkeep-before\r\nafter-without-newline' >"$TMP/drifted-expected-remove"
run_anchor "$home" preview --remove >"$preview"
base="$(sed -n 's/^base-sha256=//p' "$preview")"
run_anchor "$home" apply --remove --confirmed --base-sha256 "$base" >/dev/null
same "$home/.agents/AGENTS.md" "$TMP/drifted-expected-remove"

# Malformed or ambiguous ownership is a hard refusal with no mutation.
for case_name in duplicate-heading orphan-begin orphan-end duplicate-block inverted-block block-before-heading block-after-section malformed-marker; do
  case_home="$TMP/$case_name"
  new_home "$case_home"
  mkdir -p "$case_home/.agents"
  chmod 700 "$case_home/.agents"
  case "$case_name" in
    duplicate-heading)
      printf '## Skill routes (self-registered)\n\n## Skill routes (self-registered)\n' >"$case_home/.agents/AGENTS.md"
      ;;
    orphan-begin)
      printf '<!-- skill:agent-feedback BEGIN built-against:test -->\n' >"$case_home/.agents/AGENTS.md"
      ;;
    orphan-end)
      printf '<!-- skill:agent-feedback END -->\n' >"$case_home/.agents/AGENTS.md"
      ;;
    duplicate-block)
      printf '<!-- skill:agent-feedback BEGIN built-against:a -->\nx\n<!-- skill:agent-feedback END -->\n<!-- skill:agent-feedback BEGIN built-against:b -->\ny\n<!-- skill:agent-feedback END -->\n' >"$case_home/.agents/AGENTS.md"
      ;;
    inverted-block)
      printf '## Skill routes (self-registered)\n<!-- skill:agent-feedback END -->\n<!-- skill:agent-feedback BEGIN built-against:a -->\n' >"$case_home/.agents/AGENTS.md"
      ;;
    block-before-heading)
      printf '<!-- skill:agent-feedback BEGIN built-against:a -->\nx\n<!-- skill:agent-feedback END -->\n## Skill routes (self-registered)\n' >"$case_home/.agents/AGENTS.md"
      ;;
    block-after-section)
      printf '## Skill routes (self-registered)\n## Tail\n<!-- skill:agent-feedback BEGIN built-against:a -->\nx\n<!-- skill:agent-feedback END -->\n' >"$case_home/.agents/AGENTS.md"
      ;;
    malformed-marker)
      printf '## Skill routes (self-registered)\n <!-- skill:agent-feedback BEGIN built-against:a -->\nx\n<!-- skill:agent-feedback END -->\n' >"$case_home/.agents/AGENTS.md"
      ;;
  esac
  chmod 600 "$case_home/.agents/AGENTS.md"
  cp "$case_home/.agents/AGENTS.md" "$TMP/$case_name.before"
  no run_anchor "$case_home" preview
  same "$case_home/.agents/AGENTS.md" "$TMP/$case_name.before"
done

# Marker-like examples inside fenced code do not claim ownership or reserve the heading.
home="$TMP/fenced"
new_home "$home"
mkdir -p "$home/.agents"
chmod 700 "$home/.agents"
printf '# Examples\n\n```markdown\n## Skill routes (self-registered)\n<!-- skill:agent-feedback BEGIN built-against:fake -->\n<!-- skill:agent-feedback END -->\n```\n' >"$home/.agents/AGENTS.md"
chmod 600 "$home/.agents/AGENTS.md"
run_anchor "$home" preview >"$preview"
has "$preview" 'status=change'
base="$(sed -n 's/^base-sha256=//p' "$preview")"
run_anchor "$home" apply --confirmed --base-sha256 "$base" >/dev/null
[ "$(grep -c '^## Skill routes (self-registered)$' "$home/.agents/AGENTS.md")" -eq 2 ] && pass || fail 'fenced heading handling'

# Fence parsing follows the opening delimiter and length. Shorter or unlike
# delimiters inside a fence are example bytes, not ownership syntax.
for fence_case in longer-backtick tilde-with-backtick longer-tilde; do
  home="$TMP/fenced-$fence_case"
  new_home "$home"
  mkdir -p "$home/.agents"
  chmod 700 "$home/.agents"
  case "$fence_case" in
    longer-backtick)
      printf '# Examples\n\n````markdown\n```\n## Skill routes (self-registered)\n<!-- skill:agent-feedback BEGIN built-against:fake -->\nfake example body\n<!-- skill:agent-feedback END -->\n```\n````\n' >"$home/.agents/AGENTS.md"
      ;;
    tilde-with-backtick)
      printf '# Examples\n\n~~~markdown\n```\n## Skill routes (self-registered)\n<!-- skill:agent-feedback BEGIN built-against:fake -->\nfake example body\n<!-- skill:agent-feedback END -->\n```\n~~~\n' >"$home/.agents/AGENTS.md"
      ;;
    longer-tilde)
      printf '# Examples\n\n~~~~markdown\n~~~\n## Skill routes (self-registered)\n<!-- skill:agent-feedback BEGIN built-against:fake -->\nfake example body\n<!-- skill:agent-feedback END -->\n~~~\n~~~~\n' >"$home/.agents/AGENTS.md"
      ;;
  esac
  chmod 600 "$home/.agents/AGENTS.md"
  run_anchor "$home" preview >"$preview"
  base="$(sed -n 's/^base-sha256=//p' "$preview")"
  run_anchor "$home" apply --confirmed --base-sha256 "$base" >/dev/null
  has "$home/.agents/AGENTS.md" 'fake example body'
  [ "$(grep -c '^## Skill routes (self-registered)$' "$home/.agents/AGENTS.md")" -eq 2 ] && pass || fail "$fence_case heading handling"
done

# HOME itself may be a symlink; the helper resolves it before enforcing the
# no-symlink rule on descendants.
real_home="$TMP/physical-home"
home="$TMP/symlink-home"
new_home "$real_home"
ln -s "$real_home" "$home"
run_anchor "$home" preview >"$preview"
has "$preview" 'base-sha256=absent'
base="$(sed -n 's/^base-sha256=//p' "$preview")"
run_anchor "$home" apply --confirmed --base-sha256 "$base" >/dev/null
ok test -f "$real_home/.agents/AGENTS.md"

# Unsafe descendants and files are rejected; legacy feedback is never touched.
home="$TMP/unsafe-dir"
new_home "$home"
outside="$TMP/outside"
mkdir -p "$outside"
ln -s "$outside" "$home/.agents"
no run_anchor "$home" preview
no test -e "$outside/AGENTS.md"

home="$TMP/unsafe-file"
new_home "$home"
mkdir -p "$home/.agents"
chmod 700 "$home/.agents"
printf 'outside\n' >"$outside/file"
ln -s "$outside/file" "$home/.agents/AGENTS.md"
no run_anchor "$home" preview
has "$outside/file" 'outside'

home="$TMP/legacy"
new_home "$home"
mkdir -p "$home/.agents"
chmod 700 "$home/.agents"
printf 'legacy bytes\n' >"$home/.agents/FEEDBACK.md"
printf '# Existing route\n\nSend reusable-skill feedback to `/old-feedback`.\n' >"$home/.agents/AGENTS.md"
chmod 600 "$home/.agents/AGENTS.md"
cp "$home/.agents/FEEDBACK.md" "$TMP/legacy.before"
run_anchor "$home" preview >"$preview"
base="$(sed -n 's/^base-sha256=//p' "$preview")"
run_anchor "$home" apply --confirmed --base-sha256 "$base" >/dev/null
run_anchor "$home" preview --remove >"$preview"
base="$(sed -n 's/^base-sha256=//p' "$preview")"
run_anchor "$home" apply --remove --confirmed --base-sha256 "$base" >/dev/null
same "$home/.agents/FEEDBACK.md" "$TMP/legacy.before"
has "$home/.agents/AGENTS.md" 'Send reusable-skill feedback to `/old-feedback`.'

# The stamp follows the latest commit touching the package path, not repository-wide HEAD.
repo="$TMP/stamp-repo"
mkdir -p "$repo/skill/scripts" "$repo/skill/templates"
cp "$ANCHOR" "$repo/skill/scripts/feedback-anchor.sh"
awk '{ print }' "$TEMPLATE" >"$repo/skill/templates/agents-route.md"
cp "$SKILL/SKILL.md" "$repo/skill/SKILL.md"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.invalid
git -C "$repo" config user.name 'Skill Feedback Test'
git -C "$repo" add skill
git -C "$repo" commit -qm 'add skill'
first_stamp="$(git -C "$repo" log -1 --format=%h -- skill)"
stamp_home="$TMP/stamp-home"
new_home "$stamp_home"
HOME="$stamp_home" "$repo/skill/scripts/feedback-anchor.sh" preview >"$preview"
has "$preview" "built-against:$first_stamp"
printf 'unrelated\n' >"$repo/README.md"
git -C "$repo" add README.md
git -C "$repo" commit -qm 'unrelated change'
HOME="$stamp_home" "$repo/skill/scripts/feedback-anchor.sh" preview >"$preview"
has "$preview" "built-against:$first_stamp"
printf 'stamp input\n' >"$repo/skill/NOTE"
git -C "$repo" add skill/NOTE
git -C "$repo" commit -qm 'skill change'
second_stamp="$(git -C "$repo" log -1 --format=%h -- skill)"
HOME="$stamp_home" "$repo/skill/scripts/feedback-anchor.sh" preview >"$preview"
has "$preview" "built-against:$second_stamp"

# A malformed package template cannot produce global instructions.
printf '<!-- skill:agent-feedback BEGIN built-against:no-placeholder -->\n<!-- skill:agent-feedback END -->\n' >"$repo/skill/templates/agents-route.md"
no env HOME="$stamp_home" "$repo/skill/scripts/feedback-anchor.sh" preview
no test -e "$stamp_home/.agents"

# Cold-route doctrine covers all four signal kinds, silence, and recursion prevention.
has "$TEMPLATE" 'friction, a gap, a preservation win, or a well-supported request'
has "$TEMPLATE" 'ordinary success'
has "$TEMPLATE" 'feedback about `agent-feedback` itself'
has "$TEMPLATE" 'once before the final response'
has "$VERB" 'competing route'
has "$VERB" 'ask the human'
has "$VERB" 'always load'
has "$VERB" 'preview'
has "$VERB" 'apply'
has "$VERB" '/agent-feedback anchor --remove'

cases="$SKILL/scripts/tests/fixtures/anchor-cases.tsv"
ok test -f "$cases"
[ "$(awk -F '\t' 'NR > 1 && $3 == 1 { count++ } END { print count+0 }' "$cases")" -eq 4 ] && pass || fail 'four qualifying cold-route cases'
[ "$(awk -F '\t' 'NR > 1 && $3 == 0 { count++ } END { print count+0 }' "$cases")" -eq 2 ] && pass || fail 'two silent cold-route cases'

finish anchor-test
