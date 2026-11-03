# Stage 1: Discovery. Rule: change nothing.
# Measures what is already running and outputs a gap map for Stage 2.
# This stage creates zero resources; `terraform apply` only records the measurement in state.

data "google_project" "this" {}

data "external" "probe" {
  program = ["bash", "${path.module}/discover.sh"]
  query   = { project_id = var.project_id }
}

locals {
  probe = data.external.probe.result

  # present = already meets the baseline, leave it. absent = Stage 2 activates it.
  # different = exists with another setting, a human decides. pipeline = Stage 2 created it, keep managing.
  gap_map = {
    data_access_storage        = local.probe.data_access_storage
    audit_sink                 = local.probe.audit_sink
    buckets_missing_guardrails = tonumber(local.probe.buckets_missing_guardrails) == 0 ? "present" : "different"
    user_managed_sa_keys       = tonumber(local.probe.user_managed_sa_keys) == 0 ? "present" : "different"
  }
}
