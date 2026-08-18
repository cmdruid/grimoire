# ③ TUI v0.1 — Phase 3 implementation plan: TUI skeleton + library screen

**Status:** ARGUED 2026-08-18 — ready to build. Phase 3 of
`docs/design/2026-08-15-tui-v0.1-roadmap.md` (requires Phase 2, shipped `e49acbc`). Predecessor
plan: `docs/design/2026-08-18-tui-phase2-implementation.md`. The draft's five open questions are
settled below with their arguments; task detail follows.

## Goal

Workflow (a) shippable: browse the library and install/remove visually, through a real TUI, with a
dogfood install of a skill and a pack from this clone.

## What Phase 2 handed over

`grimoire-core` is **synchronous, clockless, and homeless** — amended into the roadmap's
*Cross-cutting foundations*:

| Need | Call |
|---|---|
| the agent set | `agents::table(&AgentEnv::from_process())` — the binary's one env read |
| a destination | `Target::global(&agent, home)` / `Target::project(&agent, project_root, home)` |
| browse | `Library::open(root).enumerate()` → `LibraryView { packs, loose, issues }` |
| preview an install | `install::preflight(&lib, pack, &target)` → `InstallPlan` (pure data, render it) |
| install | `install::install(InstallRequest { .., installed_at: Timestamp, source_ref })` |
| what's here | `inventory::inventory(&target)` |
| drift | `check::check(&lib, &target)` → `CheckReport` |
| remove | `remove::plan_remove` → render → `remove::remove` |

Three consequences for the render path:

1. **The TUI owns all concurrency.** Core ops block. Long ones (`enumerate`, `check`, `install` —
   each hashes member trees) must not run on the render thread.
2. **The binary supplies what core refuses to invent** — the clock, the git ref for `source_ref`,
   and XDG's `config_home`.
3. **Preflight-as-data is the interaction model.** `InstallPlan.members` carries a
   `MemberDisposition` per member, and `Collision` carries `adoptable`. Spec §5 forbids resolving a
   collision *silently* — the confirm screen is where that is honored.

**Enumeration is not free, and not cached.** `Library::enumerate()` runs two full tree walks
(`discover_with` + `enumerate_with`), and `resolve_pack` calls `enumerate()` internally — so
`preflight` and `install` each re-walk the library. The app therefore holds **one `LibraryView` in
state** and treats re-enumeration as an explicit refresh event; it never calls `enumerate()` to
answer a render question.

## Decisions settled (2026-08-18)

### D1 — one `AppEnv`, resolved once, is the sole constructor of `Target`

Core takes `home` as a parameter while `AgentEnv::from_process()` reads its own; nothing structural
stops the app from passing a *different* `home` to `Target::global` than the agent table resolved
against, which would silently misclassify scope (`scope_for(skills_dir, home)`).

