#!/usr/bin/env bash
# schedule-test.sh — schedule.sh end to end against a mktemp fixture: install/
# uninstall/list/status/run round-trips on BOTH platform paths (SCHEDULER_UNAME
# override; stub launchctl/crontab, fake harness bin), tick's preamble+payload
# assembly (prompt snapshot vs prompt-file read fresh, project HEARTBEAT override,
# exit codes stamped), reinstall-replaces-not-duplicates, every advertised
# refusal, and the cron→launchd conversion — the weekday-numbering trap (cron
# 0=Sunday → launchd 7) proven by breaking during development.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
SS="$SKILL/scripts/schedule.sh"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/scheduler-test.XXXXXX")"
TMP="$(cd "$TMP" && pwd)"   # canonical (a trailing-slash TMPDIR would break path equality)
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

# --- fixture: temp home, stub launchctl/crontab, fake harness binaries ----------
HOME_DIR="$TMP/proj/.scheduler"
LA="$TMP/LaunchAgents"
BIN="$TMP/bin"
mkdir -p "$TMP/proj" "$BIN"

cat >"$BIN/launchctl" <<'EOF'
#!/bin/sh
# stub launchctl: log every call; `list <label>` succeeds iff the label was
# loaded more recently than unloaded.
echo "$@" >> "$LAUNCHCTL_LOG"
case "$1" in
  load)   touch "$LAUNCHCTL_STATE.$(basename "$2" .plist)" ;;
  unload) rm -f "$LAUNCHCTL_STATE.$(basename "$2" .plist)" ;;
  list)   [ -e "$LAUNCHCTL_STATE.$2" ] ;;
esac
EOF
cat >"$BIN/crontab" <<'EOF'
#!/bin/sh
# stub crontab: -l prints the state file; - replaces it from stdin.
case "$1" in
  -l) cat "$CRONTAB_STATE" 2>/dev/null ;;
  -)  cat > "$CRONTAB_STATE" ;;
esac
EOF
cat >"$BIN/claude" <<'EOF'
#!/bin/sh
# fake harness: record argv (one per line), obey FAKE_EXIT.
printf '%s\n' "$@" > "$FAKE_ARGS"
echo "fake claude ran"
exit "${FAKE_EXIT:-0}"
EOF
chmod +x "$BIN/launchctl" "$BIN/crontab" "$BIN/claude"

export SCHEDULER_HOME="$HOME_DIR"
export SCHEDULER_LAUNCH_AGENTS="$LA"
export SCHEDULER_LAUNCHCTL="$BIN/launchctl"
export SCHEDULER_CRONTAB="$BIN/crontab"
export LAUNCHCTL_LOG="$TMP/launchctl.log" LAUNCHCTL_STATE="$TMP/launchctl.state"
export CRONTAB_STATE="$TMP/crontab.txt"
export FAKE_ARGS="$TMP/claude-args.txt"
# Pin PATH: only the fixture bin + system utils. The real machine may carry a
# real spawn-agent/claude on PATH, and the runner ladder would prefer it.
export PATH="$BIN:/usr/bin:/bin"
touch "$LAUNCHCTL_LOG"

# --- convert: the cron→launchd conversion, weekday trap front and center --------
"$SS" convert "30 6 * * 0" >"$OUT"
expect "cron Sunday 0 becomes launchd 7" "<key>Weekday</key><integer>7</integer>" "$OUT"
expect_absent "no launchd Weekday 0 emitted" "<key>Weekday</key><integer>0</integer>" "$OUT"
"$SS" convert "0 9 * * 1-5" >"$OUT"
expect "weekday range lower bound survives" "<key>Weekday</key><integer>1</integer>" "$OUT"
expect "weekday range upper bound survives" "<key>Weekday</key><integer>5</integer>" "$OUT"
expect_absent "range does not overshoot" "<key>Weekday</key><integer>6</integer>" "$OUT"
"$SS" convert "0 9 * * 7" >"$OUT"
expect "cron 7 (also Sunday) stays 7" "<key>Weekday</key><integer>7</integer>" "$OUT"
"$SS" convert "*/30 * * * *" >"$OUT"
expect "step expands to 0" "<key>Minute</key><integer>0</integer>" "$OUT"
expect "step expands to 30" "<key>Minute</key><integer>30</integer>" "$OUT"
expect_absent "wildcard hour emits no Hour key" "<key>Hour</key>" "$OUT"
"$SS" convert "0 0 * * *" >"$OUT"
expect "single combo is a bare dict" "    <dict>" "$OUT"
expect_absent "single combo has no array wrapper" "<array>" "$OUT"

