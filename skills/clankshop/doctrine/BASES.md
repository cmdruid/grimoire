# BASES — the doctrine base archive

The versioned store of **superseded entry bodies**, so a deployed handbook's three-way diff can
always retrieve the exact upstream content an entry was seeded from. The current doctrine holds
the current bodies; this file holds only what a version bump changed or retired. It ships with the
skill (fully offline — the deployed *project* never carries it) and grows by lines, not files.

**At doctrine v1 this archive is empty of bases** — v1 bodies are the live doctrine, and base
retrieval of any `origin@v1` correctly falls through to the live entry.

## Entry grammar (frozen — Appendix J of the rollout plan)

One delimited block per superseded body, keyed `origin-id @version`:

```markdown
<!-- base clankshop:INV-4 @v1 -->
…the exact prior bytes of the entry…
<!-- /base -->
```

- The origin ID is the doctrine-side typed ID qualified by the doctrine source
  (`clankshop:INV-4`); **whole-file assets** (lanes, testing docs) are path-qualified
  (`clankshop:workflows/patch`, `clankshop:testing/GATE`) and store the **full prior file body**.
- `@version` is the doctrine version the stored body was current **at** (the version being
  superseded, not the new one).
- Blocks are append-only, in bump order; nothing here is ever edited or removed.

## Bump records (coverage metadata)

Every version bump also appends **one bump record** listing exactly the origins changed or retired
in that bump:

```markdown
<!-- bump v2: clankshop:INV-4 clankshop:workflows/bug -->
```

The checker cross-references the two: a bump record naming an origin with **no matching base
block** is a **missing-base fact**; the live-doctrine fallback is legal **only** for origins no
bump record names. Without this, an omitted block would be indistinguishable from an unchanged
origin.

## Retrieval rule (frozen)

Base retrieval of `origin@vN`: the **oldest** base block for that origin with version **≥ N** —
the body that was current at vN. If none exists, the base is the **live doctrine entry** — an
unrelated bump archives nothing for untouched origins, so their base is correctly the live body.

## The bump procedure

1. Edit the doctrine entries; bump `doctrine-version:` in every doctrine declaration block (one
   integer for the whole doctrine).
2. For each changed or retired entry, append its prior body here as a base block keyed at the
   **outgoing** version.
3. Append the bump record naming exactly those origins.
4. Land it all in one scoped commit — the archive must never lag the live doctrine.

<!-- bases begin below this line -->
