# `create <stream> [<plan-or-brief>]`  · runs on the root checkout

_Read `flow.md` alongside this verb — `create` ends by entering the loop it governs._

> **GUARD — from inside a workstream you may SEED a second stream, never DRIVE one.** Before anything
> else, check: **are you already driving a workstream this session?** You are if an active
> `WORKSTREAM.md` / Coordinates block is loaded in your context (you arrived via a prior `/workstream
> load`/`create` and have been looping), or if `git -C "$(pwd)" rev-parse --show-toplevel` resolves
> under `.workstreams/`. This is a deterministic check — run it every time. If you are **not** inside a
> workstream (a fresh coordinator session on the trunk — no hand-off loaded, cwd at the root), plain
> `create` proceeds normally. If you **are** inside one, split by **what you were asked to do**:
>
> - **Plain `create` (create-and-drive) → STOP.** `create` ends by *entering the loop*, and driving a
>   second stream from this context splits your loop; standing up a stream to drive is the
>   **coordinator's** job (root-resident), not yours. This holds **even if the human asks you directly**
>   to "also" run the stream here. Instead **capture** the work (`/backlog bug` or `/backlog task`) or
>   **surface** it at a seam. Read the "all work is a workstream" doctrine correctly: it means *the
>   coordinator gives each body of work its own stream*, **not** *you spawn-and-drive one mid-loop*. And
>   needing **isolation** for a *sub-task of your own feature* is not a new workstream either — that is a
>   delegate's own worktree via `/delegate` (read-only, merged back), not a second stream.
> - **`create --seed-only`, on an explicit human request to stand a stream up for a SEPARATE session →
>   proceed.** This is the one sanctioned exception: the human has explicitly asked you to seed a
>   *different* stream that **they** will drive in another session. You run the mechanical seed and
>   **STOP before the loop** (see *Seed-only mode* below), handing back the `/workstream load` command.
>   You seed; you never drive it. This fires **only** on that explicit, in-band request — it is **never
>   inferred**, never a response to your own mid-loop tangent, and **never available in an
>   unattended/autonomous loop** (no human is present to make the request). Absent an explicit
>   `--seed-only` request, treat any surfaced second stream as the *Plain create* case above.
>
> (See SKILL.md *Scope*.)

1. Parse `<stream>` into a stream name (a single kebab segment, e.g. `items-interface`, `player`,
   `world`, or any feature slug). Branch is `stream/<stream>`; worktree is `<root>/.workstreams/<stream>`.
   A `--in-place` flag anywhere in the arguments selects **in-place isolation** (no worktree — see
   *In-place mode* below); without it, isolation is `worktree` (this file's default path).
2. **Capture the integration target.** `target = $(git -C <root> branch --show-current)` — the branch
   the stream is based on AND ships into, recorded in Coordinates and fixed for the stream's life.
   **Never hardcode `main`:** whatever trunk is checked out (today `main`, later `dev`) becomes the
   target. **Work-branch guard:** if `target` is empty (detached HEAD) or matches a work-branch shape
   (`stream/*`, `feature/*`), STOP and ask the user which branch is the intended trunk — a work
   branch is almost never the integration target (this is the W3 accident mode).
3. **Source resolution** *(referenced by `recycle.md` — keep this label)*: resolve the second
   argument into a **mode** (the queue's source is pluggable — the skill is generic, not tied to any
   one artifact). Record the resolved kind as Coordinates **`source-kind`**
   (`plan` | `roadmap` | `brief` | `template`) — `recycle` reads it:
   - **omitted** -> *unplanned* (a spike/exploration; the goal/queue is defined in the first iteration).
     `source-kind: brief`.
   - **a bare template name** (`debug`, `design`) or **a path to a file whose frontmatter
     declares `kind: workstream-template`** -> *template/intake* (`source-kind: template`): a durable,
     instance-agnostic template. A **bare name** is resolved from the skill's OWN `templates/` base
     directory (never a host path -- resolve it the same way as `workstream-git.sh`, from this skill's
     own base dir); a bare name with no matching bundled template -> STOP and ask. (The bundled
     `templates/coordinator.md` is **not** a create/recycle template — it is read directly on the
     trunk by the coordinator session.) A **path** points to
     a project's `kind: workstream-template` doc (detect the marker by reading the file's leading
     `---`..`---` frontmatter; absent the marker, fall through to the plan-bound case). Record
     Coordinates `source:` as the resolved template name or path; `source-kind: template`.
     There is **no predefined queue** -- each unit is independent; the template's durable doctrine is
     **embedded** into the hand-off (step 6), and the stream advances by **`recycle`**, not a queue.
   - **any other existing file or doc-section** (resolves to a file, a path ending `.md`, or a
     `<doc>#<anchor>` pointer) -> *plan-bound* (`source-kind: plan`, or `roadmap` for a roadmap
     section): the queue is that plan's phases, or that section's forward list. This covers both a
     standalone `plans/`-store plan AND a section of an ongoing roadmap (a stream/track heading whose
     forward list is the queue).
   - **anything else** (multi-word, or a non-file token) -> *free-text brief* for the first feature
     (`source-kind: brief`).
   If a single-token argument is genuinely ambiguous, ask the user which they meant rather than guessing.
