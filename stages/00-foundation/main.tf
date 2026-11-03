# Stage 00: Foundation
# Turns on the APIs the pipeline uses and creates one service account per pipeline job.
# Service accounts are created with NO permissions here. Each later stage grants its own
# identity exactly what that stage needs (AC-6 least privilege, AC-5 separation of duties).

locals {
  # The API list doubles as the system's service inventory (CM-8).
  apis = [
    "artifactregistry.googleapis.com",
    "cloudasset.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "eventarc.googleapis.com",
    "firestore.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ]

  # One identity per job. Names are what auditors will see in every log entry.
  service_accounts = {
    "grc-builder"    = "Builds the pipeline's Cloud Run functions. Build permissions only."
    "grc-collector"  = "Stage 3: reads Cloud Asset Inventory, writes check results to Firestore."
    "grc-reporter"   = "Stage 4: reads Firestore, writes reports to the locked bucket."
    "grc-narrator"   = "Stage 5 (optional): reads reports, calls Vertex AI."
    "grc-remediator" = "Stage 6: fixes public buckets. Bucket IAM and settings only."
    "grc-scheduler"  = "Invokes the pipeline's functions on a schedule. Invoker only."
  }
}

resource "google_project_service" "apis" {
  for_each = toset(local.apis)

  service = each.value
  # Never switch an API off on destroy: another stage may still depend on it.
  disable_on_destroy = false
}

resource "google_service_account" "pipeline" {
  for_each = local.service_accounts

  account_id   = each.key
  display_name = each.key
  description  = each.value

  depends_on = [google_project_service.apis]
}
