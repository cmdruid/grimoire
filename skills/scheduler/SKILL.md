---
name: scheduler
description: "Schedule recurring agent-harness runs on this machine (claude or codex) via launchd on macOS or cron on Linux. Each OS tick is one short-lived headless harness invocation. Use when the user wants a recurring agent run, or to list, check, test-fire, or remove one. Not ordinary OS cron unless a harness is the payload. Keywords: scheduled agent, heartbeat, recurring harness."
---

# scheduler -- recurring agent runs via the OS supervisor

## Overview

The proper way to run agents in the background is **no daemon at all**: the OS's own supervisor
(launchd on macOS, cron on Linux) is the daemon, and each tick spawns one short-lived headless
harness run. This skill wraps that pattern. The installed plist/cron line is always just
`<schedule.sh> tick <name>` -- stable forever -- and `tick` does the real work: read the job
spec, assemble preamble + payload, take the lock, exec the runner, log the outcome.

`scripts/schedule.sh` owns every fact (resolve it from **this skill's own base directory**, and
invoke it by absolute path). Prose here owns the judgment. Never hand-write a plist or crontab
line for an agent task -- the script exists because the details (weekday numbering, empty
environments, locking) are exactly where hand-written jobs silently break.

## Quick reference

```
schedule.sh install <name> --schedule "<cron>" (--prompt "<text>" | --prompt-file <abs-path>)
                    [--harness claude|codex] [--cwd <dir>] [--harness-args "<flags>"]
                    # existing <name> replaces the spec and the supervisor entry; logs stay
schedule.sh uninstall <name>       # remove the job; logs are preserved
schedule.sh list                   # every job in this project: schedule, runner, last run
schedule.sh status [<name>]        # loaded state, recent runs + exit codes, log paths
schedule.sh run <name>             # fire the tick NOW -- test exactly what the schedule runs
schedule.sh convert "<cron>"       # show the cron -> launchd calendar conversion
```

`<cron>` is a 5-field expression (`minute hour day month weekday`, numeric only). Common:
`0 9 * * 1-5` weekdays 9am · `*/30 * * * *` every 30min · `0 0 * * *` midnight.

## The `.scheduler/` home (project-scoped, self-gitignoring)

State lives in the project at `.scheduler/` -- the script creates it with its own `.gitignore`
so nothing machine-local can leak into the repo:

| Path | What | Committed? |
|---|---|---|
| `.scheduler/HEARTBEAT.md` | per-project preamble override (see below) | yes -- the one shareable piece |
| `.scheduler/jobs/<name>.job` | job spec (absolute paths, resolved runner) | never (machine-local) |
| `.scheduler/jobs/<name>.prompt` | snapshot of a `--prompt` payload | never |
| `.scheduler/logs/<name>.{out,err}.log` | harness output per run | never |
| `.scheduler/logs/<name>.last` | one line per run: timestamp + exit code | never |

**Payload semantics:** `--prompt` snapshots its text at install; `--prompt-file` records the
absolute path and reads it **fresh at every tick** -- an evolving standing-instructions doc
takes effect without reinstalling. Every run gets a preamble prepended: the project's
`.scheduler/HEARTBEAT.md` if present, else this skill's bundled `HEARTBEAT.md` (a non-interactive
notice + the `HEARTBEAT_OK` nothing-to-report convention).

## Before installing -- the judgment layer

Confirm with the user before any install; a silently-broken (or silently-spending) scheduled
task is worse than no task:

1. **The schedule and timezone.** Cron/launchd fire in local machine time. Confirm the
   expression *and* that local time is what the user means.
2. **A permission stance.** An unattended harness run cannot answer permission prompts -- it
   stalls or dies at the first one. `tick` adds **no default**: pass the user's chosen stance
   explicitly via `--harness-args` (a pre-approved allowlist, a sandbox/read-only mode, or an
   explicitly-accepted bypass). Never pick a bypass for the user.
3. **The right tool.** This skill's niche is *recurring agent-harness runs* against this
   machine's state (its checkouts, credentials, files). Ordinary OS cron (backups, log
   rotate, a non-harness script) is **when-not** — do not wrap it in a harness tick. For
   tasks that don't need this machine, a harness-native cloud schedule (which runs with the
   laptop closed) is the better home -- offer it.
4. **Cost.** A scheduled agent spends tokens unattended. Say what the cadence implies and
   point at `status` as the check-in habit.

When the user describes recurring work ("every morning", "each hour", "can this happen
automatically?"), *offer* to schedule it -- don't wait to be asked, and don't install without
the confirmations above.

## Platform notes (what the script already handles, and the two real caveats)

- **macOS:** user-scope only -- `~/Library/LaunchAgents`, no sudo, no LaunchDaemons (a daemon
  runs outside your login session and cannot reach the user keychain, which is where harness
  credentials live; daemon scope would break auth, not just safety). launchd labels are
  single-instance; missed ticks fire on wake from sleep (not across power-off).
- **macOS TCC/Full Disk Access:** grants attach to a *binary identity*. A stable runner binary
  (e.g. a `spawn-agent`-style wrapper, preferred automatically when on `$PATH`) can be granted
  FDA once and survive harness updates; a grant to the harness binary itself breaks each time
  it updates. If a scheduled run needs protected paths, expect to re-grant after updates --
  or install a stable wrapper and grant that.
- **Linux:** user crontab; `tick` self-wraps in `flock -n` where `flock` exists, since cron
  (unlike launchd) will happily stack overlapping runs. Cron has no missed-tick handling --
  if the machine may be off at the scheduled time, **systemd user timers** with
  `Persistent=true` (plus `loginctl enable-linger`) are the better substrate; the script
  doesn't generate them, but say so when the miss matters.
- **Empty environments** (the #1 silent breakage): launchd and cron jobs get no shell profile
  and a minimal `PATH`. The script defuses this by resolving the runner to an **absolute path
  at install time** and recording it in the spec -- which also means a runner installed
  *after* a job won't be picked up until reinstall. `status` shows what a job will execute.

## Triage a run

Read `.scheduler/logs/<name>.last` first (timestamp + exit code per run), then the paired
`.out.log`/`.err.log`. `status <name>` summarizes all three plus loaded state. To reproduce,
`run <name>` fires the identical code path the schedule uses -- same spec, same preamble, same
runner -- so a green `run` means the *job* is sound and remaining failures are environmental
(load state, machine asleep, TCC).

## Edges

<!-- edges:scheduler -->
- produces: — (none; jobs are local launchd/cron state)
- handoff: — (none)
- consumes: — (none)
<!-- /edges:scheduler -->

## Done when

- **`install`:** the four confirmations (schedule+timezone, permission stance, right tool,
  cost) ran **and** the script printed `installed:`. Nothing is installed without those
  confirmations.
- **`uninstall` / `list` / `status` / `run` / `convert`:** the script's printed facts, or a
  clean refuse. Do not install on an unsupported platform.
