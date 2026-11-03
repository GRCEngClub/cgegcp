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

variable "mode" {
  description = "Escalation ladder rung. Raise it only through a reviewed pull request."
  type        = string
  default     = "report_only"
  validation {
    condition     = contains(["report_only", "approve", "auto"], var.mode)
    error_message = "mode must be report_only, approve, or auto."
  }
}

variable "remediate_schedule" {
  description = "After the 06:00 collection (cron, UTC)."
  type        = string
  default     = "30 6 * * *"
}
