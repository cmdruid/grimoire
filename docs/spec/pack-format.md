# Pack Format Specification

**Format revision:** 1 · **Status:** draft for review (2026-08-08) · **Design record:**
`docs/design/2026-08-08-pack-format-design.md`

A **pack** binds agent skills into an installable, versioned system. This spec defines the pack
manifest (`PACK.md`), the pack lock (`grimoire.lock`), install/remove/check semantics, and the
conduct requirements for pack-based skills. It is an **overlay** on the open agent-skills
ecosystem (the Vercel `skills` CLI format): every pack repo is a plain skills repo first, and
every mechanism here degrades gracefully for tools that have never heard of packs.

Keywords MUST / SHOULD / MAY read per RFC 2119. "Tool" means pack-aware software (the grimoire
TUI, `install.sh`, any future implementation). "Plain CLI" means pack-unaware skills tooling
(`npx skills`, qntx `skills-cli`, and compatible).

## 1. Identity & layout

- **A pack is a skill directory that also contains a `PACK.md`.** The directory's `SKILL.md`,
  when present, is the pack's **face**: its agent-facing front door, discovered and installable
  by plain CLIs as an ordinary skill.
- The face is optional. A `PACK.md` without a sibling `SKILL.md` is a **faceless pack** (legal,
  but the face is recommended — it is what a plain-CLI user lands on).
- **Pack-as-repo:** a `PACK.md` at a repository root makes the whole repository one pack.
- `pack:` in `PACK.md` frontmatter is **authoritative** for pack identity. A face `SKILL.md`'s
  `name:` MUST equal it (validators MUST error otherwise).
- Pack enumeration for tools = every discovered skill directory containing a `PACK.md` sibling,
  plus the repo root when it carries a `PACK.md`.

## 2. The manifest: `PACK.md`

YAML frontmatter is the machine surface; the Markdown body is the pack's runbook — author
territory that tools MUST ignore.

```yaml
---
pack: clankshop                 # required. Pack identity. [a-z0-9-]+
version: 1.0.0                  # required. Semver of this pack release.
description: "One-line summary" # required.
format: 1                       # required. Pack-format revision this manifest targets.
skills: architect auditor ...   # required members — bare skill names, space-separated.
optional: bug task              # optional members — default-installed, removable without trace.
setup: /foreman setup           # optional. Lifecycle entrypoint (see §6).
---
```

- **Member references** are bare skill names resolving against the **same repository's**
  discovered skills (per the ecosystem's discovery rules). Cross-repo references are not part of
  format 1. A manifest naming an unresolvable member is **invalid**.
- A skill listed in both `skills:` and `optional:` is invalid. The face skill is implicitly a
  member and MUST NOT be listed.
- **Unknown frontmatter keys** MUST be ignored and, where a tool rewrites a manifest, preserved.
  Future format revisions claim them; `format:` bumps only on breaking change.

## 3. The lock: `grimoire.lock`

Pack state lives in a **sidecar lock owned by this spec** — never inside the ecosystem's
per-skill lock files (`skills-lock.json`, `~/.agents/.skill-lock.json`), which remain the
untouched per-skill authority (their schemas are closed: foreign keys are dropped on rewrite).
The lock is named for the format, not the payload — any spec-conforming tool writes the same
file (the `Cargo.lock`/`flake.lock` convention). Content is JSON. Scopes mirror the
ecosystem's:

- **Project:** `<project>/grimoire.lock`
- **Global:** `~/.agents/grimoire.lock`

```json
{
  "version": 1,
  "packs": {
    "clankshop": {
      "version": "1.0.0",
      "source": "cmdruid/grimoire",
      "installedAt": "2026-08-08T00:00:00Z",
      "setup": { "declared": "/foreman setup", "ran": false },
      "members": {
        "architect": { "hash": "sha256:…", "optional": false },
        "task":      { "hash": "sha256:…", "optional": true }
      }
    }
  }
}
```

- `hash` is the member's content hash at install time, computed exactly as the ecosystem's
  skill-folder hash (SHA-256 over sorted relative paths + contents).
- The pack directory itself (face + `PACK.md` + support files) is recorded as a member entry
  under the pack's own name — it is content that moves like any other member.
- Tools are the lock's only writers. **Pack-based skills read it, never write it** (§7).
- Unknown keys: same preservation rule as §2.
- `setup.ran` is a tool-side fact: it records whether the tool observed setup being run. It is
  NOT the skill-side gate — packs installed without a tool have no lock entry at all (§7).

## 4. Versioning

- **Packs** version by **semver** (`version:`). One release = one content state of all members
  shipping in the repo.
- **Members are not individually versioned.** A pack pins members by **content hash** in the
  lock at install time. There are no member version ranges in format 1.
- A hash mismatch against the lock means *moved since install* — a fact for `check`/update
  flows (re-pin), not an error (§5).

## 5. Install, remove, check

**Install is transactional** — a pack never half-installs:

1. **Preflight:** every required member resolves; no member name collides with an
   already-installed skill from a different source (collision handling MAY be interactive —
   adopt/replace — but MUST NOT be silent); the manifest is valid (§2).
2. **Install members** via ordinary skill-level machinery (which maintains the ecosystem's own
   locks per skill, as it would for any install).
3. **Write the lock entry** (§3).
4. **Offer `setup:`** if declared (§6). Never auto-run.

Any failure before step 3 completes → full rollback; no partial pack, no lock entry.

**Remove:** delete members not referenced by another installed pack's lock entry (reference
counting at pack altitude), then drop the lock entry. Removing individual **optional** members
leaves no trace: a missing optional member is never drift.

