# Pack Format ① Implementation Plan (spec draft 5)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the repo's shell implementation (manifest, installer, check facts, lint, test
fixtures) from ratified draft 3 up to spec draft 5 (`docs/spec/pack-format.md`, `c55801d`), then
build the `grimoire-pack` Rust crate — the spec's reference library (manifest parse/validate,
App B discovery, App A hash, `grimoire.lock` I/O) with conformance fixtures.

**Architecture:** Two phases. Phase A is a key/schema migration across five existing shell
surfaces, sequenced so both test suites stay green at every commit. Phase B is a new
dependency-light, synchronous Rust library at `crates/grimoire-pack` (no workspace root yet —
sub-project ② adds one), built TDD, whose conformance fixtures are the spec's "next
truth-finder". The crate implements Appendix A/B natively (that's why the spec made them
normative); it does NOT depend on the async qntx `skill` crate — that dependency belongs to the
TUI (sub-project ③).

**Tech Stack:** POSIX sh/bash (Phase A); Rust 2021 with `serde`/`serde_json` (preserve_order),
`semver`, `sha2`, `thiserror`, dev-only `tempfile` (Phase B).

**Out of scope (deferred to ③, the TUI):** the transactional install/remove engine,
adopt/replace resolution, reference counting, scope targeting, source normalization
(`github:<owner>/<repo>`), and `check` verdict presentation. `install.sh` keeps its simplified
single-scope subset. The crate provides the primitives those flows will consume.

**Ground rules for the executor:**
- The spec `docs/spec/pack-format.md` (draft 5) is the authority; cite sections when in doubt.
- The owner sometimes commits concurrently in this tree: re-check `git status`/`git log`
  immediately before every commit, and **always commit with explicit pathspecs** (never `git
  add -A` / bare `git commit -a`).
- Never add AI-attribution trailers to commits.
- Run the lint gate with **bash** (it uses process substitution; `sh` fails at line 116).
- Green baselines before Task 1: `sh skills/clankshop/scripts/tests/run.sh` → `clankshop
  tests: ALL GREEN` (onramp `pass=92`); `bash skills/skill-builder/scripts/skills-lint.sh` →
  `fails=0 warns=10`.

---

## Phase A — conform the shell implementation to draft 5

The five draft-3 surfaces: `skills/clankshop/PACK.md` (the manifest),
`install.sh` (parser + lock writer), `skills/clankshop/scripts/check-facts.sh` (manifest
reader), `skills/clankshop/scripts/tests/onramp-test.sh` (fixtures),
`skills/skill-builder/scripts/skills-lint.sh` (`core:` reader).

Draft-5 deltas to apply: `pack:`→`name:`; `skills:`→`required:`; member lists comma-separated;
`setup:` deleted (no lifecycle keys); `format:` optional (absent = format 1); lock `members`
key → `skills`; lock member flag `optional` → `required` (flipped); lock has no `setup` object.

### Task 1: Manifest key migration (all readers + the manifest itself)

Everything that reads `PACK.md` keys moves in one commit so the suites stay green.

**Files:**
- Modify: `skills/clankshop/PACK.md` (frontmatter block, lines 1–12)
- Modify: `install.sh` (resolve_pack ~line 40; --list block ~line 87; pack-resolution block
  ~line 92; write_lock setup lines ~141–147; python merge block ~line 168)
- Modify: `skills/clankshop/scripts/check-facts.sh` (pack-manifest section, ~lines 348–360)
- Modify: `skills/clankshop/scripts/tests/onramp-test.sh` (MEMBERS extraction lines 20–25;
  fixture 4 setup assertion ~line 151)
- Modify: `skills/skill-builder/scripts/skills-lint.sh` (core reader ~line 74)

- [ ] **Step 1: Rewrite the PACK.md frontmatter to draft-5 keys**

Replace the frontmatter block of `skills/clankshop/PACK.md` (everything between and including
the `---` fences; keep the Markdown body untouched) with:

```yaml
---
name: clankshop
version: 1.0.0
description: "The full development loop as a skill pack: route a change, design at seed altitude, plan and build features gate-green, ship them from long-lived workstreams, delegate work without polluting context, keep sessions resumable, root-cause bugs before patching them, and audit both code quality and doc ergonomics."
required: architect, auditor, backlog, calibrator, chiropractor, debugger, delegate, feature, foreman, guardian, handoff, mailbox, workstream
optional: bug, task
# core: is a grimoire author extension (spec §2 unknown key, ignored by tools) -- the
# lint gate's core-member exemption rule; helpers = the members not listed here.
core: clankshop, architect, auditor, backlog, calibrator, chiropractor, debugger, feature, foreman, guardian, workstream
---
```

Note what changed: `pack:`→`name:`, `skills:`→`required:` (comma-separated), `optional:`
comma-separated, `core:` comma-separated for consistency, and the `format: 1` and
`setup: /clankshop setup` lines are **deleted** (spec §2: format-1 manifests SHOULD omit
`format:`; spec §6: no lifecycle keys — setup lives in the face, which `/clankshop setup`
already is).

- [ ] **Step 2: Migrate install.sh's manifest parsing**

In `install.sh`, make these five edits.

(a) `resolve_pack` (~line 40) — match on `name:`:

```sh
# resolve_pack <name> -- echo the PACK.md whose name: matches; fail when none does
resolve_pack() {
  for m in "$root/PACK.md" "$root"/skills/*/PACK.md; do
    [ -f "$m" ] || continue
    if [ "$(frontmatter_key "$m" name)" = "$1" ]; then echo "$m"; return 0; fi
  done
  return 1
}
```

(b) the `--list` packs block (~line 87) — print `name` and `required`:

```sh
  echo "packs (PACK.md manifests):"
  for m in "$root/PACK.md" "$root"/skills/*/PACK.md; do
    [ -f "$m" ] || continue
    printf '  %-14s v%-8s %s\n' "$(frontmatter_key "$m" name)" \
      "$(frontmatter_key "$m" version)" "$(frontmatter_key "$m" required)"
  done
```

(c) the pack-resolution block (~line 92) — `format:` optional, `required:` comma-separated,
no `setup:`:

```sh
if [ -n "$pack_name" ]; then
  pack_manifest="$(resolve_pack "$pack_name")" \
    || { echo "error: no PACK.md declares name: $pack_name (try --list)" >&2; exit 2; }
  fmt="$(frontmatter_key "$pack_manifest" format)"
  [ -z "$fmt" ] || [ "$fmt" = "1" ] \
    || { echo "error: pack $pack_name declares format: $fmt -- this tool implements format 1" >&2; exit 2; }
  pack_version="$(frontmatter_key "$pack_manifest" version)"
  pack_required="$(frontmatter_key "$pack_manifest" required | tr ',' ' ')"
  pack_optional="$(frontmatter_key "$pack_manifest" optional | tr ',' ' ')"
  [ -n "$pack_required" ] || { echo "error: $pack_manifest has no required: line" >&2; exit 2; }
  pack_dir="$(dirname "$pack_manifest")"
  if [ -f "$pack_dir/SKILL.md" ]; then
    face="$(frontmatter_key "$pack_dir/SKILL.md" name)"
    [ -n "$face" ] || face="$(basename "$pack_dir")"
    [ "$face" = "$pack_name" ] \
      || { echo "error: face name $face != pack name: $pack_name (spec: they MUST match)" >&2; exit 2; }
    names+=("$face")
  fi
  for s in $pack_required $pack_optional; do names+=("$s"); done
fi
```

(`tr ',' ' '` converts the comma lists to the space-separated form the rest of the script
already iterates; surrounding whitespace around commas becomes harmless extra spaces.)

(d) in `write_lock` (~lines 140–147), delete the setup lines — remove:

```sh
  setup_json=""
  [ -n "$pack_setup" ] && setup_json="
    \"setup\": { \"declared\": \"$pack_setup\", \"ran\": false },"
```

and in `entry_json`, change the line

```sh
    \"installedAt\": \"$ts\",$setup_json
```

to

```sh
    \"installedAt\": \"$ts\",
```

(e) in the python merge heredoc (~line 168), delete the prior-setup carry — replace:

```python
prior = lock.setdefault("packs", {}).get(pack)
if prior and "setup" in prior and "setup" in entry:
    entry["setup"]["ran"] = prior["setup"].get("ran", False)
lock["packs"][pack] = entry
```

