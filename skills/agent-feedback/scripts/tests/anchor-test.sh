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

apply_preview() {
  local home="$1" preview_file="$2"
  shift 2
  local base candidate
  base="$(sed -n 's/^base-sha256=//p' "$preview_file")"
  candidate="$(sed -n 's/^candidate-sha256=//p' "$preview_file")"
  run_anchor "$home" apply "$@" --confirmed --base-sha256 "$base" --candidate-sha256 "$candidate"
}

home="$TMP/absent"
new_home "$home"
preview="$TMP/preview"
run_anchor "$home" preview >"$preview"
has "$preview" 'status=change'
has "$preview" 'base-sha256=absent'
ok grep -Eq '^candidate-sha256=[0-9a-f]{64}$' "$preview"
has "$preview" '## Skill routes (self-registered)'
has "$preview" '<!-- skill:agent-feedback BEGIN built-against:'
has "$preview" 'Edges: produces `feedback-observation`.'
no test -e "$home/.agents"
no run_anchor "$home" apply --base-sha256 absent
no test -e "$home/.agents"
no run_anchor "$home" apply --confirmed --base-sha256 deadbeef --candidate-sha256 deadbeef
no test -e "$home/.agents"

apply_out="$TMP/apply"
apply_preview "$home" "$preview" >"$apply_out"
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
candidate="$(sed -n 's/^candidate-sha256=//p' "$preview")"
run_anchor "$home" apply --confirmed --base-sha256 "$base" --candidate-sha256 "$candidate" >"$apply_out"
has "$apply_out" 'status=noop'

# A preview token is optimistic concurrency control, not a reusable authorization.
printf '\nconcurrent edit\n' >>"$agents"
no run_anchor "$home" apply --confirmed --base-sha256 "$base" --candidate-sha256 "$candidate"
has "$agents" 'concurrent edit'

# A concurrent change between snapshot and preview identity cannot produce a
# token for stale candidate bytes.
snapshot_hook="$TMP/change-after-snapshot.sh"
printf '%s\n' '#!/bin/sh' 'printf "snapshot race\n" >>"$1"' >"$snapshot_hook"
chmod +x "$snapshot_hook"
cp "$agents" "$TMP/snapshot-race.before"
if HOME="$home" AGENT_FEEDBACK_TEST_AFTER_SNAPSHOT="$snapshot_hook" "$ANCHOR" preview \
  >"$TMP/snapshot-race.out" 2>"$TMP/snapshot-race.err"; then
  fail 'snapshot race produced a preview'
else
  pass
fi
if [ ! -s "$TMP/snapshot-race.out" ]; then pass; else fail 'snapshot race emitted a confirmation token'; fi
has "$TMP/snapshot-race.err" 'error=base-changed'
has "$agents" 'snapshot race'

# Removal deletes only the owned block and preserves the heading and surrounding bytes.
run_anchor "$home" preview --remove >"$preview"
base="$(sed -n 's/^base-sha256=//p' "$preview")"
cp "$agents" "$TMP/before-remove"
apply_preview "$home" "$preview" --remove >"$apply_out"
has "$apply_out" 'removed=AGENTS.md'
has "$agents" '## Skill routes (self-registered)'
has "$agents" 'concurrent edit'
no grep -qF '<!-- skill:agent-feedback BEGIN' "$agents"
cp "$agents" "$TMP/after-remove"
run_anchor "$home" preview --remove >"$preview"
has "$preview" 'status=noop'
base="$(sed -n 's/^base-sha256=//p' "$preview")"
apply_preview "$home" "$preview" --remove >"$apply_out"
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
apply_preview "$home" "$preview" >/dev/null
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
apply_preview "$home" "$preview" --remove >/dev/null
same "$home/.agents/AGENTS.md" "$TMP/drifted-expected-remove"