# --- refusals: every advertised guard actually refuses --------------------------
refuse() { # refuse <label> <expected-stderr-fragment> <args...>
  local lbl="$1" frag="$2"; shift 2
  if "$SS" "$@" >"$OUT" 2>"$ERR"; then
    echo "FAIL: $lbl — expected refusal, got success" >&2; fail=$((fail + 1))
  else
    expect "$lbl" "$frag" "$ERR"
  fi
}
refuse "6-field cron refused" "5-field" convert "0 9 * * * 1"
refuse "weekday name refused" "names like 'mon'" convert "0 9 * * mon"
refuse "out-of-range hour refused" "out of range" convert "0 25 * * *"
refuse "bad step refused" "bad step" convert "*/x * * * *"
refuse "bad name refused" "lowercase" install "Bad Name" --schedule "0 9 * * *" --prompt hi
refuse "missing payload refused" "exactly one of" install job1 --schedule "0 9 * * *"
refuse "double payload refused" "exactly one of" install job1 --schedule "0 9 * * *" --prompt hi --prompt-file "$TMP/p.md"
refuse "relative prompt-file refused" "absolute path" install job1 --schedule "0 9 * * *" --prompt-file p.md
refuse "missing prompt-file refused" "does not exist" install job1 --schedule "0 9 * * *" --prompt-file "$TMP/nope.md"
refuse "unknown harness refused" "unknown harness" install job1 --schedule "0 9 * * *" --prompt hi --harness pi
SCHEDULER_UNAME=Plan9 refuse "unknown platform refused" "unsupported platform" install job1 --schedule "0 9 * * *" --prompt hi --cwd "$TMP/proj"
rm -f "$SCHEDULER_HOME/jobs/job1.job" "$SCHEDULER_HOME/jobs/job1.prompt"

# --- Darwin path: install → plist + symlink + load ------------------------------
export SCHEDULER_UNAME=Darwin
"$SS" install morning --schedule "0 9 * * 1-5" --prompt "review the overnight runs" \
  --cwd "$TMP/proj" --harness-args "--permission-mode plan" >"$OUT"
expect "install reports the resolved runner" "runner: claude $BIN/claude" "$OUT"
PLIST="$HOME_DIR/jobs/morning.plist"
expect "plist program is schedule.sh" "<string>$SS</string>" "$PLIST"
expect "plist arg is tick" "<string>tick</string>" "$PLIST"
expect "plist arg is the job name" "<string>morning</string>" "$PLIST"
expect "plist working dir recorded" "<string>$TMP/proj</string>" "$PLIST"
expect "plist carries the converted weekday" "<key>Weekday</key><integer>1</integer>" "$PLIST"
expect "label is namespaced" "com.agent-schedule.morning" "$PLIST"
if [ -L "$LA/com.agent-schedule.morning.plist" ]; then pass=$((pass + 1))
else echo "FAIL: symlink in LaunchAgents" >&2; fail=$((fail + 1)); fi
expect "launchctl load called on the symlink" "load $LA/com.agent-schedule.morning.plist" "$LAUNCHCTL_LOG"
expect "gitignore is self-managing" '!HEARTBEAT.md' "$HOME_DIR/.gitignore"
expect "spec records absolute runner" "runner=$BIN/claude" "$HOME_DIR/jobs/morning.job"
expect "prompt snapshotted" "review the overnight runs" "$HOME_DIR/jobs/morning.prompt"

# reinstall replaces: unload fires before the fresh load, still exactly one plist
"$SS" install morning --schedule "0 10 * * 1-5" --prompt "changed" --cwd "$TMP/proj" \
  --harness-args "--permission-mode plan" >/dev/null
expect "reinstall unloads the old job" "unload $LA/com.agent-schedule.morning.plist" "$LAUNCHCTL_LOG"
expect "reinstall rewrites the schedule" "<key>Hour</key><integer>10</integer>" "$PLIST"
expect_eq "still exactly one morning plist" "1" "$(find "$HOME_DIR/jobs" -name 'morning*.plist' | wc -l | tr -d ' ')"

# --- tick/run: preamble + payload assembly, logs, exit stamps -------------------
"$SS" run morning >"$OUT"
expect "run reports exit 0" "tick morning: exit=0" "$OUT"
expect "fake harness got -p" "-p" "$FAKE_ARGS"
expect "prompt carries the bundled preamble" "HEARTBEAT_OK" "$FAKE_ARGS"
expect "prompt carries the payload" "changed" "$FAKE_ARGS"
expect "harness-args forwarded" "--permission-mode" "$FAKE_ARGS"
expect "stdout logged" "fake claude ran" "$HOME_DIR/logs/morning.out.log"
expect "last stamp records exit 0" "	0" "$HOME_DIR/logs/morning.last"

# project HEARTBEAT override beats the bundled preamble
printf '%s\n' "CUSTOM PROJECT PREAMBLE" >"$HOME_DIR/HEARTBEAT.md"
"$SS" run morning >/dev/null
expect "project preamble used" "CUSTOM PROJECT PREAMBLE" "$FAKE_ARGS"
expect_absent "bundled preamble displaced" "HEARTBEAT_OK" "$FAKE_ARGS"
rm "$HOME_DIR/HEARTBEAT.md"

# prompt-file payloads are read FRESH each tick
printf '%s\n' "version one" >"$TMP/standing.md"
"$SS" install standing --schedule "0 0 * * *" --prompt-file "$TMP/standing.md" --cwd "$TMP/proj" >/dev/null
"$SS" run standing >/dev/null
expect "prompt-file v1 read" "version one" "$FAKE_ARGS"
printf '%s\n' "version two" >"$TMP/standing.md"
"$SS" run standing >/dev/null
expect "prompt-file re-read fresh" "version two" "$FAKE_ARGS"
expect_absent "stale content gone" "version one" "$FAKE_ARGS"

