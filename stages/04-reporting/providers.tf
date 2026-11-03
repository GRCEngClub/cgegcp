terraform {
  required_version = ">= 1.9"
  required_providers {
    google  = { source = "hashicorp/google", version = "~> 8.9" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
  }
  backend "gcs" {
    prefix = "04-reporting"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
