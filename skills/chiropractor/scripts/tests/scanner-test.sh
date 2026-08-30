#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SCAN="$HERE/../spine-scan.sh"
TEST_NAME=scanner-test
export TEST_NAME
# shellcheck source=/dev/null
. "$HERE/lib.sh"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/chiropractor-scanner.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
root="$tmp/project"
mkdir -p "$root/docs" "$root/scripts/private" "$root/bin" "$root/runbooks" \
  "$root/archive" "$root/generated" "$root/vendor/pkg" "$root/.github/workflows" "$root/scoped"
cp "$HERE/fixtures/grammar/AGENTS.md.input" "$root/AGENTS.md"
printf '%s\n' '@AGENTS.md' '' 'Claude-only: use the native sandbox.' >"$root/CLAUDE.md"
printf '# Overview\n' >"$root/README"
printf '# Scoped door\n' >"$root/scoped/AGENTS.md"
printf '%s\n' '# Same' '# Same' '<span id="explicit"></span>' >"$root/docs/guide.md"
printf '# Import\n' >"$root/docs/import.md"
printf '# Space\n' >"$root/docs/space file (v2).md"
printf '# Escaped\n' >"$root/docs/escaped file (v1).md"
printf '# <em>Linked</em>\n' >"$root/docs/complex.md"
printf '# RST\n' >"$root/docs/notes.rst"
printf '= AsciiDoc\n' >"$root/docs/notes.adoc"
printf '# Archive\n' >"$root/archive/old.md"
printf '# Generated\n' >"$root/generated/api.md"
printf '# Vendor\n' >"$root/vendor/pkg/README.md"
printf '# Runbook\n' >"$root/runbooks/release.md"
printf '#!/usr/bin/env bash\nexit 0\n' >"$root/scripts/run.sh"
printf '#!/usr/bin/env bash\nexit 0\n' >"$root/scripts/private/helper.sh"
printf '#!/usr/bin/env bash\nexit 0\n' >"$root/bin/tool"
chmod +x "$root/scripts/run.sh" "$root/bin/tool"
printf 'all:\n\t@true\n' >"$root/Makefile"
printf 'default:\n  @true\n' >"$root/Justfile"
printf 'default:\n  cmds: []\n' >"$root/Taskfile.yml"
printf '{"scripts":{"test":"true"}}\n' >"$root/package.json"
printf 'name: ci\n' >"$root/.github/workflows/ci.yml"
for n in $(seq 1 24); do printf '# Extra %s\n' "$n" >"$root/docs/extra-$n.md"; done
git -C "$root" init -q
git -C "$root" add -A
git -C "$root" -c user.name=test -c user.email=test@example.invalid commit -qm seed
printf '# Untracked\n' >"$root/docs/untracked.md"
printf '#!/usr/bin/env bash\nexit 0\n' >"$root/bin/untracked-tool"
chmod +x "$root/bin/untracked-tool"
printf '# Ignored\n' >"$root/docs/ignored.md"
printf 'docs/ignored.md\n' >"$root/.gitignore"
printf '\nDirty line\n' >>"$root/docs/guide.md"

# Nested repository and a symlinked directory are reported/excluded, never traversed.
mkdir -p "$root/nested/docs" "$tmp/outside"
printf '# Nested door\n' >"$root/nested/AGENTS.md"
printf '%s\n' '# Nested doc' '[outer](../../AGENTS.md)' >"$root/nested/docs/deep.md"
git -C "$root/nested" init -q
git -C "$root/nested" add -A
git -C "$root/nested" -c user.name=test -c user.email=test@example.invalid commit -qm nested
printf '# Outside\n' >"$tmp/outside/leak.md"
ln -s "$tmp/outside" "$root/docs/symlinked"

before="$tmp/status.before"; after="$tmp/status.after"
git -C "$root" status --porcelain=v1 --untracked-files=all >"$before"
facts="$tmp/facts"; candidates="$tmp/candidates"
"$SCAN" "$root" >"$facts"
"$SCAN" "$root" --candidates >"$candidates"
git -C "$root" status --porcelain=v1 --untracked-files=all >"$after"
if cmp -s "$before" "$after"; then ok; else not_ok "scanner mutated dirty fixture"; fi