The app gets one `AppEnv`, built once at startup, owning the `AgentEnv` plus the other three
ambient facts core refuses to invent (`config_home`, the clock, the library's git ref). It exposes
`env.global_target(&agent)` / `env.project_target(&agent, root)`; `Target::` is named nowhere else
in the app. The two homes cannot disagree because there is only one.

Enforced, not remembered: an app-side test in the shape of `grimoire-core`'s `tests/boundary.rs`
asserts that `std::env`, `Target::global`, and `Target::project` appear only in `env.rs`.

### D2 — the library screen renders one picked scope

Spec §3: an operation targets **exactly one scope**. §3 also *permits* a display-only fall-through
(project shadows global per pack name), and `inventory()` deliberately does not implement it — its
own doc records why: folding it in makes "which scope am I looking at?" unanswerable.

v0.1 follows core. The scope picker (agent × global/project) is always visible, and the screen shows
library content plus that one target's installed state. A merged/provenance view is Phase 4's
project screen, where "what is installed where" is the actual subject.

### D3 — collisions render and stop

§5 permits interactive **adopt**/**replace** but forbids silent resolution. Offering it in v0.1
would need two things core does not have: a per-member decision on `InstallRequest`, and §5's
**staging** ("replaced content is staged, not destroyed", with rollback restoring it). Core
implements no staging at all — `rollback()` only unlinks what the run created. That is a second
Phase-2-sized transaction change, not a screen.

So: the confirm screen renders each collision — where the existing link points, and its `adoptable`
bit — and aborts, naming the user's options (remove the conflicting link, or pick another scope).
`install()` already returns `CoreError::Preflight(n)`; no core change. Adopt/replace is recorded in
*Deferred* with its real prerequisite.

### D4 — close the §5 reinstall gap in core, in this phase

`install()` overwrites an existing lock entry, and `ReplacePlan` *computes* `dropped`, but nothing
unlinks those members: they stay on disk, vanish from the lock, and resurface later as loose links.
§5 says "members no longer listed are removed (subject to the reference count)."

Reinstall is reachable from the library screen the moment it exists, so this phase is what makes the
gap live. It is also what makes the ambient check's *moved since install* finding actionable — §5
says "offer re-pin or reinstall", which needs a reinstall that is correct. Closed as Task 2a.

### D5 — the project lock moves to the project root; the implementation was wrong

Spec §3: "**Project:** `<project-root>/grimoire.lock`". The implementation returns
`target.parent()` — for `/proj/.claude/skills` that is `/proj/.claude/grimoire.lock`, matching
`install.sh:143` (`dirname "$target"`). `lock.rs`'s own doc comment asserts both at once ("beside
the target dir, at the project root"), which are the same place only when the target is a direct
child of the root.

The spec wins, on two grounds:

- **Symmetry.** Global scope already shares **one** lock across all four agent dirs
  (`~/.agents/grimoire.lock`, whichever dir received the links —
  `target::tests::global_installs_share_the_one_agents_lock`). Project scope splitting per agent dir
  is the odd one out.
- **Correctness.** §5 reference-counts "in the same scope". A project using both `.claude/skills`
  and `.agents/skills` gets two locks today, so a member shared across them refcounts against
  nothing — remove one pack and the other's member is unlinked out from under it.

**The fix is lexical and needs no new parameter.** `install.sh` knows only `--target <skills-dir>`
— it has no project-root concept — so the rule must be derivable from the target alone, and is:

> project root = if the target's parent is a recognized agent dir (`.agents` / `.claude` /
> `.codex` / `.cursor`), the grandparent; otherwise the parent.

`AGENT_DIRS` is already in `lock.rs` beside `lock_path`. Cases: `/proj/.claude/skills` → `/proj`;
`/proj/.agents/skills` → `/proj` (both agent dirs now share one lock — the point); a non-agent-shaped
`--target /x/skills` → `/x`, unchanged from today. `lock_path(target, home)` keeps its signature and
`Target` keeps both constructors.

No migration burden: v0.1 has not shipped, and the only lock in the wild is the user's stray
`~/.claude/grimoire.lock` from a pre-fix global-scope bug, already noted as theirs to delete.

## Progress

- [x] **Task 1** — spike + worker seam + terminal custody (`915850c`). Two failure modes found
      and closed; both proven by breaking. **Finding: no async runtime is needed** — see the
      note under Task 1. The app crate skeleton came with it, so Task 3 is now `AppEnv` + flags
      only. *Visual half outstanding: a human must run `examples/spike.rs`.*
- [x] **Task 2** — core corrections 2a + 2b (`6711103`). Four checks proven by breaking.
      **Finding: `install.sh` had no executable coverage** — `parity.rs` asserted core matched
      the shell without ever running it, so 2b would have left one rule with two
      implementations and one untested. It now runs the shell.
- [ ] Tasks 3–8.

## Tasks

**Task 1 — the spike: ratatui + event loop, verified visually in isolation.** ✅ `915850c`.

**Transport decided: one worker thread, two `std::sync::mpsc` channels, a 50ms `event::poll`
timeout — and no async runtime.** Core is synchronous, the UI is modal (one pack installs at a
time), so at most one operation is ever in flight; `tokio::spawn_blocking` would be the same
thread with a runtime attached. **This contradicts the roadmap's surviving line "the TUI still
runs ratatui over a tokio event loop"** — a leftover from the pre-Phase-2 async posture, whose
stated rationale (`skill`'s async surface) that same amendment already removed. Flagged for the
owner as a dependency-policy call, per the `skill` precedent.

Two failure modes found and closed, in `src/worker.rs` and `src/ui.rs`:

- **A panicking job must not take the worker with it.** `catch_unwind` turns it into an ordinary
  `Outcome::Panicked` event and the worker accepts the next job.
- **`catch_unwind` does not suppress the panic *hook*.** `ratatui::init` installs a hook that
  restores the terminal, so a *caught* worker panic would still have left raw mode and the
  alternate screen — a live render loop drawing into the user's normal shell. `ui::init` replaces
  it with a thread-aware hook that restores only for the thread owning the terminal.

Proven by breaking: removing `catch_unwind` fails `tests/worker.rs`; removing the thread guard
fails `tests/panic_hook.rs`. The visual claim — does it *stay responsive* — is what
`examples/spike.rs` is for, and needs a human at a terminal.

**Task 2 — core corrections.** Independent of Task 1; ordered second only because the spike carries
the risk. Both land as one gate-green commit.

- **2a — honor `ReplacePlan.dropped` (D4).** In `install()`, capture the previous entry *before*
  `lock_data.packs.insert` overwrites it. **After** the lock write succeeds (§5's commit point),
  unlink each dropped member that is (i) referenced by no other pack entry in the new lock state and
  (ii) owned by us per `remove::owned_by` — make that helper `pub(crate)`. Unlinking before the
  write would require staging to roll back, which D3 declines to build; a crash between write and
  unlink leaves loose links that `inventory()` already reports — strictly better than today, where
  that is the guaranteed outcome. Add `dropped: Vec<String>` to `InstallOutcome` so the result screen
  reports the removal rather than doing it silently.
  **Prove by breaking:** disable the unlink loop → the dropped-member test must go red; disable the
  refcount guard → a test where a second installed pack still references the dropped member must go
  red (the link must survive).
- **2b — project lock at the project root (D5).** Change `lock_path`'s `Scope::Project` arm to the
  lexical rule above; fix `lock.rs`'s contradictory doc comment; mirror it in `install.sh`'s
  `write_lock`; update `Target`'s project tests and `tests/parity.rs`.
  **Prove by breaking:** revert the arm → a test asserting `.claude/skills` and `.agents/skills` in
  one project resolve to the *same* lock path must go red.
  *Shared surface:* `install.sh` is flagged in the hand-off as cross-stream — re-check siblings at
  ship time (neither `feat` nor `grok` owns it today).

**Task 3 — app crate skeleton + `AppEnv` (D1).** `crates/grimoire/`, package `skill-grimoire`,
`[[bin]] name = "grimoire"` (settled at ②; crates.io `grimoire` is taken). Flags only:
`--version`, `--library <path>`, `--project <dir>`. `AppEnv` supplies:
- **the clock** — `time` with an exact `format_description!("[year]-[month]-[day]T[hour]:[minute]:[second]Z")`.
  **Not** `Rfc3339`: `OffsetDateTime::now_utc()` carries nanoseconds and `Rfc3339` emits them, which
  `Timestamp::parse` rejects outright (it accepts exactly the 20-byte shape `install.sh` writes).
  The exact format description makes that unrepresentable rather than a first-install runtime error.
- **`source_ref`** — `git -C <library> rev-parse --short HEAD`, matching `install.sh:146`; a
  non-git library simply yields `None` (the field is optional).
- **`config_home`** — XDG, passed to `config::load`.

**Task 4 — app state + the core seam.** One owned state struct; ops dispatched to the worker;
results applied as events. Holds the single `LibraryView` (see above) and the selected `Target`.
This is where a `grimoire-core` shortcoming surfaces first — capture anything found, do not patch
around it silently.

**Task 5 — library screen.** Packs with member rosters (face marked; required vs optional), loose
skills, the scope picker (agent × global/project, with `detected()` shown), and confirm-then-act with
progress and failure states. The confirm screen renders `InstallPlan` — including `ReplacePlan` on a
reinstall and D3's collision rendering.

**Task 6 — ambient check on launch.** `check::check` surfaced as status, per the brainstorm's binding
decision. Facts, not verdicts: `Finding`s render as they are, `OptionalMemberAbsent` included and
never as drift.

**Task 7 — themed verb labels.** `learn`/`install`, `forget`/`remove`, `peruse`/`list`, plain
aliases in help. Machine-facing vocabulary stays plain.

**Task 8 — `TestBackend` smoke tests + the dogfood run.**

## Phase gate

- [ ] ratatui `TestBackend` smoke tests green.
- [ ] A real dogfood install of **a skill and a pack** from this clone through the TUI.
- [ ] Workspace suite + clippy `-D warnings` green.
- [ ] **The root-checkout run** (this stream's standing rule) — Task 2b changes lock-path resolution
      and `install.sh`, both repo-scanning surface, so
      `GRIMOIRE_LIVE_ROOT=/Users/cscott/Repos/grimoire cargo test -p grimoire-core --test live_repo`
      before any land.
- [ ] No regression in `grimoire-core`'s boundary tests (the app may depend on tokio; core may not),
      plus the new app-side `AppEnv` boundary test (D1).
- [ ] Task 2's two prove-by-breaking pairs demonstrated red before being fixed green.

## Deferred (explicit out-list)

- **Adopt/replace collision resolution** — needs §5 staging in core (replaced content staged and
  restorable on rollback), which does not exist. Post-v0.1, and a phase of its own.
- **Merged global+project view with provenance** — Phase 4's project screen (D2).
- The project screen, config editing UI, and everything the brainstorm excluded (remote sources,
  search, CLI verbs, authoring, file-watching).

## Risks

- **Event-loop ↔ render-loop integration** — the reason Task 1 is a spike verified in isolation
  rather than assumed.
- **A blocking core op stalling the UI** — `enumerate`/`check`/`install` all hash member trees; the
  single-`LibraryView`-in-state rule plus worker dispatch is the mitigation, and the spike proves it.
- **Task 2b touches the parity oracle.** `install.sh` is the reference implementation and
  `tests/parity.rs` pins it; changing both sides in one commit is deliberate, and the
  prove-by-breaking pair is what keeps them honest.
- **Scope creep at the screen layer** — the *Deferred* list is binding.