# Malformed or ambiguous ownership is a hard refusal with no mutation.
for case_name in duplicate-heading orphan-begin orphan-end duplicate-block inverted-block block-before-heading block-after-section malformed-marker prefixed-marker trailing-marker; do
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
    prefixed-marker)
      printf '## Skill routes (self-registered)\nforeign <!-- skill:agent-feedback BEGIN built-against:a -->\nx\n<!-- skill:agent-feedback END -->\n' >"$case_home/.agents/AGENTS.md"
      ;;
    trailing-marker)
      printf '## Skill routes (self-registered)\n<!-- skill:agent-feedback BEGIN built-against:a --> foreign -->\nx\n<!-- skill:agent-feedback END -->\n' >"$case_home/.agents/AGENTS.md"
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
apply_preview "$home" "$preview" >/dev/null
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
  apply_preview "$home" "$preview" >/dev/null
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
apply_preview "$home" "$preview" >/dev/null
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
watch_bin="$TMP/watch-bin"; mkdir -p "$watch_bin"
printf '%s\n' '#!/bin/sh' 'if [ "$1" = "$WATCH_SOURCE" ]; then printf "read\n" >"$WATCH_LOG"; fi' 'exec /bin/cp "$@"' >"$watch_bin/cp"
chmod +x "$watch_bin/cp"
no env PATH="$watch_bin:$PATH" WATCH_SOURCE="$home/.agents/AGENTS.md" WATCH_LOG="$TMP/symlink-read.log" HOME="$home" "$ANCHOR" preview
no test -e "$TMP/symlink-read.log"
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
apply_preview "$home" "$preview" >/dev/null
run_anchor "$home" preview --remove >"$preview"
base="$(sed -n 's/^base-sha256=//p' "$preview")"
apply_preview "$home" "$preview" --remove >/dev/null
same "$home/.agents/FEEDBACK.md" "$TMP/legacy.before"
has "$home/.agents/AGENTS.md" 'Send reusable-skill feedback to `/old-feedback`.'

# Install and update scan only unfenced H3 slash-command headings in the
# self-registered section. A feedback token must be hyphen-delimited.
cases="$SKILL/scripts/tests/fixtures/anchor-cases.tsv"
while IFS=$'\t' read -r case_name _signal _capture_count route_heading expected_conflict; do
  [ "$route_heading" != route_heading ] || continue
  [ "$route_heading" != - ] || continue
  route_home="$TMP/route-$case_name"; new_home "$route_home"; mkdir -p "$route_home/.agents"
  chmod 700 "$route_home/.agents"
  printf '## Skill routes (self-registered)\n\n%s\n' "$route_heading" >"$route_home/.agents/AGENTS.md"
  chmod 600 "$route_home/.agents/AGENTS.md"; cp "$route_home/.agents/AGENTS.md" "$TMP/$case_name.before"
  if [ "$expected_conflict" = yes ]; then
    if run_anchor "$route_home" preview >"$TMP/$case_name.out" 2>"$TMP/$case_name.err"; then
      fail "$case_name preview accepted competitor"
    else
      pass
    fi
    [ ! -s "$TMP/$case_name.out" ] && pass || fail "$case_name proposed a write"
    printf 'reason=competing-feedback-route action=resolve-route conflict=%s\n' "$route_heading" >"$TMP/$case_name.expected"
    same "$TMP/$case_name.err" "$TMP/$case_name.expected"
    same "$route_home/.agents/AGENTS.md" "$TMP/$case_name.before"
    route_base="$(shasum -a 256 "$route_home/.agents/AGENTS.md" | awk '{print $1}')"
    if run_anchor "$route_home" apply --confirmed --base-sha256 "$route_base" --candidate-sha256 "$(printf '%064d' 0)" \
      >"$TMP/$case_name.apply.out" 2>"$TMP/$case_name.apply.err"; then
      fail "$case_name apply bypassed competitor"
    else
      pass
    fi
    [ ! -s "$TMP/$case_name.apply.out" ] && pass || fail "$case_name apply proposed a write"
    same "$TMP/$case_name.apply.err" "$TMP/$case_name.expected"
    same "$route_home/.agents/AGENTS.md" "$TMP/$case_name.before"
  else
    run_anchor "$route_home" preview >"$TMP/$case_name.out"
    has "$TMP/$case_name.out" 'status=change'
    route_base="$(sed -n 's/^base-sha256=//p' "$TMP/$case_name.out")"
    apply_preview "$route_home" "$TMP/$case_name.out" >/dev/null
    has "$route_home/.agents/AGENTS.md" "$route_heading"
  fi
done <"$cases"

# Fenced H3 lookalikes are examples, not competitors.
home="$TMP/competing-fenced"; new_home "$home"; mkdir -p "$home/.agents"; chmod 700 "$home/.agents"
printf '## Skill routes (self-registered)\n\n```markdown\n### /review-feedback — example only\n```\n' >"$home/.agents/AGENTS.md"
chmod 600 "$home/.agents/AGENTS.md"
run_anchor "$home" preview >"$preview"; has "$preview" 'status=change'

