output "reporter_uri" {
  value = google_cloudfunctions2_function.reporter.service_config[0].uri
}

output "report_jobs" {
  value = [for j in google_cloud_scheduler_job.report : j.name]
}
