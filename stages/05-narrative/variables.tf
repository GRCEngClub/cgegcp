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

variable "gemini_model" {
  description = "Vertex AI model for the digest, called at location 'global'. New projects can't use the 2.5 models; list current ones in labs/05-reports/README.md."
  type        = string
  default     = "gemini-3.5-flash-lite"
}

variable "digest_schedule" {
  description = "Weekly, after the Monday SAR (cron, UTC)."
  type        = string
  default     = "0 9 * * 1"
}
