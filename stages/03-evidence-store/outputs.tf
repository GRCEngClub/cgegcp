output "reports_bucket" {
  value = google_storage_bucket.reports.name
}

output "collector_uri" {
  value = google_cloudfunctions2_function.collector.service_config[0].uri
}

output "scheduler_job" {
  value = google_cloud_scheduler_job.collect.name
}
