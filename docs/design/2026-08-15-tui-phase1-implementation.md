# ③ TUI v0.1 — Phase 1 implementation plan: grimoire-pack first-consumer additions

**Status:** draft (2026-08-15). Phase 1 of `docs/design/2026-08-15-tui-v0.1-roadmap.md`
(sequencing 1→2→3→4; this phase blocks Phase 2's `grimoire-core`). Built on the `app`
workstream branch. Spec: `docs/spec/pack-format.md` (draft 5, format 1).

## Goal

Close the two `grimoire-pack` gaps ① recorded that a consumer hits immediately, so Phase 2's
`grimoire-core` can resolve lock paths and enumerate a real repository without drowning in
fixture noise.

## Grounded measurement (2026-08-15, against branch HEAD 420488f)

`pack::enumerate()` over this repository today returns **3 packs and 8 issues**:

```
packs=3   alpha (crates/grimoire-pack/tests/fixtures/faced-valid/skills/alpha/PACK.md)
          twin  (crates/grimoire-pack/tests/fixtures/invalid-dup-name/skills/a1/PACK.md)
          clankshop (skills/clankshop/PACK.md)
issues=8  all eight from crates/grimoire-pack/tests/fixtures/**
```

The truth is **1 pack (clankshop), 0 issues**. Every other row is a conformance fixture — the
format's executable examples — enumerating as real content of this repo. Spec-truthful (the
fixtures *are* well-formed pack trees), but useless to a consumer. This is the exact
before/after the ignore-rules tests assert.

## Global constraints (re-verified at HEAD, not inherited)

- **No spec change.** Appendix B explicitly leaves the recursive-scan bound to implementations,
  and §3's scope rules already exist — this phase implements them, it does not amend them.
- **Purity: the scope helper does no I/O and reads no environment.** `home` is a parameter, not
  `std::env::var("HOME")` — a function that reads the ambient environment cannot be tested
  hermetically, and the crate's existing stance is already clockless (`lock.rs` takes
  timestamps from callers). Path handling is **lexical**: no canonicalization, no symlink
  resolution (consistent with the crate's symlink-blind discovery).
- **Backward compatibility is a test obligation, not a hope.** `discover(root, full_depth)` and
  `enumerate(root)` keep their exact signatures and behavior via default-`Ignore` wrappers; the
  existing 36 tests and `tests/clankshop.rs` must stay green **unmodified** as the proof.
- **Three walkers, not one.** Ignore rules must be threaded through `discovery::walk`,
  `pack::find_stray_manifests`, AND `pack::assert_nothing_nested` — missing the latter two
  leaves ignored trees still producing `Issue`s, which is the same noise by another door.
- **`PackError` holds `io::Error`,** so `Issue`/`Enumeration` are not `Clone` — do not add
  derives that would not compile (recorded limit from ①).
- **Parity divergence, deliberate and documented:** `install.sh`'s scope globs
  (`"$HOME"/.agents/*`) match strictly *below* an agent dir, so a target of exactly
  `~/.agents` would fall to project scope there. The helper treats "is, or is under, a
  recognized agent dir" as global — the spec's intent (§3: installs into the user's agent
  dirs are the global scope). In practice targets are skills dirs (`~/.agents/skills`), so
  the two never disagree on a real input; recorded rather than silently diverged.

## Task 1 — `Scope` + lock-path resolution (spec §3)