4. **Preflight the host, then branch + worktree.** Two first-run checks (both no-ops on a host
   that has streamed before):
   - **`.workstreams/` must be ignored in the root**, or the root immediately shows
     `?? .workstreams/` and stream creation turns into an unplanned root commit later. Run
     `git -C <root> check-ignore -q .workstreams/`: succeeds → covered. Fails → **propose** adding
     `.workstreams/` to the host's tracked `.gitignore` (attended: on OK, stage + commit in one
     pathspec-scoped call per the root-contention rules; a markdown-adjacent one-liner — the host's
     fast doc gate suffices) or, if the host prefers untracked config, append it to
     `<root>/.git/info/exclude`. Record which path was taken in the hand-off's *Pointers*.
     Unattended → use `info/exclude` (no root commit without a human) and record it.
   - **Submodule-heavy host?** If `<root>/.gitmodules` exists, surface the choice BEFORE
     `worktree add`: a linked worktree shares **no** submodule checkouts (every top-level submodule
     starts empty, and host gates that read into them fail until a submodule init clones them all
     into the stream), so `--in-place` is usually the better isolation here — ask, don't default in.
   Then branch + worktree from the **target ref** (a ref, so a dirty/off-target root can't corrupt
   the base):
   `git -C <root> worktree add -b stream/<stream> <root>/.workstreams/<stream> <target>`.
5. **Seed the plan on the branch** (plan-bound, *new untracked plan file* only; `create` makes no root
   commit). If the source is an already-tracked doc, skip. If it's a new untracked plan file, move it
   into the worktree under `<agent-records>/plans/` on every host (ensure it carries the
   front-matter contract: `records.sh new plans --template <resolved>` + fill if the tool
   exists; else file-mode fill from the resolved `plans.md`, naming the file
   `YYYY-MM-DD-<slug>.md` — an undated filename is not a record). Run the host's doc-linter from
   the worktree, then commit it **on the stream branch** (it rides to `<target>` at first
   ship): `git -C <worktree> add <plans-home>/<basename> &&
   git -C <worktree> commit -m "Seed stream/<stream>: plan" -- <plans-home>/<basename>`.
   Brief / unplanned mode: nothing to seed. Template mode: nothing to seed on the branch either — the template
   is an external tracked doc; its durable doctrine is **embedded** into the hand-off in step 6 (and
   re-embedded by `recycle`), and only its **name or path** is recorded in Coordinates `source:`.
