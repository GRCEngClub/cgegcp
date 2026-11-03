# The remediator must run as its own dedicated identity, never a shared or default one.
package main

import rego.v1

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type == "google_cloudfunctions2_function"
	rc.change.after.name == "grc-remediator"
	not "delete" in rc.change.actions
	sa := rc.change.after.service_config[0].service_account_email
	not startswith(sa, "grc-remediator@")
	msg := sprintf("%s must run as grc-remediator, not %s.", [rc.address, sa])
}
