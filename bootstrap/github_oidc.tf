# GitHub Actions authenticates with short-lived OIDC tokens. No access keys live
# in the repository or in GitHub secrets.
#
# Two kinds of role:
#   plan  - read-only, assumable from pull requests and from main. Used to plan.
#   apply - one per GitHub Environment, assumable ONLY from a job that runs in
#           that environment. The environment is where the required reviewer and
#           the main-only branch rule live, so the AWS trust and the GitHub gate
#           enforce the same contract.

locals {
  oidc_host = "token.actions.githubusercontent.com"

  # The repository uses GitHub's immutable subject claims, where `sub` carries
  # numeric IDs next to the names: repo:<owner>@<owner_id>/<repo>@<repo_id>:...
  # Names alone can be re-registered; IDs cannot.
  owner_name     = split("/", var.github_repository)[0]
  repo_name      = split("/", var.github_repository)[1]
  subject_prefix = "repo:${local.owner_name}@${var.github_owner_id}/${local.repo_name}@${var.github_repository_id}"
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
}

# -----------------------------------------------------------------------------
# Plan role
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values = [
        "${local.subject_prefix}:pull_request",
        "${local.subject_prefix}:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "plan" {
  name                 = "gha-${var.project}-plan"
  description          = "GitHub Actions: terraform plan (read-only)"
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "plan_read_only" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "plan" {
  statement {
    sid       = "ReadState"
    actions   = ["s3:ListBucket", "s3:GetObject"]
    resources = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
  }

  # ReadOnlyAccess can read every object in every bucket. Plans never need object
  # contents outside the state bucket, so take that away. A PR can run arbitrary
  # code during plan (providers, external data sources), so this role is treated
  # as readable by anyone who can open a PR.
  statement {
    sid           = "NoObjectReadsOutsideState"
    effect        = "Deny"
    actions       = ["s3:GetObject", "s3:GetObjectVersion"]
    not_resources = ["${aws_s3_bucket.state.arn}/*"]
  }

  statement {
    sid    = "NoSecretReads"
    effect = "Deny"
    actions = [
      "secretsmanager:GetSecretValue",
      "kms:Decrypt",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "plan" {
  name   = "state-read"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan.json
}

# -----------------------------------------------------------------------------
# Apply roles, one per environment
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "apply_trust" {
  for_each = toset(var.environments)

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["${local.subject_prefix}:environment:${each.key}"]
    }
  }
}

data "aws_iam_policy_document" "apply" {
  for_each = toset(var.environments)

  statement {
    sid = "ManageWorkloadServices"
    actions = [
      "ec2:*",
      "kms:*",
      "logs:*",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ManageProjectBuckets"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:Get*",
      "s3:List*",
      "s3:Put*",
    ]
    resources = ["arn:${local.partition}:s3:::${var.project}-${each.key}-*"]
  }

  statement {
    sid = "ReadOnlyLookups"
    actions = [
      "sts:GetCallerIdentity",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "iam:Get*",
      "iam:List*",
      "s3:ListAllMyBuckets",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "StateList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  # Each environment can only touch its own state file (and its lock file).
  statement {
    sid       = "StateReadWrite"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/${each.key}/*"]
  }

  # IAM: only roles and instance profiles named for this environment, and any role
  # it creates or changes must carry the workload boundary. Without this, the
  # pipeline could create an admin role and hand it to an instance.
  statement {
    sid = "RolesRequireBoundary"
    actions = [
      "iam:CreateRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePermissionsBoundary",
    ]
    resources = ["arn:${local.partition}:iam::${local.account_id}:role/${var.project}-${each.key}-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [aws_iam_policy.workload_boundary.arn]
    }
  }

  statement {
    sid = "ManageEnvironmentRoles"
    actions = [
      "iam:DeleteRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription",
      "iam:UpdateAssumeRolePolicy",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:UntagInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
    ]
    resources = [
      "arn:${local.partition}:iam::${local.account_id}:role/${var.project}-${each.key}-*",
      "arn:${local.partition}:iam::${local.account_id}:instance-profile/${var.project}-${each.key}-*",
    ]
  }

  statement {
    sid       = "PassEnvironmentRoles"
    actions   = ["iam:PassRole"]
    resources = ["arn:${local.partition}:iam::${local.account_id}:role/${var.project}-${each.key}-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com", "vpc-flow-logs.amazonaws.com"]
    }
  }

  statement {
    sid       = "KeepBoundaries"
    effect    = "Deny"
    actions   = ["iam:DeleteRolePermissionsBoundary"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "apply" {
  for_each = toset(var.environments)

  name                 = "gha-${var.project}-${each.key}-apply"
  description          = "GitHub Actions: terraform apply for ${each.key}"
  assume_role_policy   = data.aws_iam_policy_document.apply_trust[each.key].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "apply" {
  for_each = toset(var.environments)

  name   = "apply-${each.key}"
  role   = aws_iam_role.apply[each.key].id
  policy = data.aws_iam_policy_document.apply[each.key].json
}
