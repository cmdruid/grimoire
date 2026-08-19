# Ideal use — a worked arc through the spine

A *"how to use me"* example, read on demand. It shows the spine verbs as
**blueprint's own arc** on one concrete feature. The arc ends at the
**accepted spec**. The spec is the terminal blueprint artifact.

---

## The feature: "add a `--json` output mode to the `report` command"

**1. `brainstorm "let users get report output as JSON"`**
Harvests the conversation first (the user already said a downstream tool will
consume it → stability matters, version the shape), then reads the `report`
command's code and the host's design context. Proposes two approaches — a new
`--json` flag vs. a separate `report-json` subcommand — and recommends the
flag (less surface, reuses the existing arg parse). Weight call: one phase, no
cross-cutting decision → small feature; slices, if any, will live in the spec.
*Output:* a draft design doc in the `specs/` store (`status: open`), open
questions at its foot. → proceed to `spec`.

**2. `spec <draft>`**
Synthesizes the draft, then **grills the gaps** — two rounds of numbered
questions with recommended answers (*envelope versioning: a top-level `"v": 1`,
or a header field?* — recommends the field; *pretty-print or compact?* —
recommends compact + a `--pretty` flag deferred as YAGNI). Writes the argued
spec: **Problem** (consumers can't machine-read report output), **Approach**
(+ the subcommand alternative, rejected), **Mechanism** (serialize the
already-computed report model; no new data path), **Verification** (a
golden-file test of the envelope). Because this is a small feature, the spec
carries an optional **Slices** stub (flag parsed → envelope emitted; golden
test red-first). Self-reviews, then gates on the human reading it. On
approval: `records.sh touch <spec> --status current`.
*Output:* the accepted spec. **Blueprint stops here.**

---

## Where the arc ends

The accepted spec is the terminal blueprint artifact. Implementation
sequencing is a different job; the host's build lane (or the human) consumes
the spec from here.

## Genesis (a different arc)

The feature-spec arc above still ends at the accepted spec. Genesis is a
different arc: `new` mints a founding-shaped working file, `grill` / `spec`
fill its six map sections in place, `deploy` materializes a git repository
(a new directory, or in place in a non-git folder that does not already
hold the founding docs). Do not run this arc on a feature spec.
