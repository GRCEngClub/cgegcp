"""List or approve pending remediations. The approval is a record: who, when, which bucket.

Usage:
  python3 labs/06-loop/approve.py <PROJECT_ID>            list pending requests
  python3 labs/06-loop/approve.py <PROJECT_ID> <BUCKET>   approve the one for BUCKET
The remediator fixes an approved bucket on its next run.
"""
import datetime
import os
import subprocess
import sys

from google.cloud import firestore


def client(project):
    token = os.environ.get("GOOGLE_OAUTH_ACCESS_TOKEN")  # optional; ADC otherwise
    if token:
        from google.oauth2.credentials import Credentials
        return firestore.Client(project=project, credentials=Credentials(token))
    return firestore.Client(project=project)


def main(project, bucket=None):
    db = client(project)
    pending = [d for d in db.collection("remediations").stream()
               if d.get("status") == "pending_approval"]
    if bucket is None:
        if not pending:
            print("No remediations are waiting for approval.")
        for d in pending:
            print(f"pending: {d.get('bucket')}  ({d.get('action')})")
        return
    match = [d for d in pending if d.get("bucket") == bucket]
    if not match:
        sys.exit(f"No pending remediation for {bucket}. Run without a bucket to list them.")
    who = subprocess.run(["gcloud", "config", "get-value", "account"],
                         capture_output=True, text=True).stdout.strip()
    match[0].reference.update({"status": "approved", "approved_by": who,
                               "approved_at": datetime.datetime.now(datetime.timezone.utc)})
    print(f"Approved {bucket} as {who}. The remediator fixes it on its next run.")


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    main(*sys.argv[1:])
