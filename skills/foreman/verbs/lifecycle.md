# `activate|deprecate <owner/stem>` — change lifecycle deliberately

Run `operation-check.sh` and present the identity, digest, status, and evidence health.

- Activation requires current verification and explicit human acceptance.
- Deprecation requires explicit human acceptance and removes the operation from normal discovery.
- A foreign-owned operation is never changed. Return a bounded publisher request containing the
  identity, digest, evidence state, and requested transition.

For a Foreman-owned operation, pass the observed digest to package-local
`scripts/operation-write.sh lifecycle`. The writer rechecks drift and atomically changes only the
`status:` line. Do not rewrite instructions or evidence during a lifecycle transition.