New public surface in `crates/grimoire-pack/src/lock.rs` (§3's module — `pack.rs` is §1,
`manifest.rs` is §2, so §3's scope rules belong here).

```rust
/// Spec §3: the two lock scopes. Global installs (per-agent dirs under the
/// user's home) share one lock at `~/.agents/grimoire.lock`; anything else is a
/// project scope whose lock sits at the project root — the target's parent.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Scope {
    Global,
    Project,
}

/// The per-agent skill directories whose installs are the GLOBAL scope (§3).
/// Distinct from discovery's PRIORITY_DIRS: these are install targets under
/// `home`, not places skills are found inside a repository.
const AGENT_DIRS: &[&str] = &[".agents", ".claude", ".codex", ".cursor"];

/// Classify an install target. Pure and lexical: no I/O, no symlink
/// resolution, no environment reads — `home` is supplied by the caller.
/// A target that IS a recognized agent dir, or lies under one, is `Global`.
pub fn scope_for(target: &Path, home: &Path) -> Scope {
    for agent in AGENT_DIRS {
        let dir = home.join(agent);
        if target == dir || target.starts_with(&dir) {
            return Scope::Global;
        }
    }
    Scope::Project
}

/// Where `grimoire.lock` lives for an install into `target` (§3).
/// Global: `<home>/.agents/grimoire.lock`. Project: the lock sits beside the
/// target dir, at the project root — `<target>/../grimoire.lock`. A target
/// with no parent (a filesystem root) locks in place rather than panicking.
pub fn lock_path(target: &Path, home: &Path) -> PathBuf {
    match scope_for(target, home) {
        Scope::Global => home.join(".agents").join(LOCK_FILE),
        Scope::Project => target.parent().unwrap_or(target).join(LOCK_FILE),
    }
}
```

Add `use std::path::{Path, PathBuf};` to `lock.rs` if not already imported at that scope.

**Tests** (in `lock.rs`'s `mod tests`, red-first — write them before the functions):

```rust
#[test]
fn global_scope_for_every_agent_dir_and_below() {
    let home = Path::new("/home/u");
    for agent in [".agents", ".claude", ".codex", ".cursor"] {
        let exact = home.join(agent);
        assert_eq!(scope_for(&exact, home), Scope::Global, "{agent} itself");
        let below = exact.join("skills");
        assert_eq!(scope_for(&below, home), Scope::Global, "{agent}/skills");
        assert_eq!(lock_path(&below, home), Path::new("/home/u/.agents/grimoire.lock"));
    }
}

#[test]
fn project_scope_locks_beside_the_target_dir() {
    let home = Path::new("/home/u");
    let target = Path::new("/work/proj/.claude/skills");
    // not under HOME: a project install, however agent-shaped its path looks
    assert_eq!(scope_for(target, home), Scope::Project);
    assert_eq!(lock_path(target, home), Path::new("/work/proj/.claude/grimoire.lock"));
}

#[test]
fn home_adjacent_but_not_agent_dir_is_project_scope() {
    let home = Path::new("/home/u");
    let target = home.join("scratch/skills");
    assert_eq!(scope_for(&target, home), Scope::Project);
    assert_eq!(lock_path(&target, home), Path::new("/home/u/scratch/grimoire.lock"));
}
```

**Verify:** `cargo test -p grimoire-pack lock::` green; the three new tests fail first for the
right reason (unresolved `Scope`/`scope_for`), then pass.

## Task 2 — `Ignore`: the consumer-supplied filter

New public type in `crates/grimoire-pack/src/discovery.rs`. Data, not a closure: `Clone`-able,
inspectable, and threadable through three walkers without generics.

```rust
/// Directory names skipped by every scan, at any depth (the built-in floor).
/// Appendix B leaves the recursive bound to implementations; this is ours.
const DEFAULT_IGNORED_DIRS: &[&str] = &[".git", "node_modules", "target"];

/// Which directories a scan must not descend into.
///
/// The default is the built-in floor above. A consumer adds repo-relative
/// paths for trees that are structurally valid but not the repository's own
/// content — conformance fixtures, vendored clones, sample repos — so they
/// neither enumerate as packs nor report issues.
#[derive(Debug, Clone, Default)]
pub struct Ignore {
    rel_paths: Vec<PathBuf>,
}

impl Ignore {
    /// The built-in floor only.
    pub fn new() -> Self {
        Self::default()
    }

    /// Also skip `path`, interpreted relative to the scan root.
    pub fn with_path(mut self, path: impl Into<PathBuf>) -> Self {
        self.rel_paths.push(path.into());
        self
    }

    /// Should the scan skip `dir` (an absolute path under `root`)?
    /// Lexical: no canonicalization, consistent with the crate's symlink stance.
    pub fn skips(&self, root: &Path, dir: &Path) -> bool {
        if let Some(base) = dir.file_name() {
            if DEFAULT_IGNORED_DIRS.iter().any(|d| base == *d) {
                return true;
            }
        }
        let Ok(rel) = dir.strip_prefix(root) else {
            return false;
        };
        self.rel_paths.iter().any(|p| rel == p || rel.starts_with(p))
    }
}
```

**Tests** (in `discovery.rs`'s `mod tests`):

```rust
#[test]
fn ignore_floor_covers_default_dirs_at_any_depth() {
    let ig = Ignore::new();
    let root = Path::new("/r");
    assert!(ig.skips(root, Path::new("/r/.git")));
    assert!(ig.skips(root, Path::new("/r/a/b/node_modules")));
    assert!(ig.skips(root, Path::new("/r/crates/x/target")));
    assert!(!ig.skips(root, Path::new("/r/skills/alpha")));
}

#[test]
fn ignore_rel_path_covers_the_dir_and_everything_below() {
    let ig = Ignore::new().with_path("crates/grimoire-pack/tests/fixtures");
    let root = Path::new("/r");
    assert!(ig.skips(root, Path::new("/r/crates/grimoire-pack/tests/fixtures")));
    assert!(ig.skips(root, Path::new("/r/crates/grimoire-pack/tests/fixtures/faced-valid/skills/alpha")));
    assert!(!ig.skips(root, Path::new("/r/crates/grimoire-pack/tests")));
    assert!(!ig.skips(root, Path::new("/r/skills/clankshop")));
}

#[test]
fn ignore_never_skips_outside_the_root() {
    let ig = Ignore::new().with_path("fixtures");
    assert!(!ig.skips(Path::new("/r"), Path::new("/elsewhere/fixtures")));
}
```

**Verify:** `cargo test -p grimoire-pack discovery::tests::ignore` green (red first).

## Task 3 — thread `Ignore` through discovery

Add the `_with` variant; keep `discover` as a default wrapper so every existing caller and test
is untouched.

```rust
pub fn discover(root: &Path, full_depth: bool) -> Result<Vec<Skill>> {
    discover_with(root, full_depth, &Ignore::new())
}

/// `discover`, honoring consumer ignore rules (Appendix B's bound is ours to set).
pub fn discover_with(root: &Path, full_depth: bool, ignore: &Ignore) -> Result<Vec<Skill>> {
    // body of today's `discover`, with the two `children(...)` shallow loops
    // filtering `!ignore.skips(root, &child)` and the walk call becoming:
    //     walk(root, root, 0, ignore, &mut found)?;
}
```

`walk` gains the scan root and the rules (the root is needed to compute the relative path):

```rust
fn walk(root: &Path, dir: &Path, depth: usize, ignore: &Ignore, found: &mut Vec<Skill>) -> Result<()> {
    if depth > MAX_DEPTH {
        return Ok(());
    }
    if is_skill_dir(dir) && depth > 0 {
        push(found, dir);
        return Ok(()); // skills do not nest in discovery
    }
    for child in children(dir)? {
        if ignore.skips(root, &child) {
            continue;
        }
        walk(root, &child, depth + 1, ignore, found)?;
    }
    Ok(())
}
```

The hardcoded `base == ".git" || base == "node_modules" || base == "target"` check inside
`walk` is **deleted** — `Ignore`'s floor now owns it (one rule, one home). The shallow loops in
`discover_with` gain the same `ignore.skips` guard so a shallow scan cannot surface an ignored
tree either.

**Test:**

```rust
#[test]
fn full_depth_skips_ignored_trees() {
    let t = tempfile::tempdir().unwrap();
    skill(t.path(), "skills/real", Some("real"));
    skill(t.path(), "tests/fixtures/sample/skills/fake", Some("fake"));
    let ig = Ignore::new().with_path("tests/fixtures");
    let names: Vec<_> = discover_with(t.path(), true, &ig)
        .unwrap()
        .into_iter()
        .map(|s| s.name)
        .collect();
    assert!(names.contains(&"real".to_string()));
    assert!(!names.contains(&"fake".to_string()));
    // and the default still sees both — the wrapper's behavior is unchanged
    let all: Vec<_> = discover(t.path(), true).unwrap().into_iter().map(|s| s.name).collect();
    assert!(all.contains(&"fake".to_string()));
}
```

**Verify:** full `cargo test` from the repo root — all pre-existing discovery tests green
unmodified (the compatibility proof), plus the new one.

## Task 4 — thread `Ignore` through pack enumeration

```rust
pub fn enumerate(root: &Path) -> Result<Enumeration> {
    enumerate_with(root, &discovery::Ignore::new())
}

pub fn enumerate_with(root: &Path, ignore: &discovery::Ignore) -> Result<Enumeration> {
    let skills = discovery::discover_with(root, true, ignore)?;
    // ...unchanged manifest collection, except:
    //   find_stray_manifests(root, root, 0, ignore, &mut manifests)?;
    // ...unchanged validate_one loop, except validate_one takes `ignore`
}
```

Both remaining walkers honor the rules:

```rust
fn find_stray_manifests(
    root: &Path,
    dir: &Path,
    depth: usize,
    ignore: &discovery::Ignore,
    manifests: &mut Vec<PathBuf>,
) -> Result<()> {
    // ...unchanged, except the dir branch becomes:
    //   if ignore.skips(root, &entry.path()) { continue; }
    //   find_stray_manifests(root, &entry.path(), depth + 1, ignore, manifests)?;
    // (the inline .git/node_modules/target check is deleted — Ignore's floor owns it)
}

fn assert_nothing_nested(pack_dir: &Path, root: &Path, ignore: &discovery::Ignore) -> Result<()> {
    fn walk(root: &Path, ignore: &discovery::Ignore, dir: &Path, top: bool) -> Result<()> {
        // ...unchanged, except the dir branch becomes:
        //   if ignore.skips(root, &entry.path()) { continue; }
        //   walk(root, ignore, &entry.path(), false)?;
    }
    walk(root, ignore, pack_dir, true)
}
```

**Test** (in `crates/grimoire-pack/tests/conformance.rs`, which already builds fixture trees):

```rust
#[test]
fn ignored_trees_yield_neither_packs_nor_issues() {
    let t = tempfile::tempdir().unwrap();
    // a real pack at the top
    write_faced_pack(t.path(), "skills/real", "real", &["member"]);
    write_skill(t.path(), "skills/member", "member");
    // a valid pack AND a broken manifest inside a fixtures tree
    write_faced_pack(t.path(), "fixtures/sample/skills/alpha", "alpha", &[]);
    write_broken_manifest(t.path(), "fixtures/broken/skills/x");

    let ig = grimoire_pack::discovery::Ignore::new().with_path("fixtures");
    let e = grimoire_pack::pack::enumerate_with(t.path(), &ig).unwrap();
    assert_eq!(e.packs.len(), 1, "only the real pack");
    assert_eq!(e.packs[0].manifest.name, "real");
    assert_eq!(e.issues.len(), 0, "ignored trees must not report issues either");
}
```

(Reuse `conformance.rs`'s existing fixture-writing helpers; add a minimal
`write_broken_manifest` only if none exists — a `PACK.md` with a member that cannot resolve is
enough to produce an `Issue` when not ignored.)

**Verify:** `cargo test` from the repo root; the ten pre-existing conformance cases green
unmodified.

## Task 5 — pin the live-repo outcome

Extend `crates/grimoire-pack/tests/clankshop.rs` — the test that already pins the live flagship
pack — with the measured before/after, so the fix is proven against the real repository and
regressions are caught by the crate's own suite.

```rust
#[test]
fn repo_enumerates_exactly_one_pack_when_fixtures_are_ignored() {
    let root = repo_root(); // the existing helper this test file already uses
    let ig = grimoire_pack::discovery::Ignore::new()
        .with_path("crates/grimoire-pack/tests/fixtures");
    let e = grimoire_pack::pack::enumerate_with(&root, &ig).unwrap();
    let names: Vec<_> = e.packs.iter().map(|p| p.manifest.name.as_str()).collect();
    assert_eq!(names, vec!["clankshop"], "fixtures must not enumerate as repo packs");
    assert!(e.issues.is_empty(), "unexpected issues: {:?}", e.issues);

    // ...and without the rule the fixtures are still visible (documents WHY
    // the rule exists; measured 2026-08-15: 3 packs / 8 issues).
    let bare = grimoire_pack::pack::enumerate(&root).unwrap();
    assert!(bare.packs.len() > 1);
}
```

The second assertion is deliberately loose (`> 1`, not `== 3`): it documents the motivation
without pinning a count that legitimately moves whenever a fixture is added.

**Verify:** `cargo test` from the repo root — this test fails before Tasks 3–4 land and passes
after.

## Task 6 — module docs + roadmap status

- `discovery.rs` module doc: one sentence that ignore rules are the implementation's Appendix-B
  bound and are consumer-supplied.
- `lock.rs` module doc: one sentence that §3 scope resolution lives here and is pure/lexical.
- Flip `docs/design/2026-08-15-tui-v0.1-roadmap.md`'s Status line from `draft` to
  `current (governing)` now that its first phase is executing.

## Phase gate (the roadmap's Phase 1 exit criteria)

- [ ] New unit tests green; **the pre-existing 36 tests green unmodified** (the compatibility
      proof — a changed old test means the wrapper broke behavior).
- [ ] `cargo test` and `cargo clippy --all-targets -- -D warnings` green **from the repo root**.
- [ ] `tests/clankshop.rs` still pins the live pack, and now also pins 1-pack/0-issue
      enumeration under the fixtures rule.
- [ ] `install.sh` untouched (no shell-side change in this phase) and
      `skills/skill-builder/scripts/skills-lint.sh` unchanged at `fails=0`.
- [ ] No spec edit in the diff.
