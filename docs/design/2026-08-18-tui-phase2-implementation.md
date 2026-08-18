# ③ TUI v0.1 — Phase 2 implementation plan: `grimoire-core` (operations, no UI)

**Status:** draft (2026-08-18, revision 2 — see *Revision note*). Phase 2 of
`docs/design/2026-08-15-tui-v0.1-roadmap.md` (sequencing 1→2→3→4; blocks Phase 3's TUI). Built on
the `app` workstream branch. Spec: `docs/spec/pack-format.md` (draft 5, format 1). Predecessor:
`docs/design/2026-08-15-tui-phase1-implementation.md` (shipped — `Scope`/`lock_path`/`Ignore` are
the surface this phase consumes).

## Goal

Every v0.1 operation callable, and integration-tested, from plain Rust: open a local library,
model scopes and agents, install/remove atoms and packs with `install.sh`'s symlink semantics and
the spec's transaction, list what is installed, and check for drift — with no rendering, no TTY
assumption, and no UI crate anywhere in the dependency tree.

## Revision note (what changed and why)

Revision 1 planned to depend on `skill` `=0.8.3` for its agent registry. Revision 2 **vendors a
four-target agent table and drops the dependency entirely**, on the owner's decision (2026-08-18)
after the grounding below. Two roadmap *Cross-cutting foundations* are amended as a consequence —
Task 13 records the amendment so the roadmap and this plan cannot disagree.

## Grounded findings (2026-08-18, read against the pinned reading clone)

### Finding 1 — `skill`'s installer cannot implement this repo's install

For a local source it *copies* the tree, and the copy becomes the canonical content:

| Evidence (`repos/skill-rs/skill/src/…`) | Consequence |
|---|---|
| `installer/install.rs:103-141` — symlink mode does `clean_and_create(canonical_dir)` → `writer.write(canonical)` → symlink *agent dir → canonical* | The canonical dir is a **copy**, not the library. Edits in the clone stop being live — the dogfood property `install.sh` exists to preserve (`install.sh:16`) |
| `installer/fs.rs:69-90` — `copy_directory` **dereferences** symlinks while copying | A library tree that is itself symlinked (this machine's `~/.agents/skills` → clone) materializes as detached bytes |
| `installer/install.rs:115` — `clean_and_create` wipes the destination first | Collisions resolve by **silent destruction**; spec §5 requires resolution that "MUST NOT be silent" and replaced content "staged, not destroyed" |
| `installer/*` never calls `lock.rs`/`local_lock.rs` | Upstream's installer maintains **no** ecosystem lock; that upkeep is `skills-cli`-side. Nothing is lost by owning the link step |

So the install choreography was always going to be ours — which is what the umbrella already
specified: "install choreography **reassembled from `skill`'s public pieces**"
(`docs/design/2026-08-07-grimoire-repurpose-design.md` §4).

### Finding 2 — the only piece left to import was an agent table, and it does not fit

After Finding 1, the sole remaining use for the dependency was `AgentRegistry` — 47 agents
(`agents/builtin.rs`, 529 lines) plus async detection. Three facts killed it:

- **A pin defeats the dependency's own value.** Upstream shipped `v0.4.4`→`v0.8.3` — five
  breaking-capable `0.x` minors — between 2026-03-13 and 2026-04-22, and has published nothing
  since (commits continue; last 2026-08-07). Pinned `=0.8.3`, the table freezes, which is the one
  thing we wanted from it; unpinned, we absorb `0.x` churn for a data structure. Authorship in the
  window our (shallow) reading clone holds is 55 of 68 commits by one author.
- **47 agents contradict our own spec.** Phase 1 shipped
  `grimoire_pack::lock::AGENT_DIRS = [".agents", ".claude", ".codex", ".cursor"]` as §3's
  global-scope classification. An install target under any of upstream's other 43 agents
  classifies as `Scope::Project`, putting the lock in the wrong place. Importing 47 rows would
  have created an incoherence *inside our own system*, surfacing somewhere around Task 6.
- **The dependency is not small.** Even with `default-features = false` (which drops only
  `reqwest`), `skill` carries 13 direct non-optional deps — `regex`, `serde_yml`, `sha2`, `url`,
  `urlencoding`, `tempfile`, `dirs`, `pathdiff`, `tracing`, `tokio`, … — to obtain a path table.

**Decision:** vendor the four targets §3 already recognizes, faithful to upstream's rows
(below), and depend on nothing. This is the roadmap's documented "vendor/fork fallback" exercised
early and cheaply rather than kept hypothetical. Should remote sources land post-v0.1, `skill`'s
git/GitHub/well-known providers become attractive again — that reintroduction stays a deliberate,
separate decision.

### The vendored table (ported from `agents/builtin.rs`, verbatim in behavior)

| id | project skills dir | global skills dir | detect paths | env override |
|---|---|---|---|---|
| `claude-code` | `.claude/skills` | `<claude>/skills` | `<claude>` | `CLAUDE_CONFIG_DIR`, else `~/.claude` |
| `codex` | `.agents/skills` | `<codex>/skills` | `<codex>`, `/etc/codex` | `CODEX_HOME`, else `~/.codex` |
| `cursor` | `.agents/skills` | `~/.cursor/skills` | `~/.cursor` | — |
| `universal` | `.agents/skills` | `~/.agents/skills` | `~/.agents` | — |

`.agents/skills` is the ecosystem's universal dir (upstream's `UNIVERSAL_SKILLS_DIR`,
`types.rs:297`); three of the four rows use it at *project* scope while keeping an agent-specific
*global* dir — that asymmetry is upstream's, and it is deliberate, so we carry it. The four global
dirs are exactly `AGENT_DIRS`, which is the coherence Finding 2 demanded.

### Reference semantics being ported

`install.sh:197-275` and spec §5: preflight the whole member set (missing member; collision = a
non-symlink at the destination, or a symlink whose **physically resolved** target differs from the
source — `install.sh:210-221`); link every member; roll back this run's links on any link failure;
commit the lock last. Remove deletes only links pointing **into the library**
(`install.sh:253-262`), refcounted at pack altitude (§5).

## Global constraints (re-verified at HEAD, not inherited)

- **No spec change, no `install.sh` change.** This phase implements §3/§5/§7 in Rust; the shell
  reference implementation stays the parity oracle, untouched.
- **The hard seam rule stands:** the crate never reads `skills/` at build time. Library content
  appears only as throwaway fixture trees built by the test harness.
- **Zero new third-party dependencies.** Deps are `grimoire-pack` (path), `semver`, `thiserror` —
  all already in the workspace via `grimoire-pack`; `tempfile` for dev. **No `tokio`, no `skill`.**
  Enforced by a test (Task 12), because a dependency floor nobody checks is a wish.
- **Synchronous.** `grimoire-pack` is blocking `std::fs`; with `skill` gone there is no async
  surface left to accommodate, so core ops are plain sync functions. Keeping the responsiveness
  Phase 3 needs is the *TUI's* job: it runs core ops off the render thread (a `spawn_blocking` or
  a worker thread), which is where the concurrency belongs anyway. See Task 13's amendment.