# failing harness: exit code propagates and is stamped
rc=0
FAKE_EXIT=3 "$SS" run standing >"$OUT" || rc=$?
expect_eq "tick exits with harness code" "3" "$rc"
expect "last stamp records exit 3" "	3" "$HOME_DIR/logs/standing.last"

# tick refusal is stamped where triage looks (not just stderr)
rm "$TMP/standing.md"
if "$SS" run standing >"$OUT" 2>"$ERR"; then
  echo "FAIL: missing payload file should refuse" >&2; fail=$((fail + 1))
else
  expect "missing payload refusal names the file" "payload file missing" "$ERR"
  expect "refusal stamped in .last" "refused" "$HOME_DIR/logs/standing.last"
  expect "refusal logged in err.log" "payload file missing" "$HOME_DIR/logs/standing.err.log"
fi
printf '%s\n' "restored" >"$TMP/standing.md"

# --- list/status ----------------------------------------------------------------
"$SS" list >"$OUT"
expect "list shows morning row" "morning" "$OUT"
expect "list shows schedule" "0 10 * * 1-5" "$OUT"
expect "list shows last run" "(exit 0)" "$OUT"
"$SS" status morning >"$OUT"
expect "status shows loaded" "state: loaded" "$OUT"
expect "status shows recent runs" "recent runs" "$OUT"
"$SS" status >"$OUT"
expect "bare status falls back to list" "standing" "$OUT"
refuse "status of unknown job refused" "no such job" status ghost

# --- Darwin uninstall: job gone, logs preserved ---------------------------------
"$SS" uninstall morning >"$OUT"
expect "uninstall says logs preserved" "logs preserved" "$OUT"
expect "launchctl unload called" "unload $LA/com.agent-schedule.morning.plist" "$LAUNCHCTL_LOG"
if [ ! -e "$LA/com.agent-schedule.morning.plist" ] && [ ! -f "$HOME_DIR/jobs/morning.job" ]; then pass=$((pass + 1))
else echo "FAIL: uninstall left artifacts" >&2; fail=$((fail + 1)); fi
if [ -f "$HOME_DIR/logs/morning.out.log" ]; then pass=$((pass + 1))
else echo "FAIL: uninstall deleted logs" >&2; fail=$((fail + 1)); fi
refuse "double uninstall refused" "no such job" uninstall morning

# --- Linux path: crontab line with marker; replace-not-duplicate ----------------
export SCHEDULER_UNAME=Linux
"$SS" install nightly --schedule "15 2 * * *" --prompt "tidy up" --cwd "$TMP/proj" >/dev/null
expect "cron line calls tick" "\"$SS\" tick nightly" "$CRONTAB_STATE"
expect "cron line carries the schedule" "15 2 * * *" "$CRONTAB_STATE"
expect "cron line is markered" "# agent-schedule: nightly" "$CRONTAB_STATE"
expect "cron line redirects to wrapper log" "nightly.wrapper.log" "$CRONTAB_STATE"
"$SS" install nightly --schedule "45 3 * * *" --prompt "tidy up later" --cwd "$TMP/proj" >/dev/null
expect_eq "reinstall keeps one markered line" "1" "$(grep -cF "# agent-schedule: nightly" "$CRONTAB_STATE")"
expect "reinstalled schedule replaced" "45 3 * * *" "$CRONTAB_STATE"
expect_absent "old schedule gone" "15 2 * * *" "$CRONTAB_STATE"
"$SS" status nightly >"$OUT"
expect "linux status reads crontab" "state: in crontab" "$OUT"
"$SS" uninstall nightly >/dev/null
expect_absent "uninstall removes the cron line" "agent-schedule: nightly" "$CRONTAB_STATE"

# --- runner ladder: spawn-agent preferred when present --------------------------
cat >"$BIN/spawn-agent" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$FAKE_ARGS"
cat "$4" >> "$FAKE_ARGS"   # --task-file payload lands in argv record for asserts
echo "fake spawn-agent ran"
exit "${FAKE_EXIT:-0}"
EOF
chmod +x "$BIN/spawn-agent"
"$SS" install laddered --schedule "0 4 * * *" --prompt "ladder check" --cwd "$TMP/proj" >"$OUT"
expect "spawn-agent preferred when on PATH" "runner: spawn-agent $BIN/spawn-agent" "$OUT"
"$SS" run laddered >/dev/null
expect "spawn-agent invoked with harness" "claude" "$FAKE_ARGS"
expect "task-file carries the payload" "ladder check" "$FAKE_ARGS"
rm "$BIN/spawn-agent"
"$SS" install laddered --schedule "0 4 * * *" --prompt "ladder check" --cwd "$TMP/proj" >"$OUT"
expect "ladder degrades to harness when spawn-agent gone" "runner: claude $BIN/claude" "$OUT"

report "schedule-test" || exit 1
