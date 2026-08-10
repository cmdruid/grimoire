# `/clankshop calibrate intake` — the improvement pass: claim, dispatch, verify, close

Hat: `roles/chiropractor.md` — read the hat first; you operate this verb wearing that hat.

Run one pass of the improvement loop over the **frozen intake table** — this hat is the
only scanner of these sources, and every item leaves the pass either dispatched-and-closed,
dispatched-and-open (uptake pending), or explicitly skipped with its reason.

## The intake table (frozen; the pack doctrine states the record formats)

| source | eligibility bar | closure handle |
|---|---|---|
| `.records/trackers/feedback.md` | the whole dev-experience channel | the `F-` entry itself |
| `.records/trackers/issues.md` | **process-flavored only** — *how we work*; the rest stays with the router | the `I-` entry itself |
| `.records/trackers/notes/` | **system-flavored** — a durable trap/rule belonging in GOTCHAS/INVARIANTS | the `N-` entry itself |
| `.records/audit/FINDINGS.md` | passes the **system-improvement bar** — evidence the *framework* should change; code findings go back to the router | a materialized `T-` item |
| `.records/reports/doc-drift-*.md` | accepted doc-drift findings | a materialized `T-` item |
| `.records/reports/investigation-*.md` | the lessons slice | a materialized `T-` item |

**Tracker sources** are already ID'd work items: the entry **itself** is the dispatched artifact
and the single closure handle — no `T-` item is minted. **Non-tracker sources** (findings,
report findings) are **materialized before dispatch** as an improvement item in
`.records/trackers/tasks.md` — `- T-<n> — improve: <what> · source: <source-identifier>#<finding-key>
· added <date>` (the source-identifier is the report ID for reports, the repo-relative path for
the FINDINGS store). The `source:` line is both the claim on that finding and the closure handle.
**Identity is per finding, never per report**: a report with several findings routed to different
owners processes each independently — accepting one never hides the rest.

## Procedure

1. **Resolve root; confirm stamped.** The loop drains the deployed stores — on an unstamped root
   there is nothing to drain: report that, point at the onramps, and write nothing.
2. **Scan:** `scripts/intake-scan.sh <root>` — eligible items per source, with paused entries,
   claimed entries (`[⇢ dispatched …]` / `dispatched:` / a live `source:` claim), and
   `processed:`-stamped finding keys already excluded. Apply the **eligibility bars** (the table)
   to what remains; note each skip with its reason.
3. **Claim, then dispatch — in that order, per item:**
   - flat tracker entry → append ` [⇢ dispatched <date>]` to the entry line; store-dir item →
     add frontmatter `dispatched: <date>`; non-tracker finding → write the materialized `T-`
     item (its `source:` **is** the claim).
   - Commit the claim **trunk-side, pathspec-scoped, before any dispatch** — the claim commit is
     the serialization point; if it conflicts (another pass landed first), re-scan and skip.
   - Dispatch the item to the **owning role** — the role owning the indicted chapter or store
     (a routing gap → the foreman hat; a gate/playbook gap → the guardian hat; a
     seed divergence → the architect hat; a doc-form finding → the chiropractor's `docs` verb; a
     record format concern → the records instrument). The role applies it with its own
     expertise, as ordinary work through the ordinary lanes.
   - An item that crosses the promotion bar — a *decision*, *sign-off*, *ambiguity*, or *access*
     need only the human can resolve — is handed to `/backlog promote` instead of an owning
     hat; it stays claimed until the ticket resolves, like any other work.
4. **Verify uptake before closing:** the owning role's edit **landed** (the chapter/store
   changed as dispatched) and the deployed check chain is green. No uptake yet → the item stays
   claimed and open; a stale claim surfaces as an age fact and `/backlog curate` may release it
   (a judged act, logged).
5. **Close the books, per item:** complete the closure handle via
   `/backlog done <handle> --outcome drained` (the records instrument's completion verb — it
   refuses stale or paused handles, so a bad close is loud); **stamp the source** — a report or
   the FINDINGS store gains the finding key in its `processed:` list (the one writer grammar: a
   YAML list of keys, never a boolean). Tracker-source entries need no extra stamp — completion
   removes/advances them.
6. **Log the pass:** one dated, typed entry in `.records/logs/` — items dispatched (with
   owners), items closed, items skipped with reasons, stale claims flagged.

## Done when

Every eligible item is claimed-and-dispatched or skipped-with-reason; every verified uptake is
closed with its `drained` line and source stamp; nothing was dispatched unclaimed, nothing paused
was touched, no chapter was edited here — and the run log records the pass.
