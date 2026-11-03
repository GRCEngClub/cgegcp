# Lab 4: Evidence flowing end to end

| | |
|---|---|
| **Video** | 04_04 |
| **Hands-on time** | ~60 min (the function build adds about a minute and a half of waiting) |
| **Cost** | Under $1. Firestore, Cloud Run functions and Scheduler round to cents at lab volume |
| **Prerequisites** | Lab 3 |
| **Where you'll work** | `stages/01-discovery`, `stages/02-activation`, `stages/03-evidence-store`, repo root |

## Read this first: the one irreversible step

Stage 3 **locks** the retention policy on `YOUR_PROJECT_ID-reports`. A locked retention policy can never be removed. Nobody, including you as Owner, can delete a report until it ages out, and the bucket can't be deleted while it holds reports. The labs set a **one-day** window (`report_retention_seconds = 86400`), so this costs you nothing. For production, set it to your audit retention requirement.

## Steps

### 1. Discovery: measure, change nothing

**where:** `stages/01-discovery`

```bash
cd stages/01-discovery
terraform init -backend-config=../../labs/03-foundation/backend.hcl
terraform apply
```

**Expected on a fresh project** (validated; if you kept Lab 2's Data Access setting, `data_access_storage` reads `present`):

```
gap_map = {
  "audit_sink" = "absent"
  "buckets_missing_guardrails" = "present"
  "data_access_storage" = "absent"
  "user_managed_sa_keys" = "present"
}
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

States: `present` (meets the baseline, leave it) · `absent` (Stage 2 activates it) · `different` (a human decides) · `pipeline` (Stage 2 created it, keep managing).

### 2. Activation: close the gaps, only the gaps

**where:** `stages/02-activation`

```bash
cd ../02-activation
terraform init -backend-config=../../labs/03-foundation/backend.hcl
terraform apply
```

This creates `grc-audit-logs` (365-day retention; `_Default` keeps 30) and `grc-audit-sink`, plus Data Access logs if they were absent.

Now prove it settles. Re-run discovery, then activation:

```bash
cd ../01-discovery && terraform apply
cd ../02-activation && terraform apply
```

Discovery now reports `"audit_sink" = "pipeline"`, and activation says **No changes**. If activation ever proposed destroying the sink here, the ownership marker (`managed-by: cgegcp`) would be missing.

### 3. The evidence store and the collector

**where:** `stages/03-evidence-store`

```bash
cd ../03-evidence-store
terraform init -backend-config=../../labs/03-foundation/backend.hcl
terraform apply
```

**Expected** (validated: 11 resources, function built in ~1m16s):

```
google_cloudfunctions2_function.collector: Creation complete after 1m16s
Apply complete! Resources: 11 added, 0 changed, 0 destroyed.
```

The function builds as `grc-builder`, which holds only `roles/cloudbuild.builds.builder`. New projects don't give any account permission to build functions, so the pipeline brings its own builder.

### 4. Seed the framework and the crosswalk

**where:** repo root

```bash
.venv/bin/python labs/04-evidence/seed_frameworks.py YOUR_PROJECT_ID
```

**Expected:** `Seeded 4 frameworks and 5 mappings into YOUR_PROJECT_ID`

### 5. Collect now

```bash
gcloud scheduler jobs run grc-collect-daily --location=us-central1
```

Then **Firestore > assessments**: one document per check per resource. Each holds `status`, `evidence`, `csf`, `sp800_53`, `run_id` and `collected_at`.

`gcloud scheduler jobs describe` can show an empty last-attempt for a minute or two after a forced run. The scheduler's logs (`resource.type="cloud_scheduler_job"`) are the truth: look for `Original HTTP response code number = 200`.

### 6. Your first real finding (nobody created it)

`CHK-IAM-01` fails on a brand-new project. The evidence (validated):

```
{"basic_role_grants": [
  {"role": "roles/editor", "member": "serviceAccount:YOUR_PROJECT_NUMBER-compute@developer.gserviceaccount.com"},
  {"role": "roles/editor", "member": "serviceAccount:YOUR_PROJECT_ID@appspot.gserviceaccount.com"}]}
```

Without an Organization, Google gives two default service accounts **Editor** on every new project. The pipeline uses neither of them, so remove both grants:

```bash
gcloud projects remove-iam-policy-binding YOUR_PROJECT_ID --role=roles/editor --member=serviceAccount:YOUR_PROJECT_NUMBER-compute@developer.gserviceaccount.com --condition=None
gcloud projects remove-iam-policy-binding YOUR_PROJECT_ID --role=roles/editor --member=serviceAccount:YOUR_PROJECT_ID@appspot.gserviceaccount.com --condition=None
```

Collect again (step 5). `CHK-IAM-01` passes; on validation, the inventory reflected the change within 12 seconds. (Find your project number with `gcloud projects describe YOUR_PROJECT_ID --format='value(projectNumber)'`.)

### 7. Prove the upsert

Count the documents in `assessments`, collect again, count again: same number, and every document carries the newest `run_id`. Same check plus same resource gives the same document ID, so counts stay honest.

### 8. Try to break the evidence

```bash
echo test > /tmp/worm-proof.txt
gcloud storage cp /tmp/worm-proof.txt gs://YOUR_PROJECT_ID-reports/worm-proof.txt
gcloud storage rm gs://YOUR_PROJECT_ID-reports/worm-proof.txt
```

**Expected (it must fail):**

```
ERROR: HTTPError 403: Object 'YOUR_PROJECT_ID-reports/worm-proof.txt' is subject to bucket's retention policy or object retention and cannot be deleted or overwritten until <timestamp>.
```

Save that output as `evidence/01-retention-delete-denied.txt`. The failed delete is your proof of immutability.

## Teardown

None yet. Labs 5 and 6 build on this. Full teardown is at the end of Lab 6.
