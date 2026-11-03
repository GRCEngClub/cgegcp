# Gate rules for IAM in any Terraform plan (conftest, plan JSON).
# CHK-IAM-01 / CHK-IAM-02, enforced before deploy instead of detected after.
package main

import rego.v1

basic_roles := {"roles/owner", "roles/editor", "roles/viewer"}

iam_types := {
	"google_project_iam_member", "google_project_iam_binding", "google_project_iam_policy",
	"google_storage_bucket_iam_member", "google_storage_bucket_iam_binding",
	"google_service_account_iam_member", "google_service_account_iam_binding",
}

deny contains msg if {
	rc := input.resource_changes[_]
	iam_types[rc.type]
	not "delete" in rc.change.actions
	basic_roles[rc.change.after.role]
	msg := sprintf("CHK-IAM-01: %s grants basic role %s. Use a predefined or custom role.", [rc.address, rc.change.after.role])
}

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type == "google_service_account_key"
	"create" in rc.change.actions
	msg := sprintf("CHK-IAM-02: %s creates a service account key. Workloads use attached identities; CI uses Workload Identity Federation.", [rc.address])
}