require_line "$facts" 'agents_state=regular'
require_line "$facts" 'claude_state=regular'
require_line "$facts" 'claude_imports_agents=1'
if grep -Eq '^imported_bytes=[1-9][0-9]*$' "$facts"; then ok; else not_ok "imported bytes absent"; fi
require_line "$facts" 'root_door_outline=# Door'
require_line "$facts" 'nested_agents=scoped/AGENTS.md'
require_line "$facts" 'nested_git_roots=nested'
require_line "$facts" $'nested_root_reference=AGENTS.md\tmarkdown\tnested/docs/deep.md'
require_line "$facts" $'symlink_reference=AGENTS.md\tmarkdown\tdocs/symlinked/leak.md'
reject_text "$candidates" $'nested/docs/deep.md\t'
reject_text "$candidates" 'docs/symlinked/leak.md'
if grep -F $'candidate\tdocs/space file (v2).md\tdocumentation\ttracked\t' "$candidates" >/dev/null; then ok; else not_ok "space-path candidate missing"; fi
if grep -F $'candidate\tpackage.json\tmanifest\ttracked\t' "$candidates" >/dev/null; then ok; else not_ok "manifest candidate missing"; fi
if grep -F $'candidate\tJustfile\ttask-entry\ttracked\t' "$candidates" >/dev/null; then ok; else not_ok "Just task entry missing"; fi
if grep -F $'candidate\tbin/untracked-tool\texecutable,script\tuntracked\t' "$candidates" >/dev/null; then ok; else not_ok "untracked executable missing"; fi
if grep -F $'candidate\t.github/workflows/ci.yml\tworkflow\ttracked\t' "$candidates" >/dev/null; then ok; else not_ok "workflow candidate missing"; fi
if grep -F $'candidate\trunbooks/release.md\tdocumentation,operation\ttracked\t' "$candidates" >/dev/null; then ok; else not_ok "runbook kinds missing"; fi
if grep -F $'candidate\tarchive/old.md\tdocumentation,historical\ttracked\t' "$candidates" >/dev/null; then ok; else not_ok "historical evidence missing"; fi
reject_text "$candidates" 'docs/ignored.md'
require_line "$facts" $'edge=markdown\tAGENTS.md\tdocs/space file (v2).md'
require_line "$facts" $'edge=markdown\tAGENTS.md\tdocs/escaped file (v1).md'
require_line "$facts" $'edge=markdown\tAGENTS.md\tdocs/guide.md'
require_line "$facts" $'edge=import\tAGENTS.md\tdocs/import.md'
require_line "$facts" $'edge=code\tAGENTS.md\tscripts/run.sh'
require_line "$facts" $'escaping_reference=AGENTS.md\tmarkdown\t../outside.md'
reject_text "$facts" 'fenced-missing.md'
reject_text "$facts" 'fenced-code.md'
reject_text "$facts" 'inline-code-missing.md'
reject_text "$facts" 'inline-import-missing.md'
reject_text "$facts" 'long-fenced-one.md'
reject_text "$facts" 'long-fenced-two.md'
require_line "$facts" $'broken_reference=AGENTS.md\tmarkdown\tdocs/escaped-tick-missing.md'
reject_text "$facts" 'docs/html.md'
reject_text "$facts" 'example.invalid'
reject_text "$facts" 'maintainer@example.invalid'
reject_text "$facts" '/tmp/guide.md'
reject_text "$facts" 'docs/*.md'
reject_text "$facts" 'docs/{{name}}.md'
require_line "$facts" $'broken_reference=AGENTS.md\tmarkdown\tdocs/missing.md'
require_line "$facts" $'broken_reference=AGENTS.md\tmarkdown\tdocs/guide.md#not-there'
reject_text "$facts" 'docs/guide.md#explicit'
reject_text "$facts" 'docs/guide.md#same-1'
require_line "$facts" $'anchor_unverified=AGENTS.md\tmarkdown\tpackage.json#scripts'
require_line "$facts" $'anchor_unverified=AGENTS.md\tmarkdown\tdocs/complex.md#linked'
require_line "$facts" 'dirty_candidate=docs/guide.md'
require_line "$facts" $'candidate_kind=workflow\t1'
if grep -q '^candidate_truncated=' "$facts"; then ok; else not_ok "candidate sample cap did not truncate"; fi
if grep -q '^no_incoming_candidate_truncated=' "$facts"; then ok; else not_ok "sample cap did not truncate"; fi
fc="$(sed -n 's/^candidate_count=//p' "$facts")"; cc="$(sed -n 's/^candidate_count=//p' "$candidates")"
if [ "$fc" = "$cc" ] && [ "$(grep -c $'^candidate\t' "$candidates")" = "$cc" ]; then ok; else not_ok "candidate population drift"; fi
if cmp -s <(grep $'^candidate\t' "$candidates") <(grep $'^candidate\t' "$candidates" | LC_ALL=C sort); then ok; else not_ok "candidate rows not sorted"; fi

