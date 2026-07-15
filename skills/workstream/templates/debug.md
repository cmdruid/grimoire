---
kind: workstream-template
---

# Debug workstream -- template

_A reusable template for a `debug` workstream: live debug-harness dogfooding + visual/behavior bug
intake on the running app. **Durable and instance-agnostic by design** -- it holds the timeless debug
knowledge (mission, tools, the loop, lessons, conventions, doc pointers). The LIVE per-instance state
-- what's shipped, sync status, streams in flight, cheat-sheet line numbers, coordinates -- belongs in
the worktree's `WORKSTREAM.md`, NOT here. Tracked (version-controlled); edit this to evolve how every
debug workstream starts._

## How to use this template
- **Create a new debug workstream:**
  `/workstream create debug`
  -> seeds a worktree + a `WORKSTREAM.md` whose brief + cheat sheet come from this template;
  `create` adds the generic scaffolding (Coordinates, START HERE, loop routine).
- **Refresh an existing debug workstream:** re-apply the durable sections below into the worktree's
  `WORKSTREAM.md`, **preserving its Coordinates + live state** (shipped list, sync status, streams in
  flight). The template is the source of truth for the durable parts; the WORKSTREAM is the
  materialized instance.
- **Keep the split clean:** anything that changes per session (a SHA, a "just touched" file, what
  shipped) goes in the WORKSTREAM instance. Anything timeless (how a tool works, a lesson) goes here.

## Mission
Dogfood the running app: **observe via the live debug harness, diagnose bugs -- especially the
VISUAL/behavior class that passes unit tests + state JSON -- and fix them**, while sharpening the debug
tooling as friction surfaces. Two intertwined tracks, each a `ship`-able unit:
- **Track A -- visual/behavior bug fixes** (driven by what the user shows live).
- **Track B -- harness + tooling improvements** (friction found while dogfooding A). Route harness
  FEATURE ideas to their own stream; only a small fix that unblocks the debug loop belongs here.

## The golden rule (why this stream exists)
The bugs here pass the unit tests and the state JSON and only show up **on screen** or **over time**.
So **pick the oracle that isolates the variable** -- a single screenshot is the weakest one:
- **Temporal/continuity oracle** for motion bugs (sample the field/state across time, assert no
  rewind/snap) -- a frame can't see it.
- **A/B test** for behavior bugs -- vary ONE variable across vantages, read the state.
- **Data dump (no GPU)** when the data may be fine but rendering looks broken.

## Starting a debug session
1. **Diagnose before patching.** Reach for a structured debugging discipline before proposing a fix --
   understand the failure mode first.
2. **Launch the app + harness:**
   `<project: command to launch the app with the debug harness -- see host AGENTS.md>`
3. **Connect to the harness endpoint.** FRICTION: a mid-session attach does NOT hot-attach -- reconnect
   after any restart. `connection refused` => app not running with harness enabled / wrong port /
   startup failed before the plugin loaded.
4. **Work the loop** (`<project: diagnostics workflow doc -- see host AGENTS.md>`):
   observe -> reproduce -> isolate -> fix -> land:
   - **Observe (cheapest first):** stderr warnings/errors; in-app diagnostics overlays; no-GPU data dump.
   - **Reproduce:** pin the repro into a test scenario -> screenshot + state JSON in a known output dir.
     The scenario IS the repro -- attach it to any bug report.
   - **Isolate:** use the render inspector / isolated sandbox to render one subject and surface
     swallowed errors. A controlled scene (deterministic, bounded world) isolates visual/HUD/physics
     against a clean backdrop.
   - **Fix** under a test-driven discipline; **land** per *Where fixes land*.

## The toolbox (durable reference -> depth in the docs)
Full harness guide + debug playbook: `<project: debug tooling docs -- see host AGENTS.md>`.
- **Read tools:** live state snapshot (pose, environment, entity state), screenshot, recent events,
  bookmark list/get/export, debug bundle export, tool catalog.
- **Guarded actions:** destructive actions require a confirmation token before executing. Undo support
  for key actions (teleport, state mutations).
- **A/B rig (deterministic):** acquire control -> drive the subject (set pose, hold/release inputs,
  wait ticks) -> release control. Absolute pose set is preferred to set up a viewpoint / vary one
  variable. Replay bookmark input traces.
- **In-app diagnostic keys:** `<project: in-app diagnostic/control keys -- see host AGENTS.md>`
- **Scenario runner (E2E/repro):** run a scripted scenario headless (unattended, no focus steal);
  state JSON in output dir is the dependable headless signal. Use a fast build for throwaway
  iteration; keep the FINAL verifying run on the standard build.
  `<project: scenario runner command -- see host AGENTS.md>`
- **Render inspector / dump:** render one subject in isolation -> PNG + JSON sidecar; text data dump
  with no GPU window.
  `<project: render inspector / dump command -- see host AGENTS.md>`

## Hard-won lessons (durable)
- **Temporal/visual bugs need a temporal oracle, not one frame.** Motion bugs pass every static check;
  prove them with a continuity test that samples state over time.
- **Behavior bugs: logic unit test PLUS a live harness A/B.** Vary one variable across vantages, read
  state at each -- the A/B IS the proof.
- **Asset-root trap:** run debug/scenario/harness commands via the build tool wrapper, never the bare
  compiled binary -- else assets fail to load and meshes render invisibly.
- `<project: additional hard-won lessons -- see host dev/MEMORY.md and the host gotchas doc>`

## Where fixes land
- **Trivial one-liner** (no design) -> directly on the integration trunk (Coordinates `integration-target`), pathspec-scoped
  (`<project: pathspec-scoped commit command -- see host AGENTS.md>`), after the full gate + a
  relevant scenario. Root index is contended -- never `git add -A`.
- **A real fix needing isolation** -> in the debug workstream: build it, run the debrief sweep,
  `/workstream ship`. **`/workstream sync` first** (the stream usually trails the trunk).
- **A bug that grows into a multi-phase track** -> spin it into its OWN `/workstream`. Don't carry
  a feature in this intake stream.
- **Capture-don't-lose:** file defects to the bug tracker; feature follow-ups to the backlog; dev-tool
  friction to the issues tracker; qualitative notes to feedback. A flaky/transient bug -> capture
  seed + scenario + log + screenshot and file it so the repro survives.
  `<project: capture commands -- see host AGENTS.md dev workflow section>`

## Durable orientation pointers (NO line numbers -- they drift; re-verify per instance)
- **Debug tooling docs:** `<project: debug harness guide, diagnostics playbook, gotchas doc,
  observability design doc -- see host AGENTS.md>`
- **Harness module:** `<project: harness module location + key exported functions -- see host AGENTS.md repo-map>`
- **Visual-bug surface:** `<project: rendering/mesh/material/entity/overlay source modules -- see host AGENTS.md repo-map>`
- **Change router + front door:** `<project: dev workflow doc, front-door AGENTS.md, dev index -- see host AGENTS.md>`
- **Stream status:** `/workstream status` (check before starting new work).

## The user (honor these)
`<project: user name, git handle, collaboration style -- read the host "The user" section if present>`
On every fork question, elaborate each option with a **recommendation up front**, unprompted.
Discipline: pathspec-scoped root commits, docs-only commits skip the build gate, alpha = leave zero
tech debt.
