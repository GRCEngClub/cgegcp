# Lab 2: Turn it all on

| | |
|---|---|
| **Video** | 02_05 |
| **Hands-on time** | ~30 min |
| **Cost** | $0 |
| **Prerequisites** | Lab 1; the Python environment from `docs/SETUP.md` step 5 |
| **Where you'll work** | Google Cloud console, then the repo root |

This is the only lab where you click. You turn on logging by hand, break something on purpose, find it the way the pipeline will, and fix it.

## Steps

### 1. Data Access logs for Cloud Storage (console)

**IAM & Admin > Audit Logs > Google Cloud Storage:** tick **Data Read** and **Data Write**, then save. Admin Activity logs are always on; Data Access logs are your decision.

### 2. Make a bucket public, on purpose

**where:** repo root. Replace `YOUR_PROJECT_ID`.

```bash
gcloud storage buckets create gs://YOUR_PROJECT_ID-lab2-test --location=us-central1 --uniform-bucket-level-access
gcloud storage buckets add-iam-policy-binding gs://YOUR_PROJECT_ID-lab2-test --member=allUsers --role=roles/storage.objectViewer
```

**The grant succeeds.** A new project with no Organization doesn't block public buckets (validated: `public_access_prevention` shows `inherited`, and the `allUsers` binding is added). That gap is why the pipeline exists.

### 3. Find it with Asset Inventory

```bash
gcloud asset search-all-iam-policies --scope=projects/YOUR_PROJECT_ID --query='policy:allUsers' --format='value(resource)'
```

**Expected:** `//storage.googleapis.com/YOUR_PROJECT_ID-lab2-test`

**Empty right after the grant? That's normal.** On validation it took **57 seconds** to appear. Wait a minute and run it again.

### 4. Run the check

```bash
.venv/bin/python labs/02-toolkit/run_checks.py YOUR_PROJECT_ID CHK-STG-01
```

**Expected** (the public bucket fails; other buckets pass):

```
CHK-STG-01  FAIL  YOUR_PROJECT_ID-lab2-test
      evidence: {'public_bindings': [{'role': 'roles/storage.objectViewer', 'members': ['allUsers']}]}
```

This is the same code the Stage 3 collector runs every day.

### 5. Find who did it

**Logs Explorer**, query:

```
resource.type="gcs_bucket"
resource.labels.bucket_name="YOUR_PROJECT_ID-lab2-test"
protoPayload.methodName="storage.setIamPermissions"
```

You'll see your own account making the bucket public, with a timestamp. Bucket IAM changes are logged as `storage.setIamPermissions`; project IAM changes as `SetIamPolicy`. In Lab 6 the same query shows `grc-remediator` undoing a human's change, each entry with its own principal.

### 6. Fix it, then confirm

```bash
gcloud storage buckets remove-iam-policy-binding gs://YOUR_PROJECT_ID-lab2-test --member=allUsers --role=roles/storage.objectViewer
.venv/bin/python labs/02-toolkit/run_checks.py YOUR_PROJECT_ID CHK-STG-01
```

The bucket now passes. Detected, fixed, confirmed: the loop the whole pipeline automates.

## Teardown

```bash
gcloud storage rm --recursive gs://YOUR_PROJECT_ID-lab2-test
```

**Keep** the Data Access log setting. In Lab 4, discovery finds it, and activation leaves your decision alone.