# Door incompatibility states use isolated roots.
for state in missing directory symlink; do
  door="$tmp/door-$state"; mkdir -p "$door"
  case "$state" in directory) mkdir "$door/AGENTS.md" ;; symlink) ln -s nowhere "$door/AGENTS.md" ;; esac
  "$SCAN" "$door" >"$tmp/$state.out"
  require_line "$tmp/$state.out" "agents_state=$state"
done
door="$tmp/door-unreadable"; mkdir -p "$door"; printf '# Door\n' >"$door/AGENTS.md"; chmod 000 "$door/AGENTS.md"
"$SCAN" "$door" >"$tmp/unreadable.out"
if [ ! -r "$door/AGENTS.md" ]; then require_line "$tmp/unreadable.out" 'agents_state=unreadable'; else ok; fi
chmod 600 "$door/AGENTS.md"

# Canonical door combinations expose facts without making the scanner choose authority.
door="$tmp/agents-only"; mkdir -p "$door"; printf '# Agents\n' >"$door/AGENTS.md"; "$SCAN" "$door" >"$tmp/agents-only.out"
require_line "$tmp/agents-only.out" 'agents_state=regular'
require_line "$tmp/agents-only.out" 'claude_state=missing'
require_line "$tmp/agents-only.out" 'dead_end=AGENTS.md'
door="$tmp/claude-only"; mkdir -p "$door"; printf '# Claude\n' >"$door/CLAUDE.md"; "$SCAN" "$door" >"$tmp/claude-only.out"
require_line "$tmp/claude-only.out" 'agents_state=missing'
require_line "$tmp/claude-only.out" 'claude_state=regular'
require_line "$tmp/claude-only.out" 'no_incoming_candidate=CLAUDE.md'
require_line "$tmp/claude-only.out" 'unreachable_candidate=CLAUDE.md'
door="$tmp/neither"; mkdir -p "$door"; "$SCAN" "$door" >"$tmp/neither.out"
require_line "$tmp/neither.out" 'agents_state=missing'
require_line "$tmp/neither.out" 'claude_state=missing'
door="$tmp/divergent"; mkdir -p "$door"; printf '# Agents\n' >"$door/AGENTS.md"; printf '# Claude\n' >"$door/CLAUDE.md"; "$SCAN" "$door" >"$tmp/divergent.out"
require_line "$tmp/divergent.out" 'claude_imports_agents=0'
if [ "$(sed -n 's/^agents_digest=//p' "$tmp/divergent.out")" != "$(sed -n 's/^claude_digest=//p' "$tmp/divergent.out")" ]; then ok; else not_ok "divergent doors have equal digests"; fi
door="$tmp/duplicate"; mkdir -p "$door"; printf '# Shared\n' >"$door/AGENTS.md"; cp "$door/AGENTS.md" "$door/CLAUDE.md"; "$SCAN" "$door" >"$tmp/duplicate.out"
if [ "$(sed -n 's/^agents_digest=//p' "$tmp/duplicate.out")" = "$(sed -n 's/^claude_digest=//p' "$tmp/duplicate.out")" ]; then ok; else not_ok "duplicate doors have unequal digests"; fi
door="$tmp/import-only"; mkdir -p "$door"; printf '# Agents\n' >"$door/AGENTS.md"; printf '@AGENTS.md\n' >"$door/CLAUDE.md"; "$SCAN" "$door" >"$tmp/import-only.out"
require_line "$tmp/import-only.out" 'claude_imports_agents=1'
# Backticks are literal fixture content.
door="$tmp/import-literal"
mkdir -p "$door"
printf '# Agents\n' >"$door/AGENTS.md"
# shellcheck disable=SC2016
printf 'Document the literal `@AGENTS.md`.\n' >"$door/CLAUDE.md"
"$SCAN" "$door" >"$tmp/import-literal.out"
require_line "$tmp/import-literal.out" 'claude_imports_agents=0'

