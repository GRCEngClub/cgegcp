"""The pipeline's five checks, as code.

Each check reads Cloud Asset Inventory data (already fetched by main.py) and returns
one result per resource: status "pass" or "fail", plus the evidence the decision was
based on. Control mappings live in controls.json, so a check never decides which
framework it satisfies; the crosswalk does.
"""

PUBLIC_MEMBERS = {"allUsers", "allAuthenticatedUsers"}
BASIC_ROLES = {"roles/owner", "roles/editor", "roles/viewer"}
REQUIRED_DATA_ACCESS = {"DATA_READ", "DATA_WRITE"}


def _result(check_id, resource, passed, evidence):
    return {"check_id": check_id, "resource": resource,
            "status": "pass" if passed else "fail", "evidence": evidence}


def chk_stg_01(buckets, bucket_policies):
    """No public buckets: no allUsers / allAuthenticatedUsers in any bucket binding."""
    out = []
    for name in buckets:
        bindings = bucket_policies.get(name, [])
        public = [b for b in bindings if PUBLIC_MEMBERS & set(b.get("members", []))]
        out.append(_result("CHK-STG-01", name, not public, {"public_bindings": public}))
    return out


def chk_stg_02(buckets):
    """Uniform bucket-level access on for every bucket."""
    out = []
    for name, data in buckets.items():
        ubla = data.get("iamConfiguration", {}).get("uniformBucketLevelAccess", {}).get("enabled", False)
        out.append(_result("CHK-STG-02", name, bool(ubla), {"uniformBucketLevelAccess": ubla}))
    return out


def chk_iam_01(project, project_bindings):
    """No service account holds a basic role on the project."""
    bad = [{"role": b["role"], "member": m}
           for b in project_bindings if b.get("role") in BASIC_ROLES
           for m in b.get("members", []) if m.startswith("serviceAccount:")]
    return [_result("CHK-IAM-01", project, not bad, {"basic_role_grants": bad})]


def chk_iam_02(project, keys):
    """No user-managed service account keys: one fail per key, or one project-level pass."""
    user_keys = {name: d for name, d in keys.items() if d.get("keyType") == "USER_MANAGED"}
    if not user_keys:
        return [_result("CHK-IAM-02", project, True, {"user_managed_keys": 0})]
    return [_result("CHK-IAM-02", name, False, {"keyType": d.get("keyType"),
                                                "validAfterTime": d.get("validAfterTime")})
            for name, d in user_keys.items()]


def chk_log_01(project, audit_configs):
    """Data Access logs on for Cloud Storage (or allServices)."""
    types = set()
    for c in audit_configs:
        if c.get("service") in ("storage.googleapis.com", "allServices"):
            types |= {lc.get("logType") for lc in c.get("auditLogConfigs", [])}
    return [_result("CHK-LOG-01", project, REQUIRED_DATA_ACCESS <= types,
                    {"storage_log_types": sorted(t for t in types if t)})]
