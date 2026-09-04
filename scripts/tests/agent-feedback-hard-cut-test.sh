#!/usr/bin/env bash
set -u -o pipefail

HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
ROOT="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
pass=0
fail=0

skill_word=skill
feedback_word=feedback
agents_word=agents
skilldata_word=skilldata
agent_word=agent
s_word=S
f_word=F
old_name="${skill_word}-${feedback_word}"
current_name="${agent_word}-${feedback_word}"
schema_name="${old_name}@1"
id_prefix="${s_word}${f_word}-"
global_path=".${agents_word}/${skilldata_word}/${old_name}"
current_global_path=".${agents_word}/${skilldata_word}/${current_name}"
generic_global_path=".${agents_word}/${skilldata_word}/foreign-owner"
slash_command="/${old_name}"
begin_mark="<!-- ${skill_word}:${old_name} BEGIN"
end_mark="<!-- ${skill_word}:${old_name} END"
data_tmp=".${feedback_word}.tsv.tmp."
query_tmp="${old_name}-query."
sort_tmp="${old_name}-sort."
page_tmp="${old_name}-page."
anchor_tmp="${old_name}-anchor."
agents_tmp=".AGENTS.md.${old_name}."
fixture_word="$(printf '%s%s' 'fi' 'xture')"
negative_marker="hard-cut-negative-${fixture_word}"
approved_negative_path="skills/${current_name}/scripts/tests/fixtures/anchor-cases.tsv"
approved_negative_line="predecessor-generic	-	-	### ${slash_command} — prior route # ${negative_marker}	yes"

labels=(package schema id-prefix global-path slash-command begin-delimiter end-delimiter data-temp query-temp sort-temp page-temp anchor-temp agents-temp)
values=("$old_name" "$schema_name" "$id_prefix" "$global_path" "$slash_command" "$begin_mark" "$end_mark" "$data_tmp" "$query_tmp" "$sort_tmp" "$page_tmp" "$anchor_tmp" "$agents_tmp")

pass() { pass=$((pass + 1)); }
fail() { echo "FAIL: $*" >&2; fail=$((fail + 1)); }

live_files() {
  local root="$1"
  if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$root" ls-files -z --cached --others --exclude-standard
  else
    find "$root" \
      \( -path "$root/.git" -o -path "$root/.records" -o -path "$root/docs/design" \
         -o -path "$root/.streams" -o -path "$root/.worktrees" \) -prune -o \
      -type f -print0 | while IFS= read -r -d '' path; do
        printf '%s\0' "${path#"$root"/}"
      done
  fi
}

