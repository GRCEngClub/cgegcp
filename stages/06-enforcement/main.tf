# Stage 6: Enforcement. Close the loop: detected, fixed, re-collected, documented.
# Reference control CHK-STG-01: no public buckets.
# Ladder: report_only (record what it would fix) -> approve (a human says yes) -> auto.
# BLAST RADIUS: grc-remediator's custom role can read and change bucket IAM and bucket
# settings in this project, nothing else: no objects, no other resource types, no deletes.
# The preventive half lives in policy/*.rego (the pull-request gate).

data "google_service_account" "sa" {
  for_each   = toset(["grc-builder", "grc-remediator", "grc-scheduler"])
  account_id = each.value
}

locals {
  remediator    = data.google_service_account.sa["grc-remediator"]
  builder       = data.google_service_account.sa["grc-builder"]
  scheduler     = data.google_service_account.sa["grc-scheduler"]
  source_bucket = "${var.project_id}-fn-source"
}

resource "google_project_iam_custom_role" "bucket_remediator" {
  role_id     = "grcBucketRemediator"
  title       = "GRC bucket remediator"
  description = "Remove public bucket grants and enforce public access prevention. Nothing else. managed-by: cgegcp"
  permissions = [
    "storage.buckets.get",
    "storage.buckets.getIamPolicy",
    "storage.buckets.setIamPolicy",
    "storage.buckets.update",
  ]
}

resource "google_project_iam_member" "remediator_role" {
  project = var.project_id
  role    = google_project_iam_custom_role.bucket_remediator.id
  member  = "serviceAccount:${local.remediator.email}"
}

# Reads failing results; writes its own records to the "remediations" collection.
resource "google_project_iam_member" "remediator_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${local.remediator.email}"
}

data "archive_file" "remediator" {
  type        = "zip"
  source_dir  = "${path.module}/../../functions/remediator"
  output_path = "${path.module}/build/remediator.zip"
  excludes    = ["__pycache__"]
}

resource "google_storage_bucket_object" "remediator" {
  name   = "remediator/${data.archive_file.remediator.output_md5}.zip"
  bucket = local.source_bucket
  source = data.archive_file.remediator.output_path
}

resource "google_cloudfunctions2_function" "remediator" {
  name     = "grc-remediator"
  location = var.region

  build_config {
    runtime         = "python312"
    entry_point     = "handler"
    service_account = local.builder.id
    source {
      storage_source {
        bucket = local.source_bucket
        object = google_storage_bucket_object.remediator.name
      }
    }
  }

  service_config {
    service_account_email = local.remediator.email
    ingress_settings      = "ALLOW_ALL"
    available_memory      = "512Mi"
    timeout_seconds       = 300
    max_instance_count    = 1
    environment_variables = {
      GCP_PROJECT_ID = var.project_id
      MODE           = var.mode
    }
  }
}

resource "google_cloud_run_service_iam_member" "scheduler_invokes_remediator" {
  location = var.region
  service  = google_cloudfunctions2_function.remediator.service_config[0].service
  role     = "roles/run.invoker"
  member   = "serviceAccount:${local.scheduler.email}"
}

resource "google_cloud_scheduler_job" "remediate" {
  name     = "grc-remediate-daily"
  region   = var.region
  schedule = var.remediate_schedule

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.remediator.service_config[0].uri
    oidc_token {
      service_account_email = local.scheduler.email
      audience              = google_cloudfunctions2_function.remediator.service_config[0].uri
    }
  }

  depends_on = [google_cloud_run_service_iam_member.scheduler_invokes_remediator]
}
