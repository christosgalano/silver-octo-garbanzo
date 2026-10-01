variable "name" {
  description = "Globally unique bucket name."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key for default bucket encryption."
  type        = string
}

variable "noncurrent_version_retention_days" {
  description = "Days to keep overwritten or deleted object versions."
  type        = number
  default     = 30
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete a non-empty bucket. Keep false for anything that matters."
  type        = bool
  default     = false
}
