variable "project" {
  description = "Project name, used in resource names and tags."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "owner" {
  description = "Team that owns the environment (tag)."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "allowed_account_ids" {
  description = "Accounts this configuration may run against. Null means no check; CI always sets it via TF_VAR_allowed_account_ids."
  type        = list(string)
  default     = null
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
}

variable "az_count" {
  description = "Number of availability zones."
  type        = number
}

variable "interface_endpoints_multi_az" {
  description = "Put SSM interface endpoints in every AZ."
  type        = bool
}

variable "instance_type" {
  description = "Instance type for both instances."
  type        = string
}

variable "public_ingress_cidr" {
  description = "CIDR allowed to reach the public instance on 80/443."
  type        = string
}

variable "artifacts_force_destroy" {
  description = "Allow destroy to empty the artifacts bucket."
  type        = bool
}
