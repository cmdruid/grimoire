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
that touches a destination (`install`, `remove`, `status`, `check`, `init --project`):

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
rather than recording a path that will not work. Unknown keys in an existing config are preserved
— `config.rs` already guarantees this.

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
/// Remove a skill installed as an atom: unlink an owned symlink, no lock involved.
/// Mirrors `install_atom`'s "no lock entry" symmetry, and applies `install.sh`'s
/// ownership rule so another tool's link is reported, never deleted.
pub fn remove_atom(target: &Target, skill: &str, library: &Library) -> Result<AtomRemoval>
```

Returns whether the link was removed, absent, or foreign — never an error for "not there", the
same posture `plan_remove` takes. It reuses `owned_by`, which Phase 3 already made `pub(crate)`.

**It must refuse to unlink a member any installed pack's lock entry claims** in that scope. A
skill can be both atom-installed and a pack member; unlinking it out from under a pack is exactly
the breakage §5's reference counting exists to prevent.

### Exit codes

A taxonomy, so a script can tell "you asked wrong" from "the world said no":

| Code | Meaning |
|---|---|
| 0 | success |
| 1 | the operation failed (I/O, a read-only lock, an unresolvable member) |
| 2 | usage error (unknown verb or flag, missing value, `--skip` of a required member) |
| 3 | blocked by preflight — a collision or a missing member; nothing was changed |
| 4 | `check` found drift (that verb only) |

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
  survive `remove --skill`. Proven by breaking.
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
