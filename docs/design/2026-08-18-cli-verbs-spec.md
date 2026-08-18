---
doctype: design
status: open
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# grimoire CLI verbs — Spec

_Reverses the roadmap's binding "TUI-only v0.1" decision (owner, 2026-08-18). Governing docs:
`docs/design/2026-08-15-tui-v0.1-roadmap.md` (to be amended), `docs/spec/pack-format.md` (draft 5,
format 1). Written on the `app` workstream, branch `stream/app`, atop nine unshipped Phase 3
commits._

## Problem

`grimoire` has exactly four command-line arguments — `--version`, `--help`, `--library`,
`--project` — and every verb-shaped invocation is refused:

```
$ grimoire install clankshop
error: unknown argument: install
```

That was deliberate. The brainstorm settled "TUI-only v0.1 … CLI verbs and passthrough sugar are
post-v0.1 layers over `grimoire-core`," and Phase 3 built to it. The owner has reversed that
priority: **the CLI is the more important surface**, and its absence is what blocks real
dogfooding. `install.sh` is currently the only scriptable path, and it is a shell script this
project intends to replace.

The root need is not "add flags." It is that **every operation the tool performs is currently
reachable only by a human pressing keys in a terminal**, which excludes scripting, CI, remote
shells, and any use where the TUI's modal flow is friction rather than help.

## Goal

`grimoire <verb>` performs every v0.1 operation non-interactively, with predictable exit codes,
while bare `grimoire` still opens the TUI. When this is done, `install.sh` has no capability the
binary lacks.

## Approach

**Verbs are an opt-in layer over the operations that already exist.** Phase 2 built
`grimoire-core` UI-agnostic on purpose — synchronous, clockless, homeless, no TTY assumption, with
`tests/boundary.rs` enforcing it — and Phase 3's `job.rs` is already a verb dispatcher in all but
name. Every verb below maps to a core function that is implemented and tested. Exactly one new
core operation is required (`remove::remove_atom`, argued in *Mechanism*).

Bare `grimoire` continues to launch the TUI (owner, 2026-08-18). The two surfaces are peers over
one core, not competitors: `job::run` and the verb dispatcher call the same functions, so a
behavioral divergence between them is a bug, not a design choice.

**Alternatives rejected:**

- *A separate `grimoire-cli` binary.* Two binaries to install, two names to learn, and the shared
  argument/scope plumbing would have to be factored out anyway. The only thing it buys is a
  smaller TUI-free build, which nobody has asked for.
- *Keep TUI-only; script `install.sh`.* This is the status quo, and it is what the owner
  rejected. It also means the shell reference implementation — which this project has been
  steadily proving *against*, not building *on* — becomes permanent infrastructure.
- *CLI-first, TUI behind `grimoire tui`.* Considered and declined by the owner. It would make the
  primary surface obvious, but it breaks the one invocation people have already learned, for a
  signalling benefit.

## Mechanism

### The verb set

Six verbs. Each names the core call it is a thin wrapper over.

| Verb | Core | Notes |
|---|---|---|
| `init` | `config::save` | writes the user config (default library) |
| `init --project [dir]` | — (new: dir + empty lock) | prepares a project as an install target |
| `install <name>` | `install::preflight` → `install::install` | pack by default |
| `install --skill <name>` | `install::install_atom` | single skill, no lock entry |
| `remove <pack>` | `remove::plan_remove` → `remove::remove` | refcounted |
| `remove <pack> --member <m>` | `remove::remove_optional_member` | §5's optional-member removal |
| `remove --skill <name>` | **new** `remove::remove_atom` | see *The one new operation* |
| `list` | `Library::enumerate` | the library, with installed marks |
| `status` | `inventory::inventory` | what is installed at one target |
| `check` | `check::check` | drift, as facts |

`install`, `remove`, `list`, `status`, and `check` are the verbs; `init` is the setup verb.

### Scope grammar

Scope is **always explicit in effect, defaulted in syntax**. Three flags, shared by every verb
that touches or reports on a destination (`install`, `remove`, `list`, `status`, `check`,
`init --project`). `list` takes them because it marks which packs are already installed, and
"installed" is only meaningful against one target:

- `--global` — the agent's global skills dir. **The default when neither is given.**
- `--project [dir]` — project scope. A bare `--project` means the current directory.
- `--agent <id>` — one of `universal` (default), `claude-code`, `codex`, `cursor`.

