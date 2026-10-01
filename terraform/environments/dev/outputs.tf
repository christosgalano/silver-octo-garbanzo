output "vpc_id" {
  description = "VPC ID."
  value       = module.base.vpc_id
}

output "public_instance_ip" {
  description = "Elastic IP of the public instance."
  value       = module.base.public_instance_ip
}

output "public_instance_id" {
  description = "Public instance ID."
  value       = module.base.public_instance_id
}

output "private_instance_id" {
  description = "Private instance ID. Connect with: aws ssm start-session --target <id>"
  value       = module.base.private_instance_id
}

output "artifacts_bucket" {
  description = "Artefacts and logs bucket name."
  value       = module.base.artifacts_bucket
}
