# Stage 4: Reporting. Reports read the evidence store, and only the evidence store.
# grc-reporter can READ Firestore and CREATE objects in the locked reports bucket.
# It cannot write Firestore (the collector's job) and cannot read Asset Inventory.
# The recorder of facts and the author of reports are different identities (AC-5).

data "google_service_account" "sa" {
  for_each   = toset(["grc-builder", "grc-reporter", "grc-scheduler"])
  account_id = each.value
}

locals {
  reporter       = data.google_service_account.sa["grc-reporter"]
  builder        = data.google_service_account.sa["grc-builder"]
  scheduler      = data.google_service_account.sa["grc-scheduler"]
  reports_bucket = "${var.project_id}-reports"
  source_bucket  = "${var.project_id}-fn-source"
}

data "archive_file" "reports" {
  type        = "zip"
  source_dir  = "${path.module}/../../functions/reports"
  output_path = "${path.module}/build/reports.zip"
  excludes    = ["__pycache__"]
}

resource "google_storage_bucket_object" "reports" {
  name   = "reports/${data.archive_file.reports.output_md5}.zip"
  bucket = local.source_bucket
  source = data.archive_file.reports.output_path
}

resource "google_project_iam_member" "reporter_reads_firestore" {
  project = var.project_id
  role    = "roles/datastore.viewer"
  member  = "serviceAccount:${local.reporter.email}"
}

# Create only: objectCreator cannot read, overwrite or delete. The lock does the rest.
resource "google_storage_bucket_iam_member" "reporter_writes_reports" {
  bucket = local.reports_bucket
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${local.reporter.email}"
}

resource "google_cloudfunctions2_function" "reporter" {
  name     = "grc-reporter"
  location = var.region

  build_config {
    runtime         = "python312"
    entry_point     = "handler"
    service_account = local.builder.id
    source {
      storage_source {
        bucket = local.source_bucket
        object = google_storage_bucket_object.reports.name
      }
    }
  }

  service_config {
    service_account_email = local.reporter.email
    ingress_settings      = "ALLOW_ALL"
    available_memory      = "512Mi"
    timeout_seconds       = 300
    max_instance_count    = 1
    environment_variables = {
      GCP_PROJECT_ID = var.project_id
      REPORTS_BUCKET = local.reports_bucket
    }
  }
}

resource "google_cloud_run_service_iam_member" "scheduler_invokes_reporter" {
  location = var.region
  service  = google_cloudfunctions2_function.reporter.service_config[0].service
  role     = "roles/run.invoker"
  member   = "serviceAccount:${local.scheduler.email}"
}

resource "google_cloud_scheduler_job" "report" {
  for_each = var.schedules

  name     = "grc-report-${each.key}"
  region   = var.region
  schedule = each.value

  http_target {
    http_method = "POST"
    uri         = "${google_cloudfunctions2_function.reporter.service_config[0].uri}/?report=${each.key}" # Scheduler stores the trailing "/"; without it every plan shows drift
    oidc_token {
      service_account_email = local.scheduler.email
      audience              = google_cloudfunctions2_function.reporter.service_config[0].uri
    }
  }

  depends_on = [google_cloud_run_service_iam_member.scheduler_invokes_reporter]
}
