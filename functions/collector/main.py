"""Stage 3 collector: Cloud Asset Inventory in, check results out to Firestore.

Runs as grc-collector, which can read Asset Inventory and write Firestore. Nothing else.
Every run stamps a run_id. Document IDs are derived from check + resource, so the same
result collected twice updates one document (upsert) and counts stay honest.
"""
import datetime
import hashlib
import json
import os
import pathlib
import uuid

import functions_framework
from google.cloud import asset_v1, firestore
from google.protobuf.json_format import MessageToDict

import checks

PROJECT = os.environ["GCP_PROJECT_ID"]
CONTROLS = json.loads((pathlib.Path(__file__).parent / "controls.json").read_text())["checks"]


def _d(msg):
    """Asset resources are proto-plus messages; IAM policies are plain protobufs. Handle both."""
    return MessageToDict(getattr(msg, "_pb", msg))


def _assets(client, asset_types, content_type):
    req = {"parent": f"projects/{PROJECT}", "asset_types": asset_types, "content_type": content_type}
    return list(client.list_assets(request=req))


def gather():
    """One read of the inventory. Every check works from this snapshot."""
    c = asset_v1.AssetServiceClient()
    R, P = asset_v1.ContentType.RESOURCE, asset_v1.ContentType.IAM_POLICY
    buckets = {a.name.split("/")[-1]: _d(a.resource).get("data", {})
               for a in _assets(c, ["storage.googleapis.com/Bucket"], R)}
    bucket_policies = {a.name.split("/")[-1]: _d(a.iam_policy).get("bindings", [])
                       for a in _assets(c, ["storage.googleapis.com/Bucket"], P)}
    proj = _assets(c, ["cloudresourcemanager.googleapis.com/Project"], P)
    proj_policy = _d(proj[0].iam_policy) if proj else {}
    keys = {a.name: _d(a.resource).get("data", {})
            for a in _assets(c, ["iam.googleapis.com/ServiceAccountKey"], R)}
    return buckets, bucket_policies, proj_policy, keys


def run_checks():
    buckets, bucket_policies, proj_policy, keys = gather()
    project = f"//cloudresourcemanager.googleapis.com/projects/{PROJECT}"
    return (checks.chk_stg_01(buckets, bucket_policies)
            + checks.chk_stg_02(buckets)
            + checks.chk_iam_01(project, proj_policy.get("bindings", []))
            + checks.chk_iam_02(project, keys)
            + checks.chk_log_01(project, proj_policy.get("auditConfigs", [])))


def doc_id(check_id, resource):
    return check_id + "_" + hashlib.sha256(resource.encode()).hexdigest()[:16]


@functions_framework.http
def handler(request):
    run_id = str(uuid.uuid4())
    now = datetime.datetime.now(datetime.timezone.utc)
    db = firestore.Client(project=PROJECT)
    results = run_checks()
    prior = {d.id: d.to_dict() for d in db.collection("assessments").stream()}
    batch = db.batch()
    for r in results:
        ctl = CONTROLS[r["check_id"]]
        did = doc_id(r["check_id"], r["resource"])
        before = prior.get(did, {})
        # POA&M age: when this failure started. Kept across runs, cleared when it passes.
        first_failed = ((before.get("first_failed_at") or now) if before.get("status") == "fail" else now) \
            if r["status"] == "fail" else None
        batch.set(db.collection("assessments").document(did), {
            **r, "title": ctl["title"], "severity": ctl["severity"],
            "csf": ctl["csf"], "sp800_53": ctl["sp800_53"], "first_failed_at": first_failed,
            "collected_at": now, "run_id": run_id, "collector": "grc-collector",
        }, merge=True)
    batch.commit()

    # A failing result whose resource vanished (bucket deleted, key removed) would sit in
    # the POA&M forever. Anything still "fail" from an earlier run, not seen this run, is resolved.
    seen = {doc_id(r["check_id"], r["resource"]) for r in results}
    for did, d in prior.items():
        if d.get("status") == "fail" and did not in seen:
            db.collection("assessments").document(did).update({"status": "resolved", "resolved_reason": "resource no longer present",
                                "collected_at": now, "run_id": run_id})
    summary = {"run_id": run_id, "results": len(results),
               "failing": sorted({r["check_id"] for r in results if r["status"] == "fail"})}
    print(json.dumps({"severity": "INFO", "message": "collector run complete", **summary}))
    return summary
