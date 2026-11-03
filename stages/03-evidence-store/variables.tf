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
  description = "Terraform state bucket (from bootstrap.sh)."
  type        = string
  default     = ""
}

variable "report_retention_seconds" {
  description = "Retention on the locked reports bucket. Labs: 86400 (1 day). Production: your audit retention requirement (AU-11)."
  type        = number
  default     = 86400
}

variable "lock_reports_bucket" {
  description = "Lock the reports bucket's retention policy. IRREVERSIBLE: nobody can delete a report until it ages out."
  type        = bool
  default     = true
}

variable "collect_schedule" {
  description = "When the collector runs (cron, UTC)."
  type        = string
  default     = "0 6 * * *"
}
