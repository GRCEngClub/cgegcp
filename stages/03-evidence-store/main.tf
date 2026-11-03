# Stage 3: The evidence store. Collect once, own the evidence.
# - Firestore holds check results (assessments), the framework, and the crosswalk.
# - A Cloud Storage bucket with a LOCKED retention policy holds reports (Stage 4 writes them).
# - The collector, a Cloud Run function, runs the five checks over Cloud Asset Inventory daily.
# Identities: grc-collector reads Asset Inventory and writes Firestore, nothing else.
# grc-builder builds the function. grc-scheduler can invoke this one function, nothing else.

data "google_project" "this" {}

data "google_service_account" "sa" {
  for_each   = toset(["grc-builder", "grc-collector", "grc-scheduler"])
  account_id = each.value
}

locals {
  collector = data.google_service_account.sa["grc-collector"]
  builder   = data.google_service_account.sa["grc-builder"]
  scheduler = data.google_service_account.sa["grc-scheduler"]
}

# ---- Evidence database ------------------------------------------------------
resource "google_firestore_database" "evidence" {
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"

  # Labs tear down; production would set DELETE_PROTECTION_ENABLED.
  delete_protection_state = "DELETE_PROTECTION_DISABLED"
  deletion_policy         = "DELETE"
}

# ---- Reports bucket: retention policy, then the lock (AU-9, AU-11) ----------
resource "google_storage_bucket" "reports" {
  name     = "${var.project_id}-reports"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  retention_policy {
    retention_period = var.report_retention_seconds
    is_locked        = var.lock_reports_bucket
  }

  labels = { managed-by = "cgegcp", purpose = "grc-reports" }
}

# ---- Collector function source ---------------------------------------------
resource "google_storage_bucket" "source" {
  name     = "${var.project_id}-fn-source"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  labels = { managed-by = "cgegcp", purpose = "function-source" }
}

data "archive_file" "collector" {
  type        = "zip"
  source_dir  = "${path.module}/../../functions/collector"
  output_path = "${path.module}/build/collector.zip"
  excludes    = ["__pycache__"]
}

resource "google_storage_bucket_object" "collector" {
  name   = "collector/${data.archive_file.collector.output_md5}.zip"
  bucket = google_storage_bucket.source.name
  source = data.archive_file.collector.output_path
}

# ---- Least-privilege grants -------------------------------------------------
# New projects do NOT give any account permission to build functions. Build as grc-builder.
resource "google_project_iam_member" "builder" {
  for_each = toset(["roles/cloudbuild.builds.builder"])
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${local.builder.email}"
}

resource "google_storage_bucket_iam_member" "builder_reads_source" {
  bucket = google_storage_bucket.source.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${local.builder.email}"
}

# CA-7: the collector reads the inventory and writes check results. Nothing else.
resource "google_project_iam_member" "collector" {
  for_each = toset(["roles/cloudasset.viewer", "roles/datastore.user"])
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${local.collector.email}"
}

# ---- The collector ----------------------------------------------------------
resource "google_cloudfunctions2_function" "collector" {
  name     = "grc-collector"
  location = var.region

  build_config {
    runtime         = "python312"
    entry_point     = "handler"
    service_account = local.builder.id
    source {
      storage_source {
        bucket = google_storage_bucket.source.name
        object = google_storage_bucket_object.collector.name
      }
    }
  }

  service_config {
    service_account_email = local.collector.email
    ingress_settings      = "ALLOW_ALL"
    available_memory      = "512Mi"
    timeout_seconds       = 300
    max_instance_count    = 1
    environment_variables = { GCP_PROJECT_ID = var.project_id }
  }

  depends_on = [
    google_project_iam_member.builder,
    google_storage_bucket_iam_member.builder_reads_source,
    google_firestore_database.evidence,
  ]
}

# Only grc-scheduler may call the collector, and only this service (not run.invoker project-wide).
resource "google_cloud_run_service_iam_member" "scheduler_invokes_collector" {
  location = var.region
  service  = google_cloudfunctions2_function.collector.service_config[0].service
  role     = "roles/run.invoker"
  member   = "serviceAccount:${local.scheduler.email}"
}

resource "google_cloud_scheduler_job" "collect" {
  name     = "grc-collect-daily"
  region   = var.region
  schedule = var.collect_schedule

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.collector.service_config[0].uri
    oidc_token {
      service_account_email = local.scheduler.email
      audience              = google_cloudfunctions2_function.collector.service_config[0].uri
    }
  }

  depends_on = [google_cloud_run_service_iam_member.scheduler_invokes_collector]
}
