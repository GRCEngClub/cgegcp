# Lab 6: Close the loop

| | |
|---|---|
| **Video** | 06_02 |
| **Hands-on time** | ~60 min |
| **Cost** | Under $1 |
| **Prerequisites** | Labs 4 and 5 |
| **Where you'll work** | `stages/06-enforcement`, repo root, GitHub |

## Steps

### 1. Deploy the remediator in report-only mode

**where:** `stages/06-enforcement`

```bash
cd stages/06-enforcement
terraform init -backend-config=../../labs/03-foundation/backend.hcl
terraform apply
```

`grc-remediator` holds one custom role, `grcBucketRemediator`, with four permissions: `storage.buckets.get`, `getIamPolicy`, `setIamPolicy` and `update`. Read the blast-radius note in `docs/CONTROLS.md`.

### 2. Create the problem by hand, outside Terraform

```bash
gcloud storage buckets create gs://YOUR_PROJECT_ID-lab6-test --location=us-central1 --uniform-bucket-level-access
gcloud storage buckets add-iam-policy-binding gs://YOUR_PROJECT_ID-lab6-test --member=allUsers --role=roles/storage.objectViewer
```

Wait a minute, then collect:

```bash
gcloud scheduler jobs run grc-collect-daily --location=us-central1
```

`CHK-STG-01` fails for the bucket.

Validation note: Asset Inventory has two read paths. `search-all-iam-policies` showed the public grant in about a minute, while `list_assets` still showed nothing four minutes later. That's why the collector reads bucket IAM through search. If the check passes when it shouldn't, that's the first place to look.

### 3. Rung 1: report-only

```bash
gcloud scheduler jobs run grc-remediate-daily --location=us-central1
```

**Firestore > remediations** now has a record with `"status": "would_fix"`, the bucket, the planned action and the evidence. The bucket is still public: report-only changes nothing.

### 4. Rung 2: approval, through a pull request

In `stages/06-enforcement`, set `mode = "approve"` (for example `mode = "approve"` in a `mode.auto.tfvars`), open a pull request, read the plan (`MODE: "report_only" -> "approve"`), merge, and apply. Raising the rung is a reviewed change on the record.

Run the remediator again. It now requests approval. See what's pending:

```bash
.venv/bin/python labs/06-loop/approve.py YOUR_PROJECT_ID
```

**Expected:**

```
pending: YOUR_PROJECT_ID-lab6-test  (remove allUsers/allAuthenticatedUsers bindings; enforce public access prevention)
```

Approve it:

```bash
.venv/bin/python labs/06-loop/approve.py YOUR_PROJECT_ID YOUR_PROJECT_ID-lab6-test
```

**Expected:** `Approved YOUR_PROJECT_ID-lab6-test as you@gmail.com. The remediator fixes it on its next run.`

Run the remediator once more: `"status": "fixed"`. Check the bucket:

```bash
gcloud storage buckets describe gs://YOUR_PROJECT_ID-lab6-test --format='value(public_access_prevention,uniform_bucket_level_access)'
```

**Expected:** `enforced	True`. Collect again: `CHK-STG-01` passes, and the next POA&M drops the line. Detected, approved, fixed, re-collected, documented.

### 5. Watch it handle a recurrence

Make the bucket public again (step 2's second command), collect, run the remediator. It reopens the case as `pending_approval`. An old `fixed` record never hides a new failure. Validation caught exactly that bug before the course shipped.

### 6. Prove the preventive half

On a branch, add a bucket without guardrails and a service account key, and open a pull request:

```hcl
resource "google_storage_bucket" "loose" {
  name     = "${var.project_id}-loose"
  location = "us-central1"
}

resource "google_service_account_key" "nope" {
  service_account_id = "grc-collector@${var.project_id}.iam.gserviceaccount.com"
}
```

The gate fails and names each rule (validated messages):

```
CHK-STG-01: google_storage_bucket.loose must set public_access_prevention = "enforced".
CHK-STG-02: google_storage_bucket.loose must set uniform_bucket_level_access = true.
CHK-IAM-02: google_service_account_key.nope creates a service account key. Workloads use attached identities; CI uses Workload Identity Federation.
```

Save the failed run as `evidence/03-gate-failed.txt` and close the pull request.

## Teardown

Destroy in reverse order (`06` down to `00`): `cd stages/<stage> && terraform destroy`.

The locked reports bucket can't be deleted until its reports age out (one day). Before then you'll see `ERROR: Bucket is not empty`. Tomorrow, delete it and the state bucket:

```bash
gcloud storage rm --recursive gs://YOUR_PROJECT_ID-reports
gcloud storage rm --recursive gs://YOUR_PROJECT_ID-tfstate
```

If you're submitting the capstone, leave everything running until you've submitted: the grader looks for real run history.