**Check** reports facts, not verdicts: missing required member → *broken*; member hash ≠ locked
hash → *moved since install* (offer re-pin); missing optional member → *fine*; lock entry with
no corresponding manifest source → *orphaned*.

## 6. Lifecycle

- `setup:` is the **only** lifecycle key in format 1. Its value is an agent command string
  (e.g. `/foreman setup`) that tools **offer** to the user after install — tools MUST NOT
  execute it unprompted.
- Further lifecycle keys (teardown, check, …) are **reserved** for future revisions; authors
  MUST NOT repurpose them.
- **Lifecycle is pack-scoped.** The spec defines no per-skill setup, and `SKILL.md` frontmatter
  is not this spec's surface to extend. A pack's setup entrypoint orchestrates whatever member
  wiring the composition needs; how is the pack author's business.

## 7. Pack-based skills

A **pack-based skill** is a member written for its pack's system rather than for standalone
use. The format does NOT require members to be individually useful bare — the pack is the unit
of usefulness. What it does require:

- **Guard clause (the tripwire) — MUST.** A pack-based skill opens by cheaply detecting whether
  its pack's system is present in the current context, and on absence fails gracefully in one
  breath: state that it is part of pack `<name>` and point at the declared setup entrypoint.
  No partial execution against a system that isn't there.
- **The marker is pack-defined.** The guard checks the artifact the pack's own `setup:` creates
  (e.g. a stamped installation block). It MUST NOT gate on `grimoire.lock` — the stamp
  survives every install path (including plain-CLI installs + hand-run setup); the lock only
  exists where a pack-aware tool acted.
- **Lock-aware — SHOULD.** When `grimoire.lock` is present, a pack-based skill SHOULD read it
  (project scope, then global) for pack facts — its pack's version, member set, `setup.ran` —
  rather than rediscovering them. It MUST tolerate the lock's absence, and MUST NOT write it.
- **No install-time self-setup — MUST.** Members do not bootstrap at install (§6). Lazy
  self-healing at *use-time* is a legitimate idiom, invisible to this spec.
- **Face exception.** The face skill MUST NOT carry the tripwire: "pack not installed" is its
  welcome case — it explains the pack and points at setup.

Beyond these, member conduct is unspecified.

## 8. Graceful degradation (plain-CLI behavior)

| Action by a pack-unaware tool | Result |
|---|---|
| Discover the repo | Sees all skills, including faces and pack-based members, as ordinary atoms |
| Install the face | Gets the pack's front door; `PACK.md` rides along as payload; the face explains the rest |
| Install a pack-based member solo | Valid install; the member's guard clause fails gracefully at invocation |
| Rewrite its own locks | Unaffected — pack state lives only in the sidecar (§3) |
| Read `PACK.md` | Ignores it (not a `SKILL.md`) |

Pack-aware tools MAY hint pack membership when a member is installed solo (membership is
declared in the manifest); this is a courtesy, not a mandate.
