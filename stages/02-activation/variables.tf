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
  description = "Terraform state bucket (from bootstrap.sh), used to read Stage 1's gap map."
  type        = string
}

variable "audit_log_retention_days" {
  description = "Retention for the audit log bucket. The _Default bucket keeps 30 days; an audit period is 6-12 months (AU-11)."
  type        = number
  default     = 365
}
