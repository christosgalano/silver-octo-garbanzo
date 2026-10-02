variable "name" {
  description = "Name prefix for the environment, e.g. acme-dev."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.name))
    error_message = "name must be lowercase letters, digits and hyphens, 3-31 characters."
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones."
  type        = number
  default     = 2
}

variable "interface_endpoints_multi_az" {
  description = "Put SSM interface endpoints in every AZ. False keeps them in the private instance's AZ only, which is cheaper and loses nothing while there is one private instance."
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "Instance type for both instances."
  type        = string
  default     = "t3.micro"
}

variable "public_ingress_cidr" {
  description = "CIDR allowed to reach the public instance on 80/443."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.public_ingress_cidr, 0))
    error_message = "public_ingress_cidr must be a valid IPv4 CIDR."
  }
}

variable "artifacts_force_destroy" {
  description = "Allow destroy to empty the artifacts bucket. Only ever true in throwaway environments."
  type        = bool
  default     = false
}

variable "permissions_boundary_name" {
  description = "Name of the IAM policy (created outside this repo) that every role in this stack must carry as its permissions boundary."
  type        = string
  default     = "acme-workload-boundary"
}
