output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}

output "public_instance_id" {
  description = "Public instance ID."
  value       = module.public_instance.id
}

output "public_instance_ip" {
  description = "Elastic IP of the public instance."
  value       = module.public_instance.public_ip
}

output "private_instance_id" {
  description = "Private instance ID. Connect with: aws ssm start-session --target <id>"
  value       = module.private_instance.id
}

output "artifacts_bucket" {
  description = "Artifacts and logs bucket name."
  value       = module.artifacts.id
}