- **Clockless and homeless, like `grimoire-pack`.** The crate never calls `now()` and never reads
  the process environment: `home`, the env overrides, and `installed_at` are **parameters**. One
  clearly-marked constructor (`AgentEnv::from_process`) reads the environment for the *binary's*
  convenience and is never called by an operation. This is what makes the integration tests
  hermetic, and it matches Phase 1's stance (`scope_for(target, home)`).
- **Reuse `grimoire_pack::lock::Scope`** — do not mint a second scope enum.
- **Ecosystem per-skill locks are not written** (`skills-lock.json`, `~/.agents/.skill-lock.json`).
  Spec §3 makes them "the untouched per-skill authority"; `install.sh` writes neither; upstream's
  installer writes neither. Deliberate deferral, recorded — not an oversight.
- **A partially-linked pack must never mint a lock entry.** Spec §3: "A pack's lock state is one
  bit." The lock write is the commit point, after every link succeeds.

## Task 1 — crate skeleton, error type, dependency floor

`crates/grimoire-core/` joins the workspace by the existing `members = ["crates/*"]` glob (no root
manifest edit).

```toml
[package]
name = "grimoire-core"
version = "0.1.0"
edition = "2021"
description = "grimoire operations: library model, scopes, agents, pack install/remove/check — no UI"
license = "MIT OR Apache-2.0"

[dependencies]
grimoire-pack = { path = "../grimoire-pack" }
semver = "1"        # `Manifest.version` is `semver::Version`; naming it in our API needs the dep
thiserror = "1"

[dev-dependencies]
tempfile = "3"
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
pub mod time;      // the validated RFC3339 newtype — no `time` CRATE, see Task 6

#[derive(Debug, thiserror::Error)]
pub enum CoreError {
    #[error("io error at {path}: {source}")]
    Io { path: PathBuf, #[source] source: std::io::Error },
    #[error("pack error: {0}")]
    Pack(#[from] grimoire_pack::PackError),
    #[error("no pack named {0} in this library")]
    UnknownPack(String),
    #[error("preflight failed: {0} blocking finding(s)")]
    Preflight(usize),
    #[error("lock is read-only: {0}")]      // spec §3: version > 1, or unparseable
    LockReadOnly(String),
    #[error("malformed timestamp: {0}")]
    Timestamp(String),
    #[error("malformed config at {path}: {reason}")]
    Config { path: PathBuf, reason: String },
}

pub type Result<T> = std::result::Result<T, CoreError>;
```

