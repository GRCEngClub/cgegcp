output "remediator_uri" {
  value = google_cloudfunctions2_function.remediator.service_config[0].uri
}

output "mode" {
  value = var.mode
}
