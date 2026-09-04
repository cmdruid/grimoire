# Threat model

Sources: IAP TCP forwarding overview; SSH credential best practices; service-account
impersonation and service-account security guidance
(https://docs.cloud.google.com/iam/docs/service-account-impersonation,
https://docs.cloud.google.com/iam/docs/best-practices-service-accounts).

## What the helper reduces

- **Repeated OS Login 2FA prompts** caused by one-shot `gcloud compute ssh` / `scp`, by reusing
  one authenticated OpenSSH master (hypothesis until the live smoke test for that VM).
- **Public SSH exposure** as an agent "workaround": IAP-only path; no external IP and no public
  TCP 22 rule is ever created.
- **Credential duplication**: does not copy `~/.config/gcloud`, ADC files, or SSH private keys
  into the repository, workspace, the host temporary directory, or the session directory.
- **MFA leakage into agent artifacts**: code files are unlinked after read; logs redact codes,
  `ya29.` tokens, and `Authorization` headers; the helper never accepts the code on argv.
- **Accidental diagnostic mutations**: `doctor` / `open` / `status` / ordinary recovery cannot
  run `--troubleshoot`, enable APIs, or create connectivity tests.
- **Session confusion**: a handle is a unique directory bound to one account/project/zone/VM/OS
  Login user; mismatch refuses reuse; `close` cannot delete home, the host temporary directory, or a repo root.
- **Non-repudiation on control-plane impersonation**: optional `--impersonate-service-account`
  uses short-lived tokens from the caller's identity so audit logs retain the original
  principal, unlike a downloaded key.

## What it does not

- It does **not** disable, skip, or weaken OS Login 2FA or IAP authorization.
- It does **not** make chat-typed codes secret. If the harness has no non-echoing secret-input
  channel, the code exists in the conversation. Minimize exposure; do not pretend a PTY write is
  a secret channel.
- It does **not** authorize GCP or guest mutations. Opening a session is local transport.
- It does **not** prevent a principal who already has SSH on a VM from using the attached
  service account (SSH on a VM with an attached SA is already that powerful). Limit shell access
  and metadata-server access in IAM; this helper will not widen them.
- It does **not** replace a deployment architecture. Unattended guest changes should use
  workload identity or a managed deploy job, not a hidden long-lived SSH credential.
- It does **not** stop someone from running `gcloud compute ssh --troubleshoot` by hand. It
  refuses to run it as an ordinary diagnostic.
- Multiplexed channels share one authenticated SSH session. A compromised workstation that can
  write to the control socket can use that session until expiry. Sockets are `0700` and
  uid-checked; treat the session directory like a live SSH agent socket and `close` it.
