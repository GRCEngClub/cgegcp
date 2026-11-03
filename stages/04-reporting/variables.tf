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

variable "schedules" {
  description = "When each report runs (cron, UTC). After the 06:00 collection."
  type        = map(string)
  default = {
    poam = "0 7 * * *" # daily
    sar  = "0 7 * * 1" # weekly, Monday
    ssp  = "0 8 * * 1" # weekly, Monday
  }
}
