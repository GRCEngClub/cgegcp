output "service_accounts" {
  description = "Pipeline identities by name. Later stages read these from this stage's state."
  value       = { for k, sa in google_service_account.pipeline : k => sa.email }
}

output "enabled_apis" {
  description = "APIs this pipeline depends on."
  value       = sort([for s in google_project_service.apis : s.service])
}
