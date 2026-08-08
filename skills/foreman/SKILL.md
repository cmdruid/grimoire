---
name: foreman
description: "The change ROUTER and rulebook steward. `/foreman` (no arg, or a change description) classifies a bug/patch/feature/spike — or a seed-altitude design change — and dispatches it to the lane that owns it; the deployed routing chapter (`.handbook/rules/ROUTING.md`) is the source of truth, and foreman tends it: the rules/ and workflows/ chapters, the compiled routing table (recompiled on change), the run log, and the promotion bar at dispatch (escalation hands off to the records instrument). Operational improvement items arrive calibrator-routed and are applied here as ordinary rulebook work. Read-only on an unstamped root — the pack onramps stand systems up. Use when the user runs `/foreman ...` or asks where a change starts."
---

# foreman — the operations role: route the change, tend the rulebook

One skill, two halves of one ownership: the **change-router** (where any change starts — classify
it, apply the promotion bar, dispatch it to its lane) and **rulebook stewardship** (the deployed
`.handbook/rules/` + `.handbook/workflows/` chapters, the front door's compiled tier-0 table, and
the `.records/logs/` run log). Standing a system up is the pack onramps' job (`setup` /
`migrate` on the pack face); validating the assembly is the pack face's `check`; capturing and
completing follow-ups is the records instrument's.

This `SKILL.md` is a **thin router**: it dispatches and states the discipline every verb shares
**once**. Each verb's procedure lives in its own `verbs/<verb>.md`, **read on demand**. When a
verb is selected, **read `verbs/<verb>.md` and follow it**; do not reconstruct a procedure from
memory.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does | Trigger |
|---|---|---|---|
| `/foreman` *(no arg, or a change description)* | `verbs/route.md` | **Router** — classify a change, apply the promotion bar, dispatch to its lane; tend the walk + recompile the table on change | "where do I start?", "I'm about to change X" |

**Default (no recognized verb):** treat the argument as a change description and run
`verbs/route.md`. `/foreman init` does **not** exist; on an unstamped root every foreman verb is
**read-only** — emit `unstamped` and point at the clankshop onramps. Captured signal about the
rulebook reaches foreman as **calibrator-routed improvement items**, applied here as ordinary
chapter work — there is no separate drain verb.

## Shared discipline (every verb relies on this — stated here once)

- **Resolve root + real date.** Project-relative paths; resolve the root from a project dir the
  conversation references, else cwd, else ask. Get the date with `date +%Y-%m-%d` — never guess it.
- **Scripts compute facts; the verb prose decides.** The verb files (and this router) carry the
  *judgment* — how to classify a change, whether drift is real, how a routed improvement lands.
  The bundled scripts do only the deterministic, mechanical work: the **mutating
  mechanical helper** `scripts/scoped-commit.sh` (the atomic pathspec-scoped commit — it mutates
  by design, but only ever the paths it is handed). **Never push a decision into a script:** a
  script is stateless and can't see session context, so a *verdict* it emits is sometimes
  confidently wrong (worse than none), while a *fact* the prose reasons over is not.
- **Commit on the integration trunk, never a work branch.** A foreman write (a chapter edit, a
  table recompile) creates *shared* content, so it can't ride a feature ref — it lands on the
  **root checkout's current branch**, which must be the integration **trunk** (never hardcode its
  name). **Guard:** check `git -C <root> branch --show-current`; if it is empty (detached HEAD)
  or a work branch (`stream/*`, `feature/*`), STOP and tell the user to switch the root to its
  trunk — landing shared writes on a feature branch is the W3 failure.
- **Pathspec-atomic commit (the shared root index is contended).** The root index is shared with
  concurrent worktree streams, and `git commit` records the **entire** index — so a bare commit
  sweeps a sibling's staged files. **Always** stage *and* commit scoped to exactly the paths you
  wrote, in one step, via `scripts/scoped-commit.sh <root> "<msg>" <paths…>`. Never `git add -A`,
  never `commit -a`. Commits carry **no** `Co-Authored-By` trailer.

## Scope boundary

`/foreman` routes changes and tends the rulebook. It **routes, it does not execute**: capturing
follow-ups, auditing code, designing the seed, verifying, and the development itself each belong
to a **lane** `route` dispatches to — not to foreman. Standing up and validating the whole system
belongs to the pack face. *Which* member owns *what* is the pack's doctrine and runbook, not this
file.
