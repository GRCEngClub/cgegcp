# Setup: do this once, before Lab 1

**Tenancy assumption: one Google Cloud project on a personal @gmail.com account, with no Organization above it.**

## 1. Use a personal Gmail account

Accounts on a company or custom domain (Google Workspace, Cloud Identity) put every new project under that domain's Organization. Your employer's policies then apply to your lab, and you may not have the access the labs need. Use a **@gmail.com** account.

## 2. Free trial, one project, one budget

1. Sign in at console.cloud.google.com and start the free trial. Google asks for a card to verify identity; the trial doesn't charge it unless you choose to upgrade.
2. Create **one project for the whole course**. Each billing account can link only a few projects (validation hit the limit at three), so don't make one per lab.
3. **Billing > Budgets & alerts:** create a $25 budget for the project with alerts at 50%, 90% and 100%. A budget notifies; it doesn't stop spending.

## 3. Tools

| Tool | Version validated |
|---|---|
| gcloud SDK | 561.0.0 |
| Terraform | 1.14.9 (google provider 8.9.0) |
| Python | 3.9+ (lab scripts) |
| conftest | OPA 1.15 |
| shellcheck | optional, used by `self-check.sh` |

## 4. Log in twice, then pin the project

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
gcloud config list
```

The first login is for gcloud. The second creates Application Default Credentials, which Terraform and the Python scripts use.

**Pin the project and check `gcloud config list` before every lab.** gcloud bills API calls to whichever project its config names. Point it at the wrong one and calls fail with:

```
PERMISSION_DENIED: Caller does not have required permission to use project <other-project>. ... reason: USER_PROJECT_DENIED
```

## 5. Python environment for the lab scripts (repo root)

```bash
python3 -m venv .venv
.venv/bin/pip install -r labs/requirements.txt
```

## If you have an Organization

The pipeline works unchanged inside an Organization. You also gain:

- **Org Policy.** Constraints such as `storage.publicAccessPrevention` and `iam.managed.disableServiceAccountKeyCreation` block bad resources at request time, with a native dry-run mode. On a project with no Organization, even Owner gets `Permission 'orgpolicy.policies.create' denied`, and `roles/orgpolicy.policyAdmin` "is not supported for this resource".
- **Security Command Center** at Organization scope, as an additional evidence source for the collector.
- **No default Editor grants.** Inside an Organization, the `iam.automaticIamGrantsForDefaultServiceAccounts` constraint usually stops Google from giving default service accounts `roles/editor`. Without one, new projects get them (Lab 4's first finding).

State your tenancy in the first line of your README either way.
