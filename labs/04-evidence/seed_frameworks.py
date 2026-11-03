"""Lab 4: load the framework and the crosswalk into Firestore.

frameworks/{CSF id}  the NIST CSF 2.0 outcomes this pipeline tests
mappings/{check id}  each check's CSF outcomes and 800-53 controls

Source of truth is functions/collector/controls.json, so the collector, the reports and
this seed can never disagree. Re-running is safe: documents are overwritten in place.

Usage (from the repo root): python3 labs/04-evidence/seed_frameworks.py <PROJECT_ID>
"""
import json
import os
import pathlib
import sys

from google.cloud import firestore

CSF = {
    "PR.AA-01": "Identities and credentials for authorized users, services, and hardware are managed by the organization",
    "PR.AA-05": "Access permissions, entitlements, and authorizations are defined in a policy, managed, enforced, and reviewed, and incorporate the principles of least privilege and separation of duties",
    "PR.DS-01": "The confidentiality, integrity, and availability of data-at-rest are protected",
    "PR.PS-04": "Log records are generated and made available for continuous monitoring",
}


def client(project):
    token = os.environ.get("GOOGLE_OAUTH_ACCESS_TOKEN")  # optional; ADC otherwise
    if token:
        from google.oauth2.credentials import Credentials
        return firestore.Client(project=project, credentials=Credentials(token))
    return firestore.Client(project=project)


def main(project):
    root = pathlib.Path(__file__).resolve().parents[2]
    checks = json.loads((root / "functions/collector/controls.json").read_text())["checks"]
    db = client(project)
    for cid, title in CSF.items():
        db.collection("frameworks").document(cid).set({"framework": "NIST CSF 2.0", "title": title})
    for cid, c in checks.items():
        db.collection("mappings").document(cid).set(c)
    print(f"Seeded {len(CSF)} frameworks and {len(checks)} mappings into {project}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else sys.exit(__doc__))