# Scanning the nested repository itself reports its outward reference as an escape.
"$SCAN" "$root/nested" >"$tmp/nested.out"
require_line "$tmp/nested.out" $'escaping_reference=docs/deep.md\tmarkdown\t../../AGENTS.md'

# Red-proof fenced-example suppression by moving one planted link outside its fence.
cp "$root/AGENTS.md" "$tmp/AGENTS.before"
printf '\n[planted](docs/fenced-missing.md)\n' >>"$root/AGENTS.md"
"$SCAN" "$root" >"$tmp/red"
if grep -Fqx $'broken_reference=AGENTS.md\tmarkdown\tdocs/fenced-missing.md' "$tmp/red"; then ok; else not_ok "planted broken link stayed hidden"; fi
cp "$tmp/AGENTS.before" "$root/AGENTS.md"
if cmp -s "$tmp/AGENTS.before" "$root/AGENTS.md"; then ok; else not_ok "grammar fixture restore drifted"; fi
"$SCAN" "$root" >"$tmp/green"
reject_text "$tmp/green" 'fenced-missing.md'

# Red-proof inline-code masking: expose exactly one literal link as prose, demand red, then restore.
cp "$root/AGENTS.md" "$tmp/inline.before"
# Backticks are literal fixture delimiters.
# shellcheck disable=SC2016
sed 's|`\[inline-code\](docs/inline-code-missing.md)`|[inline-code](docs/inline-code-missing.md)|' \
  "$tmp/inline.before" >"$root/AGENTS.md"
"$SCAN" "$root" >"$tmp/inline.red"
if grep -Fqx $'broken_reference=AGENTS.md\tmarkdown\tdocs/inline-code-missing.md' "$tmp/inline.red"; then
  ok
else
  not_ok "inline-code masking guard did not turn red"
fi
cp "$tmp/inline.before" "$root/AGENTS.md"
if cmp -s "$tmp/inline.before" "$root/AGENTS.md"; then ok; else not_ok "inline-code fixture restore drifted"; fi
"$SCAN" "$root" >"$tmp/inline.green"
reject_text "$tmp/inline.green" 'inline-code-missing.md'

# Red-proof fence-length tracking: a matching four-backtick close makes the second link live.
cp "$root/AGENTS.md" "$tmp/fence.before"
awk '{if(!changed && $0=="```   "){print "````";changed=1;next} print}' \
  "$tmp/fence.before" >"$root/AGENTS.md"
"$SCAN" "$root" >"$tmp/fence.red"
if grep -Fqx $'broken_reference=AGENTS.md\tmarkdown\tdocs/long-fenced-two.md' "$tmp/fence.red"; then
  ok
else
  not_ok "fence-length guard did not turn red"
fi
cp "$tmp/fence.before" "$root/AGENTS.md"
if cmp -s "$tmp/fence.before" "$root/AGENTS.md"; then ok; else not_ok "fence fixture restore drifted"; fi
"$SCAN" "$root" >"$tmp/fence.green"
reject_text "$tmp/fence.green" 'long-fenced-two.md'

finish