# A matching H3 outside the reserved section is out of scan scope.
home="$TMP/competitor-outside-section"; new_home "$home"; mkdir -p "$home/.agents"; chmod 700 "$home/.agents"
printf '# Personal route\n\n### /review-feedback — outside reserved section\n\n## Skill routes (self-registered)\n' >"$home/.agents/AGENTS.md"
chmod 600 "$home/.agents/AGENTS.md"
run_anchor "$home" preview >"$preview"; has "$preview" 'status=change'

# Update refuses a competitor, while removal ignores it and deletes only the
# owned block.
home="$TMP/competitor-removal"; new_home "$home"
run_anchor "$home" preview >"$preview"; base="$(sed -n 's/^base-sha256=//p' "$preview")"
apply_preview "$home" "$preview" >/dev/null
printf '\n### /review-feedback — retained competitor\n' >>"$home/.agents/AGENTS.md"
cp "$home/.agents/AGENTS.md" "$TMP/competitor-installed.before"
if run_anchor "$home" preview >"$TMP/competitor-update.out" 2>"$TMP/competitor-update.err"; then
  fail 'competitor update accepted'
else
  pass
fi
has "$TMP/competitor-update.err" 'reason=competing-feedback-route action=resolve-route conflict=### /review-feedback — retained competitor'
same "$home/.agents/AGENTS.md" "$TMP/competitor-installed.before"
run_anchor "$home" preview --remove >"$preview"; base="$(sed -n 's/^base-sha256=//p' "$preview")"
apply_preview "$home" "$preview" --remove >/dev/null
has "$home/.agents/AGENTS.md" '### /review-feedback — retained competitor'
no grep -qF '<!-- skill:agent-feedback BEGIN' "$home/.agents/AGENTS.md"

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

# Confirmation binds the rendered candidate, not just the destination base.
stamp_base="$(sed -n 's/^base-sha256=//p' "$preview")"
stamp_candidate="$(sed -n 's/^candidate-sha256=//p' "$preview")"
awk '{ print }' "$repo/skill/templates/agents-route.md" >"$TMP/template.before"
awk '{ if ($0 == "<!-- skill:agent-feedback END -->") print "changed package bytes"; print }' \
  "$TMP/template.before" >"$repo/skill/templates/agents-route.md"
if HOME="$stamp_home" "$repo/skill/scripts/feedback-anchor.sh" apply --confirmed \
  --base-sha256 "$stamp_base" --candidate-sha256 "$stamp_candidate" \
  >"$TMP/candidate-drift.out" 2>"$TMP/candidate-drift.err"; then
  fail 'changed candidate reused preview authorization'
else
  pass
fi
has "$TMP/candidate-drift.err" 'error=candidate-changed'
no test -e "$stamp_home/.agents"
awk '{ print }' "$TMP/template.before" >"$repo/skill/templates/agents-route.md"

# A malformed package template cannot produce global instructions.
printf '<!-- skill:agent-feedback BEGIN built-against:no-placeholder -->\n<!-- skill:agent-feedback END -->\n' >"$repo/skill/templates/agents-route.md"
no env HOME="$stamp_home" "$repo/skill/scripts/feedback-anchor.sh" preview
no test -e "$stamp_home/.agents"

# Cold-route doctrine covers all four signal kinds, silence, and recursion prevention.
has "$TEMPLATE" 'friction, a gap, a preservation win, or a well-supported request'
has "$TEMPLATE" 'ordinary success'
has "$TEMPLATE" 'feedback about `agent-feedback` itself'
has "$TEMPLATE" 'Explicit human `/agent-feedback capture` remains valid'
has "$TEMPLATE" 'once before the final response'
has "$VERB" 'competing route'
has "$VERB" 'ask the human'
has "$VERB" 'always load'
has "$VERB" 'preview'
has "$VERB" 'apply'
has "$VERB" '/agent-feedback anchor --remove'

ok test -f "$cases"
[ "$(awk -F '\t' 'NR > 1 && $3 == 1 { count++ } END { print count+0 }' "$cases")" -eq 4 ] && pass || fail 'four qualifying cold-route cases'
[ "$(awk -F '\t' 'NR > 1 && $3 == 0 { count++ } END { print count+0 }' "$cases")" -eq 2 ] && pass || fail 'two silent cold-route cases'

finish anchor-test
