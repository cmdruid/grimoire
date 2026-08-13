# Clankshop v2 — Phase 4 plan: `scheduler` port

Companion to `2026-08-12-clankshop-v2.md` (§ The pack, Open items) and the roadmap's Phase 4.
Independent of Phase 3 (utility tier — never touches the layout). Port source: thinklab's
`agent-scheduler` skill (a sibling repo, outside this one;
`templates/agent-template/skills/task-scheduler` there is its retired ancestor). Public-repo
rule applies: no private paths may survive the port.

## Design (settled 2026-08-13 — supersedes the source's shape where they differ)

The skill schedules recurring **agent runs**: the OS supervisor (launchd/cron) fires a tick,
the tick launches an agent harness with a prompt or prompt-file. No hand-rolled daemon — the
OS scheduler *is* the daemon; every run is a short-lived headless harness invocation.

- **Payload = prompt or prompt-file** (not the source's `--skill`/`--command` pair):
  `--prompt "<text>"` stores the text; `--prompt-file <abs>` stores the path and reads it
  **fresh at each tick** (an evolving standing-instructions doc needs no reinstall).
- **Single `tick` entrypoint** (the architectural upgrade over the source): the plist/cron
  line is just `<abs schedule.sh> tick <name>` — stable forever. `tick` reads the job spec,
  assembles preamble + payload, takes the lock, execs the resolved runner, writes logs + a
  last-run/exit-code stamp. **`run <name>` is `tick` by hand** — you test exactly what the
  scheduler will run ("a silently-broken scheduled task is worse than no task").
- **Project-scoped, self-gitignoring home `.scheduler/`** (the `.workstreams/` pattern):
  `jobs/<name>.job` specs + `logs/` are machine-local (absolute paths, run output — never
  committed; the dir writes its own `.gitignore`); `HEARTBEAT.md` is the one committable
  piece — a per-project preamble override of the skill's bundled default.
- **Runner ladder, resolved to absolute paths at install** (kills the empty-PATH trap):
  `spawn-agent` if on `$PATH` (opportunistic — never bundled, never required), else the
  requested harness (`claude -p` / `codex exec`). Recorded in the spec so `status` shows
  what a job actually executes.
- **User scope only**: `~/Library/LaunchAgents` + user crontab. No sudo/daemon scope — a
  LaunchDaemon can't reach the user keychain, so daemon scope would break harness auth.
- **Permissions: explicit flag, no default.** `tick` passes only what `--harness-args`
  provides; prose makes the installing agent confirm a stance (allowlist/sandbox/bypass)
  with the user before installing — an unattended run can't answer prompts.
- **Locking**: launchd labels are single-instance; the cron path wraps `tick` in
  `flock -n` where `flock` exists (Linux). systemd user timers (`Persistent=true`)
  documented in prose as the Linux missed-tick-coalescing alternative.
- **Prose carries the judgment layer**: TCC/FDA caveat (a stable binary identity like
  spawn-agent survives harness updates; a bare `claude` grant does not), the unattended-
  permissions stance, the local-scheduler vs cloud-routines boundary (this skill's niche is
  "runs against this machine's state"), timezone confirmation, offer-to-schedule triggers.

## Tasks

1. ~~Read the source skill and inventory what ports~~ (done 2026-08-13: SKILL.md prose +
   HEARTBEAT.md preamble port; CARD.md/INDEX machinery does not — `list`/`status` replace it;
   spawn-agent stays private, ladder covers it).
2. **`skills/scheduler/SKILL.md`** — utility-tier; frontmatter self-routing (cron, launchd,
   background task, daemon keywords); prose = judgment layer above + quick reference +
   `.scheduler/` layout + triage (logs, `.last` stamp, `run`).
3. **`skills/scheduler/HEARTBEAT.md`** — bundled default preamble (non-interactive notice,
   complete-and-exit, `HEARTBEAT_OK` convention), overridden by `.scheduler/HEARTBEAT.md`.
4. **`scripts/schedule.sh`** — the facts script: `install` / `uninstall` / `list` /
   `status [name]` / `run <name>` / `tick <name>` (internal) / `convert "<cron>"` (the
   cron→launchd conversion exposed for direct testing). Env-overridable seams for fixtures:
   state home, LaunchAgents dir, `launchctl`, `crontab`, platform (`uname`). Validation
   refusals: bad name, wrong cron field count, payload not-exactly-one, unknown harness,
   non-numeric weekday.
5. **Tests** — `scripts/tests/schedule-test.sh` + own `lib.sh` (journal harness pattern;
   patient-zero: mktemp fixture home + stub `crontab`/`launchctl`/fake harness bin, never
   the real LaunchAgents/crontab). Round-trip install/uninstall/list/status/run on BOTH
   platform paths (uname override); tick assembles preamble+payload, reads prompt-file
   fresh, records exit codes; reinstall replaces not duplicates; refusals refuse. The
   cron↔launchd conversion **proven by breaking on the weekday-numbering trap specifically**
   (cron 0=Sun → launchd 7; `1-5` unchanged; roadmap exit). shellcheck/bash -n clean.
6. **PACK.md** — add `scheduler` to the manifest `optional:` line and flip the transition
   note from "new port pending" to landed.

## Exit (roadmap)

Install/uninstall/list/status round-trips on a fixture; the cron↔launchd conversion proven by
breaking (weekday trap); lints green. Consider back-porting `schedule.sh` to thinklab
(human's call, outside this stream).

## Decisions (settled by human, 2026-08-13 — do not re-ask)

- **Strict ladder** — no bundled spawn-agent stub; prefer it opportunistically when on
  `$PATH`, degrade to `claude -p` / `codex exec`.
- **User-scoped only** — LaunchAgents + user crontab; no sudo/daemon scope (keychain).
- **State home `.scheduler/`** — project-scoped, self-gitignoring; `HEARTBEAT.md` the one
  committable piece. (`.records/` rejected: typed committed schema vs churny local state.)
- **Permissions: explicit flag, no default** — nothing silently elevated; prose mandates
  confirming a stance before install.