**The default target is `universal` at global scope** — `~/.agents/skills`, with the lock at
`~/.agents/grimoire.lock` (owner, 2026-08-18). Chosen over `install.sh`'s `~/.claude/skills`
because §3's global lock already lives beside `.agents/`, because `agents.rs` records it as "the
one `install.sh` and this machine actually use," and because a four-agent tool should not
privilege one harness in its default. This is a **deliberate behavioral difference from
`install.sh`** and must be called out in the README when it lands.

Every command prints its resolved destination before acting, so the default is never silent.

### Library resolution

`install`, `list`, and `check` need a library, and they reuse `main.rs`'s existing cascade
unchanged: `--library <path>` → the configured default (`config::load`) → the current directory.

With one difference for verbs. The cwd fallback is right for the TUI — it is what lets a
dogfooder run `grimoire` inside a clone with no setup — but for a verb it turns a missing library
into an empty result rather than an error: `grimoire list` in an unrelated directory would
succeed and print nothing. **A verb that falls through to cwd and finds no packs and no loose
skills exits 2**, naming the three ways to set a library. Silence that looks like success is the
failure mode worth spending an exit code on.

### `--help`

`grimoire --help` lists the verbs. `grimoire <verb> --help` prints that verb's own flags and
exits 0, on every verb — including before any scope or library resolution runs, so `--help` works
in a directory where the command itself would fail.

### `install`

```
grimoire install <name> [--skill] [--skip <member>]... [--global|--project [dir]] [--agent <id>] [--library <path>] [--yes]
```

- A **bare name resolves to a pack** if the library has one by that name, otherwise to a loose
  skill (owner, 2026-08-18). A faced pack's face is a skill of the same name, so this is a real
  ambiguity; packs are the format's primary unit, so they win. `--skill <name>` forces the atom
  install.
- `--skip <member>` (repeatable) declines an optional member. This finally supplies the
  `skip_optional` field that `app.rs` currently hardcodes to `Vec::new()`. Skipping a **required**
  member is a usage error, not a silent no-op — `LibraryPack::selected` ignores it, so the CLI
  must reject it up front.
- Preflight runs first and is **printed**, always: every member with its disposition. Then:
  - all clear → install, print what was linked, exit 0.
  - any `Collision` or `Missing` → **print each blocking member and abort, exit 3.** No prompt, no
    `--force`. §5 permits a tool to resolve a collision by adopt/replace but forbids doing it
    silently, and core implements neither (its `rollback` only unlinks what the run created; §5's
    staging does not exist). Offering a flag that "resolves" it would be exactly the silent
    resolution §5 prohibits. This is Phase 3's D3 decision on a second surface.
- **Reinstall** (`ReplacePlan` present) prints the previous version and source, flags a backward
  version or changed source (§5 MUST), and lists members that will be dropped. Because a drop
  unlinks files, it follows the *destructive-operation rule* below.

### `remove`

```
grimoire remove <pack> [--member <m>] [--skill] [scope flags] [--yes]
```

Prints the removal plan — members to unlink, members retained because another pack still holds
them, foreign links that will be left alone — and §5's teardown warning **before deleting
anything**, while the face still exists to be read. Then the destructive-operation rule.

### The destructive-operation rule

Any operation that unlinks something — `remove`, and a reinstall that drops members — behaves as
follows (owner, 2026-08-18):

1. The plan and any warning are **always printed**, on every path. This is what satisfies §5's
   MUST; it does not depend on interactivity.
2. If stdout is a terminal and `--yes` was not given → prompt `y/N`, default no.
3. If not a terminal (piped, CI, scripted) → proceed without prompting.
4. `--yes` skips the prompt everywhere.

TTY detection is `std::io::IsTerminal` (stable since Rust 1.70) — no new dependency.

Non-destructive operations (`install` of fresh members, `list`, `status`, `check`, `init`) never
prompt.

### `init`

```
grimoire init [--library <path>]              # user config
grimoire init --project [dir] [--agent <id>]  # prepare a project
```

**`init`** writes `<config_home>/grimoire/config.toml` with `library = "<path>"`, giving
`config::save` its first caller. `--library` names the path; without it, the current directory is
used and must enumerate as a library (at least one pack or loose skill) or the command errors
rather than recording a path that will not work.

