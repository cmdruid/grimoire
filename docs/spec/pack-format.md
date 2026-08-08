# Pack Format Specification

**Format revision:** 1 · **Status:** draft 2 for review (2026-08-08; draft 1 revised against an
independent implementer review — see `docs/design/2026-08-08-pack-format-design.md`) ·
**Design record:** `docs/design/2026-08-08-pack-format-design.md`

A **pack** binds agent skills into an installable, versioned system. This spec defines the pack
manifest (`PACK.md`), the pack lock (`grimoire.lock`), install/remove/check semantics, and the
conduct requirements for pack-based skills. It is an **overlay** on the open agent-skills
ecosystem (the Vercel `skills` CLI format): every pack repo is a plain skills repo first, and
the mechanisms here degrade gracefully for tools that have never heard of packs (§8, including
the limits of that guarantee).

Keywords MUST / SHOULD / MAY read per RFC 2119. "Tool" means pack-aware software (the grimoire
TUI, `install.sh`, any future implementation). "Plain CLI" means pack-unaware skills tooling
(`npx skills`, qntx `skills-cli`, and compatible). "Discovery" means the ecosystem's de facto
skill-discovery procedure, summarized normatively in Appendix B.

## 1. Identity & layout

- **A pack is a skill directory that also contains a `PACK.md`.** The directory's `SKILL.md` is
  the pack's **face**: its agent-facing front door, discovered and installable by plain CLIs as
  an ordinary skill. The face and the pack directory are one artifact — one install unit, one
  lock entry (§3).
- **Non-root packs MUST have a face.** A faceless pack (`PACK.md` with no sibling `SKILL.md`)
  is legal **only at a repository root** (**pack-as-repo**: the whole repository is one pack).
  Anywhere else it would be undiscoverable and is invalid.
- `pack:` in `PACK.md` frontmatter is **authoritative** for pack identity. A face `SKILL.md`'s
  `name:` MUST equal it (validators MUST error otherwise).
- Pack enumeration for tools = every discovered skill directory containing a `PACK.md` sibling,
  plus the repository root when it carries a `PACK.md`.
- Packs do not nest: a pack directory MUST NOT contain further `SKILL.md` or `PACK.md` files
  below it.

## 2. The manifest: `PACK.md`

YAML frontmatter is the machine surface; the Markdown body is the pack's runbook — author
territory that tools MUST ignore and SHOULD never rewrite. A tool that must rewrite a manifest
MUST preserve the body byte-for-byte and MUST preserve unknown frontmatter keys (semantic
preservation; formatting of the frontmatter block MAY normalize).

```yaml
---
pack: clankshop                 # required. Pack identity. [a-z0-9-]+
version: 1.0.0                  # required. Semver 2.0.0 of this pack release.
description: "One-line summary" # required.
format: 1                       # required. Pack-format revision this manifest targets.
skills: architect auditor ...   # required members — bare skill names, space-separated.
optional: bug task              # optional members — default-installed, removable without trace.
setup: /foreman setup           # optional. Lifecycle entrypoint (see §6).
---
```

**Grammar.** `skills:` and `optional:` are single YAML string scalars: skill names separated by
runs of spaces (format 1 accepts no YAML sequences). Names match `[a-z0-9-]+`. `skills:` MUST
name at least one member. A name appearing twice anywhere across the two lists is invalid.
`version:` MUST parse as semver 2.0.0. Duplicate YAML keys are invalid.

- **Member references** are bare skill names resolving against the **same repository's**
  discovered skills (Appendix B). Cross-repo references are not part of format 1. A manifest
  naming an unresolvable member is **invalid**.
- The face skill is implicitly a member and MUST NOT be listed.
- **Unknown frontmatter keys** MUST be ignored (and preserved per above). Future format
  revisions claim them; `format:` bumps only on breaking change.
- A tool encountering a `format:` value it does not implement MUST NOT install or write; it MAY
  still enumerate and display the pack.

## 3. The lock: `grimoire.lock`

