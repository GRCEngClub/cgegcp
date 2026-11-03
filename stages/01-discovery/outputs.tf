output "gap_map" {
  description = "Per baseline item: present (leave it), absent (Stage 2 activates), different (a human decides)."
  value       = local.gap_map
}

output "raw" {
  description = "The raw probe answers behind the gap map, for the evidence trail."
  value       = local.probe
}

output "project_number" {
  value = data.google_project.this.number
}