with:

```python
lock.setdefault("packs", {})[pack] = entry
```

Also update the `write_lock` header comment (~line 125): change "preserving other packs,
unknown keys, and a prior setup.ran" to "preserving other packs and unknown keys".

- [ ] **Step 3: Migrate check-facts.sh's manifest reader**

In `skills/clankshop/scripts/check-facts.sh` (~lines 348–360), replace the section header
comment and the three `sed` extractions:

```sh
# ---------- pack manifest vs installed set ----------
# PACK.md (spec format 1, beside the pack face): required = name: (the implicit face)
# + required:; optional: members absent from the install are a green fact, never drift.
LOCK=$DIR/../PACK.md
if [ -f "$LOCK" ]; then
  echo "lock_found=1"
  lock_face=$(sed -n 's/^name:[[:space:]]*//p' "$LOCK" | head -1)
  lock_skills=$(sed -n 's/^required:[[:space:]]*//p' "$LOCK" | head -1 | tr ',' ' ' | tr -s ' ')
  lock_optional=$(sed -n 's/^optional:[[:space:]]*//p' "$LOCK" | head -1 | tr ',' ' ' | tr -s ' ')
```

(The rest of the section — `lock_members=`, the missing-installed loop, the `else` arm — is
unchanged: it already consumes space-separated lists. The trailing `tr -s ' '` is required to keep
the emitted fact format stable: `required:`/`optional:` are comma+space-separated (`a, b, c`), so a
bare `tr ',' ' '` leaves double spaces, and the section's `tr ' ' ','` re-join would turn those into
doubled commas / empty tokens.)

- [ ] **Step 4: Migrate the onramp fixture's manifest reader and setup assertion**

In `skills/clankshop/scripts/tests/onramp-test.sh`:

(a) MEMBERS extraction (lines 20–25) — new keys, commas converted:

```sh
# The installed set = the manifest's members (spec format 1: the name: face is an
# implicit member; optional: members are default-installed). Stubs keep fixture and
# manifest in sync.
MEMBERS="$(sed -n 's/^name:[[:space:]]*//p' "$LOCK" | head -1) \
$(sed -n 's/^required:[[:space:]]*//p' "$LOCK" | head -1 | tr ',' ' ') \
$(sed -n 's/^optional:[[:space:]]*//p' "$LOCK" | head -1 | tr ',' ' ')"
```

(b) in fixture 4 (~line 151), the manifest no longer declares setup, so the lock must not
carry a setup object. Replace:

```sh
expect "install: setup declared"     "\"declared\": \"/clankshop setup\"" "$IT/grimoire.lock"
```

with:

```sh
expect_eq "install: no setup object" "absent" \
  "$(grep -q '"setup"' "$IT/grimoire.lock" && echo present || echo absent)"
```

Careful: `expect_eq`'s `$(...)` argument runs when the line executes — keep it positioned
after the install commands, exactly where the old line was.

- [ ] **Step 5: Migrate the lint gate's core: reader**

In `skills/skill-builder/scripts/skills-lint.sh` (~line 74), the `core:` value is now
comma-separated — convert on read. Change:

```sh
  pcore="$(printf '%s\n' "$pfm" | sed -n 's/^core:[[:space:]]*//p' | head -1)"
```

to:

```sh
  pcore="$(printf '%s\n' "$pfm" | sed -n 's/^core:[[:space:]]*//p' | head -1 | tr ',' ' ')"
```

- [ ] **Step 6: Run both suites**

```sh
sh skills/clankshop/scripts/tests/run.sh
bash skills/skill-builder/scripts/skills-lint.sh
```

Expected: `clankshop tests: ALL GREEN` with `onramp: pass=92 fail=0` (one assertion was
replaced, count unchanged), and `fails=0 warns=10`.

- [ ] **Step 7: Grep for stragglers**

```sh
grep -rn '^pack:\|frontmatter_key.*" pack"\|frontmatter_key "$m" pack\|s/\^pack:\|s/\^skills:\|setup:' \
  install.sh skills/clankshop/PACK.md skills/clankshop/scripts/ skills/skill-builder/scripts/skills-lint.sh
```

Expected: no hits on the old keys (hits on the word "setup" in prose comments about the face
verb are fine — judge each; the machine keys must be gone).

- [ ] **Step 8: Commit**

```sh
git status --short && git log --oneline -3   # concurrency check first
git commit -m "pack-format(impl): draft-5 manifest keys -- name:/required:, comma lists, setup:/format: dropped from PACK.md; install.sh, check-facts, onramp, lint core: reader migrated" \
  -- skills/clankshop/PACK.md install.sh skills/clankshop/scripts/check-facts.sh \
     skills/clankshop/scripts/tests/onramp-test.sh skills/skill-builder/scripts/skills-lint.sh
```

### Task 2: Lock schema migration (`members`→`skills`, flag flip)

**Files:**
- Modify: `install.sh` (write_lock member loop, ~lines 132–139 and the `entry_json` block)
- Modify: `skills/clankshop/scripts/tests/onramp-test.sh` (fixture 4 assertions ~lines 148–150)

- [ ] **Step 1: Flip the lock writer**

In `install.sh` `write_lock`, replace the member-loop and entry construction. Current:

```sh
  members_json=""
  for name in "${names[@]}"; do
    opt=false
    case " $pack_optional " in *" $name "*) opt=true ;; esac
    h="$(member_hash "$root/skills/$name")"
    members_json="${members_json}${members_json:+,}
      \"$name\": { \"hash\": \"$h\", \"optional\": $opt }"
  done
```

New:

```sh
  skills_json=""
  for name in "${names[@]}"; do
    req=true
    case " $pack_optional " in *" $name "*) req=false ;; esac
    h="$(member_hash "$root/skills/$name")"
    skills_json="${skills_json}${skills_json:+,}
      \"$name\": { \"hash\": \"$h\", \"required\": $req }"
  done
```

And in `entry_json`, change:

```sh
    \"members\": {$members_json
```

to:

```sh
    \"skills\": {$skills_json
```

Also update the comment above `member_hash` if it references the lock's `members` key, and
scan `install.sh` for any other literal `members` referring to the lock schema:

```sh
grep -n 'members' install.sh
```

Expected: no remaining lock-schema uses (prose uses of the word "member" for the concept are
fine and should stay).

- [ ] **Step 2: Update fixture 4's lock assertions**

In `skills/clankshop/scripts/tests/onramp-test.sh` fixture 4, replace:

```sh
expect "install: optional flagged"   "\"optional\": true" "$IT/grimoire.lock"
```

with:

```sh
expect "install: skills map"         "\"skills\": {" "$IT/grimoire.lock"
expect "install: optional flagged"   "\"required\": false" "$IT/grimoire.lock"
```

- [ ] **Step 3: Run the suite and a live install**

```sh
sh skills/clankshop/scripts/tests/run.sh
```

Expected: `ALL GREEN`, `onramp: pass=93 fail=0` (one assertion added).

Then verify the real artifact end-to-end:

```sh
T=$(mktemp -d) && ./install.sh --pack clankshop --target "$T/skills" && python3 -m json.tool "$T/grimoire.lock" | head -20 && rm -rf "$T"
```

Expected: `locked    clankshop@1.0.0 -> .../grimoire.lock`; the JSON shows
`"skills": { "clankshop": { "hash": "sha256:...", "required": true }, ...` and **no**
`"setup"` key anywhere.

- [ ] **Step 4: Commit**

```sh
git status --short && git log --oneline -3
git commit -m "pack-format(impl): draft-5 lock schema -- skills map replaces members, required flag replaces optional, no setup object" \
  -- install.sh skills/clankshop/scripts/tests/onramp-test.sh
```

### Task 3: Sweep and Phase A gate

**Files:**
- Modify: any stragglers the sweep finds (docs/comments only; the machine surfaces are done)

- [ ] **Step 1: Sweep the active surface for stale key references**

```sh
grep -rn 'pack:\s\|skills:\s\|setup:\s\|"members"\|"optional":' \
  --include='*.sh' --include='*.md' \
  install.sh README.md AGENTS.md skills/clankshop/ skills/skill-builder/scripts/ \
  | grep -v 'docs/design/' | grep -v spec
```

