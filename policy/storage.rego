# Gate rules for Cloud Storage. CHK-STG-01 / CHK-STG-02 as preventive controls.
package main

import rego.v1

public_members := {"allUsers", "allAuthenticatedUsers"}

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type == "google_storage_bucket"
	not "delete" in rc.change.actions
	# Unset values are absent from the plan; absent must DENY, or the rule silently passes.
	object.get(rc.change.after, "public_access_prevention", "unset") != "enforced"
	msg := sprintf("CHK-STG-01: %s must set public_access_prevention = \"enforced\".", [rc.address])
}

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type == "google_storage_bucket"
	not "delete" in rc.change.actions
	object.get(rc.change.after, "uniform_bucket_level_access", false) != true
	msg := sprintf("CHK-STG-02: %s must set uniform_bucket_level_access = true.", [rc.address])
}

deny contains msg if {
	rc := input.resource_changes[_]
	startswith(rc.type, "google_storage_bucket_iam_")
	not "delete" in rc.change.actions
	m := object.get(rc.change.after, "member", "")
	public_members[m]
	msg := sprintf("CHK-STG-01: %s grants %s on a bucket.", [rc.address, m])
}
