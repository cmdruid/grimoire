#!/usr/bin/env bash
# schedule.sh -- facts script for the scheduler skill: recurring agent runs via the
# OS supervisor (launchd on macOS, cron on Linux; user scope only). The installed
# plist/cron line is always `<this script> tick <name>`; tick reads the job spec,
# assembles preamble + payload, takes the lock, and execs the runner that was
# resolved to an absolute path at install time.
#
# DOCTRINE: facts, not verdicts. Subcommands print what they did or refuse with a
# reason on stderr (exit 2); tick/run exit with the harness's own code.
#
# Env seams (fixtures override; defaults are the real machine):
#   SCHEDULER_HOME           state dir           (default <project>/.scheduler)
#   SCHEDULER_LAUNCH_AGENTS  LaunchAgents dir    (default ~/Library/LaunchAgents)
#   SCHEDULER_LAUNCHCTL      launchctl command   (default launchctl)
#   SCHEDULER_CRONTAB        crontab command     (default crontab)
#   SCHEDULER_UNAME          platform override   (default `uname -s`)
set -eu
set -f  # noglob: cron fields are full of `*` -- nothing here may glob-expand.
        # The one glob consumer (job listing) re-enables it in a tight scope.

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LAUNCHCTL="${SCHEDULER_LAUNCHCTL:-launchctl}"
CRONTAB="${SCHEDULER_CRONTAB:-crontab}"
MAX_CALENDAR_ENTRIES=100

die() { echo "schedule.sh: $*" >&2; exit 2; }

platform() { echo "${SCHEDULER_UNAME:-$(uname -s)}"; }

home_dir() {
  if [ -n "${SCHEDULER_HOME:-}" ]; then echo "$SCHEDULER_HOME"; return; fi
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  echo "$root/.scheduler"
}

ensure_home() { # <home>
  mkdir -p "$1/jobs" "$1/logs"
  if [ ! -f "$1/.gitignore" ]; then
    printf '%s\n' \
      '# .scheduler/ is machine-local (absolute paths, run logs) except the preamble.' \
      '*' \
      '!.gitignore' \
      '!HEARTBEAT.md' >"$1/.gitignore"
  fi
}

label_for() { echo "com.agent-schedule.$1"; }
marker_for() { echo "# agent-schedule: $1"; }

spec_get() { # <spec-file> <key>  (first match; value may contain spaces and =)
  sed -n "s/^$2=//p" "$1" | head -1
}

