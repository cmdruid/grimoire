# `/skill-builder check` (alias `audit`) — the gate + the boundary audit

Two passes: the **mechanical** gate (`scripts/skills-lint.sh`) and the **judgment** pass
(`docs/BOUNDARY-AUDIT.md`'s workflow). Run Pass 1 often (cheap,
deterministic); run the full boundary audit (Pass 2) when a description/body changed or before a
release — it needs a read, not just a script run.

## When to use

- Before committing any change under a library's `skills/` tree (Pass 1, at minimum).
- After editing a `description:` or adding a cross-skill reference (the full audit — the mechanical
  pass alone won't catch body-level re-documentation).
- The user says "audit the skills", "check the boundaries", "run the skill lint", "is this skill
  independent?".

## Pass 1 — mechanical (`scripts/skills-lint.sh`)

```bash
bash <this-skill-dir>/scripts/skills-lint.sh <library-root>
```

Facts, not verdicts: `FAIL:`/`WARN:` lines with evidence, a `fails=N warns=N` summary, exit 1 on any
FAIL. It never fixes anything — read every FAIL as a defect to fix before committing; read WARNs and
judge each against `docs/BOUNDARY-AUDIT.md`'s rubric (check 7's sibling-ref WARNs) or accept as a known
exception (an orphan edge-type WARN during a rollout, a shellcheck style note).

## Pass 2 — the boundary audit (judgment)

Walk `docs/BOUNDARY-AUDIT.md`'s 8-step workflow: inventory → scan descriptions/bodies against the
violation rubric → cross-check asserted seams against the runbook's seam table → list findings (with
allowed exceptions noted) → fix (self-scope the leaf; move real seams to the runbook) → **routing-probe**
the thinned descriptions (ideally via a fresh sub-agent with no audit reasoning in context — a mis-route
fails the gate, and the fix is sharper self-scope, never a restored cross-reference) → re-run Pass 1 →
report.

## Read the facts, don't just relay them

| signal | means | judgment |
|---|---|---|
| lint `FAIL:` | a hard defect (bad frontmatter, dangling ref, malformed edge block, script syntax) | fix before committing — never a judgment call |
| lint `WARN: … names sibling` | check 7's boundary candidate (description-level) | judge against the rubric; self-scope unless it's a documented router/fragment exception |
| lint `WARN: … names N distinct verbs of sibling … in one paragraph` | check 9's boundary candidate (body-level enumerated roster, BL-1) | judge against the rubric; point at the sibling instead of enumerating its verbs, unless it's a genuine documented exception |
| lint `WARN: edge type … declared by only one skill` | a genuine orphan/typo, or a consumer not yet wired | the lint already excludes a same-skill produces/handoff↔consumes pair (BL-4) — a lingering WARN here is a real single-direction type, expected mid-rollout or worth fixing |
| routing-probe miss | independence claimed but not actually achieved | sharpen the losing skill's scope; do not restore a cross-reference to patch it |

## Done when

Pass 1 reports `fails=0`; every residual WARN is either fixed or a documented exception; if Pass 2
ran, the routing-probe passed against
the thinned descriptions alone and the findings + probe result are reported.
