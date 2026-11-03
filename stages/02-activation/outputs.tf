output "activated" {
  description = "What this run manages, and what it left for a human."
  value = {
    data_access_storage = local.manage_data_access ? "managed by stage 2" : "left as found (${local.gap.data_access_storage})"
    audit_sink          = local.manage_audit_sink ? "managed by stage 2" : "left as found (${local.gap.audit_sink})"
  }
}
