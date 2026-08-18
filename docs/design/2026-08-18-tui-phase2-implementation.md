# ③ TUI v0.1 — Phase 2 implementation plan: `grimoire-core` (operations, no UI)

**Status:** draft (2026-08-18). Phase 2 of `docs/design/2026-08-15-tui-v0.1-roadmap.md`
(sequencing 1→2→3→4; blocks Phase 3's TUI). Built on the `app` workstream branch.
Spec: `docs/spec/pack-format.md` (draft 5, format 1). Predecessor:
`docs/design/2026-08-15-tui-phase1-implementation.md` (shipped — `Scope`/`lock_path`/`Ignore`
are the surface this phase consumes).

## Goal

Every v0.1 operation callable, and integration-tested, from plain async Rust: open a local
library, model scopes and agents, install/remove atoms and packs with `install.sh`'s symlink
semantics and the spec's transaction, list what is installed, and check for drift — with no
rendering, no TTY assumption, and no UI crate anywhere in the dependency tree.

## Grounded findings (2026-08-18, read against the pinned reading clone)

The roadmap flagged one Phase 2 risk as "`skill` 0.8.3 API friction at the wrapping seam."
Read against the source, it is sharper than friction — it decides the crate's shape, so it is
recorded here before any task.

**`skill::SkillManager::install_skill` cannot implement this repo's install.** For a local
source it *copies* the tree, and the copy is the canonical content:

| Evidence (`repos/skill-rs/skill/src/…`) | Consequence for us |
|---|---|
| `installer/install.rs:103-141` — symlink mode does `clean_and_create(canonical_dir)` → `writer.write(canonical)` → symlink *agent dir → canonical* | The canonical dir is a **copy**, not the library. Edits in the clone stop being live — the dogfood property `install.sh` exists to preserve ("the clone stays canonical, edits here are live immediately", `install.sh:16`) |
| `installer/fs.rs:69-90` — `copy_directory` **dereferences** symlinks while copying | A library tree that is itself symlinked (this machine's `~/.agents/skills` → clone) materializes as detached bytes |
| `installer/install.rs:115` — `clean_and_create` wipes the destination first | Collisions resolve by **silent destruction**; spec §5 requires resolution that "MUST NOT be silent" and replaced content "staged, not destroyed" |
| `agents/builtin.rs:26-74` — `Env` is private and captured from the **process** environment at registry build | Global agent dirs cannot be redirected per-call; hermetic tests cannot use `AgentRegistry::with_defaults()` |
| `installer/*` never calls `lock.rs`/`local_lock.rs` | Upstream's installer maintains **no** ecosystem lock; lock upkeep is `skills-cli`-side. Nothing is lost by owning the link step |

This confirms rather than contradicts the binding docs: the umbrella already specifies
"install choreography **reassembled from `skill`'s public pieces**"
(`docs/design/2026-08-07-grimoire-repurpose-design.md` §4), and the roadmap repeats it. So:

> **`grimoire-core` owns the link/transaction layer; `skill` supplies the agent model.**
> We depend on `skill` `=0.8.3` for the one thing it has and we cannot faithfully reproduce —
> the curated registry of ~30 agents' skills-dir layouts plus async detection
> (`AgentRegistry`, `detect_installed`, `AgentConfig`) — and we link members ourselves,
> `install.sh`-style, into the target scope's skills dir.

Every roadmap decision survives intact: `skill` stays pinned and in the tree, its async
surface still justifies tokio, `skill` types still never cross our public API (they are
confined to `agents.rs`), and `install.sh` parity — the property Phase 4's gate depends on
("a full dogfood session replacing `install.sh` for machine installs") — is preserved.

**Reference semantics we are porting** (`install.sh:197-275`, spec §5): preflight the whole
member set (missing member; collision = a non-symlink at the destination, or a symlink whose
**physically resolved** target differs from the source — `install.sh:210-221`); link every
member; roll back this run's links on any link failure; commit the lock last. Remove deletes
only links that point **into the library** (`install.sh:253-262`), refcounted at pack altitude
(spec §5).

## Global constraints (re-verified at HEAD, not inherited)

- **No spec change, no `install.sh` change.** This phase implements §3/§5/§7 in Rust; the shell
  reference implementation stays the parity oracle, untouched.
- **The hard seam rule stands:** the crate never reads `skills/` at build time. Library content
  appears only as throwaway fixture trees built by the test harness.
- **`skill` types never cross the public API.** `skill::{AgentConfig, AgentId, AgentRegistry}`
  appear **only** inside `src/agents.rs`; everything public is our own domain type. This is what
  keeps the documented vendor/fork escape hatch real.
- **Clockless and homeless, like `grimoire-pack`.** The crate never calls `now()`, never reads
  `$HOME`, and never reads the process environment: `home`, `installed_at`, and the agent set
  are **parameters**. This is the only way the integration tests are hermetic, and it matches
  the stance Phase 1 already set (`scope_for(target, home)`).
- **`grimoire-pack` is blocking; core is async.** Its walks are recursive `std::fs`. Every call
  into it from an async fn goes through `tokio::task::spawn_blocking` — never inline in the
  event loop (Phase 3 renders while these run).
- **No UI crate in the dependency tree.** Enforced by a test, not by intention (Task 12).
- **Reuse `grimoire_pack::lock::Scope`** — do not mint a third scope enum (the crate already
  owns §3's; `skill::InstallScope` is upstream's and stays inside `agents.rs`, unused since we
  do not call their installer).
- **Ecosystem per-skill locks are not written** (`skills-lock.json`, `~/.agents/.skill-lock.json`).
  Spec §3 makes them "the untouched per-skill authority"; `install.sh` writes neither; upstream's
  installer writes neither. Deliberate deferral, recorded — not an oversight.
- **A partially-linked pack must never mint a lock entry.** Spec §3: "A pack's lock state is one
  bit." The lock write is the commit point and happens after every link succeeds.

## Task 1 — crate skeleton, error type, dependency floor

`crates/grimoire-core/` joins the workspace by the existing `members = ["crates/*"]` glob (no
root manifest edit).

```toml
[package]
name = "grimoire-core"
version = "0.1.0"
edition = "2021"
description = "grimoire operations: library model, scopes, agents, pack install/remove/check — no UI"
license = "MIT OR Apache-2.0"

[dependencies]
grimoire-pack = { path = "../grimoire-pack" }
skill = "=0.8.3"                                    # agent registry + detection ONLY (see findings)
semver = "1"                                        # `Manifest.version` is `semver::Version` —
                                                    # naming it in our own API needs the dep
tokio = { version = "1", features = ["fs", "process", "rt", "macros"] }
time = { version = "0.3", features = ["formatting", "parsing"] }
thiserror = "1"

[dev-dependencies]
tempfile = "3"
tokio = { version = "1", features = ["rt-multi-thread", "macros"] }
```

```rust
// src/lib.rs
pub mod agents;
pub mod check;
pub mod config;
pub mod install;
pub mod inventory;
pub mod library;
pub mod remove;
pub mod target;

#[derive(Debug, thiserror::Error)]
pub enum CoreError {
    #[error("io error at {path}: {source}")]
    Io { path: PathBuf, #[source] source: std::io::Error },
    #[error("pack error: {0}")]
    Pack(#[from] grimoire_pack::PackError),
    #[error("agent backend error: {0}")]      // skill's error, stringified at the seam —
    Agent(String),                            // never re-exported as a type
    #[error("no pack named {0} in this library")]
    UnknownPack(String),
    #[error("preflight failed: {0} blocking finding(s)")]
    Preflight(usize),
    #[error("lock is read-only: {0}")]        // spec §3: version > 1, or unparseable
    LockReadOnly(String),
}

pub type Result<T> = std::result::Result<T, CoreError>;
```

**Verify:** `cargo build -p grimoire-core` green; `cargo tree -p grimoire-core | grep -Ei
'ratatui|crossterm|termion' ` empty (Task 12 pins this as a test).

## Task 2 — `Target`: the scope/agent-resolved destination

`src/target.rs`. A `Target` is "where an operation happens": one scope, one agent's skills dir,
one lock path. Pure — construction does no I/O.

```rust
pub use grimoire_pack::lock::Scope;   // §3's two scopes; do not redefine

/// One resolved install destination: an agent's skills dir at a scope, plus
/// the §3 lock that governs it. Pure and lexical — `home` is a parameter.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Target {
    pub agent: crate::agents::Agent,
    pub scope: Scope,
    /// Where member links are created: the agent's skills dir at this scope.
    pub skills_dir: PathBuf,
    /// Where `grimoire.lock` lives for this destination (spec §3).
    pub lock_path: PathBuf,
}

impl Target {
    /// Global: the agent's own global skills dir (None ⇒ unsupported for this agent).
    pub fn global(agent: &Agent, home: &Path) -> Option<Self>;
    /// Project: `<project>/<agent.project_skills_dir>` (e.g. `.claude/skills`).
    pub fn project(agent: &Agent, project_root: &Path, home: &Path) -> Self;
}
```

Both constructors derive `lock_path` through `grimoire_pack::lock::lock_path(&skills_dir, home)`
— Phase 1's helper is the single §3 authority, and routing every scope decision through it is
what keeps core and `install.sh` from drifting.

**Tests** (`mod tests`, red-first):

```rust
#[test]
fn global_target_locks_in_the_shared_agents_lock() {
    let home = Path::new("/home/u");
    let agent = Agent::fixture("claude", "/home/u/.claude/skills", ".claude/skills");
    let t = Target::global(&agent, home).unwrap();
    assert_eq!(t.scope, Scope::Global);
    assert_eq!(t.lock_path, Path::new("/home/u/.agents/grimoire.lock"));
}

#[test]
fn project_target_locks_beside_the_agent_dir() {
    let home = Path::new("/home/u");
    let agent = Agent::fixture("claude", "/home/u/.claude/skills", ".claude/skills");
    let t = Target::project(&agent, Path::new("/work/proj"), home);
    assert_eq!(t.scope, Scope::Project);
    assert_eq!(t.skills_dir, Path::new("/work/proj/.claude/skills"));
    assert_eq!(t.lock_path, Path::new("/work/proj/.claude/grimoire.lock"));
}

#[test]
fn a_project_under_home_is_still_project_scope() {
    // the §3 rule is "under a recognized agent dir in HOME", not "under HOME"
    let home = Path::new("/home/u");
    let agent = Agent::fixture("claude", "/home/u/.claude/skills", ".claude/skills");
    let t = Target::project(&agent, &home.join("work/proj"), home);
    assert_eq!(t.scope, Scope::Project);
}
```

**Verify:** `cargo test -p grimoire-core target::` green (red first).

## Task 3 — `Agent` / `Agents`: the model, with `skill` confined

`src/agents.rs`. The **only** module that names a `skill` type.

```rust
/// One agent harness, as this crate models it. Owns no `skill` types.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Agent {
    pub id: String,               // "claude", "codex", …
    pub display_name: String,
    /// Project-relative skills dir, e.g. `.claude/skills`.
    pub project_skills_dir: PathBuf,
    /// Absolute global skills dir; `None` ⇒ this agent has no global scope.
    pub global_skills_dir: Option<PathBuf>,
    /// Probed at detection time; `false` for a fixture agent.
    pub detected: bool,
}

/// The agent set an operation runs against.
#[derive(Debug, Clone, Default)]
pub struct Agents(Vec<Agent>);

impl Agents {
    /// PRODUCTION path: upstream's curated registry + async detection.
    /// The one place `skill` is touched; resolves against the PROCESS
    /// environment (upstream's `Env` is private), so tests never call it.
    pub async fn detect() -> Result<Self> { /* AgentRegistry::with_defaults() → map → Agent */ }

    /// TEST/injection path: an explicit set, e.g. rooted in a temp dir.
    pub fn from_agents(agents: Vec<Agent>) -> Self;

    pub fn detected(&self) -> impl Iterator<Item = &Agent>;
    pub fn get(&self, id: &str) -> Option<&Agent>;
}

impl Agent {
    /// Injection constructor for tests and callers that know their layout.
    /// Plain `pub`, NOT `#[cfg(test)]`: the integration tests in `tests/` are a
    /// separate crate, where a `cfg(test)` item does not exist.
    pub fn fixture(id: &str, global: impl Into<PathBuf>, project: impl Into<PathBuf>) -> Self;
}
```

`detect()` maps `AgentConfig { name, display_name, skills_dir, global_skills_dir, detect_paths }`
→ `Agent`, marking `detected` from `AgentRegistry::detect_installed().await`. `skill`'s error
is stringified into `CoreError::Agent` at this boundary.

**Test:** a mapping test over a hand-built `skill::AgentConfig` (its fields are public), asserting
`detected=false` and exact path carry-over. Detection against the real environment is **not**
asserted (it is the machine's, not ours) — an `#[ignore]`d smoke test records that `detect()`
returns a non-empty set on a developer machine.

**Verify:** `cargo test -p grimoire-core agents::` green; `grep -rn "skill::" src/ | grep -v
"^src/agents.rs"` empty — the seam, proven mechanically.

## Task 4 — `Library`: the local source

`src/library.rs`. Wraps `grimoire-pack` enumeration behind `spawn_blocking`, with the ignore
rules Phase 1 built.

```rust
/// A local library clone: this repo, or any Vercel-format skills tree.
#[derive(Debug, Clone)]
pub struct Library { root: PathBuf, ignore: grimoire_pack::discovery::Ignore }

/// A pack as the app renders it: manifest facts + the resolved member set.
/// Members are FLAT and their pack-dependence is opaque (brainstorm, binding).
#[derive(Debug, Clone)]
pub struct LibraryPack {
    pub name: String,
    pub version: semver::Version,
    pub description: String,
    pub faced: bool,
    pub dir: PathBuf,
    pub members: Vec<Member>,     // face first (implicit member), then required, then optional
}

#[derive(Debug, Clone)]
pub struct Member { pub name: String, pub dir: PathBuf, pub required: bool, pub is_face: bool }

impl Library {
    /// Default ignore rules: the built-in floor plus this repo's own fixture
    /// and vendor trees, so a grimoire clone enumerates its real content.
    pub fn open(root: impl Into<PathBuf>) -> Self;
    pub fn with_ignore(root: impl Into<PathBuf>, ignore: Ignore) -> Self;

    pub async fn packs(&self) -> Result<Vec<LibraryPack>>;       // + issues, see below
    pub async fn loose_skills(&self) -> Result<Vec<Member>>;     // discovered skills in no pack
    pub async fn enumerate(&self) -> Result<LibraryView>;        // packs + loose + issues, one walk
    pub fn resolve_pack(&self, name: &str) -> ...                // by manifest `name:`, not dir
}
```

Member resolution mirrors `install.sh:88-111` exactly: the face is an **implicit** member and its
`SKILL.md` `name:` MUST equal the pack's `name:`; `required` and `optional` are both installed by
default; a **faceless** pack resolves its members but is flagged — §3 requires caching the
manifest into the lock for a faceless install, which Task 6 handles (unlike `install.sh`, which
refuses).

`LibraryView` carries `issues: Vec<String>` (rendered from `grimoire_pack::pack::Issue`, whose
`PackError` is not `Clone` — a recorded Phase 1 limit; core renders to strings rather than
re-exporting a non-`Clone` type into app state Phase 3 will want to clone).

**Tests:** hermetic, against a fixture library built by the harness (Task 11): a faced pack with
one required + one optional member and one loose skill enumerates as 1 pack / 3 members / 1 loose;
face-name ≠ pack-name is an issue, not a pack; an ignored subtree contributes nothing.

**Verify:** `cargo test -p grimoire-core library::` green (red first).

## Task 5 — install preflight: the plan, computed without touching disk state

`src/install.rs`, part 1. Preflight is pure inspection returning **data** — the TUI (Phase 3)
renders it and asks for confirmation; nothing mutates yet.

```rust
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MemberDisposition {
    /// Nothing at the destination — link it.
    Fresh,
    /// A symlink already resolving to this exact source (physical compare) — no-op.
    AlreadyInstalled,
    /// Destination occupied by something else. Blocking by default (spec §5:
    /// resolution MUST NOT be silent); the face is never adoptable.
    Collision { at: PathBuf, points_to: Option<PathBuf>, adoptable: bool },
    /// The member does not exist in the library.
    Missing,
}

#[derive(Debug, Clone)]
pub struct InstallPlan {
    pub pack: String,
    pub target: Target,
    pub members: Vec<(Member, MemberDisposition)>,
    /// Present ⇒ this is a reinstall/upgrade of an existing lock entry (§5).
    pub replacing: Option<ReplacePlan>,
}

impl InstallPlan {
    pub fn blocking(&self) -> impl Iterator<Item = &(Member, MemberDisposition)>;
    pub fn is_installable(&self) -> bool;   // no Missing, no un-resolved Collision
}

pub async fn preflight(lib: &Library, pack: &str, target: &Target) -> Result<InstallPlan>;
```

The collision predicate is `install.sh:210-221`'s, ported: `symlink_metadata` says symlink →
compare `canonicalize(link)` against `canonicalize(source)`; equal ⇒ `AlreadyInstalled`
(a chain through an intermediate symlink is the same install, not a collision); unequal ⇒
`Collision`. Anything else existing ⇒ `Collision { points_to: None }`. Spec §5's hash-based
predicate is the *scope-wide* rule; at v0.1 the destination-level check above is what
`install.sh` enforces and what the dogfood loop needs — the hash comparison enters `check`
(Task 9), and the gap is recorded in *Deferred* below.

`ReplacePlan` covers §5's reinstall/upgrade: members added by the new release, members dropped
(subject to Task 8's refcount), version moving **backward** or `source` changing — each surfaced
as a fact the caller must see, never silent.

**Tests:** fresh tree ⇒ all `Fresh`; pre-linked member ⇒ `AlreadyInstalled`; a regular directory
at the destination ⇒ blocking `Collision`; a symlink to a *different* source ⇒ blocking
`Collision`; a link reached through an intermediate symlink ⇒ `AlreadyInstalled`, not a collision.

**Verify:** `cargo test -p grimoire-core install::preflight` green (red first).

## Task 6 — install execute: the transaction

`src/install.rs`, part 2. Spec §5's four steps, with the rollback discipline.

```rust
/// The caller supplies the clock (the crate is clockless, like grimoire-pack)
/// and the git ref when it knows one.
pub struct InstallRequest<'a> {
    pub library: &'a Library,
    pub pack: &'a str,
    pub target: &'a Target,
    pub installed_at: time::OffsetDateTime,
    pub source_ref: Option<String>,
    /// Optional members the user deselected (§5: an optional member absent
    /// from the lock stays uninstalled).
    pub skip_optional: Vec<String>,
}

pub struct InstallOutcome {
    pub linked: Vec<(String, PathBuf)>,
    pub already_present: Vec<String>,
    /// §5 step 4: the face to point the user at. We surface it; we never execute it.
    pub face: Option<PathBuf>,
}

pub async fn install(req: InstallRequest<'_>) -> Result<InstallOutcome>;
```

Sequence, aborting into rollback at any failure before the lock write:

1. `preflight` → if `!is_installable()`, `Err(CoreError::Preflight(n))` with **no** filesystem
   change (`install.sh:223-226`'s "no partial install").
2. `create_dir_all(target.skills_dir)`, then link each non-`AlreadyInstalled` member
   (`tokio::fs::symlink`), pushing every link created onto a `created: Vec<PathBuf>`.
   Any link error ⇒ remove exactly `created` (this run's links only — never a pre-existing one)
   and return the error. (`tokio::fs::symlink` is unix-only upstream; v0.1 targets unix, as does
   the bash reference implementation. Windows is out of scope, not overlooked.)
3. Read the lock via `grimoire_pack::lock::read` (`Ok(None)` ⇒ fresh `Lock::default()`).
   A lock with `version > 1` or unparseable ⇒ **`CoreError::LockReadOnly`, after rolling back
   the links** — spec §3 forbids rewriting it, and a linked-but-unlocked pack is exactly the
   "silently plausible partial pack" §5 tells tools to avoid.
4. Insert one `PackEntry { version, source: library root, r#ref, installed_at, skills, manifest }`
   — `skills` keyed by member name, each `SkillEntry { hash: member_hash(dir), required }` where
   `required` is the classification **at install time** (§3), and `manifest` populated **only for
   a faceless pack** (§3's caching requirement). Other packs' entries and unknown keys are
   preserved by construction (we mutate the read `Lock`, and `grimoire-pack`'s types carry
   `extra`). `grimoire_pack::lock::write` commits — the transaction's commit point.
5. Return the face path for the caller to surface (§5 step 4). **Never execute anything.**

Atom (single loose skill) install is the same machinery with a one-member set and **no** lock
entry — an atom is not a pack and `install.sh` locks nothing for it.

**Tests:** happy path (links land, lock entry matches the fixture's hashes, face returned);
`installed_at` round-trips as RFC3339; a lock at `version: 2` ⇒ `LockReadOnly` **and the tree is
unchanged** (the rollback is asserted, not assumed); a mid-flight link failure (destination made
unwritable, or a member removed between preflight and link) leaves zero new links and no lock
entry; a second install of the same pack is idempotent; installing a *second* pack preserves the
first's entry and any unknown top-level lock keys.

**Verify:** `cargo test -p grimoire-core install::` green (red first).

## Task 7 — inventory: what is installed here

`src/inventory.rs`. The read the library screen and the project screen both need.

```rust
pub struct InstalledPack { pub name: String, pub entry: PackEntry, pub dir_present: bool }
pub struct Inventory {
    pub packs: Vec<InstalledPack>,        // from the target scope's lock
    pub loose: Vec<InstalledMember>,      // links in skills_dir owned by no lock entry
}
pub async fn inventory(target: &Target) -> Result<Inventory>;
```

Reads the scope's lock plus the actual entries in `target.skills_dir` (a link is "ours" when it
resolves into a known library; unresolvable links are reported, not hidden). §3's read rule —
project shadows global per pack name — is applied by the **caller** composing two `Target`s;
`inventory` answers for exactly one scope, which is what §3's "every operation targets exactly
one scope" requires.

**Verify:** `cargo test -p grimoire-core inventory::` green.

## Task 8 — remove: refcounted at pack altitude

`src/remove.rs`. Spec §5's remove, plus `install.sh`'s ownership rule.

```rust
pub struct RemovePlan {
    pub pack: String,
    pub unlink: Vec<(String, PathBuf)>,          // unreferenced by any other pack in this scope
    pub retained: Vec<(String, String)>,         // (member, still required by pack X)
    pub foreign: Vec<(String, PathBuf)>,         // link points outside the library — never touched
    /// §5: setup artifacts may persist; relay the face's guidance BEFORE deleting.
    pub face_warning: Option<PathBuf>,
}

pub async fn plan_remove(target: &Target, pack: &str) -> Result<RemovePlan>;
pub async fn remove(target: &Target, plan: &RemovePlan) -> Result<()>;
pub async fn remove_optional_member(target: &Target, pack: &str, member: &str) -> Result<()>;
```

Refcount: a member is unlinked only when **no other pack entry in the same scope's lock** lists
it (§5's "reference counting at pack altitude"). `foreign` ports `install.sh:255-259` — a link
that does not point into a library is another tool's, and we skip it with a fact. Optional-member
removal drops the member entry and leaves no other trace (§5); the pack entry stays.

**Tests:** two packs sharing a member ⇒ removing one retains the member and keeps the other's
entry intact; removing the second unlinks it; a hand-placed foreign link is reported and left on
disk; optional-member removal leaves the pack installed with the member gone from the lock;
`face_warning` is populated before anything is deleted.

**Verify:** `cargo test -p grimoire-core remove::` green (red first).

## Task 9 — check: facts, not verdicts

`src/check.rs`. Spec §5's table verbatim, plus enumeration issues from Task 4.

```rust
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Finding {
    RequiredMemberMissing { pack: String, member: String },        // broken
    MemberMoved { pack: String, member: String, locked: String, actual: String },  // re-pin/reinstall
    OptionalMemberAbsent { pack: String, member: String },         // fine — never drift
    OrphanedPack { pack: String },                                 // installed manifest gone
    SharedMemberDisagreement { member: String, packs: Vec<String> },// §5 shared members
}
pub struct CheckReport { pub findings: Vec<Finding>, pub library_issues: Vec<String> }
pub async fn check(lib: &Library, target: &Target) -> Result<CheckReport>;
```

Local only — no network, no source (spec §5). Hashes recompute through
`grimoire_pack::hash::member_hash` (Appendix A) inside `spawn_blocking`. A faced pack consults the
**installed** `PACK.md`; a faceless pack consults the manifest cached in the lock (§3).

**Tests:** clean install ⇒ empty findings; delete a required member ⇒ `RequiredMemberMissing`;
edit a member's bytes ⇒ `MemberMoved` with both hashes; delete an optional member ⇒
`OptionalMemberAbsent` only; remove the pack dir ⇒ `OrphanedPack`; two packs locking different
hashes for one shared member ⇒ `SharedMemberDisagreement`.

**Verify:** `cargo test -p grimoire-core check::` green (red first).

## Task 10 — the tiny config

`src/config.rs`. One key in v0.1: the default library path.

```rust
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Config { pub library: Option<PathBuf> }

/// `<config_home>/grimoire/config.toml`. `config_home` is a PARAMETER
/// (the crate reads no environment); the binary passes XDG's.
pub fn config_path(config_home: &Path) -> PathBuf;
pub async fn load(config_home: &Path) -> Result<Config>;   // absent file ⇒ Config::default()
pub async fn save(config_home: &Path, cfg: &Config) -> Result<()>;
```

Format: TOML, hand-editable, unknown keys ignored (the format's own posture). Parsing is a
hand-rolled two-key reader rather than a new `toml` + `serde` dependency pair — v0.1 has exactly
one key, and the dependency policy is deliberate about weight. If a second structured key
appears, adopt `toml` then.

**Tests:** absent file ⇒ default; round-trip; unknown key preserved-and-ignored; a malformed file
is an error, not a panic.

**Verify:** `cargo test -p grimoire-core config::` green.

## Task 11 — the sandbox harness + both workflows end-to-end

`crates/grimoire-core/tests/`. This is the phase gate's evidence, so the harness comes with it.

`tests/sandbox.rs` (module shared by the integration tests) builds a throwaway world in one
`tempfile::TempDir`:

```
<tmp>/library/skills/{alpha/SKILL.md+PACK.md, beta/SKILL.md, gamma/SKILL.md, loose/SKILL.md}
<tmp>/home/{.agents/, .claude/skills/}          # a FAKE home — never the developer's
<tmp>/project/                                   # a fake project root
```

with `Agents::from_agents(vec![Agent::fixture("claude", "<tmp>/home/.claude/skills",
".claude/skills")])` — never `Agents::detect()`, which would resolve against the real machine.

- `tests/workflow_library.rs` — **workflow (a)**: enumerate → preflight → install a pack at
  **global** scope → inventory lists it → check is clean → remove → tree and lock return to their
  pre-install state.
- `tests/workflow_project.rs` — **workflow (b)**: the same at **project** scope, asserting the
  lock lands at `<project>/.claude/grimoire.lock` (§3) and that a global install of the same pack
  is untouched by the project remove (scope isolation — §3's "exactly one scope").
- `tests/parity.rs` — the install-shape parity assertions against `install.sh`'s semantics:
  every installed member is a **symlink** (not a copy) resolving into the library, so an edit to
  a library file is visible through the installed path. This is the dogfood property Phase 4's
  gate depends on; asserting it here is what stops a future refactor from quietly reintroducing
  copy semantics.

**Prove by breaking** (house rule — a check nobody has seen fail is not evidence): with the
refcount in Task 8 disabled, `workflow_*`'s shared-member assertion must go red; with the
rollback in Task 6 short-circuited, the mid-flight failure test must go red; with the collision
predicate weakened to a bare `exists()`, the intermediate-symlink case must go red. Record the
three observed failures in the ship's commit message, then restore.

**Verify:** `cargo test -p grimoire-core --tests` green; the three break-tests observed red then
restored.

## Task 12 — boundary tests, docs, roadmap status

- `tests/boundary.rs`: (a) no UI crate in the dependency tree — parse `cargo metadata` output and
  assert nothing named `ratatui`/`crossterm`/`termion` appears among `grimoire-core`'s transitive
  deps; (b) `skill` containment — assert no `src/*.rs` other than `agents.rs` mentions `skill::`.
  Both are the crate's architectural invariants, so they are tests, not comments.
- Module docs: `lib.rs` states the crate's contract (async, clockless, homeless, no UI, `skill`
  confined to `agents.rs`); `install.rs` names the spec sections it implements and the
  `install.sh` lines it ports.
- Flip Phase 2's roadmap entry to shipped with a one-paragraph summary, matching Phase 1's
  precedent (`docs/design/2026-08-15-tui-v0.1-roadmap.md:46-52`).

## Deferred (recorded, not forgotten)

- **Scope-wide hash collision predicate** (§5's "already installed in the target scope with
  different content"): v0.1 uses the destination-level predicate `install.sh` enforces. The
  scope-wide version needs an installed-content index; `check` (Task 9) already computes the
  hashes it would need, so this is a later composition, not new machinery.
- **Interactive adopt/replace** (§5): `MemberDisposition::Collision.adoptable` carries the flag,
  but v0.1 aborts rather than resolving — resolution is a TUI interaction (Phase 3+), and the
  spec only forbids doing it *silently*.
- **Ecosystem per-skill lock upkeep** — see Global constraints.
- **Remote sources, search, upgrade-from-source** — outside v0.1 by the brainstorm.

## Phase gate (the roadmap's Phase 2 exit criteria)

- [ ] Sandboxed integration tests cover **both** workflows end-to-end (discover → install → list
      → check → remove) against throwaway fixture trees, with a fake home — no test reads or
      writes the developer's real agent dirs.
- [ ] **No UI crate in `grimoire-core`'s dependency tree**, asserted by `tests/boundary.rs`.
- [ ] `skill` types confined to `agents.rs`, asserted by `tests/boundary.rs`.
- [ ] Workspace suite green and `cargo clippy --all-targets -- -D warnings` clean **from the repo
      root**, and — the standing rule of this stream, because this is repo-scanning code — the
      suite also run **in the root checkout** before the land, not only in the worktree.
- [ ] Phase 1's 48 tests green **unmodified** (this phase adds a crate; it changes none of
      `grimoire-pack`'s behavior).
- [ ] Three prove-by-breaking failures observed and recorded (Task 11).
- [ ] `install.sh` untouched, no spec edit in the diff, and
      `skills/skill-builder/scripts/skills-lint.sh` unchanged at `fails=0`.
