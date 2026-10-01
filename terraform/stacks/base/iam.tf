# Role for the private instance: read the artefacts bucket, nothing else.
#
# It deliberately has no Systems Manager permissions. Session Manager access comes
# from Default Host Management Configuration (set up outside this repo), which only
# kicks in when the instance profile does NOT allow ssm:UpdateInstanceInformation.
# That keeps this role exactly what the brief asks for.

data "aws_iam_policy_document" "private_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

data "aws_iam_policy_document" "read_artifacts" {
  statement {
    sid       = "ListBucket"
    actions   = ["s3:ListBucket"]
    resources = [local.bucket_arn]
  }

  statement {
    sid       = "ReadObjects"
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${local.bucket_arn}/*"]
  }
}

# Objects are SSE-KMS encrypted, so reading them needs Decrypt on the bucket key,
# and only when the call comes through S3.
data "aws_iam_policy_document" "decrypt_artifacts" {
  statement {
    sid       = "DecryptViaS3"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.this.arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${local.region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "private" {
  name                 = "${var.name}-private-instance"
  description          = "Private instance: read-only access to the artefacts bucket"
  assume_role_policy   = data.aws_iam_policy_document.private_trust.json
  permissions_boundary = local.permissions_boundary_arn
}

resource "aws_iam_role_policy" "read_artifacts" {
  name   = "read-artifacts"
  role   = aws_iam_role.private.id
  policy = data.aws_iam_policy_document.read_artifacts.json
}

resource "aws_iam_role_policy" "decrypt_artifacts" {
  name   = "decrypt-artifacts"
  role   = aws_iam_role.private.id
  policy = data.aws_iam_policy_document.decrypt_artifacts.json
}

resource "aws_iam_instance_profile" "private" {
  name = "${var.name}-private-instance"
  role = aws_iam_role.private.name
}
