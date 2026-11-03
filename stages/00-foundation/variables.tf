variable "project_id" {
  description = "Your lab project ID."
  type        = string
}

variable "region" {
  description = "Region for every regional resource in the pipeline."
  type        = string
  default     = "us-central1"
}

variable "state_bucket" {
  description = "Terraform state bucket (from bootstrap.sh). Unused here; declared so one tfvars file fits every stage."
  type        = string
  default     = ""
}
