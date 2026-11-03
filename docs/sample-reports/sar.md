# Security Assessment Report: cge-gcp-lab

Generated 2026-11-03 18:40 UTC from the evidence store (Firestore). 11 assessment results.

| CSF 2.0 | Outcome | Pass | Fail | Result |
|---|---|---|---|---|
| PR.AA-01 | Identities and credentials for authorized users, services, and hardware are managed by the organization | 1 | 0 | Satisfied |
| PR.AA-05 | Access permissions, entitlements, and authorizations are defined in a policy, managed, enforced, and reviewed, and incorporate the principles of least privilege and separation of duties | 8 | 1 | Not satisfied |
| PR.DS-01 | The confidentiality, integrity, and availability of data-at-rest are protected | 4 | 0 | Satisfied |
| PR.PS-04 | Log records are generated and made available for continuous monitoring | 1 | 0 | Satisfied |

## Checks

- **CHK-IAM-01** No service account holds a basic role (Owner, Editor, Viewer) (800-53: AC-6): 0 pass, 1 fail
  - fail: `//cloudresourcemanager.googleapis.com/projects/cge-gcp-lab`
- **CHK-IAM-02** No service account has a user-managed key (800-53: IA-5): 1 pass, 0 fail
- **CHK-LOG-01** Data Access logs (read and write) are on for Cloud Storage (800-53: AU-2, AU-12): 1 pass, 0 fail
- **CHK-STG-01** No Cloud Storage bucket is publicly accessible (800-53: AC-3, AC-6, SC-7): 4 pass, 0 fail
- **CHK-STG-02** Uniform bucket-level access is on for every bucket (800-53: AC-3, AC-6): 4 pass, 0 fail
