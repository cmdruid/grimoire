# Doc audit — keep the doctrine home true and lean

The review station's periodic sweep of this doctrine home (and the door). Scan → diagnose → adjust;
mechanical facts first, judgment second. Run it when doctrine has churned, when a load set
feels heavy, or on the review station's own cadence.

## Mechanical floor (scripts first)

1. `context.sh --check` — every station's load set resolves. Red here is a defect; fix before
   any judgment pass.
2. Link walk: every relative `.md` link in this doctrine home and the door resolves to a real file.
3. Stamp present: the README's seed stamp line is intact (it is the workshop's version anchor).

## Judgment pass

Walk each doc against these questions; fix small findings in place, route larger ones as
tracker entries:

- **Restatement** — does a station chapter restate core instead of refining it? (The precedence
  rule: core is the floor.) Deduplicate: the fact lives once, linked from elsewhere (INV-10).
- **Divergence** — does the doc describe practice as it *is*? Where practice and doctrine
  disagree, decide which is wrong and fix that one.
- **Load-set weight** — is standing context (core + a station POLICY) carrying content that
  should be lazy (a workflow) or a record? Every line in a load set is paid on every load.
- **Drains** — does every capture surface named by the docs still have a drain (INV-11)?
- **The door** — is `AGENTS.md`'s table thin, current, and consistent with `core/ROUTING.md`?

## Output

Small fixes land directly (patch lane, docs-only). Findings that need decisions become tracker
entries; a pattern of drift worth a standing rule goes to `core/` via the review station's
improvement loop.
