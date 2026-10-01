# -----------------------------------------------------------------------------
# Permissions boundary for every role the pipeline creates
# -----------------------------------------------------------------------------

# The ceiling for workload roles. Even if someone writes an over-broad inline
# policy, the effective permissions cannot go beyond this.
data "aws_iam_policy_document" "workload_boundary" {
  statement {
    sid = "WorkloadCeiling"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket",
      "kms:Decrypt",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "workload_boundary" {
  name        = "${var.project}-workload-boundary"
  description = "Permissions boundary required on every role created by the pipeline"
  policy      = data.aws_iam_policy_document.workload_boundary.json
}

# -----------------------------------------------------------------------------
# Session Manager: Default Host Management Configuration
# -----------------------------------------------------------------------------

# DHMC lets Systems Manager manage every IMDSv2 instance in the region with its
# own role, so instances do not need SSM permissions in their instance profile.
# It is a region-wide account setting, which is why it lives here and not in an
# environment.

data "aws_iam_policy_document" "dhmc_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dhmc" {
  name               = "AWSSystemsManagerDefaultEC2InstanceManagementRole"
  path               = "/service-role/"
  description        = "Default Host Management Configuration for Systems Manager"
  assume_role_policy = data.aws_iam_policy_document.dhmc_trust.json
}

resource "aws_iam_role_policy_attachment" "dhmc" {
  role       = aws_iam_role.dhmc.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy"
}

resource "aws_ssm_service_setting" "dhmc" {
  setting_id    = "arn:${local.partition}:ssm:${var.region}:${local.account_id}:servicesetting/ssm/managed-instance/default-ec2-instance-management-role"
  setting_value = "service-role/${aws_iam_role.dhmc.name}"

  depends_on = [aws_iam_role_policy_attachment.dhmc]
}

# -----------------------------------------------------------------------------
# Budget
# -----------------------------------------------------------------------------

resource "aws_budgets_budget" "monthly" {
  name         = "${var.project}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = { actual_50 = ["ACTUAL", 50], actual_80 = ["ACTUAL", 80], forecast_100 = ["FORECASTED", 100] }

    content {
      comparison_operator        = "GREATER_THAN"
      notification_type          = notification.value[0]
      threshold                  = notification.value[1]
      threshold_type             = "PERCENTAGE"
      subscriber_email_addresses = [var.budget_alert_email]
    }
  }
}
