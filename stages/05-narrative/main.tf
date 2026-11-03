# Stage 5: AI narrative. OPTIONAL: walkthrough-only, extra credit, never graded.
# Describe, never decide. grc-narrator reads finished reports and calls Vertex AI.
# It cannot read Firestore, write Firestore, or delete anything.
# Delete this stage (terraform destroy here) and every other stage keeps working.

data "google_service_account" "sa" {
  for_each   = toset(["grc-builder", "grc-narrator", "grc-scheduler"])
  account_id = each.value
}

locals {
  narrator       = data.google_service_account.sa["grc-narrator"]
  builder        = data.google_service_account.sa["grc-builder"]
  scheduler      = data.google_service_account.sa["grc-scheduler"]
  reports_bucket = "${var.project_id}-reports"
  source_bucket  = "${var.project_id}-fn-source"
}

resource "google_project_service" "vertex" {
  service            = "aiplatform.googleapis.com"
  disable_on_destroy = false
}

data "archive_file" "narrator" {
  type        = "zip"
  source_dir  = "${path.module}/../../functions/narrator"
  output_path = "${path.module}/build/narrator.zip"
  excludes    = ["__pycache__"]
}

resource "google_storage_bucket_object" "narrator" {
  name   = "narrator/${data.archive_file.narrator.output_md5}.zip"
  bucket = local.source_bucket
  source = data.archive_file.narrator.output_path
}

resource "google_project_iam_member" "narrator_calls_vertex" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${local.narrator.email}"
}

resource "google_storage_bucket_iam_member" "narrator_reads_reports" {
  bucket = local.reports_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${local.narrator.email}"
}

resource "google_storage_bucket_iam_member" "narrator_writes_digest" {
  bucket = local.reports_bucket
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${local.narrator.email}"
}

resource "google_cloudfunctions2_function" "narrator" {
  name     = "grc-narrator"
  location = var.region

  build_config {
    runtime         = "python312"
    entry_point     = "handler"
    service_account = local.builder.id
    source {
      storage_source {
        bucket = local.source_bucket
        object = google_storage_bucket_object.narrator.name
      }
    }
  }

  service_config {
    service_account_email = local.narrator.email
    ingress_settings      = "ALLOW_ALL"
    available_memory      = "512Mi"
    timeout_seconds       = 300
    max_instance_count    = 1
    environment_variables = {
      GCP_PROJECT_ID = var.project_id
      REPORTS_BUCKET = local.reports_bucket
      GEMINI_MODEL   = var.gemini_model
    }
  }

  depends_on = [google_project_service.vertex]
}

resource "google_cloud_run_service_iam_member" "scheduler_invokes_narrator" {
  location = var.region
  service  = google_cloudfunctions2_function.narrator.service_config[0].service
  role     = "roles/run.invoker"
  member   = "serviceAccount:${local.scheduler.email}"
}

resource "google_cloud_scheduler_job" "digest" {
  name     = "grc-digest-weekly"
  region   = var.region
  schedule = var.digest_schedule

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.narrator.service_config[0].uri
    oidc_token {
      service_account_email = local.scheduler.email
      audience              = google_cloudfunctions2_function.narrator.service_config[0].uri
    }
  }

  depends_on = [google_cloud_run_service_iam_member.scheduler_invokes_narrator]
}