Pack state lives in a **sidecar lock owned by this spec** — never inside the ecosystem's
per-skill lock files (`skills-lock.json`, `~/.agents/.skill-lock.json`), which remain the
untouched per-skill authority (their schemas are closed: foreign keys are dropped on rewrite).
The lock is named for the format, not the payload — any spec-conforming tool writes the same
file (the `Cargo.lock`/`flake.lock` convention). Content is JSON.

**Scopes.** Two lock scopes exist, mirroring the ecosystem's:

- **Project:** `<project-root>/grimoire.lock`, where the project root is the directory the tool
  is operating on (the same root the ecosystem's `skills-lock.json` would live in).
- **Global:** `~/.agents/grimoire.lock`.

Every pack operation (install/remove/check) targets **exactly one scope**, chosen by the user.
Reads that answer "is pack X present?" consult the target scope first and MAY fall through
per pack name to the other scope for display purposes; reference counting (§5) never crosses
scopes. For pack-based skills' reads, project shadows global per pack name.

```json
{
  "version": 1,
  "packs": {
    "clankshop": {
      "version": "1.0.0",
      "source": "github:cmdruid/grimoire",
      "ref": "a1b2c3d",
      "installedAt": "2026-08-08T00:00:00Z",
      "setup": { "declared": "/foreman setup", "ran": false },
      "members": {
        "clankshop": { "hash": "sha256:…", "optional": false },
        "architect": { "hash": "sha256:…", "optional": false },
        "task":      { "hash": "sha256:…", "optional": true }
      }
    }
  }
}
```

- `source` is the canonical origin: `github:<owner>/<repo>`, a full git URL, or an absolute
  local path. `ref` (optional) records the commit or tag actually installed, when known. The
  pair is what update flows resolve against; local-path sources update from disk.
- `members` records **what is installed**, one entry per installed member, keyed by skill name.
  The pack directory (face + `PACK.md` + support files) appears under the pack's own name.
  For a faceless pack-as-repo there is no pack-directory entry — only the listed members
  install.
- `hash` is the member's content hash at install time (Appendix A — byte-identical to the
  ecosystem's skill-folder hash).
- Removing an optional member removes its `members` entry (§5); the manifest, not the lock,
  is what identifies it as an optional member that could be reinstalled.
- The lock records **content facts only**. Per-agent placement (which agent directories a
  skill was linked into) is the ecosystem locks' domain, not this file's.
- Tools are the lock's only writers. **Pack-based skills read it, never write it** (§7).
- Unknown keys: ignored and preserved, as §2.
- A tool encountering a lock `"version"` greater than it implements MUST treat the file as
  read-only and refuse operations that would rewrite it.
- `setup.ran` records only that the tool dispatched the declared entrypoint after the user
  accepted the offer (§6). It is best-effort — not proof the setup succeeded or its artifacts
  exist. `check` reconciles it against reality. It is NOT the skill-side gate — packs installed
  without a tool have no lock entry at all (§7).

## 4. Versioning

- **Packs** version by **semver** (`version:`). One release = one content state of all members
  shipping in the repo.
- **Members are not individually versioned.** A pack pins members by **content hash** in the
  lock at install time. There are no member version ranges in format 1.
- A hash mismatch against the lock means *moved since install* — a fact for `check`, not an
  error. **Re-pin** = accept the bytes currently on disk and update the lock hash (the normal
  outcome after a deliberate `git pull` of a symlinked library). Restoring the recorded release
  instead is a reinstall against `source`+`ref`.

## 5. Install, remove, check

**Install is transactional** — a pack never half-installs:

1. **Preflight:** the manifest is valid (§2); every required member resolves; no member name
   collides with an already-installed skill of different content from a different source.
   Preflight failure aborts by default. A tool MAY resolve a collision interactively —
   **adopt** (accept the existing on-disk skill as this member; its current bytes are hashed
   into the lock) or **replace** (remove the existing skill via ordinary skill-level machinery,
   then install the pack's member; the prior content is not preserved) — but resolution MUST
   NOT be silent.
2. **Install members** via ordinary skill-level machinery (which maintains the ecosystem's own
   locks per skill, as it would for any install).
3. **Write the lock entry** (§3).
4. **Offer `setup:`** if declared (§6). Never auto-run.

Any failure before step 3 completes → rollback: newly installed members are removed and both
lock families restored to their pre-transaction observable state; adopted/replaced content is
not resurrected. Tools SHOULD stage work so that a crash mid-transaction leaves either the
prior state or a state `check` reports as *broken* — never a silently plausible partial pack.

**Reinstall / upgrade.** Installing a pack whose name already has a lock entry in the target
scope is a transactional replace (any version direction, any source). When the version moves
backward or the source changes, the tool MUST surface that fact — never silent.

**Remove:** delete members not referenced by another installed pack's lock entry **in the same
scope** (reference counting at pack altitude), then drop the lock entry. A member that was
`adopt`ed at install is owned by the pack thereafter and removes like any other. Removing
individual **optional** members leaves no trace: drop the member entry from the lock, remove
the skill if unreferenced; a missing optional member is never drift. Removing a **required**
member of an installed pack (by hand or plain CLI) is not a tool operation this spec defines —
it is a state `check` reports as *broken*.

**Shared members.** Two packs MAY both reference an installed skill; the refcount governs
removal. If their locks record different hashes for it, `check` reports the mismatch against
each lock's expectation; format 1 defines no resolution (last install won the bytes on disk).

**Check** compares the target scope's lock against disk, consulting each pack's *installed*
manifest (the `PACK.md` in the installed pack directory; for pack-as-repo, the manifest at
`source` when locally resolvable). It reports facts, not verdicts:

| Fact | Meaning |
|---|---|
| required member missing | *broken* — offer reinstall |
| member hash ≠ locked hash | *moved since install* — offer re-pin or reinstall (§4) |
| optional member absent | *fine* |
| lock entry, but pack manifest no longer locally resolvable | *orphaned* — offer removal or re-source |
| `setup.ran` true but the pack's marker absent (where the manifest declares `setup:`) | *setup drift* — re-offer setup |

Network unavailability never turns a fact into an error: facts that need the remote source
(nothing above does) are reported as *unknown*.

## 6. Lifecycle

- `setup:` is the **only** lifecycle key in format 1. Its value is an agent command string
  (e.g. `/foreman setup`) that tools **offer** to the user after install — tools MUST NOT
  execute it unprompted. The string is harness-facing text: this spec does not define command
  dispatch, and tools present it for the user's agent environment to run.
- Authors SHOULD make the entrypoint runnable from the face alone (the face is what a plain-CLI
  user has), or document its dependencies in the face.
- Further lifecycle keys (teardown, check, …) are **reserved** for future revisions; authors
  MUST NOT repurpose them.
- **Lifecycle is pack-scoped.** The spec defines no per-skill setup, and `SKILL.md` frontmatter
  is not this spec's surface to extend. A pack's setup entrypoint orchestrates whatever member
  wiring the composition needs; how is the pack author's business.

## 7. Pack-based skills

A **pack-based skill** is a member written for its pack's system rather than for standalone
use. The format does NOT require members to be individually useful bare — the pack is the unit
of usefulness. §7 is **author-facing conduct**: nothing in the manifest machine-declares which
members are pack-based, so tools cannot enforce these clauses; validators MAY check them
heuristically (e.g. guard-clause presence).

- **Guard clause (the tripwire) — MUST.** A pack-based skill opens by cheaply detecting whether
  its pack's system is present in the current context, and on absence fails gracefully in one
  breath: state that it is part of pack `<name>` and point at the declared `setup:` entrypoint,
  or at the pack's face when none is declared. No partial execution against a system that isn't
  there.
- **The marker is pack-defined.** The guard checks the artifact the pack's own setup creates
  (e.g. a stamped installation block). It MUST NOT gate on `grimoire.lock` — the stamp survives
  every install path (including plain-CLI installs + hand-run setup); the lock only exists
  where a pack-aware tool acted.
- **Guard vs. self-healing.** The guard governs the *system marker*: marker absent → graceful
  refusal, full stop. Lazy use-time self-healing is legitimate only *inside* a stamped system —
  repairing or scaffolding sub-artifacts the marker's system implies. A skill MUST NOT
  self-heal its way past an absent marker.
- **Lock-aware — SHOULD.** When `grimoire.lock` is present (project scope shadowing global,
  §3), a pack-based skill SHOULD read it for pack facts — its pack's version, member set,
  `setup.ran` — rather than rediscovering them. It MUST tolerate the lock's absence, and MUST
  NOT write it.
- **No install-time self-setup — MUST.** Members do not bootstrap at install (§6).
- **Face exception.** The face skill MUST NOT carry the tripwire: "pack not installed" is its
  welcome case — it explains the pack and points at setup.
- A member shipped by multiple packs of one repository guards on the marker of whichever of
  its packs' systems it requires; authors owning such members define that choice.

Beyond these, member conduct is unspecified.

## 8. Graceful degradation & limits

Behavior of pack-unaware tooling:

| Action by a plain CLI | Result |
|---|---|
| Discover the repo | Sees all skills, including faces and pack-based members, as ordinary atoms |
| Install the face | Gets the pack's front door; `PACK.md` and support files ride along as the skill directory's payload; the face explains the rest |
| Install a pack-based member solo | Valid install; the member's guard clause fails gracefully at invocation |
| Rewrite its own locks | `grimoire.lock` is not touched (§3) |
| Read `PACK.md` | Ignores it (not a `SKILL.md`) |

The payload guarantee assumes the plain CLI installs skill directories whole (the de facto
behavior verified against the reference implementations); a CLI that filtered unrecognized
files would deliver a face without its manifest — degraded but not broken (the face still
speaks).

**Limits (format 1) — stated, not solved.** The sidecar being *untouched* is not the same as
*still true*: a plain CLI can add, update, or remove individual members underneath an installed
pack, producing states no pack release describes. The guard clause is a **bootstrap gate**, not
an integrity system — a stale or surviving marker (e.g. after removing members or a whole pack;
format 1 has no teardown key) can let pack-based skills run against a partial system. `check`
(§5) is the integrity instrument: it exists precisely to surface these states as facts. Skill
names are flat in the ecosystem; two sources can overwrite each other's same-named skills, and
the lock records that only as a hash mismatch. Pack-aware tools MAY hint pack membership when
a member is installed or removed solo (membership is declared in the manifest); this is a
courtesy, not a mandate.

## Appendix A — member content hash (normative)

Byte-identical to the ecosystem's skill-folder hash (verified against the Rust and TypeScript
reference implementations):

1. Walk the skill directory recursively. Skip directories named `.git` or `node_modules`.
   Include regular files only (symlinks and other entry types are skipped, not followed).
2. For each file, form its path relative to the skill directory root, with `/` as separator on
   all platforms; pair it with the file's raw bytes.
3. Sort pairs by relative path (lexicographic byte order).
4. SHA-256 over the concatenation, per pair in order, of the path's UTF-8 bytes followed by the
   file's bytes. No delimiters, lengths, or terminators are added.
5. Render lowercase hex. The lock stores it prefixed `sha256:`.

## Appendix B — discovery (normative summary of the de facto ecosystem procedure)

A skill directory is a directory containing `SKILL.md`. Discovery over a repository:

1. If the repository root is itself a skill directory, it is the sole discovered skill —
   unless a full-depth scan is requested.
2. Otherwise scan the fixed priority directories one level deep — the root itself, `skills/`,
   `skills/.curated`, `skills/.experimental`, `skills/.system`, and the per-agent skill
   directories (`.agents/skills`, `.claude/skills`, …) — collecting each child skill
   directory.
3. If nothing was found, fall back to a bounded recursive scan.

A skill's identity is the `name:` in its `SKILL.md` frontmatter (directory name as fallback).
First-seen wins on duplicate names. Pack member resolution (§2) resolves bare names against
this procedure's results for the pack's own repository; nested `SKILL.md`s below a pack
directory are invalid (§1) and not resolvable members.
