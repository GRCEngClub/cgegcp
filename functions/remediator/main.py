"""Stage 6 remediator: fixes public buckets (CHK-STG-01), one rung at a time.

MODE (set in Terraform, so raising it is a reviewed pull request):
  report_only  record what it WOULD fix, change nothing
  approve      record a request; fix only after a human sets it to "approved"
  auto         fix immediately
Reads failing CHK-STG-01 results from the evidence store. Runs as grc-remediator, whose
custom role can read and change bucket IAM and bucket settings, and nothing else.
Every action is recorded in Firestore collection "remediations" and in Cloud Logging.
"""
import datetime
import json
import os

import functions_framework
from google.cloud import firestore, storage

PROJECT = os.environ["GCP_PROJECT_ID"]
MODE = os.environ.get("MODE", "report_only")
PUBLIC = {"allUsers", "allAuthenticatedUsers"}


def log(**kw):
    print(json.dumps({"severity": "NOTICE", "component": "grc-remediator", "mode": MODE, **kw}))


def fix(bucket_name):
    # get_bucket (not .bucket) loads current settings. Patching an unloaded bucket sends
    # defaults and switched uniform bucket-level access OFF during validation (CHK-STG-02 caught it).
    b = storage.Client(project=PROJECT).get_bucket(bucket_name)
    policy = b.get_iam_policy(requested_policy_version=3)
    removed = []
    for binding in policy.bindings:
        public = PUBLIC & set(binding["members"])
        if public:
            removed += [{"role": binding["role"], "member": m} for m in public]
            binding["members"] = set(binding["members"]) - PUBLIC
    policy.bindings = [x for x in policy.bindings if x["members"]]
    b.set_iam_policy(policy)
    b.iam_configuration.public_access_prevention = "enforced"
    b.iam_configuration.uniform_bucket_level_access_enabled = True
    b.patch()
    return removed


@functions_framework.http
def handler(request):
    db = firestore.Client(project=PROJECT)
    now = datetime.datetime.now(datetime.timezone.utc)
    failing = [d for d in db.collection("assessments").stream()
               if d.get("check_id") == "CHK-STG-01" and d.get("status") == "fail"]
    out = []
    for d in failing:
        bucket = d.get("resource")
        ref = db.collection("remediations").document(d.id)
        prior = (ref.get().to_dict() or {})
        # A fix only counts if it came after this failure started. If the bucket went public
        # AGAIN, the old "fixed" record must not hide it (validation caught exactly that).
        started = d.get("first_failed_at")
        if prior.get("status") == "fixed" and started and prior.get("fixed_at") and prior["fixed_at"] >= started:
            continue
        if prior.get("status") == "fixed":
            prior = {}  # recurrence: start the ladder over for this bucket
        planned = {"bucket": bucket, "check_id": "CHK-STG-01", "assessment": d.id,
                   "action": "remove allUsers/allAuthenticatedUsers bindings; enforce public access prevention",
                   "evidence": d.get("evidence"), "mode": MODE, "updated_at": now}
        if MODE == "report_only":
            ref.set({**planned, "status": "would_fix"}, merge=True)
            log(message="would fix", bucket=bucket)
        elif MODE == "approve" and prior.get("status") != "approved":
            ref.set({**planned, "status": "pending_approval"}, merge=True)
            log(message="approval requested", bucket=bucket,
                approve=f"python3 labs/06-loop/approve.py {PROJECT} {bucket}")
        else:  # auto, or approve with a human "approved"
            removed = fix(bucket)
            ref.set({**planned, "status": "fixed", "removed": removed, "fixed_at": now,
                     "approved_by": prior.get("approved_by")}, merge=True)
            log(message="fixed", bucket=bucket, removed=removed, approved_by=prior.get("approved_by"))
        out.append({"bucket": bucket, "status": (ref.get().to_dict() or {}).get("status")})
    return {"mode": MODE, "failing_public_buckets": len(failing), "actions": out}
