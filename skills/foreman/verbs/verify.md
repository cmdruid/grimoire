# `verify <owner/stem>` — bind evidence to current instructions

Verification is attended.

1. Run `operation-check.sh` and stop on malformed structure, missing references, cycles, or imported
   source drift. Record the reported recursive digest.
2. Read and follow only the operation's Verification section. The check may inspect outputs but
   does not authorize unrelated repair or a waived invariant.
3. If the check succeeds, summarize compact evidence in an ephemeral Markdown fragment. Preview the
   digest and evidence. Record only after the user accepts the successful result.
4. Call `operation-write.sh verify --expected-digest <digest> --evidence-file <fragment>`.

The writer atomically sets `verified-against` and replaces only Verification evidence. It reuses the
canonical recursive digest; it does not compute a second identity. For another owner's operation,
return the identity, digest, evidence, and requested publisher update without writing. A procedure,
referenced operation, or imported-source change makes the evidence stale automatically.
