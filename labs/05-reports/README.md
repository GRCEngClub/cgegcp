# Lab 5: Generate your first ATO deliverables

| | |
|---|---|
| **Video** | 05_02 (and 05_03 for the optional digest) |
| **Hands-on time** | ~40 min |
| **Cost** | Under $1 (the optional Gemini digest costs a fraction of a cent per run) |
| **Prerequisites** | Lab 4, with at least one collector run |
| **Where you'll work** | `stages/04-reporting`, repo root, optionally `stages/05-narrative` |

## Steps

### 1. Deploy the reporter

**where:** `stages/04-reporting`

```bash
cd stages/04-reporting
terraform init -backend-config=../../labs/03-foundation/backend.hcl
terraform apply
```

`grc-reporter` gets exactly two permissions: read Firestore, and **create** objects in the reports bucket. It can't overwrite, delete or read Asset Inventory.

### 2. Generate the reports

```bash
gcloud scheduler jobs run grc-report-poam --location=us-central1
gcloud scheduler jobs run grc-report-sar --location=us-central1
gcloud scheduler jobs run grc-report-ssp --location=us-central1
gcloud storage ls -r gs://YOUR_PROJECT_ID-reports/
```

Every file name carries a timestamp, because the bucket is locked and nothing is ever overwritten. Samples from the validation run are in `docs/sample-reports/`.

### 3. Trace one POA&M line to its evidence

Open the POA&M CSV. Take the `poam_id` of any line and open that document in **Firestore > assessments**: same resource, same `run_id`, and the `evidence` field holds the inventory record the decision came from. That trace is what you walk an auditor through.

### 4. Validate the SSP

```bash
curl -sSLo /tmp/oscal_ssp_schema.json https://github.com/usnistgov/OSCAL/releases/download/v1.1.2/oscal_ssp_schema.json
gcloud storage cp "$(gcloud storage ls gs://YOUR_PROJECT_ID-reports/ssp/ | tail -1)" /tmp/ssp.json
.venv/bin/python labs/05-reports/validate_ssp.py /tmp/oscal_ssp_schema.json /tmp/ssp.json
```

**Expected:** `VALID` (validated against the official NIST OSCAL 1.1.2 SSP schema).

### 5. Prove separation of duties

Even as project Owner, you can't act as `grc-reporter` until you're allowed to. Grant yourself that right on this **one** identity, run the test, then take it away:

```bash
gcloud iam service-accounts add-iam-policy-binding grc-reporter@YOUR_PROJECT_ID.iam.gserviceaccount.com --member="user:$(gcloud config get-value account)" --role=roles/iam.serviceAccountTokenCreator
```

Wait about a minute (validation: 58 seconds) for the grant to take effect. Then try to write evidence as the reporter:

```bash
RT=$(gcloud auth print-access-token --impersonate-service-account=grc-reporter@YOUR_PROJECT_ID.iam.gserviceaccount.com)
curl -s -X PATCH -H "Authorization: Bearer $RT" -H "Content-Type: application/json" "https://firestore.googleapis.com/v1/projects/YOUR_PROJECT_ID/databases/(default)/documents/assessments/sod-test" -d '{"fields":{"status":{"stringValue":"pass"}}}'
```

**Expected (it must fail):** `"code": 403`, `"message": "Missing or insufficient permissions."`, `"status": "PERMISSION_DENIED"`. Save it as `evidence/02-reporter-write-denied.txt`.

Before the grant took effect, the impersonation itself failed with `Permission 'iam.serviceAccounts.getAccessToken' denied`. That's a control too: nobody becomes a pipeline identity silently. Now remove the grant:

```bash
gcloud iam service-accounts remove-iam-policy-binding grc-reporter@YOUR_PROJECT_ID.iam.gserviceaccount.com --member="user:$(gcloud config get-value account)" --role=roles/iam.serviceAccountTokenCreator
```

### 6. Optional: the AI digest (Stage 5, never graded)

**where:** `stages/05-narrative`

```bash
cd ../05-narrative
terraform init -backend-config=../../labs/03-foundation/backend.hcl
terraform apply
gcloud scheduler jobs run grc-digest-weekly --location=us-central1
```

The digest lands in `digest/`, labeled as AI-generated, with every factual sentence citing `[file:line]` in the SAR or POA&M. Check two citations yourself.

Model notes from validation: new projects can't use the Gemini 2.5 models (`404 ... not found or your project does not have access`). Current models answer only at location **`global`**. The default is `gemini-3.5-flash-lite`; change `gemini_model` if it's ever retired.

Then the real test of where AI sits: `terraform destroy` in `stages/05-narrative`, and run the collector and a report again. Everything still works.

## Teardown

None yet. Lab 6 builds on this.
