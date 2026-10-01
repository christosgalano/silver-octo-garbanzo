variable "project" {
  description = "Project name. Workload roles created by the pipeline must start with this prefix."
  type        = string
  default     = "acme"
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-central-1"
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the pipeline roles, as owner/name."
  type        = string
  default     = "christosgalano/silver-octo-garbanzo"
}

variable "github_owner_id" {
  description = "Numeric ID of the repository owner. Part of GitHub's immutable OIDC subject claim."
  type        = number
  default     = 61470783
}

variable "github_repository_id" {
  description = "Numeric ID of the repository. Part of GitHub's immutable OIDC subject claim, so a renamed or re-created repository with the same name cannot inherit the trust."
  type        = number
  default     = 1399716642
}

variable "environments" {
  description = "GitHub Environments that may assume the apply role. One role per environment keeps blast radius per environment."
  type        = list(string)
  default     = ["dev"]
}

variable "budget_limit_usd" {
  description = "Monthly cost budget. Alerts at 50%, 80% and 100% (forecast)."
  type        = number
  default     = 20
}

variable "budget_alert_email" {
  description = "Where budget alerts go."
  type        = string
}