excluded_path() {
  case "$1" in
    .git/* | .records/* | docs/design/* | .streams/* | .worktrees/*) return 0 ;;
    *) return 1 ;;
  esac
}

scan_live() {
  local root="$1" rel file token label match matches line i marker_count=0

  while IFS= read -r -d '' rel; do
    excluded_path "$rel" && continue
    for ((i = 0; i < ${#values[@]}; i++)); do
      token="${values[$i]}"
      label="${labels[$i]}"
      case "$rel" in
        *"$token"*)
          echo "hard-cut violation kind=path form=$label path=$rel" >&2
          return 1
          ;;
      esac
    done

    file="$root/$rel"
    [ -f "$file" ] || continue
    matches="$(LC_ALL=C grep -a -nF -- "$negative_marker" "$file" 2>/dev/null || true)"
    while IFS= read -r match; do
      [ -n "$match" ] || continue
      line="${match#*:}"
      if [ "$rel" = "$approved_negative_path" ] && [ "$line" = "$approved_negative_line" ]; then
        marker_count=$((marker_count + 1))
      else
        echo "hard-cut violation kind=annotation path=$rel match=$match" >&2
        return 1
      fi
    done <<<"$matches"
    for ((i = 0; i < ${#values[@]}; i++)); do
      token="${values[$i]}"
      label="${labels[$i]}"
      matches="$(LC_ALL=C grep -a -nF -- "$token" "$file" 2>/dev/null || true)"
      while IFS= read -r match; do
        [ -n "$match" ] || continue
        line="${match#*:}"
        if [ "$rel" = "$approved_negative_path" ] && [ "$line" = "$approved_negative_line" ]; then
          continue
        fi
        echo "hard-cut violation kind=content form=$label path=$rel match=$match" >&2
        return 1
      done <<<"$matches"
    done
  done < <(live_files "$root")
  if [ "$marker_count" -gt 1 ]; then
    echo "hard-cut violation kind=annotation-count count=$marker_count" >&2
    return 1
  fi
}

builder_global_access_free() {
  local builder="$1" rel match
  while IFS= read -r -d '' rel; do
    case "$rel" in
      SKILL.md | docs/DOCTRINE.md | verbs/check.md | verbs/new.md | verbs/review.md | \
        scripts/skills-lint.sh | scripts/tests/lint-global-skilldata-test.sh | scripts/tests/lint-skilldata-path-test.sh)
        continue
        ;;
    esac
    while IFS= read -r match; do
      [ -z "$match" ] || return 1
    done < <(LC_ALL=C grep -a -nE '(~|\$HOME|\$\{HOME\})/\.agents/skilldata' "$builder/$rel" 2>/dev/null || true)
  done < <(cd "$builder" && find . -type f -print0 | while IFS= read -r -d '' rel; do printf '%s\0' "${rel#./}"; done)
}

edge_digest() {
  local doc="$1" owner="$2"
  awk -v begin="<!-- edges:$owner -->" -v end="<!-- /edges:$owner -->" '
    $0 == begin { on=1 }
    on { print }
    $0 == end { exit }
  ' "$doc" | {
    if command -v shasum >/dev/null 2>&1; then shasum -a 256; else sha256sum; fi
  } | awk '{print $1}'
}

independence_ok() {
  local builder="$1" collector="$2"
  ! grep -R -Fq -- "$old_name" "$builder" 2>/dev/null &&
    ! grep -R -Fq -- "$current_name" "$builder" 2>/dev/null &&
    ! grep -R -Fq -- 'skill-builder' "$collector" 2>/dev/null &&
    ! grep -R -Fq -- "$current_global_path" "$builder" 2>/dev/null &&
    builder_global_access_free "$builder" &&
    [ "$(edge_digest "$builder/SKILL.md" skill-builder)" = 020203784f053f489652df9fd2effe59b0f3ccf607233532c014c099a326ae35 ] &&
    [ "$(edge_digest "$collector/SKILL.md" agent-feedback)" = 54ea9c32404a02f3c18a1bc233ec93cc2b2619a03b39925f975a843f57c4e585 ]
}

if scan_live "$ROOT"; then pass; else fail 'live retired-contract sweep'; fi
if [ "$(grep -Fxc -- "$approved_negative_line" "$ROOT/$approved_negative_path" 2>/dev/null || true)" = 1 ]; then
  pass
else
  fail 'approved negative fixture is not exact and unique'
fi
if independence_ok "$ROOT/skills/skill-builder" "$ROOT/skills/agent-feedback"; then
  pass
else
  fail 'live package independence'
fi
if [ -d "$ROOT/skills/agent-feedback" ] && [ ! -e "$ROOT/skills/$old_name" ]; then
  pass
else
  fail 'package hard cut'
fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/agent-feedback-hard-cut.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
fixture_root="$tmp/live"
mkdir -p "$fixture_root"
cp "$ROOT/README.md" "$fixture_root/README.md"
cp "$fixture_root/README.md" "$tmp/README.before"

if scan_live "$fixture_root"; then pass; else fail 'clean sweep fixture'; fi

for ((i = 0; i < ${#values[@]}; i++)); do
  cp "$tmp/README.before" "$fixture_root/README.md"
  printf '\n%s\n' "${values[$i]}" >>"$fixture_root/README.md"
  if scan_live "$fixture_root" >/dev/null 2>&1; then
    fail "${labels[$i]} plant stayed green"
  else
    pass
  fi
  cp "$tmp/README.before" "$fixture_root/README.md"
  if cmp -s "$tmp/README.before" "$fixture_root/README.md" && scan_live "$fixture_root"; then
    pass
  else
    fail "${labels[$i]} restore drifted"
  fi
done

mkdir -p "$fixture_root/$old_name"
printf 'path fixture\n' >"$fixture_root/$old_name/value.txt"
if scan_live "$fixture_root" >/dev/null 2>&1; then fail 'path plant stayed green'; else pass; fi
rm "$fixture_root/$old_name/value.txt"
rmdir "$fixture_root/$old_name"
if scan_live "$fixture_root"; then pass; else fail 'path fixture cleanup stayed red'; fi

printf '\n%s # %s\n' "$slash_command" "$negative_marker" >>"$fixture_root/README.md"
if scan_live "$fixture_root" >/dev/null 2>&1; then fail 'annotation outside approved fixture stayed green'; else pass; fi
cp "$tmp/README.before" "$fixture_root/README.md"

mkdir -p "$fixture_root/$(dirname "$approved_negative_path")"
printf '%s\n' "$approved_negative_line" >"$fixture_root/$approved_negative_path"
cp "$fixture_root/$approved_negative_path" "$tmp/negative.before"
if scan_live "$fixture_root"; then pass; else fail 'exact approved negative fixture rejected'; fi
printf '%s\n' "$approved_negative_line" >>"$fixture_root/$approved_negative_path"
if scan_live "$fixture_root" >/dev/null 2>&1; then fail 'duplicate approved annotation stayed green'; else pass; fi
cp "$tmp/negative.before" "$fixture_root/$approved_negative_path"
if cmp -s "$tmp/negative.before" "$fixture_root/$approved_negative_path" && scan_live "$fixture_root"; then pass; else fail 'negative fixture restore drifted'; fi

for excluded in .git .records docs/design .streams .worktrees; do
  mkdir -p "$fixture_root/$excluded"
  printf '%s\n' "$schema_name" >"$fixture_root/$excluded/excluded.txt"
done
if scan_live "$fixture_root"; then pass; else fail 'historical/worktree exclusions leaked'; fi

boundary_root="$tmp/boundary"
mkdir -p "$boundary_root"
cp -R "$ROOT/skills/skill-builder" "$boundary_root/skill-builder"
cp -R "$ROOT/skills/agent-feedback" "$boundary_root/agent-feedback"
cp "$boundary_root/skill-builder/verbs/tune.md" "$tmp/tune.before"
cp "$boundary_root/agent-feedback/verbs/capture.md" "$tmp/capture.before"
cp "$boundary_root/skill-builder/SKILL.md" "$tmp/builder-skill.before"
cp "$boundary_root/agent-feedback/SKILL.md" "$tmp/collector-skill.before"

printf '\n%s\n' "$old_name" >>"$boundary_root/skill-builder/verbs/tune.md"
if independence_ok "$boundary_root/skill-builder" "$boundary_root/agent-feedback"; then fail 'builder dependency plant stayed green'; else pass; fi
cp "$tmp/tune.before" "$boundary_root/skill-builder/verbs/tune.md"
if cmp -s "$tmp/tune.before" "$boundary_root/skill-builder/verbs/tune.md" && independence_ok "$boundary_root/skill-builder" "$boundary_root/agent-feedback"; then pass; else fail 'builder dependency restore drifted'; fi

printf '\n%s\n' "$current_name" >>"$boundary_root/skill-builder/scripts/source-custody.sh"
if independence_ok "$boundary_root/skill-builder" "$boundary_root/agent-feedback"; then fail 'current collector dependency plant stayed green'; else pass; fi
cp "$ROOT/skills/skill-builder/scripts/source-custody.sh" "$boundary_root/skill-builder/scripts/source-custody.sh"
if cmp -s "$ROOT/skills/skill-builder/scripts/source-custody.sh" "$boundary_root/skill-builder/scripts/source-custody.sh" && independence_ok "$boundary_root/skill-builder" "$boundary_root/agent-feedback"; then pass; else fail 'current collector dependency restore drifted'; fi

printf '\nskill-builder\n' >>"$boundary_root/agent-feedback/verbs/capture.md"
if independence_ok "$boundary_root/skill-builder" "$boundary_root/agent-feedback"; then fail 'collector dependency plant stayed green'; else pass; fi
cp "$tmp/capture.before" "$boundary_root/agent-feedback/verbs/capture.md"
if cmp -s "$tmp/capture.before" "$boundary_root/agent-feedback/verbs/capture.md" && independence_ok "$boundary_root/skill-builder" "$boundary_root/agent-feedback"; then pass; else fail 'collector dependency restore drifted'; fi

printf '\n%s\n' "$global_path" >>"$boundary_root/skill-builder/verbs/tune.md"
if independence_ok "$boundary_root/skill-builder" "$boundary_root/agent-feedback"; then fail 'builder global-access plant stayed green'; else pass; fi
cp "$tmp/tune.before" "$boundary_root/skill-builder/verbs/tune.md"
if cmp -s "$tmp/tune.before" "$boundary_root/skill-builder/verbs/tune.md" && independence_ok "$boundary_root/skill-builder" "$boundary_root/agent-feedback"; then pass; else fail 'builder global-access restore drifted'; fi

printf '\npath="$HOME/%s"\n' "$generic_global_path" >>"$boundary_root/skill-builder/scripts/source-custody.sh"
if independence_ok "$boundary_root/skill-builder" "$boundary_root/agent-feedback"; then fail 'builder generic global-access plant stayed green'; else pass; fi
cp "$ROOT/skills/skill-builder/scripts/source-custody.sh" "$boundary_root/skill-builder/scripts/source-custody.sh"
if cmp -s "$ROOT/skills/skill-builder/scripts/source-custody.sh" "$boundary_root/skill-builder/scripts/source-custody.sh" && independence_ok "$boundary_root/skill-builder" "$boundary_root/agent-feedback"; then pass; else fail 'builder generic global-access restore drifted'; fi

printf '\nedge drift\n' >>"$boundary_root/skill-builder/SKILL.md"
if independence_ok "$boundary_root/skill-builder" "$boundary_root/agent-feedback"; then
  pass
else
  fail 'builder outside-edge text should not affect edge contract'
fi
cp "$tmp/builder-skill.before" "$boundary_root/skill-builder/SKILL.md"
if cmp -s "$tmp/builder-skill.before" "$boundary_root/skill-builder/SKILL.md"; then pass; else fail 'builder outside-edge restore drifted'; fi

awk '{ print; if ($0 == "<!-- edges:skill-builder -->") print "edge drift" }' "$boundary_root/skill-builder/SKILL.md" >"$tmp/builder.bad"
mv "$tmp/builder.bad" "$boundary_root/skill-builder/SKILL.md"
if independence_ok "$boundary_root/skill-builder" "$boundary_root/agent-feedback"; then fail 'builder edge plant stayed green'; else pass; fi
cp "$tmp/builder-skill.before" "$boundary_root/skill-builder/SKILL.md"
if cmp -s "$tmp/builder-skill.before" "$boundary_root/skill-builder/SKILL.md" && independence_ok "$boundary_root/skill-builder" "$boundary_root/agent-feedback"; then pass; else fail 'builder edge restore drifted'; fi

awk '{ print; if ($0 == "<!-- edges:agent-feedback -->") print "edge drift" }' "$boundary_root/agent-feedback/SKILL.md" >"$tmp/collector.bad"
mv "$tmp/collector.bad" "$boundary_root/agent-feedback/SKILL.md"
if independence_ok "$boundary_root/skill-builder" "$boundary_root/agent-feedback"; then fail 'collector edge plant stayed green'; else pass; fi
cp "$tmp/collector-skill.before" "$boundary_root/agent-feedback/SKILL.md"
if cmp -s "$tmp/collector-skill.before" "$boundary_root/agent-feedback/SKILL.md" && independence_ok "$boundary_root/skill-builder" "$boundary_root/agent-feedback"; then pass; else fail 'collector edge restore drifted'; fi

printf 'agent-feedback-hard-cut-test: pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
