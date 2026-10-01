variable "name" {
  description = "Instance name."
  type        = string
}

variable "public" {
  description = "Whether the instance is internet-facing. Public instances get an Elastic IP and are tagged Exposure=public."
  type        = bool
  default     = false
}

variable "subnet_id" {
  description = "Subnet to launch into."
  type        = string
}

variable "security_group_ids" {
  description = "Security groups to attach."
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) > 0
    error_message = "At least one security group is required; the VPC default group has no rules."
  }
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI to use. Defaults to the latest Amazon Linux 2023 at first apply."
  type        = string
  default     = null
}

variable "iam_instance_profile" {
  description = "Instance profile name. Leave null for no instance role; Session Manager works through DHMC either way."
  type        = string
  default     = null
}

variable "user_data" {
  description = "Cloud-init user data."
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Root volume size in GiB."
  type        = number
  default     = 8
}

variable "detailed_monitoring" {
  description = "Enable 1-minute CloudWatch metrics (extra cost)."
  type        = bool
  default     = false
}
