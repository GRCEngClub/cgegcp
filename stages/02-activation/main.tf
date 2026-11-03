# Stage 2: Activation. Enable what's missing, and only what's missing.
# Reads Stage 1's gap map. Never touches an item discovery marked "different":
# someone may have chosen that setting on purpose, so a human decides.

data "terraform_remote_state" "discovery" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "01-discovery"
  }
}

locals {
  gap = data.terraform_remote_state.discovery.outputs.gap_map

  # Manage an item when it was absent, or when this pipeline already owns it.
  # Audit configs carry no description to mark ownership, so "present" (already exactly
  # the baseline) is managed too: Terraform merges into it and changes nothing.
  manage_data_access = contains(["absent", "present"], local.gap.data_access_storage)
  manage_audit_sink  = contains(["absent", "pipeline"], local.gap.audit_sink)
  marker             = "managed-by: cgegcp"
}

# AU-2 / AU-12: Data Access logs for Cloud Storage (reads and writes of evidence and reports).
# Admin Activity logs are always on and cannot be disabled.
resource "google_project_iam_audit_config" "storage" {
  count   = local.manage_data_access ? 1 : 0
  project = var.project_id
  service = "storage.googleapis.com"

  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# AU-11: keep audit logs for the audit period, not the _Default bucket's 30 days.
resource "google_logging_project_bucket_config" "audit" {
  count          = local.manage_audit_sink ? 1 : 0
  project        = var.project_id
  location       = "global"
  bucket_id      = "grc-audit-logs"
  retention_days = var.audit_log_retention_days
  description    = "Audit logs kept for the audit period. ${local.marker}"
}

resource "google_logging_project_sink" "audit" {
  count       = local.manage_audit_sink ? 1 : 0
  name        = "grc-audit-sink"
  description = "Routes Cloud Audit Logs to grc-audit-logs. ${local.marker}"
  destination = "logging.googleapis.com/${google_logging_project_bucket_config.audit[0].id}"
  filter      = "logName:\"cloudaudit.googleapis.com\""

  unique_writer_identity = true
}