6. **Hand-off instantiation** *(the template-mode part is re-applied in place by `recycle.md` — keep
   these labels)*: write the hand-off into the worktree, then exclude it locally:
   - Copy this skill's bundled `templates/workstream-handoff.md` (resolve it from the skill's own
     base directory — never a host-project path, so it works wherever the skill is installed) to
     `<root>/.workstreams/<stream>/WORKSTREAM.md` and fill it in:
     - Coordinates: ABSOLUTE worktree path, absolute root path, branch, **`integration-target: <target>`**;
       `source:` is the plan path or roadmap-section pointer (plan-bound), the **template name or path**
       (template mode), or `(none — brief only)`; **`source-kind:`** is the kind resolved in step 3
       (`plan`/`roadmap`/`brief`/`template`). (`source-kind: template` = a bundled template name OR a
       `kind: workstream-template` doc path.)
     - "Stream / queue" section: the roadmap-section queue (plan-bound on a roadmap), a pointer to the plan
       (plan-file mode), or the verbatim brief (brief mode). **Sweep a transcribed queue for staleness
       at authoring time:** when the queue's items were transcribed from tracker/backlog entries (a
       roadmap seeded from a Backlog sweep), grep EACH item's key symbols/files against the done trail
       (`records.sh history` / `git log` / the project's done records) **before** recording it — stale
       tracker entries seed already-shipped queue items (observed 4× across two phases of one
       roadmap), and the launch-time "verify the front item" check only ever catches them one wasted
       unit later. **Template mode:** there is no queue — write the
       no-queue/`recycle`-between-units note, and **embed the template's durable sections** (mission, governing
       principle, toolbox, hard-won lessons, the template's own user/conventions block) into the hand-off body
       so the instance is self-contained; the per-unit sections (TL;DR, Queue state, What's been done)
       start blank.
     - **`<debrief>`:** run the *Host layout* probe (does
       `<agent-workspace>/doctrine/README.md`, by default `.dev/doctrine/README.md`,
       carry `Seeded from clankshop`?). Stamp present → write `/backlog debrief`.
       Absent → write `the project's own close-the-books sweep (do not invoke /backlog)`.
       Recycle re-applies this fill (it re-runs this step).
     Do NOT commit it; do NOT seed it on the root.
   - Make it ignored from inside the worktree — **idempotently** — by running this skill's bundled
     `scripts/worktree-exclude.sh <root>/.workstreams/<stream>` (resolve `scripts/` from the skill's
     own base directory, not the host project) (for a
     linked worktree `--git-path info/exclude` resolves to the **shared** common-dir exclude, so one
     line covers every stream forever; the script's grep guard makes re-runs a no-op — a blind `>>`
     would accrete a duplicate per create, ISSUES W12).
     (Without the line `WORKSTREAM.md` shows as untracked inside the worktree and blocks a clean
     `git worktree remove`.)
   - **Ensure the front-door recovery anchor — idempotently.** (The workstream **instance** of
     `/checkpoint`'s recovery-anchor convention — an installer verb with a genuine install moment
     may automate its own instance; the generic convention stays human-installed.) Check the
     host's always-loaded front-door doc (`AGENTS.md`, or `CLAUDE.md` where that is the host's
     front-door):
     `grep -q '^## Workstream compaction recovery' <root>/AGENTS.md` → present, no-op (the normal
     case after the first stream). Absent → **propose** appending this skill's bundled
     `templates/compaction-anchor.md` (resolve from the skill's own base directory, never a host
     path) to the front-door and, on the human's OK, commit it under the root-contention rules
     (stage + commit in one call, explicit pathspec): `git -C <root> add AGENTS.md && git -C <root>
     commit -m "Register workstream compaction-recovery anchor" -- AGENTS.md`. The block is generic
     convention text — one registration serves every stream forever (worktrees inherit it from the
     branch; in-place streams read it from the root). **Unattended or `--seed-only` create** → do
     not commit to the root: skip, and record `anchor: unregistered` in the hand-off's *Pointers /
     open questions* so the next attended session proposes it. (Why it matters: the front-door is
     re-injected every request in both harnesses, so this block survives compaction by construction
     — it is what points a compacted session back to the hand-off; `flow.md` -> *Scenario C*.)
   - **Build the Cheat sheet** (the template's `## Cheat sheet` section) — a durable orientation map so
     a resuming or small-context agent navigates this domain without re-exploring (the exploration
     `/blueprint brainstorm`/`spec` would otherwise re-derive into context that each reset destroys).
     Dispatch a few **read-only** Explore subagents (allowed: `create` runs on the root checkout, and
     the read-only bar forbids *editing* in a worktree, not reading) to map the domain the plan/brief
     targets, then fill the four pointer blocks from what they find — the key host source files +
     entry points (the host's `AGENTS.md` repo-map names the layout), the governing decision/design
     docs, the exercising tests + scenario files, and the domain's
     gotchas-doc traps + memory invariants. Keep it **pointer-only** (paths/IDs,
     never pasted code — pointers rot gracefully) and set `built-against:` to
     `git -C <worktree> rev-parse --short HEAD`. Scale the sweep to the plan's size; an unplanned/brief
     stream with no target yet gets a one-line stub ("built in the first iteration"). **Template mode:** the
     template already carries a durable orientation-pointers section — lift those into the cheat sheet rather
     than running a fresh Explore sweep, then set `built-against:` to the current HEAD.
   - **Pre-confirm the execution mode** (`delegate` | `manual`; see `flow.md` *Execution mode*).
     `create` runs
     with the human present, so propose and confirm now: **default `delegate`** (autonomous-safe,
     today's behavior) — or `manual` if the human wants to drive each phase on a model-optimized
     session. Record it in Coordinates **`mode:`**. **Unattended create** → record `delegate` (manual
     can't run without a human to swap models). **Template/intake streams** (`source-kind: template`) → record
     `delegate` (manual's PLAN/BUILD/SHIP split is shaped for feature cycles, not a template unit). The mode
     selects the **primary model lever** confirmed next: `delegate` → the delegation route; `manual` →
     the phase model map. (A `manual` stream still *records* a delegation route, but only for **fan-out**
     — default `inline-only`; its model lever is the phase map, not delegation.)
   - **Pre-confirm the delegation route** (so the autonomous loop delegates without per-dispatch friction,
     and the per-feature tally is interpretable). Defer to `/delegate`'s route-confirmation — **don't
     reimplement it here**: run its confirm-the-route step (self-check the checkable, propose a route
     with the concrete available models **or `inline-only`** if there's no cheaper tier / no sub-agent
     capability, get the human's OK). The per-phase model map is `/delegate`'s to define, not this file's. `create` runs on the root checkout **with the human present**,
     so **confirm it now** (the human owns the unobservable cost/quota; one touch pays off across the whole
     loop). Record the result in the hand-off's **`Delegation route`** section: the per-phase route +
     fallback policy, or `inline-only` (a *deliberate* `0` tally, not a firing failure). **Unattended
     create** (no human to confirm) → record `unconfirmed — defaults to inline until confirmed` (distinct
     from `inline-only`) so a later session re-confirms and a `0` tally isn't misread. (In `manual` mode
     record the route as `inline-only` unless you specifically want **fan-out** delegation — the model
     lever there is the phase model map below, not the route.)
   - **Pre-confirm the phase model map** (`manual` mode only — skip in `delegate`). Propose the default
     — **PLAN → strong, BUILD → mid, SHIP → strong** — naming the concrete models the harness offers
     (e.g. plan: a strong tier, build: a mid tier, ship: a strong tier), confirm or edit, and record it
     in the hand-off's
     **`Phase model map`** section. The swap is a manual `/model` action, so any phase's model stays
     overridable on the fly — the map is the reminder default each phase-boundary park instruction cites.
     **Bootstrap the first phase:** set Queue-state `Phase: plan` (PLAN authors the plan) — or
     `Phase: build` if the stream was seeded from an *existing* plan (step 5: the plan artifact already
     exists, so the first feature skips PLAN). The first phase runs **in-place in the create session**,
     so tell the human to align `/model` to that phase's model before it starts; only *subsequent* phases
     get a park's swap instruction.
   - **Pre-confirm the ship cadence** (so the autonomous loop lands deliberately, not per-feature by
     reflex — `ship` is expensive; see `flow.md` *Ship cadence*). Like the delegation route, this is
     set with the human present at `create`: **propose `milestone`** — the default: land at the track
     end + at critical milestones the agent nominates — and confirm, or take `per-track` / `per-stage`
     if the user prefers each-feature-at-once or each-feature-promptly. Record the result in the
     hand-off's **`Ship cadence`** section. **Unattended create** (no human) → record the default
     `milestone`. **Template/intake streams** (`source-kind: template`) are inherently per-unit — record
     `per-stage` and don't propose milestone batching (there is no feature queue to accumulate).
7. **Surface the recorded `integration-target`** in the create summary (so it's visible/correctable),
   then run the **Confident launch** (`flow.md`) — the same KNOWN/AMBIGUOUS interaction `load` uses,
   not a bespoke menu. Plan-bound with a clear first feature -> KNOWN (confirm it). Unplanned/brief
   with a real fork -> AMBIGUOUS (pick). A baseline-verify is the agent's own autonomous first step,
   not a user option.
8. `cd <root>/.workstreams/<stream>` (UX only), then enter the first iteration in-place: run the
   hand-off's START HERE verification, then proceed per the launch.

## Seed-only mode (`--seed-only`)

`--seed-only` produces a ready-to-drive stream **without entering its loop** — the sanctioned way an
in-workstream session stands one up on the human's explicit behalf (see the GUARD and SKILL.md
*Scope*). It is create's mechanics minus the drive:

1. Run **steps 1–6 unchanged** (parse, capture target, source resolution, worktree add, seed plan on
   the branch, hand-off instantiation — including the Cheat sheet Explore sweep, which is read-only and
   root-checkout-safe from anywhere). Because step 5 commits the seed plan **on the branch** and
   `create` makes **no root commit**, seed-only adds **zero** root-index contention — it is safe to run
   concurrently with the coordinator or a sibling stream.
2. For the **pre-confirm sub-steps** of step 6 (execution mode, delegation route, phase model map, ship
   cadence), take the **unattended-create path** — record `delegate` / `unconfirmed — defaults to inline
   until confirmed` / `milestone` — and let the **driving session confirm them at first `load`**. You
   are not the driver; the driver owns those choices with full attention. Do not run the confirm
   interview here — the human's attention is on the stream you *are* driving.
3. **Skip steps 7–8.** Do **not** run the Confident launch and do **not** `cd`/enter the first
   iteration. Instead print the recorded `integration-target` and the exact resume command for the
   human's separate session — **`/workstream load <stream>`** — then return to your own stream's loop.

One session drives one stream is unchanged: seed-only never `load`s or drives the seeded stream from
this session.

## In-place mode (`--in-place`)

`--in-place` runs the stream **in the main checkout** — no worktree; the branch is checked out in
the one shared tree, which the stream then holds (**custody**, `verbs/park.md`) until `park` or
`close`. For repos where worktrees are impractical (disk/RAM; submodule-heavy monorepos —
`worktree add` shares no submodule checkouts). Same steps as above, with these substitutions:

- **Guards (before anything):** the GUARD at the top applies unchanged (including seed-only). Two
  additional deterministic checks:
  - **One resident stream:** run `workstream-git.sh inplace-scan <root>`; if `inplace_streams=` is
    not `none`, STOP — the tree is singular; a second in-place stream cannot hold it.
  - **Clean tree:** worktree create branches from a *ref*, so a dirty root cannot corrupt the base —
    but `git switch -c` carries working-tree dirt onto the new branch. If `git -C <root> status
    --porcelain` is non-empty, STOP and report; the human decides whether the dirt belongs to the
    new stream.
- **Step 4 (branch):** `git -C <root> switch -c stream/<stream>` — from the trunk's current HEAD
  (capture `target` first, step 2, work-branch guard included). No `worktree add`.
- **Step 5 (seed plan):** unchanged — it already commits on the branch; `<worktree>` = `<root>`.
- **Step 6 (hand-off):** write to `<root>/.workstreams/<stream>/WORKSTREAM.md` (`mkdir -p` the
  directory — it contains no checkout, only the hand-off). **Ensure the hand-off is ignored:** if
  `git -C <root> check-ignore -q .workstreams/` succeeds, nothing to do (the host ignores the
  directory). If it fails, run this skill's bundled `scripts/worktree-exclude.sh <root>` — on the
  root checkout `--git-path info/exclude` resolves to `.git/info/exclude`, so the `WORKSTREAM.md`
  basename pattern hides the hand-off locally without touching the host's tracked `.gitignore`.
  Either way the hand-off must never show as untracked in the root — `park`'s `add -A` would
  otherwise sweep it into the `wip:` commit. Coordinates record
  `worktree:` = the ROOT path, `isolation: in-place`; Queue state records `Parked: false`.
- **Landing-mode pre-confirm** (new, alongside mode/route/cadence): propose and confirm
  **`landing:`** — `local` (default; `ship` stops after the local trunk advance) | `push` (`ship`
  also pushes `<target>` to the remote) | `pr` (`ship` pushes the branch and opens a PR instead of
  advancing locally). Unattended create → record `local`. (Worktree streams record `landing: local`
  implicitly — today's behavior.)
- **Steps 7–8:** unchanged, minus the `cd` — the session is already in the tree.
- **`--seed-only --in-place`:** run the seed as above, then hand the tree back — `git -C <root>
  switch <target>` — set `Parked: true`, and return `/workstream load <stream>` for the driving
  session (whose `load` unparks). The seed-only GUARD conditions apply unchanged.
