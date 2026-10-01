output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs, in AZ order."
  value       = [for az in local.azs : aws_subnet.public[az].id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs, in AZ order."
  value       = [for az in local.azs : aws_subnet.private[az].id]
}

output "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks, in AZ order."
  value       = [for az in local.azs : local.private_subnets[az]]
}

output "s3_prefix_list_id" {
  description = "Prefix list of the S3 gateway endpoint, for security group egress rules."
  value       = aws_vpc_endpoint.s3.prefix_list_id
}
