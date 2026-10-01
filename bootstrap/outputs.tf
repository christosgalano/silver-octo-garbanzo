output "state_bucket" {
  description = "Terraform state bucket. Set as the <ENV>_ repository variables (e.g. DEV_TF_STATE_BUCKET)."
  value       = aws_s3_bucket.state.id
}

output "plan_role_arn" {
  description = "Plan role for this account. Set as the <ENV>_ repository variables (e.g. DEV_TF_STATE_BUCKET)."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arns" {
  description = "Set each as the AWS_APPLY_ROLE_ARN variable on the matching GitHub Environment."
  value       = { for env, role in aws_iam_role.apply : env => role.arn }
}

output "account_id" {
  description = "Account ID. Set as the <ENV>_ repository variables (e.g. DEV_TF_STATE_BUCKET)."
  value       = local.account_id
}

output "region" {
  description = "Set as the AWS_REGION repository variable."
  value       = var.region
}
