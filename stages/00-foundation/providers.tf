terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.9"
    }
  }

  # Bucket comes from labs/03-foundation/backend.hcl (written by bootstrap.sh).
  # Init with: terraform init -backend-config=../../labs/03-foundation/backend.hcl
  backend "gcs" {
    prefix = "00-foundation"
  }
}

# Credentials: Application Default Credentials locally (gcloud auth application-default login),
# Workload Identity Federation in CI. Never a key file.
provider "google" {
  project = var.project_id
  region  = var.region
}