xml_escape() { printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

# ---------------------------------------------------------------- cron parsing
# expand_field <spec> <min> <max> <label> -> "ANY" or a space-separated value list.
# Supports *, a, a-b, */s, a-b/s, and comma lists thereof. Numeric only -- weekday
# names (mon, tue) are refused so the 0=Sunday trap can't hide behind a name.
expand_field() {
  local spec="$1" min="$2" max="$3" name="$4" out="" part step lo hi v
  [ "$spec" = "*" ] && { echo "ANY"; return; }
  local IFS=','
  for part in $spec; do
    step=1
    case "$part" in
      */*) step="${part#*/}"; part="${part%%/*}" ;;
    esac
    case "$step" in ''|*[!0-9]*) die "bad step in $name field: '$spec'" ;; esac
    [ "$step" -ge 1 ] || die "bad step in $name field: '$spec'"
    if [ "$part" = "*" ]; then lo="$min"; hi="$max"
    else
      case "$part" in
        *-*) lo="${part%-*}"; hi="${part#*-}" ;;
        *)   lo="$part"; hi="$part" ;;
      esac
    fi
    case "$lo$hi" in
      ''|*[!0-9]*) die "non-numeric $name field: '$spec' (names like 'mon' are not supported -- use numbers)" ;;
    esac
    { [ "$lo" -ge "$min" ] && [ "$hi" -le "$max" ] && [ "$lo" -le "$hi" ]; } \
      || die "$name field out of range $min-$max: '$spec'"
    v="$lo"
    while [ "$v" -le "$hi" ]; do out="$out $v"; v=$((v + step)); done
  done
  echo "${out# }"
}

# map_weekdays <list|ANY> -> launchd weekdays. THE TRAP: cron 0=Sunday, launchd
# 1=Mon..7=Sun. 0 maps to 7; 1-6 pass through; 7 (valid cron Sunday too) stays 7.
map_weekdays() {
  [ "$1" = "ANY" ] && { echo "ANY"; return; }
  local out="" v seen7=0
  for v in $1; do
    [ "$v" -eq 0 ] && v=7
    if [ "$v" -eq 7 ]; then
      [ "$seen7" -eq 1 ] && continue
      seen7=1
    fi
    out="$out $v"
  done
  echo "${out# }"
}

# calendar_fragment "<cron>" -> the <key>StartCalendarInterval</key> block.
# Cross-product of the non-wildcard fields, one launchd dict per combination.
calendar_fragment() {
  local cron="$1" f_min f_hr f_day f_mon f_wkd
  # shellcheck disable=SC2086
  set -- $cron
  [ "$#" -eq 5 ] || die "schedule must be a 5-field cron expression (minute hour day month weekday), got $# field(s): '$cron'"
  f_min="$(expand_field "$1" 0 59 minute)"
  f_hr="$(expand_field "$2" 0 23 hour)"
  f_day="$(expand_field "$3" 1 31 day)"
  f_mon="$(expand_field "$4" 1 12 month)"
  # Two statements on purpose: nesting the substitutions would swallow
  # expand_field's refusal (a die in an inner $() kills only that subshell).
  f_wkd="$(expand_field "$5" 0 7 weekday)"
  f_wkd="$(map_weekdays "$f_wkd")"

  local dicts="" count=0 m h d mo w entry
  for m in $f_min; do for h in $f_hr; do for d in $f_day; do for mo in $f_mon; do for w in $f_wkd; do
    entry="        <dict>"$'\n'
    [ "$m" != "ANY" ] && entry="$entry            <key>Minute</key><integer>$m</integer>"$'\n'
    [ "$h" != "ANY" ] && entry="$entry            <key>Hour</key><integer>$h</integer>"$'\n'
    [ "$d" != "ANY" ] && entry="$entry            <key>Day</key><integer>$d</integer>"$'\n'
    [ "$mo" != "ANY" ] && entry="$entry            <key>Month</key><integer>$mo</integer>"$'\n'
    [ "$w" != "ANY" ] && entry="$entry            <key>Weekday</key><integer>$w</integer>"$'\n'
    entry="$entry        </dict>"
    dicts="$dicts$entry"$'\n'
    count=$((count + 1))
    [ "$count" -le "$MAX_CALENDAR_ENTRIES" ] || die "schedule expands to more than $MAX_CALENDAR_ENTRIES calendar entries -- simplify '$cron'"
  done; done; done; done; done

  echo "    <key>StartCalendarInterval</key>"
  if [ "$count" -eq 1 ]; then
    printf '%s' "$dicts" | sed 's/^        //'  | sed 's/^/    /'
  else
    echo "    <array>"
    printf '%s' "$dicts"
    echo "    </array>"
  fi
}

# -------------------------------------------------------------------- install
cmd_install() {
  local name="" schedule="" prompt="" prompt_file="" harness="claude" cwd="" harness_args=""
  local have_prompt=0 have_file=0
  [ "$#" -ge 1 ] || die "usage: install <name> --schedule \"<cron>\" (--prompt <text> | --prompt-file <abs>) [--harness claude|codex] [--cwd <dir>] [--harness-args <flags>]"
  name="$1"; shift
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --schedule)     schedule="${2:?--schedule needs a value}"; shift 2 ;;
      --prompt)       prompt="${2:?--prompt needs a value}"; have_prompt=1; shift 2 ;;
      --prompt-file)  prompt_file="${2:?--prompt-file needs a value}"; have_file=1; shift 2 ;;
      --harness)      harness="${2:?--harness needs a value}"; shift 2 ;;
      --cwd)          cwd="${2:?--cwd needs a value}"; shift 2 ;;
      --harness-args) harness_args="${2:?--harness-args needs a value}"; shift 2 ;;
      *) die "unknown install flag: $1" ;;
    esac
  done

  case "$name" in
    ''|*[!a-z0-9-]*) die "name must be lowercase alphanumeric + hyphens: '$name'" ;;
    -*) die "name must not start with a hyphen: '$name'" ;;
  esac
  [ -n "$schedule" ] || die "--schedule is required"
  [ $((have_prompt + have_file)) -eq 1 ] || die "exactly one of --prompt / --prompt-file is required"
  if [ "$have_file" -eq 1 ]; then
    case "$prompt_file" in /*) : ;; *) die "--prompt-file must be an absolute path: '$prompt_file'" ;; esac
    [ -f "$prompt_file" ] || die "--prompt-file does not exist: '$prompt_file' (a missing payload would break silently at the first tick)"
  fi
  case "$harness" in claude|codex) : ;; *) die "unknown harness '$harness' (claude|codex)" ;; esac
  case "$harness_args" in *$'\n'*) die "--harness-args must be a single line" ;; esac

  # Runner ladder, resolved to ABSOLUTE paths now (a scheduled job gets no shell
  # profile and a minimal PATH): spawn-agent when present, else the harness itself.
  local runner runner_kind
  if runner="$(command -v spawn-agent 2>/dev/null)"; then
    runner_kind="spawn-agent"
  elif runner="$(command -v "$harness" 2>/dev/null)"; then
    runner_kind="$harness"
  else
    die "no runner found: neither spawn-agent nor '$harness' is on PATH"
  fi

  local home; home="$(home_dir)"
  ensure_home "$home"
  [ -n "$cwd" ] || cwd="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  [ -d "$cwd" ] || die "--cwd is not a directory: '$cwd'"

  # Validate the schedule up front -- both backends consume it.
  calendar_fragment "$schedule" >/dev/null

  local spec="$home/jobs/$name.job" payload_kind payload_path
  if [ "$have_prompt" -eq 1 ]; then
    payload_kind="prompt"
    payload_path="$home/jobs/$name.prompt"
    printf '%s\n' "$prompt" >"$payload_path"
  else
    payload_kind="prompt-file"
    payload_path="$prompt_file"
  fi
  {
    echo "name=$name"
    echo "schedule=$schedule"
    echo "harness=$harness"
    echo "runner=$runner"
    echo "runner_kind=$runner_kind"
    echo "payload=$payload_kind"
    echo "payload_path=$payload_path"
    echo "cwd=$cwd"
    echo "harness_args=$harness_args"
    echo "created=$(date +%Y-%m-%d)"
  } >"$spec"

  case "$(platform)" in
    Darwin) install_darwin "$name" "$home" "$schedule" "$cwd" ;;
    Linux)  install_linux "$name" "$home" "$schedule" ;;
    *)      die "unsupported platform: $(platform)" ;;
  esac

  echo "installed: $name (runner: $runner_kind $runner, schedule: $schedule, payload: $payload_kind $payload_path)"
}

install_darwin() { # <name> <home> <cron> <cwd>
  local name="$1" home="$2" cron="$3" cwd="$4"
  local label plist la link
  label="$(label_for "$name")"
  plist="$home/jobs/$name.plist"
  la="${SCHEDULER_LAUNCH_AGENTS:-$HOME/Library/LaunchAgents}"
  link="$la/$label.plist"
  mkdir -p "$la"

  {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
    echo '<plist version="1.0">'
    echo '<dict>'
    echo "    <key>Label</key><string>$(xml_escape "$label")</string>"
    echo '    <key>ProgramArguments</key>'
    echo '    <array>'
    echo "        <string>$(xml_escape "$SELF")</string>"
    echo '        <string>tick</string>'
    echo "        <string>$(xml_escape "$name")</string>"
    echo '    </array>'
    echo "    <key>WorkingDirectory</key><string>$(xml_escape "$cwd")</string>"
    calendar_fragment "$cron"
    echo "    <key>StandardOutPath</key><string>$(xml_escape "$home/logs/$name.wrapper.log")</string>"
    echo "    <key>StandardErrorPath</key><string>$(xml_escape "$home/logs/$name.wrapper.log")</string>"
    echo '</dict>'
    echo '</plist>'
  } >"$plist"

  if [ -e "$link" ] || [ -L "$link" ]; then
    "$LAUNCHCTL" unload "$link" >/dev/null 2>&1 || true
  fi
  ln -sf "$plist" "$link"
  "$LAUNCHCTL" load "$link" || die "launchctl load failed for $link"
}

install_linux() { # <name> <home> <cron>
  local name="$1" home="$2" cron="$3" marker existing line
  marker="$(marker_for "$name")"
  existing="$("$CRONTAB" -l 2>/dev/null || true)"
  line="$cron \"$SELF\" tick $name >> \"$home/logs/$name.wrapper.log\" 2>&1 $marker"
  printf '%s\n' "$existing" | grep -vF "$marker" | { grep -v '^$' || true; echo "$line"; } | "$CRONTAB" -
}

# ------------------------------------------------------------------ uninstall
cmd_uninstall() {
  local name="${1:?usage: uninstall <name>}" home spec
  home="$(home_dir)"
  spec="$home/jobs/$name.job"
  [ -f "$spec" ] || die "no such job: $name (no $spec)"

  case "$(platform)" in
    Darwin)
      local label link
      label="$(label_for "$name")"
      link="${SCHEDULER_LAUNCH_AGENTS:-$HOME/Library/LaunchAgents}/$label.plist"
      "$LAUNCHCTL" unload "$link" >/dev/null 2>&1 || true
      rm -f "$link" "$home/jobs/$name.plist"
      ;;
    Linux)
      local marker existing
      marker="$(marker_for "$name")"
      existing="$("$CRONTAB" -l 2>/dev/null || true)"
      printf '%s\n' "$existing" | { grep -vF "$marker" || true; } | "$CRONTAB" -
      ;;
    *) die "unsupported platform: $(platform)" ;;
  esac

  rm -f "$spec" "$home/jobs/$name.prompt"
  echo "uninstalled: $name (logs preserved under $home/logs/)"
}

# -------------------------------------------------------------------- tick/run
cmd_tick() {
  local name="${1:?usage: tick <name>}" home spec
  home="$(home_dir)"
  spec="$home/jobs/$name.job"
  [ -f "$spec" ] || die "no such job: $name (no $spec)"

  # Cron stacks overlapping runs (launchd labels don't); self-wrap in flock when
  # available. The re-exec guard keeps this a single hop.
  local lock="$home/logs/$name.lock"
  if [ -z "${SCHEDULER_TICK_LOCKED:-}" ] && command -v flock >/dev/null 2>&1; then
    SCHEDULER_TICK_LOCKED=1 exec flock -n "$lock" "$SELF" tick "$name"
  fi

  local runner runner_kind harness payload_path cwd harness_args
  runner="$(spec_get "$spec" runner)"
  runner_kind="$(spec_get "$spec" runner_kind)"
  harness="$(spec_get "$spec" harness)"
  payload_path="$(spec_get "$spec" payload_path)"
  cwd="$(spec_get "$spec" cwd)"
  harness_args="$(spec_get "$spec" harness_args)"

  local out="$home/logs/$name.out.log" err="$home/logs/$name.err.log" last="$home/logs/$name.last"
  mkdir -p "$home/logs"

  fail_run() { # <reason> -- record the failure where triage looks, then refuse
    echo "$(date '+%Y-%m-%d %H:%M:%S')	tick refused: $1" >>"$err"
    printf '%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "refused" >>"$last"
    die "$1"
  }
  [ -x "$runner" ] || fail_run "runner missing or not executable: $runner (reinstall to re-resolve)"
  [ -f "$payload_path" ] || fail_run "payload file missing: $payload_path"
  [ -d "$cwd" ] || fail_run "cwd missing: $cwd"

  # Preamble: project override, else the skill's bundled default. Payload read
  # FRESH each tick (that is the --prompt-file contract).
  local preamble="$SKILL_DIR/HEARTBEAT.md" prompt_text
  [ -f "$home/HEARTBEAT.md" ] && preamble="$home/HEARTBEAT.md"
  prompt_text="$(cat "$preamble")"$'\n\n'"$(cat "$payload_path")"

  local rc=0
  cd "$cwd"
  {
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') tick $name (runner: $runner_kind)"
  } >>"$out"
  # harness_args is a recorded flag string; word-splitting is the contract.
  # shellcheck disable=SC2086
  case "$runner_kind" in
    spawn-agent)
      local task_file
      task_file="$(mktemp "${TMPDIR:-/tmp}/schedule-task.XXXXXX")"
      printf '%s\n' "$prompt_text" >"$task_file"
      "$runner" --harness "$harness" --task-file "$task_file" --project "$cwd" $harness_args >>"$out" 2>>"$err" || rc=$?
      rm -f "$task_file"
      ;;
    claude)
      "$runner" -p "$prompt_text" $harness_args >>"$out" 2>>"$err" || rc=$?
      ;;
    codex)
      "$runner" exec $harness_args "$prompt_text" >>"$out" 2>>"$err" || rc=$?
      ;;
    *)
      fail_run "unknown runner_kind in spec: $runner_kind"
      ;;
  esac

  printf '%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$rc" >>"$last"
  echo "tick $name: exit=$rc out=$out err=$err"
  return "$rc"
}

# ------------------------------------------------------------------ list/status
last_run_of() { # <home> <name> -> "never" or "ts (exit N)"
  local last="$1/logs/$2.last" line
  [ -f "$last" ] || { echo "never"; return; }
  line="$(tail -1 "$last")"
  echo "${line%	*} (exit ${line##*	})"
}

cmd_list() {
  local home spec name specs
  home="$(home_dir)"
  set +f
  specs=("$home/jobs/"*.job)
  set -f
  if [ ! -e "${specs[0]}" ]; then
    echo "no jobs installed (home: $home)"
    return
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "name" "schedule" "runner" "payload" "last-run"
  for spec in "${specs[@]}"; do
    name="$(spec_get "$spec" name)"
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$name" \
      "$(spec_get "$spec" schedule)" \
      "$(spec_get "$spec" runner_kind)" \
      "$(spec_get "$spec" payload): $(spec_get "$spec" payload_path)" \
      "$(last_run_of "$home" "$name")"
  done
}

cmd_status() {
  [ "$#" -ge 1 ] || { cmd_list; return; }
  local name="$1" home spec
  home="$(home_dir)"
  spec="$home/jobs/$name.job"
  [ -f "$spec" ] || die "no such job: $name (no $spec)"

  echo "job: $name"
  sed 's/^/  /' "$spec"

  local loaded="unknown"
  case "$(platform)" in
    Darwin)
      if "$LAUNCHCTL" list "$(label_for "$name")" >/dev/null 2>&1; then loaded="loaded"; else loaded="NOT loaded"; fi ;;
    Linux)
      if "$CRONTAB" -l 2>/dev/null | grep -qF "$(marker_for "$name")"; then loaded="in crontab"; else loaded="NOT in crontab"; fi ;;
  esac
  echo "  state: $loaded"
  echo "  logs: $home/logs/$name.out.log | $home/logs/$name.err.log"
  if [ -f "$home/logs/$name.last" ]; then
    echo "  recent runs (timestamp<TAB>exit):"
    tail -3 "$home/logs/$name.last" | sed 's/^/    /'
  else
    echo "  recent runs: none yet (test with: schedule.sh run $name)"
  fi
}

# ------------------------------------------------------------------- dispatch
usage() {
  sed -n '2,8p' "$SELF" | sed 's/^# \{0,1\}//'
  echo "subcommands: install uninstall list status run tick convert"
}

[ "$#" -ge 1 ] || { usage; exit 2; }
cmd="$1"; shift
case "$cmd" in
  install)   cmd_install "$@" ;;
  uninstall) cmd_uninstall "$@" ;;
  list)      cmd_list "$@" ;;
  status)    cmd_status "$@" ;;
  run|tick)  cmd_tick "$@" ;;
  convert)   calendar_fragment "${1:?usage: convert \"<cron>\"}" ;;
  -h|--help|help) usage ;;
  *) die "unknown subcommand: $cmd" ;;
esac
