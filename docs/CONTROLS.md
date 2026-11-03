# Controls

Every check, gate rule and pipeline design choice, mapped to NIST CSF 2.0 and NIST SP 800-53 Rev. 5. The check mappings are data (`functions/collector/controls.json`); this page explains them. Keep it current with the code: the grader compares the two.

## Checks (detective, daily, Stage 3)

| Check | What it tests | CSF 2.0 | 800-53 | Corrected by |
|---|---|---|---|---|
| `CHK-STG-01` | No bucket binding grants `allUsers` / `allAuthenticatedUsers` | PR.AA-05, PR.DS-01 | AC-3, AC-6, SC-7 | Stage 6 remediator |
| `CHK-STG-02` | Uniform bucket-level access is on | PR.AA-05 | AC-3, AC-6 | Stage 6 (kept on during every fix) |
| `CHK-IAM-01` | No service account holds Owner, Editor or Viewer on the project | PR.AA-05 | AC-6 | Manual (Lab 4) |
| `CHK-IAM-02` | No user-managed service account keys | PR.AA-01 | IA-5 | Manual; gate blocks new ones |
| `CHK-LOG-01` | Data Access logs (read + write) on for Cloud Storage | PR.PS-04 | AU-2, AU-12 | Stage 2 activation |

## Gate rules (preventive, every pull request)

| Rule | File | Blocks | Maps to |
|---|---|---|---|
| Basic roles | `policy/iam.rego` | Any IAM resource granting `roles/owner`, `roles/editor`, `roles/viewer` | `CHK-IAM-01` · AC-6 |
| Service account keys | `policy/iam.rego` | Any `google_service_account_key` | `CHK-IAM-02` · IA-5 |
| Bucket guardrails | `policy/storage.rego` | Buckets without `public_access_prevention = "enforced"` or `uniform_bucket_level_access = true`; any public bucket member | `CHK-STG-01/02` · AC-3, SC-7 |
| Dedicated remediator | `policy/remediation.rego` | `grc-remediator` running as any identity but its own | AC-5, AC-6 |

## Design controls

| Design choice | Where | 800-53 |
|---|---|---|
| Six identities, created with zero permissions; each stage grants its own | Stage 0, each stage | AC-6 |
| Collector writes facts, reporter writes reports, neither can do the other's job | Stages 3, 4 | AC-5 |
| Reports bucket: retention policy locked (WORM); reporter can only create objects | Stage 3, 4 | AU-9, AU-11 |
| Audit logs kept 365 days in `grc-audit-logs` (the `_Default` bucket keeps 30) | Stage 2 | AU-11 |
| Every collector run stamps `run_id` and `collected_at`; document IDs are check + resource | Stage 3 | AU-3, CA-7 |
| Remediation mode is a Terraform variable: raising it is a reviewed pull request | Stage 6 | CM-3 |
| CI holds read-only roles through Workload Identity Federation; no keys anywhere | `labs/03-foundation` | IA-5, AC-6 |

## Blast radius

- **`grc-remediator`** holds custom role `grcBucketRemediator`: `storage.buckets.get`, `getIamPolicy`, `setIamPolicy`, `update`. It cannot read or delete objects, touch any other resource type, or delete a bucket. In `report_only` mode it changes nothing.
- **`grc-collector`**: `cloudasset.viewer` + `datastore.user`. It can't change any resource.
- **CI**: the read-only roles in `labs/03-foundation/ci-roles.txt`, plus write access to the state lock. CI never applies.
