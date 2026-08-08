# `/foreman` (route) — classify a change and dispatch it

The default verb: with no argument (or a change description), `/foreman` is the **change router**.
It reads the installation's deployed routing chapter — `.handbook/rules/ROUTING.md` — as the
source of truth (it does **not** restate the classification walk) and dispatches the change to the
lane that owns it.

The deployed front door carries a **tier-0 routing table compiled from that walk** — it decides
the common cases at zero extra reads, dispatching straight to a lane. `route` is the **slow path
behind the table**: invoked from its *unsure / mixed altitude* row (or when no table is stamped
yet), never a mandatory hop in front of it.

**On an unstamped root** (no installation block), foreman is **read-only**: emit `unstamped`,
point at the clankshop onramps (`setup` / `migrate`), and stop — foreman no longer stands systems
up, and `/foreman init` does not exist.

## Procedure

1. **Classify** the change — bug / patch / feature / spike / **seed-altitude design** — by
   `.handbook/rules/ROUTING.md`'s walk, plus the altitude discriminator below for the design case.
2. **Apply the promotion bar at dispatch** (the escalation layer,
   `.handbook/rules/RECORDS.md`): if resolving the change would require standing in for the human
   — a *decision*, *sign-off*, *ambiguity*, or *access* trigger — hand off to `/backlog promote`
   (or a direct ticket) **before** the work starts; the lane proceeds when the ticket resolves.
3. **Route**, dispatching to the lane's entry point (each lane file's by-hand walk is the co-equal
   fallback when its skill isn't installed):
   - **bug** (`.handbook/workflows/bug.md`) → file it first (`/backlog bug`), then `/debugger`
     root-causes it — from the filed report, or directly from a live symptom.
   - **patch** (`.handbook/workflows/patch.md`) → land on the trunk by hand (the inline lane; no
     skill).
   - **feature** (`.handbook/workflows/feature.md`) → the lane's tier decision → `/feature`
     (brainstorm | design | plan | build), built in a `/workstream` when it needs isolation.
   - **spike** (`.handbook/workflows/spike.md`) → timeboxed, by hand; capture the learnings.
   - **foundational / seed-altitude design change** (a tenet, a system contract, a seam — not a
     feature to build) → `/architect brainstorm` (then `/architect plan` to sequence the rollout).
     See the altitude discriminator below.
   - **capture / complete / escalate a follow-up** → the records instrument (`/backlog` — capture
     by kind, `done`, tickets); **finished a body of work** → `/backlog debrief`.
   - **code-quality** → `/auditor`; **docs-quality** → `/chiropractor`; **context snapshot** →
     `/handoff`.
4. Where a lane's skill isn't installed, follow the lane file's by-hand walk. `/foreman` owns the
   routing *policy*; the lanes and companion skills own the *operations*.

## Rulebook stewardship (the other half of this verb's ownership)

Foreman **tends the rulebook**: the `.handbook/rules/` and `.handbook/workflows/` chapters, and
the front door's compiled table. When the classification walk changes, **recompile the tier-0
table in the same commit** (the walk is the source; the table is its projection — clankshop
`check` flags drift between them). Routing decisions that set precedent are logged to
`.records/logs/` (typed, one line per routed change where the call was non-obvious). Chapter
content changes are ordinary trunk-side scoped commits.

## Altitude discriminator (feature vs architect)

The seam is **altitude**, not docs-vs-code: `/feature` mutates **code** (a change built against
the seed); `/architect` mutates **the seed itself** (the foundation code is later regenerated
from). *Changing the foundation → `/architect`. Building on it → `/feature`.* Route to the
architect whenever the change asks "should this tenet/contract/seam even be this way," not "how
do I build the next thing on top of it." Without this check the router silently sends
foundational work down the incremental feature lane.

## Done when

The change is classified per the deployed walk, the promotion bar was applied at dispatch, and
the change is dispatched to the right lane/skill (or the lane's by-hand walk named) — with the
table recompiled in the same commit if the walk itself changed.
