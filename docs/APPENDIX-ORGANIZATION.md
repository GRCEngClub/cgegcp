# Appendix: if you have an Organization

**The course is project-scoped on purpose.** Every lab and the capstone run in one project with no Organization above it, and nothing here is graded. Read this when your company's projects sit inside an Organization and you want to know what the platform adds on top of the pipeline you built.

**What was validated:** the pipeline itself, end to end, on a project with no Organization (`docs/VALIDATION-LOG.md`). The Organization features below were not run in that validation, because they can't be: a project with no Organization can't hold an organization policy. The commands follow Google's documentation, which is linked in each section. Test them in a sandbox folder before you rely on them.

## What an Organization changes

| | No Organization (the course) | Inside an Organization |
|---|---|---|
| Where a control is set | The project | Organization, folder or project, inherited downward |
| Preventive guardrail | Secure defaults in Terraform + the pull request gate | Org Policy also refuses the request at the API |
| Reach | Resources created through your pipeline | Every resource, including ones made by hand in the console |
| Posture findings | Your five checks over Cloud Asset Inventory | Your checks, plus Security Command Center |
| Default service accounts | Get `roles/editor` on new projects (Lab 4's first finding) | Usually blocked by `iam.automaticIamGrantsForDefaultServiceAccounts` |

The pipeline works unchanged inside an Organization. State your tenancy in the first line of your README either way.

## 1. Folder-level guardrails with Org Policy

An organization policy set on a folder applies to every project in that folder, including projects created later. That is the difference from the gate: the gate checks changes that go through your pull requests, and Org Policy checks every request no matter who makes it or how.

You need `roles/orgpolicy.policyAdmin`, granted at the Organization. On a project with no Organization, even Owner gets `Permission 'orgpolicy.policies.create' denied`, and the role "is not supported for this resource" (validation finding V2).

The two constraints that match the course's checks:

| Constraint | Blocks | Course check it backs up |
|---|---|---|
| `storage.publicAccessPrevention` | Public access on any bucket | `CHK-STG-01` |
| `iam.managed.disableServiceAccountKeyCreation` | New user-managed service account keys | `CHK-IAM-02` |

A policy file for a folder:

```yaml
name: folders/YOUR_FOLDER_ID/policies/storage.publicAccessPrevention
spec:
  rules:
  - enforce: true
```

```bash
gcloud org-policies set-policy policy.yaml
```

Reference: [Organization Policy overview](https://cloud.google.com/resource-manager/docs/organization-policy/overview) and the [constraint list](https://cloud.google.com/resource-manager/docs/organization-policy/org-policy-constraints).

## 2. Dry run first: the same ladder you built in Lab 6

Lab 6 moved the remediator from `report_only` to `approve` to `auto`, and you only moved up when the data said it was safe. Org Policy has the first rung built in. A policy in dry-run mode records what it would have denied in the audit logs and blocks nothing.

```yaml
name: folders/YOUR_FOLDER_ID/policies/storage.publicAccessPrevention
dryRunSpec:
  rules:
  - enforce: true
```

```bash
gcloud org-policies set-policy policy.yaml --update-mask=dryRunSpec
```

Leave it in dry run for a full release cycle, read the violations, fix or exempt what you find, then move the rule from `dryRunSpec` to `spec`. Raising it is a reviewed change, the same as raising `remediation_mode` in Stage 6.

Reference: [Create an organization policy in dry-run mode](https://cloud.google.com/resource-manager/docs/organization-policy/dry-run-policy).

## 3. Custom constraints

When no built-in constraint says what you need, you write your own: a condition over a resource's fields, checked on create and update. This example comes from Google's Cloud Storage documentation and requires Object Versioning on buckets:

```yaml
name: organizations/YOUR_ORG_ID/customConstraints/custom.bucketVersioning
resourceTypes:
- storage.googleapis.com/Bucket
methodTypes:
- CREATE
- UPDATE
condition: "resource.versioning.enabled == true"
actionType: ALLOW
displayName: Buckets must have Object Versioning enabled
description: Buckets must be created or updated with Object Versioning enabled.
```

```bash
gcloud org-policies set-custom-constraint constraint.yaml
```

A custom constraint is defined once at the Organization and does nothing until an organization policy enforces it on the Organization, a folder or a project. Put it in dry run first, as in section 2.

It is the same idea as a Rego rule in `policy/`: a rule over resource fields. The gate runs it on the plan before deploy. A custom constraint runs it at the API on every request.

Reference: [Creating and managing custom constraints](https://cloud.google.com/resource-manager/docs/organization-policy/creating-managing-custom-constraints) and [custom constraints for Cloud Storage](https://cloud.google.com/storage/docs/custom-constraints).

## 4. Security Command Center

Security Command Center is activated for an Organization and produces its own posture findings. On a project with no Organization it is not active and has no command-line activation path (validation finding V1), which is why the collector runs its own checks over Cloud Asset Inventory.

Inside an Organization, treat it as a second evidence source. Keep the five checks, because you can read every line of them and the capstone rubric asks for a check of your own. Add a collector function that reads Security Command Center findings into the same `assessments` collection, stamped with the same `run_id` and `collected_at`, and map them in `controls.json`. Reports still read from Firestore only.

Reference: [Security Command Center overview](https://cloud.google.com/security-command-center/docs/security-command-center-overview).

## What stays the same

- **The evidence store.** Org Policy and Security Command Center tell you about today. Firestore and the locked reports bucket are still how you answer for last March.
- **The gate and the remediator.** Org Policy refuses a bad request. The gate explains the failure in the pull request before anyone tries, and the remediator handles what was already there. Keep all three layers.
- **Identities.** Six service accounts, zero keys, one job each.

## Capstone note

The capstone is graded on the project-scoped pipeline. Organization features are neither required nor scored. If you use them, say so in your tenancy statement and in `docs/CONTROLS.md`.
