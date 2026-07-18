# `/foreman check` — validate the deployed dev system

The **cheap validator**. It flags **drift** between the glue `/foreman init` generated — the deployed
`.agents/foreman/docs/` doctrine plus the `AGENTS.md` wiring — and the current reality: the runbook that system
was generated from, and the skills actually installed. Run it **often and cheaply**; it finds the
mechanical rot so `/foreman calibrate` can spend its turns on the semantic fixes.

It runs the read-only fact script, then **you** judge the facts. Like every validator here it emits
`key=value` facts, never verdicts — a stateless script can't see session context, so it reports the
variables and the prose decides.

## Run it

```bash
bash <skill-dir>/scripts/foreman-health.sh coverage   <root>
bash <skill-dir>/scripts/foreman-health.sh stale-refs <root>
```

- `<root>` is the host repo root (resolve it as the *Shared discipline* says; never guess).
- Both are **read-only** and emit no recommendation — they surface what the host doc-linter can't see
  (spine reachability, rooted `file:line` currency), *complementing* the gate's link/index/frontmatter
  checks, not re-implementing them. Run the host gate for the mechanical half first.

## Read the facts, don't just relay them

| fact | means | judgment |
|---|---|---|
| `spine_uncovered: <dir>/` | a top-level dir not reachable from the spine (`AGENTS.md` / `.agents/foreman/README.md` / `README.md`) | wire it into the spine, or confirm it's deliberately out of scope |
| `stale_refs: <ref> (missing)` | a rooted path in a spine/tracker doc no longer resolves | repoint or drop it — a rename/delete left a dead pointer |
| `stale_refs: <ref> (file has N lines)` | a `file:line` ref points past the file's end | the referenced code moved or shrank — re-anchor it |
| `checked=` / `stale=` | how many rooted refs were checked and how many rotted | a nonzero `stale` is the currency-drift count |

Then check the two things the script can't compute, by reading:

- **Glue ↔ composition drift.** Does the deployed `.agents/foreman/docs/` doctrine still match the
  composition `/foreman init` recorded — the pack runbook if one drove init, else the baseline
  introspection? A section the composition dropped or reworded, but the deployed docs still carry,
  is drift — flag it for a re-`init` or a `calibrate` pass.
- **Glue ↔ installed-skills drift.** The doctrine names companion skills generically (`/architect`,
  `/workstream`, `/backlog`, `/auditor`, `/handoff`) and resolves host entrypoints (the gate, the
  fast doc-linter, the diagnostics tooling) **through `AGENTS.md`**. Confirm each named skill is still
  installed (or the by-hand fallback is stated) and each generic entrypoint still resolves to a real
  command in `AGENTS.md` — a skill uninstalled or a command renamed leaves "run the gate" pointing at
  nothing.

## Turn facts into action, don't auto-fix

- **`spine_uncovered` / `stale_refs` → flag, then fix in place or hand to `/foreman calibrate`.** A single
  dead pointer is a fix-in-place; a *pattern* (the docs keep drifting the same way) is signal for
  `calibrate` to fold back into the doctrine.
- **A deliberate negative example is not drift.** A doc that references a path to say "don't create
  this" is working as intended — judge, don't mechanically repoint.

## Scope boundary — this is not the doc chiropractor

`check` validates that **this system's** generated glue still resolves and still matches its runbook
and installed skills. It is **not** a general documentation-ergonomics pass. Broad doc-spine health
for a repo — front-door bloat, onboarding navigation, missing glossary/index, duplicated or
contradictory prose — is **`/chiropractor`**'s job; defer there rather than growing this verb into it.
Project-code quality is `/auditor`. Curating the trackers as lists is `/backlog curate`.

## The one thing this cannot tell you

`check` is **necessary but not sufficient**. It catches *structural* rot — an uncovered dir, a dead
ref, a named skill that vanished — because those are mechanically checkable. It **cannot** tell you
whether doctrine that passes every check still *describes the system correctly*: a `DEVELOPMENT.md`
routing rule can resolve every pointer and still send the wrong change down the wrong lane. That
semantic judgment is `/foreman calibrate`'s (and, for a deep read, the fresh-agent test: hand an agent only
the deployed docs and confirm they can route a real change without guessing). `check` is the floor you
run cheaply; `calibrate` is where the drift it surfaces gets fixed.
