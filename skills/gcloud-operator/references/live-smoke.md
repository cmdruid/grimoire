# Live smoke test

Not part of the deterministic suite. Requires explicit human approval for one named
project/zone/VM. Do not run it against production data. Fixture tests do **not** prove MFA
reuse on OS Login.

## Approve first

Record the exact `PROJECT`, `ZONE`, and `VM`. Confirm:

- The VM has no external IP, or SSH from the internet is not allowed.
- Effective OS Login 2FA is enabled (`doctor` prints `oslogin=TRUE` and
  `oslogin_2fa=TRUE`, each with `oslogin_source` / `oslogin_2fa_source` of
  `instance` or `project`).
- The operator is willing to complete **one** MFA challenge.
- Guest work is limited to a newly created remote temporary directory.

## Canonical baseline (capture before `open`)

Save this read-only inventory. Compare the same commands after `close`. The helper
must not enable APIs, IAM logging, or otherwise mutate this set.

1. **Instance identity:** `gcloud compute instances describe VM --project=PROJECT --zone=ZONE`
   (name, id, status, internal IP, external IP, attached service account).
2. **Effective metadata:** instance `metadata.items` and project
   `commonInstanceMetadata.items` for `enable-oslogin` and `enable-oslogin-2fa`.
3. **Firewall:** rules that allow TCP 22, including source ranges and target tags.
4. **Enabled APIs:** `gcloud services list --enabled --project=PROJECT`.
5. **IAM:** relevant bindings on the project and, if present, on the instance and
   attached service account (`get-iam-policy`). At minimum capture members holding
   `roles/iap.tunnelResourceAccessor`, OS Login roles, and `iam.serviceAccountUser`.
6. **`gcloud-session.sh doctor --project PROJECT --zone ZONE --vm VM`.** Expect
   `planned_network_path=iap-tcp`, `transport=unverified`, and no helper-created
   public SSH path.

If the consuming project already has IAP Data Access audit logs enabled, note that
fact in the baseline. After the session, check for the expected IAP tunnel and OS
Login events. Do **not** have this helper enable Data Access logging or change
audit policy.

## Procedure

1. Capture the canonical baseline above.
2. Collect a fresh `--mfa-method` choice and code. `open` immediately. Expect
   `transport=verified` and `mfa_completed=true`.
3. Without a second prompt: `run -- HANDLE -- true`, then `run -- HANDLE -- uname -a`.
4. On the guest, create a disposable directory (`mktemp -d` under the guest temporary
   directory). `copy-to` a small local file into that directory, `copy-from` it back,
   compare bytes.
5. `run -- HANDLE -- rm -rf --` that exact directory only. Do not delete `$HOME` or
   the host temporary directory.
6. `close -- HANDLE`. Confirm the control socket is gone and no `start-iap-tunnel`
   child remains. `status` on the closed handle must not report `transport=verified`.
7. Re-run the canonical baseline. Instance identity, firewalls, instance and project
   metadata, attached service account, enabled APIs, and IAM bindings must be
   unchanged.

## Verdict

- **Pass:** IAP reached the private VM; one OS Login 2FA event; two later commands and one
  harmless round-trip transfer used the master without another MFA prompt; close left the
  baseline unchanged.
- **Fail / incompatible:** If a second MFA prompt appeared on `run` or `copy-*`, multiplexing
  is not sufficient here. Use the persistent interactive-shell fallback in
  `references/transport.md` and record the limitation. Do not disable 2FA to make the test pass.
