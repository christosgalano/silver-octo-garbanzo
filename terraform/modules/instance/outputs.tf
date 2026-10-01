output "id" {
  description = "Instance ID."
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP address."
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Elastic IP, or null for private instances."
  value       = var.public ? aws_eip.this[0].public_ip : null
}
