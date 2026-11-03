terraform {
  required_version = ">= 1.9"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 8.9" }
  }
  backend "gcs" {
    prefix = "02-activation"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