**It must load before it mutates**, in exactly this sequence:

```rust
let mut config = config::load(env.config_home())?;   // NOT Config::default()
config.library = Some(path);
config::save(env.config_home(), &config)?;
```

This is a correctness requirement, not a style note. `Config::unknown` — which holds the user's
comments and any key this version does not interpret — is a **private** field populated *only* by
`config::load`. Constructing a fresh `Config` and assigning `library` compiles cleanly and
**silently erases every comment and unknown key in the user's config on save**. The preservation
guarantee lives in the caller's sequence, not in `config.rs`.

**`init --project [dir]`** creates the agent's project skills dir and `<dir>/grimoire.lock`
containing `{"version": 1, "packs": {}}` (owner, 2026-08-18).

The honest caveat, argued rather than assumed: §3 says "a pack's lock state is one bit — entry
present, or no entry," so an empty lock asserts nothing about any pack. It is a **marker**, not
state: it makes the project's grimoire-ness visible in `git status`, and it gives `status` and
`check` a file to read instead of reporting nothing on an initialized project. That is the same
role `git init` plays. Both actions are **idempotent and never destructive** — an existing lock is
left exactly as found, never truncated to empty.

### The one new operation: `remove::remove_atom`

`install_atom` deliberately writes no lock entry ("an atom is not a pack, and `install.sh` locks
nothing for a bare skill install either"). But `plan_remove` reads the lock to find what to
unlink, so **a skill installed as an atom cannot be removed by the tool at all** — while
`install.sh --remove <name>` unlinks it happily, gated on `readlink` pointing into the clone
(`install.sh:261-264`). The CLI makes that hole obvious the moment `install --skill` exists.

```rust
/// Remove a skill installed as an atom: unlink an owned symlink.
///
/// **Reads the lock, never writes it.** An atom has no lock entry of its own —
/// that is `install_atom`'s deliberate asymmetry — but the lock must still be
/// consulted, because the refcount guard below depends on it. Mirrors
/// `install_atom` in writing no entry, and applies `install.sh`'s ownership rule
/// so another tool's link is reported, never deleted.
///
/// `source` is the library root the link must point into — the same role
/// `PackEntry::source` plays for `plan_remove`.
pub fn remove_atom(target: &Target, skill: &str, source: &Path) -> Result<AtomRemoval>
```

Returns whether the link was removed, absent, or foreign — never an error for "not there", the
same posture `plan_remove` takes. It reuses `owned_by`, which Phase 3 already made `pub(crate)`.

**It must refuse to unlink a skill that any installed pack's lock entry claims** in that scope,
reporting it as retained rather than removing it. A skill can be both atom-installed and a pack
member; unlinking it out from under a pack is exactly the breakage §5's reference counting exists
to prevent. This is why the operation reads the lock despite owning no entry in it — the two
statements above are one contract, not a contradiction.

**Why not simply give atoms lock entries?** That is the design-around, and it would delete this
operation entirely: reference counting would cover atoms for free, and `check` would notice a
broken atom instead of being blind to it. It is rejected for v0.1 as **pay-the-debt, knowingly**
(owner, 2026-08-18). §3's entries are keyed by pack and carry a version, a source, and a member
map; an atom has none of those, so locking one changes what a lock entry *means* and belongs in a
`docs/spec/pack-format.md` conversation, not a CLI phase. The debt is recorded here so the next
format revision inherits the argument rather than rediscovering it.

### Exit codes

A taxonomy, so a script can tell "you asked wrong" from "the world said no":

| Code | Meaning |
|---|---|
| 0 | success |
| 1 | the operation failed (I/O, a read-only lock) |
| 2 | usage error — the request itself was wrong; nothing was attempted |
| 3 | blocked by preflight — a collision or a missing member; nothing was changed |
| 4 | `check` found drift (that verb only) |

Every `CoreError` variant maps explicitly, because the obvious mapping is wrong in one place:

| `CoreError` | Code | Note |
|---|---|---|
| `Io` | 1 | carries the path already |
| `Pack` | 1 | a malformed manifest or lock in the library |
| `LockReadOnly` | 1 | §3: surface the fact, refuse the rewrite |
| `UnknownPack`, `UnknownSkill` | 2 | the user named something that is not there |
| `NotInstalled` | 2 | likewise, for a remove |
| `UnresolvedMember` | 1 | the *library* is inconsistent, not the request |
| `Timestamp`, `Config` | 1 | malformed on-disk state |
| `Preflight` **from `install`** | 3 | a real collision or missing member |
| `Preflight` **from `remove_optional_member`** | **2** | see below |

`remove_optional_member` returns `CoreError::Preflight(1)` when asked to remove a **required**
member (`remove.rs:131`) — §5 defines no such operation, so it is a malformed *request*, not a
blocked preflight. Mapping it to 3 would report a collision that does not exist. The dispatcher
therefore rejects a required member **before** calling core, and treats any `Preflight` reaching
it from that path as the usage error it is.

**`check` exits 4 when it finds anything that is not *fine***, so it works as a CI gate.
`OptionalMemberAbsent` is excluded: §5's table calls it *fine*, and a gate that fails on it would
be reporting a verdict where the spec reports a fact.

### Output

Plain text on stdout, diagnostics on stderr. Line-oriented and greppable; no table drawing, no
colour when not a terminal.

`--json` is **deferred, not rejected.** Every verb's output derives from a core type that already
has the shape (`LibraryView`, `Inventory`, `CheckReport`, `InstallPlan`), so adding it later is
additive and breaks nothing. Building it now would mean designing a schema before anyone has
scripted against the text.

### What does not change

`grimoire` with no verb opens the TUI exactly as it does today. `--library` and `--project` keep
their current meaning as global flags. The three Phase 3 TUI gaps found earlier
(optional-member deselection in the confirm screen, `remove_optional_member`, a full findings
view) are **not** in this spec's scope — though `--skip` here builds the same `skip_optional`
plumbing the TUI's deselection will need.

## Verification

- **Unit:** argument parsing for every verb and flag combination, including each usage error and
  its exit code. `args.rs`'s existing table-driven tests extend directly.
- **Integration, headless:** each verb driven end to end against the `World` fixture — install a
  pack, install an atom, skip an optional member, remove a pack, remove an optional member, remove
  an atom, list, status, check. Assert on both stdout and the exit code.
- **The collision path specifically:** a blocked install exits 3, prints every blocking member,
  and leaves the destination byte-identical. Proven by breaking: make the abort fall through and
  the test must fail.
- **`remove_atom`'s refcount guard:** a skill that is both atom-installed and a pack member must
  survive `remove --skill`. Proven by breaking — disable the lock consultation and the test must
  go red, which also proves the fixture actually contains the doubly-claimed skill (a guard test
  whose world cannot produce the failing arm stays green with the guard deleted).
- **`init` preserves the user's config:** write a `config.toml` carrying a comment and an
  unrecognized key, run `init --library <other>`, and assert both survive alongside the new
  value. Proven by breaking — swap the `load` for `Config::default()` and the test must go red.
  This is the one finding from review whose naive implementation compiles and destroys data, so
  it gets a test rather than a note.
- **Exit codes are asserted per class, not just per happy path:** a collision exits 3, an unknown
  pack exits 2, a required-member removal exits 2 (not 3), a read-only lock exits 1, `check` on a
  drifted target exits 4 and on a clean one exits 0.
- **A verb that falls through to cwd with no library exits 2** rather than printing an empty
  list.
- **`install.sh` parity, executable:** extend `tests/parity.rs` — which now runs the shell — so
  that for the same pack and target, the binary and the script produce the same links and the same
  lock location. This is the test that keeps the two implementations honest, and it is the reason
  the parity harness was built this phase.
- **Dogfood:** `tests/dogfood.rs` gains a CLI pass over the real `clankshop` pack, into a temp
  home, run against the ROOT CHECKOUT per this stream's standing rule.
- **Manual:** the roadmap's dogfood gate — replace `install.sh` for one real machine install.

## Slices

| id | what | verify | paths |
|---|---|---|---|
| C1 | `remove::remove_atom` + refcount guard | `cargo test -p grimoire-core` | `crates/grimoire-core/src/remove.rs`, `tests/transaction.rs` |
| C2 | verb + flag parsing, exit-code taxonomy | `cargo test -p skill-grimoire --lib` | `crates/grimoire/src/args.rs` |
| C3 | the dispatcher: verbs → core, plain-text output | `cargo test -p skill-grimoire --test cli` | `crates/grimoire/src/cli.rs` (new), `src/main.rs` |
| C4 | `init` and `init --project` | `cargo test -p skill-grimoire --test cli` | `crates/grimoire/src/cli.rs`, `grimoire-core/src/config.rs` |
| C5 | destructive-operation rule (print / TTY prompt / `--yes`) | `cargo test -p skill-grimoire --test cli` | `crates/grimoire/src/cli.rs` |
| C6 | `install.sh` parity + real-clone dogfood for the verbs | `GRIMOIRE_LIVE_ROOT=<root> cargo test` | `grimoire-core/tests/parity.rs`, `grimoire/tests/dogfood.rs` |
| C7 | roadmap amendment + README's CLI section | doc-linter | `docs/design/2026-08-15-tui-v0.1-roadmap.md`, `README.md` |

C1 and C2 are independent and can run in parallel; C3 depends on both; C4–C6 depend on C3; C7 is
last.

## Open risks

- **The default-target difference from `install.sh`** (`~/.agents/skills` vs `~/.claude/skills`)
  will surprise anyone with muscle memory. Mitigated by printing the resolved destination on every
  command, and by a README note — not by changing the default, which was chosen deliberately.
- **Nine unshipped Phase 3 commits sit under this work**, and the owner has chosen to keep
  stacking rather than land first. Divergence risk is currently zero (`main` has not moved since
  `e49acbc`), but it grows, and this stream has already turned the trunk red once from a
  worktree-only gate. Every commit continues to run the root-checkout gate.

## Review history

### 2026-08-18 — needs-rework

Approach and structure are sound; every finding below is localized to *Mechanism*. This is a
tight rework, not a redesign. Groundedness was checked by re-reading the code each claim rests
on, not only by resolving paths — `Lock::default()` does set `version: LOCK_VERSION`, so the
`init --project` payload claim holds, and `selected()` does ignore a skipped required member, so
that claim holds too.

**Must-fix**

1. **`remove_atom` contradicts itself.** Its doc comment says "no lock involved" (line 188);
   twelve lines later it "must refuse to unlink a member any installed pack's lock entry claims"
   (line 197). The refusal *requires* reading the lock. Both cannot hold, and an implementer
   following the signature would ship the version without the guard — the one that silently
   breaks a pack. **Fix:** say it reads the lock read-only for the refcount check and never
   writes it. That is consistent with `install_atom`, which also never writes one, and it is
   what the guard actually needs.
2. **`list` is specified two ways.** The verb table gives it "installed marks" (line 81), which
   requires a target, but the scope-flag paragraph omits `list` from the verbs that take scope
   flags (line 89). **Fix:** add `list` to that set, or drop the installed marks. Adding it is
   better — a bare library listing with no notion of what is already installed is the weaker
   verb.
3. **The unknown-key guarantee is misattributed, and the naive implementation destroys data.**
   The spec says "Unknown keys in an existing config are preserved — `config.rs` already
   guarantees this." Verified: `Config.unknown` is **private** and populated only by
   `config::load`. So the guarantee holds only if `init` does load → mutate `library` → save. An
   implementer writing the obvious `Config { library: Some(p), ..Default::default() }` cannot
   even compile it (private field), but `Config::default()` then assigning `library` compiles
   fine and **silently erases every comment and unknown key in the user's config on save**.
   **Fix:** specify the load-then-mutate-then-save sequence in *Mechanism*, and stop crediting
   core with a guarantee that depends on the caller.
4. **The exit-code table is incomplete, and the obvious mapping is wrong for one case.** Five
   codes are defined; `CoreError`'s ten variants are never mapped onto them. Under the natural
   reading (`Preflight → 3`, "blocked by preflight — a collision or a missing member"),
   `remove <pack> --member <required>` reports a collision that does not exist:
   `remove_optional_member` returns `CoreError::Preflight(1)` when refusing to remove a required
   member, which is a **usage** error (2). **Fix:** add an explicit variant → code table, and
   distinguish the refusal from a real preflight block.

**Nice-to-have**

5. **Substrate-skeptic: the new operation may be paying a debt instead of deleting it.**
   `remove_atom` exists only because `install_atom` writes no lock entry, and it writes none
   because "`install.sh` locks nothing for a bare skill install either." That is a limitation
   inherited from the shell reference, not a property of the format — §3 says the lock records
   "what is installed," and nothing there forbids an atom entry. Were atoms locked, `remove_atom`
   would be unnecessary, reference counting would cover them for free, and `check` would notice a
   broken atom instead of being blind to it. The spec should name this as an explicit
   pay-the-debt (match the shell) vs design-around (lock atoms) choice rather than treating the
   asymmetry as given. This is precisely the greenfield check the spec's own self-review owed and
   did not deliver.
6. **Library resolution for verbs is unstated.** `install`, `list`, and `check` need a library,
   but the spec never says they reuse `main.rs`'s existing `--library` → config → cwd cascade.
   The cwd fallback is defensible for the TUI and surprising for a verb: `grimoire list` in an
   unrelated directory would list nothing rather than saying the library is unset.
7. **`remove_atom`'s signature is heavier than its job.** It takes `&Library` where `owned_by`
   needs only the source root; `&Path` is the lighter seam and avoids an enumeration the
   operation does not perform.
8. **`grimoire <verb> --help` is unspecified.**

**Dispositions (revise, 2026-08-18)** — all eight verified against `HEAD` before classifying; no
push-backs, no parked decision branches.

1. `resolved` — the contract is now stated as one thing: reads the lock for the refcount guard,
   never writes it. Signature and doc comment corrected together.
2. `resolved` — `list` added to the verbs taking scope flags, with the reason it needs them.
3. `resolved` — *Mechanism* now specifies the load → mutate → save sequence as a correctness
   requirement, names the private `unknown` field as the reason, and *Verification* gains a
   prove-by-breaking test for it.
4. `resolved` — added a full `CoreError` → exit-code table, and the `remove_optional_member`
   required-member case is now rejected before core is called and mapped to 2, not 3.
5. `resolved` — atom-locking is now argued explicitly as pay-the-debt, with the design-around
   named and the reason it belongs to a format revision rather than a CLI phase (owner,
   2026-08-18).
6. `resolved` — added a *Library resolution* section; a verb falling through to cwd with no
   library exits 2 rather than printing nothing.
7. `resolved` — signature takes `&Path` (the source root) instead of `&Library`.
8. `resolved` — added a `--help` section covering per-verb help, resolved before scope or
   library so it works where the command itself would fail.

### 2026-08-18 — approve-with-changes (delta re-review)

Delta pass over Review history + what changed. All eight prior findings confirmed genuinely
resolved, not merely marked: F1's contract now reads as one statement, F3's sequence is stated as
a requirement with a red-proof behind it, and F4's table covers all ten `CoreError` variants
(checked against `lib.rs:32-57` — none invented, none missed). The `remove.rs:131` citation
resolves exactly to the required-member refusal it claims.

Safe to sequence against once F9 lands. F9 is a hole the fold itself opened.

**Must-fix**

9. **`remove --skill` needs a library, and *Library resolution* does not list it.** F7 changed
   `remove_atom`'s signature to take `source: &Path` — the library root the link must point into
   — so an atom removal cannot resolve ownership without a library. But the new section names
   only `install`, `list`, and `check`. Following it as written, `remove --skill` has no library
   to derive `source` from. (`remove <pack>` genuinely does not need one: `plan_remove` reads
   `entry.source` out of the lock.) **Fix:** add `remove --skill` to the verbs requiring library
   resolution, and say explicitly that the pack form does not.

**Nice-to-have**

10. **`AtomRemoval`'s states are described twice and enumerated never.** One sentence gives
    "removed, absent, or foreign"; the refcount paragraph adds "retained" separately. That is
    four variants the implementer must assemble from two places. Enumerate them once. While
    there: the exit-code table says "`Preflight` **from `install`**" without settling whether
    `install_atom` counts — it does (it returns `Preflight(1)` on a blocking disposition), and a
    blocked atom install should exit 3 like any other.
11. **Per-verb `--help` invalidates an existing test's assumption.** `args.rs`'s
    `version_and_help_short_circuit` asserts `--help` short-circuits wherever it appears; once
    `grimoire install --help` must print *install's* help, the parser can no longer return on the
    first `--help` it sees. Worth naming in *Slices* C2 so it reads as expected work rather than
    a regression.
