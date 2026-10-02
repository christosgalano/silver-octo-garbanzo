data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
  partition  = data.aws_partition.current.partition

  # Built from the name rather than read from the resource, so IAM documents that
  # reference the bucket are fully known at plan time and policy checks can see them.
  bucket_name = "${var.name}-artifacts-${local.account_id}"
  bucket_arn  = "arn:${local.partition}:s3:::${local.bucket_name}"

  permissions_boundary_arn = "arn:${local.partition}:iam::${local.account_id}:policy/${var.permissions_boundary_name}"
}

# -----------------------------------------------------------------------------
# Encryption
# -----------------------------------------------------------------------------

# One key for this environment's data at rest: the artifacts bucket and the flow
# log group. Key policy keeps admin with the account and lets CloudWatch Logs use
# it only for this environment's log groups.
data "aws_iam_policy_document" "kms" {
  statement {
    sid       = "AccountAdministration"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }

  statement {
    sid = "CloudWatchLogs"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${local.region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:/vpc/${var.name}/*"]
    }
  }
}

resource "aws_kms_key" "this" {
  description             = "${var.name} data at rest"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.kms.json
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.this.key_id
}

# -----------------------------------------------------------------------------
# Network and storage
# -----------------------------------------------------------------------------

module "network" {
  source = "../../modules/network"

  name                         = var.name
  account_id                   = local.account_id
  cidr_block                   = var.vpc_cidr
  az_count                     = var.az_count
  enable_ssm_endpoints         = true
  interface_endpoints_multi_az = var.interface_endpoints_multi_az
  kms_key_arn                  = aws_kms_key.this.arn
  permissions_boundary_arn     = local.permissions_boundary_arn
}

module "artifacts" {
  source = "../../modules/bucket"

  name          = local.bucket_name
  kms_key_arn   = aws_kms_key.this.arn
  force_destroy = var.artifacts_force_destroy
}