**Verify:** `cargo build -p grimoire-core` green; `cargo tree -p grimoire-core --depth 1` shows
only `grimoire-pack`, `semver`, `thiserror` (Task 12 pins this as a test).

## Task 2 — `Target`: the scope/agent-resolved destination

`src/target.rs`. A `Target` is "where an operation happens": one scope, one agent's skills dir, one
lock path. Pure — construction does no I/O.

```rust
pub use grimoire_pack::lock::Scope;   // §3's two scopes; do not redefine

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Target {
    pub agent: crate::agents::Agent,
    pub scope: Scope,
    /// Where member links are created.
    pub skills_dir: PathBuf,
    /// Where `grimoire.lock` lives for this destination (spec §3).
    pub lock_path: PathBuf,
}

impl Target {
    /// Global: the agent's own global skills dir.
    pub fn global(agent: &Agent, home: &Path) -> Self;
    /// Project: `<project_root>/<agent.project_skills_dir>`.
    pub fn project(agent: &Agent, project_root: &Path, home: &Path) -> Self;
}
```

Both derive `lock_path` through `grimoire_pack::lock::lock_path(&skills_dir, home)` — Phase 1's
helper is the single §3 authority, and routing every scope decision through it is what keeps core
and `install.sh` from drifting.

**Tests** (red-first): a global `claude-code` target locks at `<home>/.agents/grimoire.lock` (§3's
"global installs share one lock" — note it is **not** `<home>/.claude/grimoire.lock`); a project
target at `/work/proj` locks at `/work/proj/.claude/grimoire.lock`; a project *inside* home is
still `Scope::Project` (the §3 rule is "under a recognized agent dir", not "under home"); every
one of the four vendored agents produces a `Scope::Global` global target — the regression test for
Finding 2's incoherence.

**Verify:** `cargo test -p grimoire-core target::` green (red first).

## Task 3 — `agents`: the vendored table

`src/agents.rs`. Data plus two pure functions; the env is a parameter.

