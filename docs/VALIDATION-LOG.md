# CGE-GCP Lab Validation Log

Every lab in this repo is executed end to end on a **brand-new Google Cloud free-trial
account with no Organization** before the course ships. This log records what actually
happened, including everything that broke, and the fix baked into the labs. If a lab step
surprises you, check here first.

## Environment

| Item | Value |
|---|---|
| Account type | Personal @gmail.com, no Organization, paid billing account (not a fresh free trial, so V7 still open) |
| Project | `cgegcp-val-1103` (created 2026-11-03) |
| gcloud SDK | 561.0.0 |
| Terraform | 1.14.9 |
| google provider | (pending) |
| Validation date | 2026-11-03 (probe runs 1 and 2, raw logs in `validation/raw/`) |

## Design-deciding questions (answered by validation/probe-v1-v3.sh)

| ID | Question | Result | Course impact |
|---|---|---|---|
| V1 | SCC Standard activation + findings read at project scope, no Organization | **Not active by default, and no CLI path found to activate it.** `scc manage services describe` → `INVALID_ARGUMENT`; `scc findings list` → `NOT_FOUND`. Course redesigned to not depend on SCC (checks as code over Asset Inventory). Inventory delay for a new public grant: **57s** (`validation/raw/2026-11-03-asset-delay.log`) | Labs 2, 4, 6 evidence source |
| V2 | Org Policy constraints + dryRunSpec at project scope; public-bucket default on new projects | **Org Policy can't be set on a no-Organization project.** Owner gets `Permission 'orgpolicy.policies.create' denied`; granting `roles/orgpolicy.policyAdmin` at project scope → `Role ... is not supported for this resource`. Effective policies read fine (all `enforce: false`). New projects do NOT block public buckets (`public_access_prevention: inherited`, `allUsers` grant succeeds) | Labs 3, 6; 02_03, 03_02, 06_01 scripts |
| V3 | Bucket Lock blocked-delete error string; teardown after retention | **Answered.** Lock works (`isLocked=True`); delete inside retention → `HTTPError 403: Object '<b>/<o>' is subject to bucket's retention policy or object retention and cannot be deleted or overwritten until <ts>`; bucket delete with object → `Bucket is not empty`; after expiry, object + bucket delete succeed (bucket delete took 269s) | Lab 4 WORM proof, Lab 6 teardown |
| V4 | Cloud Run functions build SA + scheduler invoker on a fresh project | pending | Lab 4 |
| V5 | Workload Identity Federation per fork | pending | Lab 3 |
| V6 | Vertex AI Gemini on a free-trial project | pending | 05_03 |
| V7 | Free-trial terms at signup ($300 / 90 days, card wording) | pending | 00_02, Lab 1 |
| V8 | `compliances` field contents on Standard-tier SHA findings | retired: no SCC dependency | n/a |

## Findings and fixes

### F1: gcloud bills API calls to the configured project, not the target project
SCC calls against `cgegcp-val-1103` failed with `USER_PROJECT_DENIED ... consumer: projects/grc-pipeline-poc-aj` because the gcloud config still pointed at another account's project.
**Fix:** 00_02 tells learners to `gcloud config set project` and check `gcloud config list`; the probe pins `CLOUDSDK_CORE_PROJECT` / `CLOUDSDK_BILLING_QUOTA_PROJECT` per run.

### F2: `--lock-retention-period --quiet` aborts the lock
`--quiet` takes the prompt's default (No) and prints `Abort locking retention policy`, exit 0, bucket NOT locked. A silent pass.
**Fix:** answer the prompt explicitly, then confirm with `buckets describe --format='value(retention_policy)'` showing `isLocked=True`. Terraform (`retention_policy { is_locked = true }`) avoids the prompt in the labs.

### F3: `iam.disableServiceAccountKeyCreation` has a managed successor
gcloud warns that `constraints/iam.managed.disableServiceAccountKeyCreation` supports dry run and simulation. Use the managed constraint wherever an Organization exists.

### F4: billing accounts cap linked projects
Linking failed with `Cloud billing quota exceeded` on an account with 3 projects. 00_02 tells learners to use one project for the whole course.

### F5 (design-deciding): no Org Policy without an Organization
See V2. Every Org Policy step in the storyboard (02_03, 03_02, Lab 3 baseline, 06_01, Lab 6 enforce) is impossible on the course's stated tenancy. Decision needed from AJ before stages 00 and 06 are written.

### F6: Stages 00-02 converge (2026-11-03)
Run 1: discovery gap map `audit_sink=absent`, `data_access_storage=absent`, `buckets_missing_guardrails=present`, `user_managed_sa_keys=present`; activation created the audit config, `grc-audit-logs` (365 days) and `grc-audit-sink`.
Run 2: discovery reports `audit_sink=pipeline`, `data_access_storage=present`. Activation keeps managing both: **No changes**.
Design note: activation must keep managing what it created, or run 2 destroys it. The sink and log bucket carry `managed-by: cgegcp`; audit configs have no description field, so `present` is managed too (Terraform merges, changes nothing).
One transient `Post https://cloudresourcemanager...` network error on a run; a clean rerun passed.

### F7: No `terraform import` step exists for Lab 2's manual setting
`google_project_iam_audit_config` merges into an existing audit config without import. The 03_03 import beat was removed from the storyboard.

### F8 (teaching gift): new no-Organization projects grant `roles/editor` to default service accounts
The first collector run on a fresh project failed `CHK-IAM-01` with evidence:
`roles/editor` → `serviceAccount:<PROJECT_NUMBER>-compute@developer.gserviceaccount.com` and `serviceAccount:<PROJECT_ID>@appspot.gserviceaccount.com`.
Inside an Organization, Org Policy `iam.automaticIamGrantsForDefaultServiceAccounts` normally prevents this; without one, nothing does.
**Course use:** Lab 4's first real finding is one nobody created on purpose. Removing it is safe because the pipeline builds as `grc-builder`, not the compute default account.

### F9: Stage 3 deploys first try with a dedicated build identity
`google_cloudfunctions2_function` with `build_config.service_account = grc-builder` (only `roles/cloudbuild.builds.builder` + objectViewer on the source bucket) built in 1m16s. This sidesteps the April POC's build-permission error on the compute default account. Scheduler → function with an OIDC token from `grc-scheduler` holding `run.invoker` on that one service: `AttemptFinished ... Original HTTP response code number = 200`.
Note: `gcloud scheduler jobs describe` showed `status.code=-1` with no lastAttemptTime for ~2 minutes after a forced run; the scheduler logs are the truth.

### F10: Collector results
11 results per run on the validation project (4 buckets × 2 bucket checks, 3 project-level checks). Second run: still 11 documents, every one carrying the latest `run_id` (upsert proven).
Lab note: Cloud Functions creates `gcf-v2-sources-<PROJECT_NUMBER>-<REGION>` itself; it passes both bucket checks.

### F11: WORM proof on the real reports bucket
`retention_policy`: `isLocked=True; retentionPeriod=86400`. Delete attempt → `HTTPError 403: Object 'cgegcp-val-1103-reports/worm-proof.txt' is subject to bucket's retention policy or object retention and cannot be deleted or overwritten until ...`
