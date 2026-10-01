# Account-level foundations that have to exist before CI can run anything:
# state bucket, GitHub OIDC trust, pipeline roles, the workload permissions
# boundary, Session Manager's default host management, and a budget alarm.
#
# Applied once, by a human with admin credentials. State is local on first run;
# migrate it into the state bucket afterwards (see README).

terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.67"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      Owner     = "platform"
      ManagedBy = "terraform"
      Component = "bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
}
