terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.67"
    }
  }

  # Bucket comes from -backend-config (it contains the account ID). Locking uses
  # S3 native lock files, so there is no DynamoDB table to manage.
  backend "s3" {
    key          = "dev/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  # Fail fast if credentials point at the wrong account.
  allowed_account_ids = var.allowed_account_ids

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "terraform"
      Repository  = "christosgalano/silver-octo-garbanzo"
    }
  }
}
