terraform {
  required_version = ">= 1.9"
  required_providers {
    google   = { source = "hashicorp/google", version = "~> 8.9" }
    external = { source = "hashicorp/external", version = "~> 2.3" }
  }
  backend "gcs" {
    prefix = "01-discovery"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
