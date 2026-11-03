# Lab 3: Deploy your foundation

| | |
|---|---|
| **Video** | 03_03 |
| **Hands-on time** | ~45 min |
| **Cost** | $0 (APIs and service accounts are free; the state bucket holds kilobytes) |
| **Prerequisites** | Labs 1 and 2. A GitHub account (your fork) |
| **Where you'll work** | `labs/03-foundation`, then `stages/00-foundation`, then GitHub |

## Steps

### 1. Bootstrap remote state

**where:** repo root

```bash
./labs/03-foundation/bootstrap.sh
```

This creates `gs://YOUR_PROJECT_ID-tfstate` (versioned, uniform access, public access prevention enforced). It also writes `labs/03-foundation/backend.hcl`, plus a `project.auto.tfvars` in every stage folder so no stage needs `-var` flags. Re-running is safe.

### 2. Deploy stage 00

**where:** `stages/00-foundation`

```bash
cd stages/00-foundation
terraform init -backend-config=../../labs/03-foundation/backend.hcl
terraform apply
```

**Expected outputs** (validated):

```
service_accounts = {
  "grc-builder" = "grc-builder@YOUR_PROJECT_ID.iam.gserviceaccount.com"
  "grc-collector" = "grc-collector@YOUR_PROJECT_ID.iam.gserviceaccount.com"
  "grc-narrator" = "grc-narrator@YOUR_PROJECT_ID.iam.gserviceaccount.com"
  "grc-remediator" = "grc-remediator@YOUR_PROJECT_ID.iam.gserviceaccount.com"
  "grc-reporter" = "grc-reporter@YOUR_PROJECT_ID.iam.gserviceaccount.com"
  "grc-scheduler" = "grc-scheduler@YOUR_PROJECT_ID.iam.gserviceaccount.com"
}
```

Run `terraform apply` a second time: `No changes`.

### 3. Prove every identity starts with nothing

```bash
gcloud projects get-iam-policy YOUR_PROJECT_ID --format=json | grep -c 'grc-'
```

**Expected:** `0`. Six identities, zero permissions. Each later stage grants its own identity exactly what that stage needs.

### 4. Arm your fork (no keys)

**where:** repo root. Use **your** GitHub user and fork name.

```bash
./labs/03-foundation/arm-your-fork.sh YOUR_GITHUB_USER/cgegcp
```

The argument is required and has no default: a default would make your project trust someone else's repository. The script creates a Workload Identity Federation pool that trusts GitHub tokens from your fork only, and grants it the read-only roles in `ci-roles.txt`. CI plans; it never applies.

**Expected** (validated):

```
>> Done. In your fork on GitHub: Settings > Secrets and variables > Actions > Variables tab.
   Add these two repository VARIABLES (not secrets; there is nothing secret to store):

   GCP_PROJECT_ID     = YOUR_PROJECT_ID
   GCP_WIF_PROVIDER   = projects/YOUR_PROJECT_NUMBER/locations/global/workloadIdentityPools/github/providers/github
```

Add both variables in your fork. Until they exist, the workflows skip themselves.

### 5. Watch the gate pass, then watch it fail

Push a branch and open a pull request **against your fork**. `gate` plans every stage and checks each plan against `policy/*.rego`: green.

Now add this to `stages/00-foundation/main.tf` on the branch and push:

```hcl
resource "google_project_iam_member" "oops" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:grc-collector@${var.project_id}.iam.gserviceaccount.com"
}
```

The gate fails and names the rule:

```
FAIL - ... - main - CHK-IAM-01: google_project_iam_member.oops grants basic role roles/editor. Use a predefined or custom role.
```

A gate you've never seen fail is a gate you can't trust. Save the failed run's link for your capstone `evidence/` folder, then revert the commit.

You can run the same check locally against the deliberately bad plan:

```bash
conftest test -p policy policy/tests/bad-plan.json
```

## Teardown

None. Every later lab builds on this foundation.
