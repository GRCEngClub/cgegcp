# Deliberately non-compliant: `terraform plan` this and conftest must FAIL on every rule.
# Never apply it. Used by self-check.sh and the Lab 3 / Lab 6 watch-it-fail steps.
terraform {
  required_providers {
    google = { source = "hashicorp/google", version = "~> 8.9" }
  }
}

variable "project_id" { type = string }

provider "google" { project = var.project_id }

resource "google_storage_bucket" "open" {
  name                        = "${var.project_id}-gate-test-open"
  location                    = "us-central1"
  uniform_bucket_level_access = false
}

resource "google_storage_bucket_iam_member" "public" {
  bucket = google_storage_bucket.open.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_project_iam_member" "editor" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:grc-collector@${var.project_id}.iam.gserviceaccount.com"
}

resource "google_service_account_key" "key" {
  service_account_id = "grc-collector@${var.project_id}.iam.gserviceaccount.com"
}