Judge each hit: prose describing the OLD format in historical design docs stays; anything
describing the CURRENT format (READMEs, SKILL.md bodies, script comments, doctrine chapters
that quote manifest keys) is updated to the draft-5 keys. Make the edits.

- [ ] **Step 2: Full gate**

```sh
sh skills/clankshop/scripts/tests/run.sh
bash skills/skill-builder/scripts/skills-lint.sh
```

Expected: `ALL GREEN` (201 total asserts across the suite scripts; onramp 93) and
`fails=0 warns=10`.

- [ ] **Step 3: Commit (only if Step 1 changed files)**

```sh
git status --short && git log --oneline -3
git commit -m "pack-format(impl): draft-5 key sweep -- prose/doc references updated" -- <the files step 1 touched>
```

---

## Phase B — the `grimoire-pack` crate

A synchronous, dependency-light library: the spec's reference implementation and conformance
harness. Layout (no workspace root yet — ② adds it; run cargo from the crate dir):

```
crates/grimoire-pack/
  Cargo.toml
  .gitignore              # /target
  src/lib.rs              # error type + module exports
  src/frontmatter.rs      # flat scalar frontmatter parser (strict subset of YAML)
  src/manifest.rs         # PACK.md model + §2 grammar validation
  src/hash.rs             # Appendix A member content hash
  src/discovery.rs        # Appendix B discovery
  src/pack.rs             # §1 shapes, member resolution, pack enumeration
  src/lock.rs             # grimoire.lock model + I/O (§3)
  tests/conformance.rs    # fixture-driven conformance suite
  tests/fixtures/...      # one directory per conformance case
```

Design decisions (argue with the spec, not the plan):
- **No qntx `skill` dependency.** App A/B are normative in our spec precisely so implementers
  don't need the reference source; the crate implements them directly. Parity with the
  ecosystem hash is pinned by a golden-value test cross-checked against `install.sh`'s
  `member_hash` (itself byte-verified against both reference implementations).
- **Hand-rolled flat frontmatter parser, not serde_yaml.** Format-1 manifests are flat string
  scalars (spec §2 grammar), and the spec demands duplicate-key detection — which serde_yaml
  silently merges. A strict subset parser is smaller, spec-faithful, and testable.
- **No timestamps/clock in the library.** `installedAt` is a caller-supplied string; the TUI
  owns time.

### Task 4: Scaffold the crate

**Files:**
- Create: `crates/grimoire-pack/Cargo.toml`
- Create: `crates/grimoire-pack/.gitignore`
- Create: `crates/grimoire-pack/src/lib.rs`

- [ ] **Step 1: Check the toolchain**

Run: `cargo --version`
Expected: any recent stable (1.7x+). If missing, stop and report — don't install toolchains
unprompted.

- [ ] **Step 2: Create the crate**

```sh
mkdir -p crates
cargo new --lib crates/grimoire-pack --name grimoire-pack --vcs none
printf '/target\n' > crates/grimoire-pack/.gitignore
```

Write `crates/grimoire-pack/Cargo.toml`:

```toml
[package]
name = "grimoire-pack"
version = "0.1.0"
edition = "2021"
description = "Pack format (format 1) reference library: PACK.md manifests, grimoire.lock, member hashing, discovery"
license = "MIT OR Apache-2.0"

[dependencies]
semver = "1"
serde = { version = "1", features = ["derive"] }
serde_json = { version = "1", features = ["preserve_order"] }
sha2 = "0.10"
thiserror = "1"

[dev-dependencies]
tempfile = "3"
```

- [ ] **Step 3: Write the error type in `src/lib.rs`**

```rust
//! Reference library for the pack format, revision 1
//! (`docs/spec/pack-format.md`): `PACK.md` manifests, `grimoire.lock`,
//! member content hashing (Appendix A), and discovery (Appendix B).

use std::path::PathBuf;

pub mod frontmatter;

#[derive(Debug, thiserror::Error)]
pub enum PackError {
    #[error("io error at {path}: {source}")]
    Io {
        path: PathBuf,
        #[source]
        source: std::io::Error,
    },
    #[error("invalid frontmatter: {0}")]
    Frontmatter(String),
    #[error("invalid manifest: {0}")]
    Manifest(String),
    #[error("unsupported pack format {0} (this library implements format 1)")]
    UnsupportedFormat(u64),
    #[error("invalid pack shape: {0}")]
    Shape(String),
    #[error("lock is read-only: {0}")]
    LockReadOnly(String),
    #[error("invalid lock: {0}")]
    Lock(String),
}

pub type Result<T> = std::result::Result<T, PackError>;
```

Also create an empty `src/frontmatter.rs` so it compiles:

```rust
// Task 5 fills this in.
```

- [ ] **Step 4: Verify it builds**

Run: `cd crates/grimoire-pack && cargo test`
Expected: compiles, `0 passed` (delete the `cargo new` template test in `lib.rs` if one was
generated — the file above replaces it entirely).

- [ ] **Step 5: Commit**

```sh
git status --short && git log --oneline -3
git commit -m "pack-format(crate): scaffold grimoire-pack -- error type, deps, no workspace root yet (sub-project 2 adds it)" \
  -- crates/grimoire-pack
```

### Task 5: Frontmatter parser

**Files:**
- Modify: `crates/grimoire-pack/src/frontmatter.rs`

