variable "name" {
  description = "Name prefix for every resource in the network."
  type        = string
}

variable "account_id" {
  description = "AWS account ID, used for confused-deputy conditions."
  type        = string
}

variable "cidr_block" {
  description = "VPC CIDR. Each subnet gets a /20 carved out of it."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.cidr_block, 0)) && tonumber(split("/", var.cidr_block)[1]) <= 16
    error_message = "cidr_block must be a valid CIDR of /16 or larger."
  }
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4."
  }
}

variable "enable_ssm_endpoints" {
  description = "Create the ssm, ssmmessages and ec2messages interface endpoints so private instances can use Session Manager without internet access."
  type        = bool
  default     = true
}

variable "interface_endpoints_multi_az" {
  description = "Place interface endpoints in every private subnet (true) or only the first (false, cheaper)."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "KMS key used to encrypt the flow log group."
  type        = string
}

variable "flow_log_retention_days" {
  description = "Retention for VPC flow logs."
  type        = number
  default     = 30
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary attached to IAM roles created by this module."
  type        = string
}