```rust
/// The environment the agent table resolves against. A PARAMETER — the crate
/// never reads the process environment during an operation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AgentEnv {
    pub home: PathBuf,
    /// `$CLAUDE_CONFIG_DIR`, else `<home>/.claude`.
    pub claude: PathBuf,
    /// `$CODEX_HOME`, else `<home>/.codex`.
    pub codex: PathBuf,
}

impl AgentEnv {
    /// Every path derived from one root. THE test constructor.
    pub fn rooted(home: impl Into<PathBuf>) -> Self;
    /// Reads `HOME`, `CLAUDE_CONFIG_DIR`, `CODEX_HOME`. For the BINARY only —
    /// no operation calls this. Empty values count as unset (xdg-basedir
    /// behavior, ported from upstream's `env_override`).
    pub fn from_process() -> Self;
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Agent {
    pub id: String,                       // "claude-code", "codex", "cursor", "universal"
    pub display_name: String,
    pub project_skills_dir: PathBuf,      // relative, e.g. `.claude/skills`
    pub global_skills_dir: PathBuf,       // absolute, resolved against AgentEnv
    detect_paths: Vec<PathBuf>,
}

impl Agent {
    /// Existence probe — sync, best-effort, short-circuiting. Never errors:
    /// an unreadable path is "not installed" (upstream swallows probe
    /// failures the same way).
    pub fn detected(&self) -> bool;
    /// Does this agent install into the universal `.agents/skills` at project scope?
    pub fn is_universal(&self) -> bool;
}

/// The four targets spec §3 recognizes, resolved against `env`. Pure.
pub fn table(env: &AgentEnv) -> Vec<Agent>;
pub fn get(env: &AgentEnv, id: &str) -> Option<Agent>;
```

Rows exactly as tabulated in *The vendored table* above. Each row carries a `// upstream:
agents/builtin.rs:<line>` comment naming its source, so a future re-check against upstream is a
diff rather than an investigation.

**Tests:** `table(&AgentEnv::rooted("/home/u"))` yields the four expected global dirs; the four
global dirs each classify `Scope::Global` under `grimoire_pack::lock::scope_for` (the coherence
invariant — a fifth agent added later without a matching `AGENT_DIRS` entry fails here, which is
the point); `AgentEnv::rooted` overrides propagate (a `claude` override moves both the global dir
and the detect path); `detected()` is true for an existing fixture dir and false for an absent
one; `from_process` is **not** exercised by any test.

**Verify:** `cargo test -p grimoire-core agents::` green (red first).

## Task 4 — `Library`: the local source

`src/library.rs`. Wraps `grimoire-pack` enumeration with the ignore rules Phase 1 built.

```rust
#[derive(Debug, Clone)]
pub struct Library { root: PathBuf, ignore: grimoire_pack::discovery::Ignore }

/// A pack as the app renders it. Members are FLAT and their pack-dependence
/// is opaque to the app (brainstorm decision, binding).
#[derive(Debug, Clone)]
pub struct LibraryPack {
    pub name: String,
    pub version: semver::Version,
    pub description: String,
    pub faced: bool,
    pub dir: PathBuf,
    pub members: Vec<Member>,   // face first (implicit), then required, then optional
}

#[derive(Debug, Clone)]
pub struct Member { pub name: String, pub dir: PathBuf, pub required: bool, pub is_face: bool }

pub struct LibraryView { pub packs: Vec<LibraryPack>, pub loose: Vec<Member>, pub issues: Vec<String> }

impl Library {
    /// Default ignore rules: the built-in floor plus this repo's fixture and
    /// vendor trees, so a grimoire clone enumerates its real content.
    pub fn open(root: impl Into<PathBuf>) -> Self;
    pub fn with_ignore(root: impl Into<PathBuf>, ignore: Ignore) -> Self;
    pub fn enumerate(&self) -> Result<LibraryView>;      // one walk
    pub fn resolve_pack(&self, name: &str) -> Result<LibraryPack>;   // by manifest `name:`
}
```

Member resolution mirrors `install.sh:88-111` exactly: the face is an **implicit** member and its
`SKILL.md` `name:` MUST equal the pack's `name:`; `required` and `optional` are both installed by
default; a **faceless** pack resolves its members but is flagged — §3 requires caching the
manifest into the lock for a faceless install, which Task 6 handles (unlike `install.sh`, which
refuses).

`issues` are rendered to `String` from `grimoire_pack::pack::Issue`, whose `PackError` is not
`Clone` (a recorded Phase 1 limit) — Phase 3 will want to clone app state, so the non-`Clone` type
stops here.

**Tests:** hermetic, against the Task 11 fixture library — a faced pack with one required + one
optional member and one loose skill enumerates as 1 pack / 3 members / 1 loose; face-name ≠
pack-name is an issue, not a pack; an ignored subtree contributes nothing.