- [ ] **Step 1: Write the failing tests** (bottom of `src/frontmatter.rs`)

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_flat_pairs_in_order() {
        let fm = "---\nname: alpha\nversion: 1.0.0\n---\nbody\n";
        let pairs = parse(fm).unwrap();
        assert_eq!(
            pairs,
            vec![
                ("name".to_string(), "alpha".to_string()),
                ("version".to_string(), "1.0.0".to_string())
            ]
        );
    }

    #[test]
    fn strips_quotes_comments_and_blanks() {
        let fm = "---\n# a comment\ndescription: \"One: two\"\n\nrequired: a, b  # trailing\n---\n";
        let pairs = parse(fm).unwrap();
        assert_eq!(pairs[0].1, "One: two");
        assert_eq!(pairs[1].1, "a, b");
    }

    #[test]
    fn duplicate_keys_are_an_error() {
        let fm = "---\nname: a\nname: b\n---\n";
        assert!(matches!(parse(fm), Err(crate::PackError::Frontmatter(_))));
    }

    #[test]
    fn unfenced_input_is_an_error() {
        assert!(parse("name: a\n").is_err());
        assert!(parse("---\nname: a\n").is_err()); // no closing fence
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cargo test -p grimoire-pack` (from `crates/grimoire-pack`: `cargo test`)
Expected: FAIL — `parse` not found.

- [ ] **Step 3: Implement `parse`** (top of `src/frontmatter.rs`)

```rust
//! A flat scalar frontmatter block: `key: value` lines between `---` fences.
//! Format-1 manifests are flat string scalars only (spec §2), so this parser is
//! deliberately a strict subset of YAML: `#` comment lines and blanks are
//! skipped, values may be double-quoted (protecting `#` and `:`), an unquoted
//! trailing ` #...` is stripped, and duplicate keys are an error (spec §2).

use crate::{PackError, Result};

pub fn parse(text: &str) -> Result<Vec<(String, String)>> {
    let mut lines = text.lines();
    if lines.next().map(str::trim_end) != Some("---") {
        return Err(PackError::Frontmatter("no opening --- fence".into()));
    }
    let mut pairs: Vec<(String, String)> = Vec::new();
    let mut closed = false;
    for line in lines {
        if line.trim_end() == "---" {
            closed = true;
            break;
        }
        let t = line.trim();
        if t.is_empty() || t.starts_with('#') {
            continue;
        }
        let (key, rest) = t
            .split_once(':')
            .ok_or_else(|| PackError::Frontmatter(format!("not a `key: value` line: {line}")))?;
        let key = key.trim();
        let key_ok = !key.is_empty()
            && key
                .chars()
                .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_');
        if !key_ok {
            return Err(PackError::Frontmatter(format!("bad key: {key}")));
        }
        if pairs.iter().any(|(k, _)| k == key) {
            return Err(PackError::Frontmatter(format!("duplicate key: {key}")));
        }
        let mut value = rest.trim().to_string();
        if value.len() >= 2 && value.starts_with('"') && value.ends_with('"') {
            value = value[1..value.len() - 1].to_string();
        } else if let Some(i) = value.find(" #") {
            value.truncate(i);
            let trimmed = value.trim_end().len();
            value.truncate(trimmed);
        }
        pairs.push((key.to_string(), value));
    }
    if !closed {
        return Err(PackError::Frontmatter("no closing --- fence".into()));
    }
    Ok(pairs)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cargo test`
Expected: 4 passed.

- [ ] **Step 5: Commit**

```sh
git commit -m "pack-format(crate): flat frontmatter parser -- ordered pairs, quote/comment handling, duplicate keys rejected" \
  -- crates/grimoire-pack/src/frontmatter.rs
```

### Task 6: Manifest model and §2 grammar

**Files:**
- Create: `crates/grimoire-pack/src/manifest.rs`
- Modify: `crates/grimoire-pack/src/lib.rs` (add `pub mod manifest;`)

- [ ] **Step 1: Write the failing tests** (bottom of `src/manifest.rs`)

```rust
#[cfg(test)]
mod tests {
    use super::*;

    const OK: &str = "---\nname: clank\nversion: 1.2.3\ndescription: \"a pack\"\nrequired: alpha, beta\noptional: gamma\ncore: clank, alpha\n---\nbody\n";

    #[test]
    fn parses_a_valid_manifest() {
        let m = Manifest::parse(OK).unwrap();
        assert_eq!(m.name, "clank");
        assert_eq!(m.version.to_string(), "1.2.3");
        assert_eq!(m.required, vec!["alpha", "beta"]);
        assert_eq!(m.optional, vec!["gamma"]);
        assert_eq!(m.format, None);
        assert_eq!(m.unknown, vec![("core".to_string(), "clank, alpha".to_string())]);
        assert!(m.is_supported());
    }

    #[test]
    fn format_absent_means_one_and_present_must_be_positive_int() {
        let m = Manifest::parse(&OK.replace("core: clank, alpha", "format: 1")).unwrap();
        assert_eq!(m.format, Some(1));
        assert!(Manifest::parse(&OK.replace("core: clank, alpha", "format: 0")).is_err());
        assert!(Manifest::parse(&OK.replace("core: clank, alpha", "format: x")).is_err());
    }

    #[test]
    fn unsupported_format_is_a_typed_error() {
        let e = Manifest::parse(&OK.replace("core: clank, alpha", "format: 2")).unwrap_err();
        assert!(matches!(e, crate::PackError::UnsupportedFormat(2)));
    }

    #[test]
    fn grammar_violations_are_errors() {
        // empty token
        assert!(Manifest::parse(&OK.replace("alpha, beta", "alpha,, beta")).is_err());
        // bad name chars
        assert!(Manifest::parse(&OK.replace("alpha, beta", "Alpha")).is_err());
        // dup across the two lists
        assert!(Manifest::parse(&OK.replace("optional: gamma", "optional: alpha")).is_err());
        // required: missing entirely
        assert!(Manifest::parse(&OK.replace("required: alpha, beta\n", "")).is_err());
        // bad semver
        assert!(Manifest::parse(&OK.replace("1.2.3", "1.2")).is_err());
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cargo test`
Expected: FAIL — module/type not found (add `pub mod manifest;` to `lib.rs` first so the
failure is about the type, not the module).

- [ ] **Step 3: Implement** (top of `src/manifest.rs`)

```rust
//! The `PACK.md` machine surface: frontmatter model + §2 grammar validation.

use crate::{frontmatter, PackError, Result};

pub const FORMAT: u64 = 1;

#[derive(Debug, Clone, PartialEq)]
pub struct Manifest {
    pub name: String,
    pub version: semver::Version,
    pub description: String,
    pub required: Vec<String>,
    pub optional: Vec<String>,
    /// Declared format revision; `None` means absent = format 1 (spec §2).
    pub format: Option<u64>,
    /// Keys this format does not claim, in file order (spec §2: preserved).
    pub unknown: Vec<(String, String)>,
}

/// Skill-name grammar: `[a-z0-9-]+` (spec §2).
pub fn is_valid_name(s: &str) -> bool {
    !s.is_empty()
        && s.chars()
            .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-')
}

fn split_list(key: &str, raw: &str) -> Result<Vec<String>> {
    let mut out = Vec::new();
    for tok in raw.split(',') {
        let t = tok.trim();
        if t.is_empty() {
            return Err(PackError::Manifest(format!("{key}: empty token")));
        }
        if !is_valid_name(t) {
            return Err(PackError::Manifest(format!("{key}: bad skill name: {t}")));
        }
        out.push(t.to_string());
    }
    Ok(out)
}

impl Manifest {
    pub fn parse(text: &str) -> Result<Manifest> {
        let pairs = frontmatter::parse(text)?;
        let mut name = None;
        let mut version = None;
        let mut description = None;
        let mut required = None;
        let mut optional = Vec::new();
        let mut format = None;
        let mut unknown = Vec::new();
        for (k, v) in pairs {
            match k.as_str() {
                "name" => name = Some(v),
                "version" => version = Some(v),
                "description" => description = Some(v),
                "required" => required = Some(split_list("required", &v)?),
                "optional" => optional = split_list("optional", &v)?,
                "format" => {
                    let n: u64 = v
                        .parse()
                        .map_err(|_| PackError::Manifest(format!("format: not an integer: {v}")))?;
                    if n == 0 {
                        return Err(PackError::Manifest("format: must be positive".into()));
                    }
                    format = Some(n);
                }
                _ => unknown.push((k, v)),
            }
        }
        if let Some(n) = format {
            if n != FORMAT {
                return Err(PackError::UnsupportedFormat(n));
            }
        }
        let name = name.ok_or_else(|| PackError::Manifest("name: missing".into()))?;
        if !is_valid_name(&name) {
            return Err(PackError::Manifest(format!("name: bad pack name: {name}")));
        }
        let version = version.ok_or_else(|| PackError::Manifest("version: missing".into()))?;
        let version = semver::Version::parse(&version)
            .map_err(|e| PackError::Manifest(format!("version: not semver: {e}")))?;
        let description =
            description.ok_or_else(|| PackError::Manifest("description: missing".into()))?;
        let required =
            required.ok_or_else(|| PackError::Manifest("required: missing".into()))?;
        let mut seen = std::collections::HashSet::new();
        for n in required.iter().chain(optional.iter()) {
            if !seen.insert(n.as_str()) {
                return Err(PackError::Manifest(format!("member listed twice: {n}")));
            }
        }
        Ok(Manifest {
            name,
            version,
            description,
            required,
            optional,
            format,
            unknown,
        })
    }

    pub fn is_supported(&self) -> bool {
        self.format.unwrap_or(FORMAT) == FORMAT
    }

    /// All declared members, required first (the face is NOT in this list — it
    /// is implicit, spec §2).
    pub fn members(&self) -> impl Iterator<Item = &str> {
        self.required
            .iter()
            .chain(self.optional.iter())
            .map(String::as_str)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cargo test`
Expected: all pass (8 total so far).

- [ ] **Step 5: Commit**

```sh
git commit -m "pack-format(crate): manifest model -- spec 2 grammar, format optional-default-1, unknown keys preserved" \
  -- crates/grimoire-pack/src/manifest.rs crates/grimoire-pack/src/lib.rs
```

### Task 7: Appendix A member hash

**Files:**
- Create: `crates/grimoire-pack/src/hash.rs`
- Modify: `crates/grimoire-pack/src/lib.rs` (add `pub mod hash;`)

- [ ] **Step 1: Compute the golden value**

Build a tiny fixture by hand and hash it with the same algorithm `install.sh` uses (this
pins parity with the shell implementation, which is byte-verified against the reference
implementations):

```sh
D=$(mktemp -d)/skill && mkdir -p "$D/sub"
printf 'alpha\n' > "$D/a.txt"
printf 'beta\n'  > "$D/sub/b.txt"
( cd "$D" && find . \( -name .git -o -name node_modules \) -prune -o -type f -print \
  | sed 's|^\./||' | LC_ALL=C sort \
  | while IFS= read -r f; do printf '%s' "$f"; cat "./$f"; done | shasum -a 256 )
```

Record the printed hex digest — it goes into the test below as `GOLDEN`.

- [ ] **Step 2: Write the failing tests** (bottom of `src/hash.rs`)

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    // Computed in plan Task 7 Step 1 via install.sh's algorithm; parity anchor.
    const GOLDEN: &str = "sha256:<hex from Step 1>";

    fn fixture() -> tempfile::TempDir {
        let t = tempfile::tempdir().unwrap();
        fs::create_dir_all(t.path().join("sub")).unwrap();
        fs::write(t.path().join("a.txt"), "alpha\n").unwrap();
        fs::write(t.path().join("sub/b.txt"), "beta\n").unwrap();
        t
    }

    #[test]
    fn matches_the_ecosystem_hash() {
        assert_eq!(member_hash(fixture().path()).unwrap(), GOLDEN);
    }

    #[test]
    fn ignores_git_and_node_modules() {
        let t = fixture();
        fs::create_dir_all(t.path().join(".git")).unwrap();
        fs::write(t.path().join(".git/junk"), "x").unwrap();
        fs::create_dir_all(t.path().join("node_modules")).unwrap();
        fs::write(t.path().join("node_modules/junk"), "x").unwrap();
        assert_eq!(member_hash(t.path()).unwrap(), GOLDEN);
    }

    #[test]
    fn content_changes_the_hash() {
        let t = fixture();
        fs::write(t.path().join("a.txt"), "ALPHA\n").unwrap();
        assert_ne!(member_hash(t.path()).unwrap(), GOLDEN);
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cargo test`
Expected: FAIL — `member_hash` not found.

- [ ] **Step 4: Implement** (top of `src/hash.rs`)

```rust
//! Appendix A: the member content hash — byte-identical to the ecosystem's
//! skill-folder hash. Regular files only (symlinks skipped, not followed),
//! `.git`/`node_modules` pruned, `/`-joined relative paths sorted by byte
//! order, sha256 over path-bytes + content-bytes per pair, no delimiters.

use crate::{PackError, Result};
use sha2::Digest;
use std::fs;
use std::path::{Path, PathBuf};

pub fn member_hash(dir: &Path) -> Result<String> {
    let mut files: Vec<(String, PathBuf)> = Vec::new();
    collect(dir, dir, &mut files)?;
    files.sort_by(|a, b| a.0.as_bytes().cmp(b.0.as_bytes()));
    let mut h = sha2::Sha256::new();
    for (rel, abs) in &files {
        h.update(rel.as_bytes());
        h.update(&fs::read(abs).map_err(|e| PackError::Io {
            path: abs.clone(),
            source: e,
        })?);
    }
    Ok(format!("sha256:{:x}", h.finalize()))
}

fn collect(base: &Path, dir: &Path, out: &mut Vec<(String, PathBuf)>) -> Result<()> {
    let entries = fs::read_dir(dir).map_err(|e| PackError::Io {
        path: dir.to_path_buf(),
        source: e,
    })?;
    for entry in entries {
        let entry = entry.map_err(|e| PackError::Io {
            path: dir.to_path_buf(),
            source: e,
        })?;
        let ft = entry.file_type().map_err(|e| PackError::Io {
            path: entry.path(),
            source: e,
        })?; // file_type() does not follow symlinks
        if ft.is_dir() {
            let name = entry.file_name();
            if name == ".git" || name == "node_modules" {
                continue;
            }
            collect(base, &entry.path(), out)?;
        } else if ft.is_file() {
            let rel = entry
                .path()
                .strip_prefix(base)
                .expect("child of base")
                .components()
                .map(|c| c.as_os_str().to_string_lossy().into_owned())
                .collect::<Vec<_>>()
                .join("/");
            out.push((rel, entry.path()));
        }
        // symlinks and other entry types: skipped (Appendix A)
    }
    Ok(())
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cargo test`
Expected: all pass. If the golden test fails, re-run Step 1 and check the constant — do NOT
"fix" the algorithm to match a guessed value.

- [ ] **Step 6: Commit**

```sh
git commit -m "pack-format(crate): appendix A member hash -- golden parity with install.sh member_hash" \
  -- crates/grimoire-pack/src/hash.rs crates/grimoire-pack/src/lib.rs
```

### Task 8: Appendix B discovery

**Files:**
- Create: `crates/grimoire-pack/src/discovery.rs`
- Modify: `crates/grimoire-pack/src/lib.rs` (add `pub mod discovery;`)

- [ ] **Step 1: Write the failing tests** (bottom of `src/discovery.rs`)

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::path::Path;

    fn skill(root: &Path, rel: &str, name: Option<&str>) {
        let d = root.join(rel);
        fs::create_dir_all(&d).unwrap();
        let fm = match name {
            Some(n) => format!("---\nname: {n}\ndescription: t\n---\n"),
            None => "no frontmatter here".to_string(),
        };
        fs::write(d.join("SKILL.md"), fm).unwrap();
    }

    #[test]
    fn root_skill_dir_is_the_sole_discovery() {
        let t = tempfile::tempdir().unwrap();
        skill(t.path(), ".", Some("root-skill"));
        skill(t.path(), "skills/inner", Some("inner"));
        let found = discover(t.path(), false).unwrap();
        assert_eq!(found.len(), 1);
        assert_eq!(found[0].name, "root-skill");
    }

    #[test]
    fn priority_dirs_one_level_deep_with_name_fallback() {
        let t = tempfile::tempdir().unwrap();
        skill(t.path(), "skills/alpha", Some("alpha"));
        skill(t.path(), "skills/noname", None); // falls back to dir name
        skill(t.path(), ".claude/skills/beta", Some("beta"));
        skill(t.path(), "skills/alpha/nested", Some("hidden")); // 2 levels: not seen shallow
        let names: Vec<_> = discover(t.path(), false)
            .unwrap()
            .into_iter()
            .map(|s| s.name)
            .collect();
        assert!(names.contains(&"alpha".to_string()));
        assert!(names.contains(&"noname".to_string()));
        assert!(names.contains(&"beta".to_string()));
        assert!(!names.contains(&"hidden".to_string()));
    }

    #[test]
    fn full_depth_finds_nested_and_first_seen_wins_on_dup_names() {
        let t = tempfile::tempdir().unwrap();
        skill(t.path(), "skills/alpha", Some("twin"));
        skill(t.path(), "skills/beta", Some("twin"));
        skill(t.path(), "deep/down/gamma", Some("gamma"));
        let found = discover(t.path(), true).unwrap();
        let twins: Vec<_> = found.iter().filter(|s| s.name == "twin").collect();
        assert_eq!(twins.len(), 1); // first-seen wins
        assert!(found.iter().any(|s| s.name == "gamma"));
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cargo test`
Expected: FAIL — `discover` not found.

- [ ] **Step 3: Implement** (top of `src/discovery.rs`)

```rust
//! Appendix B: discovery. A skill directory is a directory containing
//! `SKILL.md`. Shallow discovery scans the root + fixed priority directories
//! one level deep; full-depth (used for pack enumeration and member
//! resolution, §1/§2) recurses. First-seen wins on duplicate names; identity
//! is `name:` in `SKILL.md` frontmatter, directory name as fallback.

use crate::{PackError, Result};
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, PartialEq)]
pub struct Skill {
    pub name: String,
    pub dir: PathBuf,
}

/// The priority directories scanned one level deep (Appendix B step 2).
const PRIORITY_DIRS: &[&str] = &["skills", ".agents/skills", ".claude/skills", ".codex/skills"];

pub fn is_skill_dir(dir: &Path) -> bool {
    dir.join("SKILL.md").is_file()
}

/// `name:` from SKILL.md frontmatter, directory basename as fallback.
/// Lenient by design: SKILL.md is a foreign format — a first `name:` line
/// inside the fence is taken as-is, malformed files fall back.
pub fn skill_name(dir: &Path) -> String {
    let fallback = || {
        dir.file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .unwrap_or_default()
    };
    let Ok(text) = fs::read_to_string(dir.join("SKILL.md")) else {
        return fallback();
    };
    let mut lines = text.lines();
    if lines.next().map(str::trim_end) != Some("---") {
        return fallback();
    }
    for line in lines {
        if line.trim_end() == "---" {
            break;
        }
        if let Some(rest) = line.strip_prefix("name:") {
            let v = rest.trim();
            if !v.is_empty() {
                return v.to_string();
            }
        }
    }
    fallback()
}

pub fn discover(root: &Path, full_depth: bool) -> Result<Vec<Skill>> {
    let mut found: Vec<Skill> = Vec::new();
    if is_skill_dir(root) && !full_depth {
        push(&mut found, root);
        return Ok(found);
    }
    if !full_depth {
        for child in children(root)? {
            if is_skill_dir(&child) {
                push(&mut found, &child);
            }
        }
        for p in PRIORITY_DIRS {
            let dir = root.join(p);
            if !dir.is_dir() {
                continue;
            }
            for child in children(&dir)? {
                if is_skill_dir(&child) {
                    push(&mut found, &child);
                }
            }
        }
        if !found.is_empty() {
            return Ok(found);
        }
    }
    // Full-depth (or shallow-found-nothing fallback): bounded recursive scan.
    walk(root, 0, &mut found)?;
    Ok(found)
}

fn push(found: &mut Vec<Skill>, dir: &Path) {
    let name = skill_name(dir);
    if !found.iter().any(|s| s.name == name) {
        found.push(Skill {
            name,
            dir: dir.to_path_buf(),
        });
    }
}

fn children(dir: &Path) -> Result<Vec<PathBuf>> {
    let rd = fs::read_dir(dir).map_err(|e| PackError::Io {
        path: dir.to_path_buf(),
        source: e,
    })?;
    let mut out: Vec<PathBuf> = rd
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().map(|t| t.is_dir()).unwrap_or(false))
        .map(|e| e.path())
        .collect();
    out.sort(); // deterministic first-seen order
    Ok(out)
}

const MAX_DEPTH: usize = 12;

fn walk(dir: &Path, depth: usize, found: &mut Vec<Skill>) -> Result<()> {
    if depth > MAX_DEPTH {
        return Ok(());
    }
    if is_skill_dir(dir) && depth > 0 {
        push(found, dir);
        // skills do not nest in discovery: don't descend into a skill dir
        return Ok(());
    }
    for child in children(dir)? {
        let base = child.file_name().unwrap_or_default();
        if base == ".git" || base == "node_modules" || base == "target" {
            continue;
        }
        walk(&child, depth + 1, found)?;
    }
    Ok(())
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cargo test`
Expected: all pass.

- [ ] **Step 5: Commit**

```sh
git commit -m "pack-format(crate): appendix B discovery -- priority dirs, full-depth walk, first-seen wins, name fallback" \
  -- crates/grimoire-pack/src/discovery.rs crates/grimoire-pack/src/lib.rs
```

### Task 9: §1 pack shapes, member resolution, enumeration + conformance fixtures

**Files:**
- Create: `crates/grimoire-pack/src/pack.rs`
- Create: `crates/grimoire-pack/tests/conformance.rs`
- Create: `crates/grimoire-pack/tests/fixtures/` (eight fixture trees, below)
- Modify: `crates/grimoire-pack/src/lib.rs` (add `pub mod pack;`)

- [ ] **Step 1: Build the fixture trees**

Each `SKILL.md` below is exactly `---\nname: <n>\ndescription: t\n---\nbody\n`; each `PACK.md`
body is one line `runbook\n` after the fence. Create:

```
tests/fixtures/faced-valid/skills/alpha/PACK.md      name: alpha / version: 1.0.0 / description: "p" / required: beta / optional: gamma
tests/fixtures/faced-valid/skills/alpha/SKILL.md     name: alpha
tests/fixtures/faced-valid/skills/beta/SKILL.md      name: beta
tests/fixtures/faced-valid/skills/gamma/SKILL.md     name: gamma

tests/fixtures/faceless-valid/PACK.md                name: bundle / version: 1.0.0 / description: "p" / required: beta, gamma
tests/fixtures/faceless-valid/skills/beta/SKILL.md   name: beta
tests/fixtures/faceless-valid/skills/gamma/SKILL.md  name: gamma

tests/fixtures/invalid-nested/       — copy of faced-valid plus skills/alpha/sub/SKILL.md (name: sub)
tests/fixtures/invalid-unresolvable/ — copy of faced-valid with alpha/PACK.md required: ghost
tests/fixtures/invalid-face-mismatch/— copy of faced-valid with alpha/SKILL.md name: wrong
tests/fixtures/invalid-listed-face/  — copy of faced-valid with alpha/PACK.md required: beta, alpha
tests/fixtures/invalid-faceless-nonroot/skills/loose/PACK.md   name: loose / version: 1.0.0 / description: "p" / required: beta   (no SKILL.md sibling)
tests/fixtures/invalid-faceless-nonroot/skills/beta/SKILL.md   name: beta

tests/fixtures/invalid-dup-name/skills/a1/{PACK.md,SKILL.md}   both name: twin / required: beta
tests/fixtures/invalid-dup-name/skills/a2/{PACK.md,SKILL.md}   both name: twin / required: beta
tests/fixtures/invalid-dup-name/skills/beta/SKILL.md           name: beta
```

Shell to generate them (run from `crates/grimoire-pack`):

```sh
fx=tests/fixtures
sk() { mkdir -p "$1"; printf -- '---\nname: %s\ndescription: t\n---\nbody\n' "$2" > "$1/SKILL.md"; }
pk() { mkdir -p "$(dirname "$1")"; printf -- '---\n%s\n---\nrunbook\n' "$2" > "$1"; }

sk $fx/faced-valid/skills/alpha alpha; sk $fx/faced-valid/skills/beta beta; sk $fx/faced-valid/skills/gamma gamma
pk $fx/faced-valid/skills/alpha/PACK.md 'name: alpha
version: 1.0.0
description: "p"
required: beta
optional: gamma'

sk $fx/faceless-valid/skills/beta beta; sk $fx/faceless-valid/skills/gamma gamma
pk $fx/faceless-valid/PACK.md 'name: bundle
version: 1.0.0
description: "p"
required: beta, gamma'

cp -R $fx/faced-valid $fx/invalid-nested && sk $fx/invalid-nested/skills/alpha/sub sub
cp -R $fx/faced-valid $fx/invalid-unresolvable
pk $fx/invalid-unresolvable/skills/alpha/PACK.md 'name: alpha
version: 1.0.0
description: "p"
required: ghost'
cp -R $fx/faced-valid $fx/invalid-face-mismatch && sk $fx/invalid-face-mismatch/skills/alpha wrong
cp -R $fx/faced-valid $fx/invalid-listed-face
pk $fx/invalid-listed-face/skills/alpha/PACK.md 'name: alpha
version: 1.0.0
description: "p"
required: beta, alpha'
sk $fx/invalid-faceless-nonroot/skills/beta beta
pk $fx/invalid-faceless-nonroot/skills/loose/PACK.md 'name: loose
version: 1.0.0
description: "p"
required: beta'

sk $fx/invalid-dup-name/skills/beta beta
for d in a1 a2; do
  sk $fx/invalid-dup-name/skills/$d twin
  pk $fx/invalid-dup-name/skills/$d/PACK.md 'name: twin
version: 1.0.0
description: "p"
required: beta'
done
```

- [ ] **Step 2: Write the failing conformance tests** (`tests/conformance.rs`)

```rust
//! Conformance fixtures: one directory per spec case (§1/§2). These trees are
//! the format's executable examples — extend them as the spec evolves.

use grimoire_pack::pack::{enumerate, PackShape};
use grimoire_pack::PackError;
use std::path::PathBuf;

fn fixture(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(name)
}

#[test]
fn faced_pack_enumerates_with_resolved_members() {
    let packs = enumerate(&fixture("faced-valid")).unwrap();
    assert_eq!(packs.len(), 1);
    let p = &packs[0];
    assert_eq!(p.manifest.name, "alpha");
    assert!(matches!(p.shape, PackShape::Faced { .. }));
    assert_eq!(p.manifest.required, vec!["beta"]);
}

#[test]
fn faceless_root_pack_is_manifest_only() {
    let packs = enumerate(&fixture("faceless-valid")).unwrap();
    assert_eq!(packs.len(), 1);
    assert_eq!(packs[0].manifest.name, "bundle");
    assert!(matches!(packs[0].shape, PackShape::Faceless));
}

#[test]
fn nested_skill_below_a_faced_pack_dir_is_invalid() {
    assert!(matches!(
        enumerate(&fixture("invalid-nested")),
        Err(PackError::Shape(_))
    ));
}

#[test]
fn unresolvable_member_is_invalid() {
    assert!(matches!(
        enumerate(&fixture("invalid-unresolvable")),
        Err(PackError::Shape(_))
    ));
}

#[test]
fn face_name_mismatch_is_invalid() {
    assert!(matches!(
        enumerate(&fixture("invalid-face-mismatch")),
        Err(PackError::Shape(_))
    ));
}

#[test]
fn face_listed_as_member_is_invalid() {
    assert!(matches!(
        enumerate(&fixture("invalid-listed-face")),
        Err(PackError::Shape(_))
    ));
}

#[test]
fn faceless_manifest_off_root_is_invalid() {
    assert!(matches!(
        enumerate(&fixture("invalid-faceless-nonroot")),
        Err(PackError::Shape(_))
    ));
}

#[test]
fn two_manifests_with_one_pack_name_are_invalid() {
    assert!(matches!(
        enumerate(&fixture("invalid-dup-name")),
        Err(PackError::Shape(_))
    ));
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cargo test`
Expected: FAIL — `pack` module not found.

- [ ] **Step 4: Implement** (`src/pack.rs`)

```rust
//! §1: pack shapes and enumeration. A faced pack is a skill directory that
//! also contains `PACK.md` (its `SKILL.md` is the face); a faceless pack is a
//! `PACK.md` at the repository root with no sibling `SKILL.md` —
//! manifest-only. Enumeration is a full-depth operation.

use crate::discovery::{self, Skill};
use crate::manifest::Manifest;
use crate::{PackError, Result};
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, PartialEq)]
pub enum PackShape {
    Faced { dir: PathBuf },
    Faceless,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Pack {
    pub manifest: Manifest,
    pub manifest_path: PathBuf,
    pub shape: PackShape,
}

/// Enumerate and validate every pack in the repository (spec §1, §2).
pub fn enumerate(root: &Path) -> Result<Vec<Pack>> {
    let skills = discovery::discover(root, true)?;
    let mut manifests: Vec<PathBuf> = Vec::new();
    for s in &skills {
        let m = s.dir.join("PACK.md");
        if m.is_file() {
            manifests.push(m);
        }
    }
    let root_manifest = root.join("PACK.md");
    if root_manifest.is_file() && !discovery::is_skill_dir(root) {
        manifests.push(root_manifest);
    }
    // A PACK.md beside no SKILL.md anywhere below the root is invalid — find those too.
    find_stray_manifests(root, 0, &skills, &mut manifests)?;

    let mut packs: Vec<Pack> = Vec::new();
    for path in manifests {
        let pack = validate_one(root, &path, &skills)?;
        if packs.iter().any(|p| p.manifest.name == pack.manifest.name) {
            return Err(PackError::Shape(format!(
                "two manifests declare the pack name {}",
                pack.manifest.name
            )));
        }
        packs.push(pack);
    }
    Ok(packs)
}

fn validate_one(root: &Path, manifest_path: &Path, skills: &[Skill]) -> Result<Pack> {
    let text = std::fs::read_to_string(manifest_path).map_err(|e| PackError::Io {
        path: manifest_path.to_path_buf(),
        source: e,
    })?;
    let manifest = Manifest::parse(&text)?;
    let dir = manifest_path.parent().expect("manifest has a parent");

    let shape = if discovery::is_skill_dir(dir) {
        // Faced: face name must equal manifest name; nothing nests below (§1).
        let face = discovery::skill_name(dir);
        if face != manifest.name {
            return Err(PackError::Shape(format!(
                "face name {face} != pack name {}",
                manifest.name
            )));
        }
        assert_nothing_nested(dir)?;
        if manifest.members().any(|m| m == manifest.name) {
            return Err(PackError::Shape(format!(
                "face {} must not be listed as a member (it is implicit)",
                manifest.name
            )));
        }
        PackShape::Faced {
            dir: dir.to_path_buf(),
        }
    } else {
        // Faceless: only valid at the repository root (§1).
        if dir != root {
            return Err(PackError::Shape(format!(
                "faceless PACK.md off the repository root: {}",
                manifest_path.display()
            )));
        }
        if manifest.members().any(|m| m == manifest.name) {
            return Err(PackError::Shape(format!(
                "faceless pack {} lists a member with its own name",
                manifest.name
            )));
        }
        PackShape::Faceless
    };

    for member in manifest.members() {
        if !skills.iter().any(|s| s.name == member) {
            return Err(PackError::Shape(format!(
                "member {member} does not resolve in this repository"
            )));
        }
    }
    Ok(Pack {
        manifest,
        manifest_path: manifest_path.to_path_buf(),
        shape,
    })
}

/// §1: a faced pack directory MUST NOT contain further SKILL.md or PACK.md below it.
fn assert_nothing_nested(pack_dir: &Path) -> Result<()> {
    fn walk(dir: &Path, top: bool) -> Result<()> {
        for entry in std::fs::read_dir(dir)
            .map_err(|e| PackError::Io {
                path: dir.to_path_buf(),
                source: e,
            })?
            .filter_map(|e| e.ok())
        {
            let p = entry.path();
            if p.is_dir() {
                walk(&p, false)?;
            } else if !top {
                let base = p.file_name().unwrap_or_default();
                if base == "SKILL.md" || base == "PACK.md" {
                    return Err(PackError::Shape(format!(
                        "nested {} below a faced pack dir: {}",
                        base.to_string_lossy(),
                        p.display()
                    )));
                }
            }
        }
        Ok(())
    }
    walk(pack_dir, true)
}

/// A PACK.md that is neither beside a SKILL.md nor at the root is invalid (§1).
fn find_stray_manifests(
    dir: &Path,
    depth: usize,
    _skills: &[Skill],
    manifests: &mut Vec<PathBuf>,
) -> Result<()> {
    if depth > 12 {
        return Ok(());
    }
    for entry in std::fs::read_dir(dir)
        .map_err(|e| PackError::Io {
            path: dir.to_path_buf(),
            source: e,
        })?
        .filter_map(|e| e.ok())
    {
        let p = entry.path();
        let base = entry.file_name();
        if p.is_dir() {
            if base == ".git" || base == "node_modules" || base == "target" {
                continue;
            }
            find_stray_manifests(&p, depth + 1, _skills, manifests)?;
        } else if base == "PACK.md" && depth > 0 && !manifests.contains(&p) {
            // found a PACK.md that full-depth skill discovery did not claim
            manifests.push(p);
        }
    }
    Ok(())
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cargo test`
Expected: all pass, including the eight conformance tests.

- [ ] **Step 6: Commit**

```sh
git commit -m "pack-format(crate): pack shapes + enumeration -- spec 1 rules, member resolution, eight conformance fixtures" \
  -- crates/grimoire-pack/src/pack.rs crates/grimoire-pack/src/lib.rs \
     crates/grimoire-pack/tests/conformance.rs crates/grimoire-pack/tests/fixtures
```

### Task 10: `grimoire.lock` model and I/O

**Files:**
- Create: `crates/grimoire-pack/src/lock.rs`
- Modify: `crates/grimoire-pack/src/lib.rs` (add `pub mod lock;`)

- [ ] **Step 1: Write the failing tests** (bottom of `src/lock.rs`)

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::BTreeMap;

    fn entry() -> PackEntry {
        let mut skills = BTreeMap::new();
        skills.insert(
            "alpha".to_string(),
            SkillEntry {
                hash: "sha256:aa".into(),
                required: true,
                extra: Default::default(),
            },
        );
        skills.insert(
            "gamma".to_string(),
            SkillEntry {
                hash: "sha256:cc".into(),
                required: false,
                extra: Default::default(),
            },
        );
        PackEntry {
            version: "1.0.0".into(),
            source: "github:o/r".into(),
            r#ref: Some("abc1234".into()),
            installed_at: "2026-08-08T00:00:00Z".into(),
            skills,
            manifest: None,
            extra: Default::default(),
        }
    }

    #[test]
    fn roundtrip_preserves_unknown_keys() {
        let t = tempfile::tempdir().unwrap();
        let path = t.path().join("grimoire.lock");
        let json = r#"{
  "version": 1,
  "x-note": "keep me",
  "packs": {
    "other": { "version": "2.0.0", "source": "s", "installedAt": "t",
               "skills": {}, "x-owner": "them" }
  }
}"#;
        std::fs::write(&path, json).unwrap();
        let mut lock = read(&path).unwrap().unwrap();
        lock.packs.insert("alpha".to_string(), entry());
        write(&lock, &path).unwrap();
        let out = std::fs::read_to_string(&path).unwrap();
        assert!(out.contains("\"x-note\": \"keep me\""));
        assert!(out.contains("\"x-owner\": \"them\""));
        assert!(out.contains("\"required\": false"));
        assert!(out.ends_with('\n'));
        let again = read(&path).unwrap().unwrap();
        assert_eq!(again.packs.len(), 2);
        assert_eq!(again.packs["alpha"], entry());
    }

    #[test]
    fn absent_lock_reads_as_none() {
        let t = tempfile::tempdir().unwrap();
        assert!(read(&t.path().join("grimoire.lock")).unwrap().is_none());
    }

    #[test]
    fn newer_version_and_garbage_are_read_only_errors() {
        let t = tempfile::tempdir().unwrap();
        let path = t.path().join("grimoire.lock");
        std::fs::write(&path, r#"{"version": 2, "packs": {}}"#).unwrap();
        assert!(matches!(read(&path), Err(crate::PackError::LockReadOnly(_))));
        std::fs::write(&path, "not json").unwrap();
        assert!(matches!(read(&path), Err(crate::PackError::LockReadOnly(_))));
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cargo test`
Expected: FAIL — types not found.

- [ ] **Step 3: Implement** (top of `src/lock.rs`)

```rust
//! §3: the `grimoire.lock` sidecar. Tools are its only writers; unknown keys
//! are preserved; a newer lock version (or an unparseable file) is read-only.
//! The library takes `installedAt` as a caller-supplied string — no clock here.

use crate::{PackError, Result};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::path::Path;

pub const LOCK_VERSION: u64 = 1;
pub const LOCK_FILE: &str = "grimoire.lock";

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SkillEntry {
    pub hash: String,
    pub required: bool,
    #[serde(flatten)]
    pub extra: serde_json::Map<String, serde_json::Value>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PackEntry {
    pub version: String,
    pub source: String,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub r#ref: Option<String>,
    #[serde(rename = "installedAt")]
    pub installed_at: String,
    #[serde(default)]
    pub skills: BTreeMap<String, SkillEntry>,
    /// Faceless packs cache the decoded manifest frontmatter here (§3).
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub manifest: Option<serde_json::Value>,
    #[serde(flatten)]
    pub extra: serde_json::Map<String, serde_json::Value>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Lock {
    pub version: u64,
    #[serde(default)]
    pub packs: BTreeMap<String, PackEntry>,
    #[serde(flatten)]
    pub extra: serde_json::Map<String, serde_json::Value>,
}

impl Default for Lock {
    fn default() -> Self {
        Lock {
            version: LOCK_VERSION,
            packs: BTreeMap::new(),
            extra: serde_json::Map::new(),
        }
    }
}

/// `Ok(None)` when the file does not exist. `LockReadOnly` when it cannot be
/// parsed or declares a newer version — the caller must refuse rewrites (§3).
pub fn read(path: &Path) -> Result<Option<Lock>> {
    let text = match std::fs::read_to_string(path) {
        Ok(t) => t,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(None),
        Err(e) => {
            return Err(PackError::Io {
                path: path.to_path_buf(),
                source: e,
            })
        }
    };
    let value: serde_json::Value = serde_json::from_str(&text)
        .map_err(|e| PackError::LockReadOnly(format!("unparseable: {e}")))?;
    let version = value.get("version").and_then(|v| v.as_u64()).unwrap_or(1);
    if version > LOCK_VERSION {
        return Err(PackError::LockReadOnly(format!(
            "lock version {version} > implemented {LOCK_VERSION}"
        )));
    }
    let lock: Lock = serde_json::from_value(value)
        .map_err(|e| PackError::Lock(format!("malformed lock: {e}")))?;
    Ok(Some(lock))
}

pub fn write(lock: &Lock, path: &Path) -> Result<()> {
    let mut text = serde_json::to_string_pretty(lock)
        .map_err(|e| PackError::Lock(format!("serialize: {e}")))?;
    text.push('\n');
    std::fs::write(path, text).map_err(|e| PackError::Io {
        path: path.to_path_buf(),
        source: e,
    })
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cargo test`
Expected: all pass.

- [ ] **Step 5: Commit**

```sh
git commit -m "pack-format(crate): grimoire.lock model + IO -- unknown keys preserved, newer/unparseable locks read-only, clockless API" \
  -- crates/grimoire-pack/src/lock.rs crates/grimoire-pack/src/lib.rs
```

### Task 11: Real-manifest integration test and close-out

**Files:**
- Create: `crates/grimoire-pack/tests/clankshop.rs`
- Modify: `docs/design/2026-08-08-pack-format-design.md` (status pointer)

- [ ] **Step 1: Write the integration test** (`tests/clankshop.rs`)

The flagship pack in this repository must satisfy the library end-to-end:

```rust
//! The flagship: this repository's own clankshop pack must enumerate and
//! validate against the library. Runs against the live tree two levels up.

use grimoire_pack::pack::{enumerate, PackShape};
use std::path::PathBuf;

fn repo_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .and_then(|p| p.parent())
        .expect("crates/grimoire-pack sits two levels below the repo root")
        .to_path_buf()
}

#[test]
fn clankshop_is_a_valid_faced_pack() {
    let packs = enumerate(&repo_root()).unwrap();
    let clank = packs
        .iter()
        .find(|p| p.manifest.name == "clankshop")
        .expect("clankshop pack found");
    assert!(matches!(clank.shape, PackShape::Faced { .. }));
    assert_eq!(clank.manifest.version.to_string(), "1.0.0");
    assert!(clank.manifest.required.iter().any(|m| m == "foreman"));
    assert_eq!(clank.manifest.optional, vec!["bug", "task"]);
    // the author-extension key rides in unknown, preserved
    assert!(clank.manifest.unknown.iter().any(|(k, _)| k == "core"));
}

#[test]
fn clankshop_member_hashes_compute() {
    let root = repo_root();
    let h = grimoire_pack::hash::member_hash(&root.join("skills/foreman")).unwrap();
    assert!(h.starts_with("sha256:"));
}
```

- [ ] **Step 2: Run it**

Run: `cargo test`
Expected: all pass. If `enumerate` fails on the live tree, the failure is a real finding —
inspect whether the tree or the library is wrong before touching either (the spec decides).

- [ ] **Step 3: Full gate — everything**

```sh
cd ../.. && sh skills/clankshop/scripts/tests/run.sh && bash skills/skill-builder/scripts/skills-lint.sh && cd crates/grimoire-pack && cargo test
```

Expected: `ALL GREEN`, `fails=0 warns=10`, all cargo tests pass.

- [ ] **Step 4: Update the design record**

In `docs/design/2026-08-08-pack-format-design.md`, at the end of the "Owner review" section,
add:

```markdown
**Implementation (2026-08-08+):** shell surfaces conformed to draft 5 and the
`grimoire-pack` crate built per `docs/design/2026-08-08-pack-format-impl-plan.md` — the
crate's `tests/fixtures/` conformance trees are the format's executable examples and the
spec's next truth-finder.
```

- [ ] **Step 5: Commit**

```sh
git status --short && git log --oneline -3
git commit -m "pack-format(crate): clankshop integration test + close-out -- the live pack validates against the library" \
  -- crates/grimoire-pack/tests/clankshop.rs docs/design/2026-08-08-pack-format-design.md
```

---

## Self-review notes (spec coverage)

- §1 shapes/no-nesting/root-only faceless/dup names/identity-authority → Task 9 (+ Task 1 for
  the shell face check). §2 grammar/format rule/unknown keys → Tasks 1, 6. §3 lock
  scopes/schema/read-only/one-bit state → Tasks 2, 10 (single-scope subset in shell; full
  scope targeting is ③'s). §4 semver/hash pinning → Tasks 6, 7. §5 install/remove/check
  engine → out of scope (③), shell keeps its simplified transactional subset (Tasks 1–2 keep
  it conformant). §6 no lifecycle keys → Task 1. §7 conduct → author-facing, no code. §8 —
  informative. Appendix A → Task 7. Appendix B → Task 8.
- Deliberately not built (YAGNI, deferred to ③): adopt/replace, refcounted removal, re-pin,
  source normalization, `check` fact table assembly, faceless manifest caching on install
  (the lock model carries the field; the writer arrives with the tool that installs remote
  packs).