**Verify:** `cargo test -p grimoire-core library::` green (red first).

## Task 5 — install preflight: the plan, computed without mutating anything

`src/install.rs`, part 1. Preflight returns **data**; the TUI renders it and asks. Nothing mutates.

```rust
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MemberDisposition {
    Fresh,
    /// A symlink already resolving to this exact source (physical compare).
    AlreadyInstalled,
    /// Occupied by something else. Blocking by default (§5: resolution MUST
    /// NOT be silent); the face is never adoptable.
    Collision { at: PathBuf, points_to: Option<PathBuf>, adoptable: bool },
    Missing,
}

pub struct InstallPlan {
    pub pack: String,
    pub target: Target,
    pub members: Vec<(Member, MemberDisposition)>,
    /// Present ⇒ reinstall/upgrade of an existing lock entry (§5).
    pub replacing: Option<ReplacePlan>,
}

impl InstallPlan {
    pub fn blocking(&self) -> impl Iterator<Item = &(Member, MemberDisposition)>;
    pub fn is_installable(&self) -> bool;
}

pub fn preflight(lib: &Library, pack: &str, target: &Target) -> Result<InstallPlan>;
```

The collision predicate is `install.sh:210-221`'s, ported: `symlink_metadata` says symlink →
compare `canonicalize(link)` against `canonicalize(source)`; equal ⇒ `AlreadyInstalled` (a chain
through an intermediate symlink is the same install, not a collision); unequal ⇒ `Collision`.
Anything else existing ⇒ `Collision { points_to: None }`. Spec §5's hash-based predicate is the
*scope-wide* rule; v0.1 enforces the destination-level check `install.sh` uses, and the gap is
recorded under *Deferred*.

`ReplacePlan` covers §5's reinstall/upgrade: members added, members dropped (subject to Task 8's
refcount), version moving **backward** or `source` changing — each a fact the caller must see.

**Tests:** fresh ⇒ all `Fresh`; pre-linked ⇒ `AlreadyInstalled`; a directory at the destination ⇒
blocking `Collision`; a symlink to a different source ⇒ blocking `Collision`; a link reached
through an intermediate symlink ⇒ `AlreadyInstalled`, not a collision.

**Verify:** `cargo test -p grimoire-core install::preflight` green (red first).

## Task 6 — install execute: the transaction

`src/install.rs`, part 2, plus `src/time.rs`.

The crate stays clockless, so the caller supplies the timestamp — and to keep the dependency floor
at zero, it arrives as a validated newtype rather than a `time::OffsetDateTime`:

```rust
// src/time.rs
/// An RFC3339 UTC instant in exactly the shape `install.sh` writes
/// (`date -u +%Y-%m-%dT%H:%M:%SZ`) — validated lexically, no date math and
/// no dependency. The BINARY decides how it obtains one.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Timestamp(String);

impl Timestamp {
    pub fn parse(s: &str) -> Result<Self>;   // shape + range check on each field
    pub fn as_str(&self) -> &str;
}
```

```rust
pub struct InstallRequest<'a> {
    pub library: &'a Library,
    pub pack: &'a str,
    pub target: &'a Target,
    pub installed_at: crate::time::Timestamp,
    pub source_ref: Option<String>,     // caller-supplied; core never runs git
    /// Optional members the user deselected (§5: an optional member absent
    /// from the lock stays uninstalled).
    pub skip_optional: Vec<String>,
}

pub struct InstallOutcome {
    pub linked: Vec<(String, PathBuf)>,
    pub already_present: Vec<String>,
    /// §5 step 4: the face to point the user at. We surface it; never execute it.
    pub face: Option<PathBuf>,
}

pub fn install(req: InstallRequest<'_>) -> Result<InstallOutcome>;
```

Sequence, aborting into rollback at any failure before the lock write:

1. `preflight` → if `!is_installable()`, `Err(CoreError::Preflight(n))` with **no** filesystem
   change (`install.sh:223-226`'s "no partial install").
2. `create_dir_all(target.skills_dir)`, then link each non-`AlreadyInstalled` member
   (`std::os::unix::fs::symlink`), pushing every created link onto `created: Vec<PathBuf>`. Any
   link error ⇒ remove exactly `created` (this run's links only, never a pre-existing one) and
   return the error. Unix-only, as is the bash reference implementation; Windows is out of v0.1
   scope, not overlooked.
3. Read the lock via `grimoire_pack::lock::read` (`Ok(None)` ⇒ `Lock::default()`). `version > 1`
   or unparseable ⇒ **`CoreError::LockReadOnly` after rolling back the links** — §3 forbids
   rewriting it, and a linked-but-unlocked pack is exactly the "silently plausible partial pack"
   §5 tells tools to avoid.
4. Insert one `PackEntry { version, source: library root, r#ref, installed_at, skills, manifest }`
   — `skills` keyed by member name, each `SkillEntry { hash: member_hash(dir), required }` with
   `required` recording the classification **at install time** (§3), and `manifest` populated
   **only for a faceless pack** (§3's caching requirement). Other packs' entries and unknown keys
   survive because we mutate the lock we read and `grimoire-pack`'s types carry `extra`.
   `grimoire_pack::lock::write` commits — the transaction's commit point.
5. Return the face path for the caller to surface (§5 step 4). **Never execute anything.**

Atom (single loose skill) install is the same machinery with a one-member set and **no** lock
entry — an atom is not a pack, and `install.sh` locks nothing for it.

**Tests:** happy path (links land, lock entry matches fixture hashes, face returned);
`Timestamp::parse` rejects `2026-08-18 12:00:00` and `2026-13-01T00:00:00Z`, accepts
`install.sh`'s exact shape; a lock at `version: 2` ⇒ `LockReadOnly` **and the tree is unchanged**
(rollback asserted, not assumed); a mid-flight link failure leaves zero new links and no lock
entry; re-install is idempotent; installing a second pack preserves the first's entry and any
unknown top-level lock keys.

**Verify:** `cargo test -p grimoire-core install::` green (red first).

## Task 7 — inventory: what is installed here

`src/inventory.rs`.

```rust
pub struct InstalledPack { pub name: String, pub entry: PackEntry, pub dir_present: bool }
pub struct Inventory { pub packs: Vec<InstalledPack>, pub loose: Vec<InstalledMember> }
pub fn inventory(target: &Target) -> Result<Inventory>;
```

Reads the scope's lock plus the real entries in `target.skills_dir` (a link is "ours" when it
resolves into a known library; unresolvable links are reported, not hidden). §3's read rule —
project shadows global per pack name — is applied by the **caller** composing two `Target`s;
`inventory` answers for exactly one scope, which is what §3's "every operation targets exactly one
scope" requires.

**Verify:** `cargo test -p grimoire-core inventory::` green.

## Task 8 — remove: refcounted at pack altitude

`src/remove.rs`.

```rust
pub struct RemovePlan {
    pub pack: String,
    pub unlink: Vec<(String, PathBuf)>,     // unreferenced by any other pack in this scope
    pub retained: Vec<(String, String)>,    // (member, still required by pack X)
    pub foreign: Vec<(String, PathBuf)>,    // points outside the library — never touched
    /// §5: setup artifacts may persist; relay the face's guidance BEFORE deleting.
    pub face_warning: Option<PathBuf>,
}

pub fn plan_remove(target: &Target, pack: &str) -> Result<RemovePlan>;
pub fn remove(target: &Target, plan: &RemovePlan) -> Result<()>;
pub fn remove_optional_member(target: &Target, pack: &str, member: &str) -> Result<()>;
```

A member is unlinked only when **no other pack entry in the same scope's lock** lists it (§5's
"reference counting at pack altitude"). `foreign` ports `install.sh:255-259`. Optional-member
removal drops the member entry and leaves no other trace (§5); the pack entry stays.

**Tests:** two packs sharing a member ⇒ removing one retains the member and the other's entry;
removing the second unlinks it; a hand-placed foreign link is reported and left on disk;
optional-member removal leaves the pack installed with the member gone from the lock;
`face_warning` is populated before anything is deleted.

**Verify:** `cargo test -p grimoire-core remove::` green (red first).

## Task 9 — check: facts, not verdicts

`src/check.rs`. Spec §5's table verbatim, plus Task 4's enumeration issues.

```rust
pub enum Finding {
    RequiredMemberMissing { pack: String, member: String },                        // broken
    MemberMoved { pack: String, member: String, locked: String, actual: String },  // re-pin/reinstall
    OptionalMemberAbsent { pack: String, member: String },                         // fine
    OrphanedPack { pack: String },                                                 // manifest gone
    SharedMemberDisagreement { member: String, packs: Vec<String> },               // §5
}
pub struct CheckReport { pub findings: Vec<Finding>, pub library_issues: Vec<String> }
pub fn check(lib: &Library, target: &Target) -> Result<CheckReport>;
```

Local only — no network, no source (§5). Hashes recompute through
`grimoire_pack::hash::member_hash` (Appendix A). A faced pack consults the **installed** `PACK.md`;
a faceless pack consults the manifest cached in the lock (§3).

**Tests:** clean install ⇒ empty; delete a required member ⇒ `RequiredMemberMissing`; edit a
member's bytes ⇒ `MemberMoved` with both hashes; delete an optional member ⇒
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
pub fn load(config_home: &Path) -> Result<Config>;   // absent file ⇒ default
pub fn save(config_home: &Path, cfg: &Config) -> Result<()>;
```

TOML, hand-editable, unknown keys ignored and preserved. Parsed by a hand-rolled single-key reader
rather than adding `toml` + `serde` — v0.1 has exactly one key and the dependency floor is now an
invariant. When a second structured key appears, adopt `toml` then.

**Tests:** absent ⇒ default; round-trip; unknown key ignored **and still present after `save`**; a
malformed file is `CoreError::Config`, not a panic.

**Verify:** `cargo test -p grimoire-core config::` green.

## Task 11 — the sandbox harness + both workflows end-to-end

`crates/grimoire-core/tests/`. The phase gate's evidence, so the harness ships with it.

`tests/sandbox.rs` builds a throwaway world in one `tempfile::TempDir`:

```
<tmp>/library/skills/{alpha/SKILL.md+PACK.md, beta/SKILL.md, gamma/SKILL.md, loose/SKILL.md}
<tmp>/home/{.agents/, .claude/skills/, .codex/, .cursor/}   # a FAKE home
<tmp>/project/                                               # a fake project root
```

with `AgentEnv::rooted("<tmp>/home")` — never `AgentEnv::from_process()`, which would resolve
against the developer's real machine.

- `tests/workflow_library.rs` — **workflow (a)**: enumerate → preflight → install a pack at
  **global** scope → inventory lists it → check clean → remove → tree and lock return to their
  pre-install state.
- `tests/workflow_project.rs` — **workflow (b)**: the same at **project** scope, asserting the lock
  lands at `<project>/.claude/grimoire.lock` (§3) and that a global install of the same pack is
  untouched by the project remove (scope isolation — §3's "exactly one scope").
- `tests/parity.rs` — install-shape parity with `install.sh`: every installed member is a
  **symlink** resolving into the library, so editing a library file is visible through the
  installed path. This is the dogfood property Phase 4's gate depends on; asserting it here is
  what stops a future refactor from quietly reintroducing copy semantics.

**Prove by breaking** (house rule — a check nobody has seen fail is not evidence): with Task 8's
refcount disabled, the shared-member assertion must go red; with Task 6's rollback
short-circuited, the mid-flight failure test must go red; with the collision predicate weakened to
a bare `exists()`, the intermediate-symlink case must go red. Record the three observed failures
in the ship's commit message, then restore.

**Verify:** `cargo test -p grimoire-core --tests` green; three break-tests observed red, restored.

## Task 12 — boundary tests

`tests/boundary.rs`. The crate's architectural invariants are tests, not comments:

- **Dependency floor:** parse `cargo metadata` and assert `grimoire-core`'s transitive deps contain
  no `skill`, no `tokio`, and nothing named `ratatui`/`crossterm`/`termion`. Finding 2's decision
  is only durable if a re-introduction fails the suite.
- **No environment reads in operations:** assert no `src/*.rs` other than `agents.rs` mentions
  `std::env`, and that `agents.rs`'s only use is inside `from_process`.

**Verify:** `cargo test -p grimoire-core --test boundary` green; each assertion observed failing
against a deliberately-broken variant (add `tokio` to the manifest; add an `std::env::var` call).

## Task 13 — roadmap amendment + docs

The vendoring decision contradicts two of the roadmap's *Cross-cutting foundations* as written, so
amend them in the same commit that lands the crate — a plan and its roadmap must not disagree:

- **Async posture** ("`grimoire-core` adopts tokio and exposes async operations"): amend to
  "`grimoire-core` is synchronous; the TUI runs core operations off its render thread. The original
  rationale — `skill`'s async surface — no longer applies, `skill` having been dropped
  (2026-08-18)." The ratatui/tokio event loop in Phase 3 is **unaffected**.
- **Dependency policy** ("`skill` pinned `=0.8.3`; vendor/fork is the documented fallback"): amend
  to record that the fallback was **taken** for v0.1 — the four-target table is vendored, `skill`
  is not a dependency — and that remote sources would be the deliberate occasion to reconsider.
- Keep **Seam types** as-is: it now holds trivially.
- Module docs: `lib.rs` states the contract (sync, clockless, homeless, no UI, zero third-party
  deps beyond the workspace's); `agents.rs` names upstream as the table's provenance with the
  per-row line references; `install.rs` names the spec sections it implements and the `install.sh`
  lines it ports.
- Flip Phase 2's roadmap entry to shipped with a one-paragraph summary, per Phase 1's precedent
  (`docs/design/2026-08-15-tui-v0.1-roadmap.md:46-52`).

## Deferred (recorded, not forgotten)

- **Scope-wide hash collision predicate** (§5's "already installed in the target scope with
  different content"): v0.1 uses the destination-level predicate `install.sh` enforces. `check`
  already computes the hashes the scope-wide version needs — a later composition, not new
  machinery.
- **Interactive adopt/replace** (§5): `Collision.adoptable` carries the flag; v0.1 aborts rather
  than resolving. Resolution is a TUI interaction (Phase 3+); the spec only forbids doing it
  *silently*.
- **Agents beyond the four** §3 recognizes: adding one is a table row **plus** an `AGENT_DIRS`
  entry in `grimoire-pack` — Task 3's coherence test fails loudly if only one side is edited.
- **Ecosystem per-skill lock upkeep** — see Global constraints.
- **Remote sources, search, upgrade-from-source** — outside v0.1 by the brainstorm; the natural
  occasion to reconsider `skill`.

## Phase gate (the roadmap's Phase 2 exit criteria)

- [ ] Sandboxed integration tests cover **both** workflows end-to-end (discover → install → list →
      check → remove) against throwaway fixture trees with a fake home — no test reads or writes
      the developer's real agent dirs.
- [ ] **No UI crate, no `tokio`, no `skill`** in `grimoire-core`'s dependency tree, asserted by
      `tests/boundary.rs` and each assertion observed failing when deliberately broken.
- [ ] The four vendored agents all classify `Scope::Global` under `grimoire_pack::lock::scope_for`
      (Finding 2's coherence invariant).
- [ ] Workspace suite green and `cargo clippy --all-targets -- -D warnings` clean **from the repo
      root**, and — this stream's standing rule, because this is repo-scanning code — the suite
      also run **in the root checkout** before the land, not only in the worktree.
- [ ] Phase 1's 48 tests green **unmodified** (this phase adds a crate; it changes none of
      `grimoire-pack`'s behavior).
- [ ] Three prove-by-breaking failures observed and recorded (Task 11).
- [ ] Roadmap's *Cross-cutting foundations* amended in the same commit range (Task 13).
- [ ] `install.sh` untouched, no spec edit in the diff, and
      `skills/skill-builder/scripts/skills-lint.sh` unchanged at `fails=0`.
