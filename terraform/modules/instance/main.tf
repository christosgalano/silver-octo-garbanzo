# Latest Amazon Linux 2023. It ships an SSM Agent recent enough for Default Host
# Management Configuration, which is how both instances get Session Manager access.
data "aws_ssm_parameter" "al2023" {
  count = var.ami_id == null ? 1 : 0

  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "this" {
  ami                    = coalesce(var.ami_id, try(data.aws_ssm_parameter.al2023[0].insecure_value, null))
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = var.iam_instance_profile

  # No automatic public IP: subnets set map_public_ip_on_launch = false, and public
  # instances get an EIP below. associate_public_ip_address is left unset on
  # purpose: once the EIP attaches AWS reports it as true, and pinning it to false
  # would force a replacement on every plan.

  user_data                   = var.user_data
  user_data_replace_on_change = true

  monitoring    = var.detailed_monitoring
  ebs_optimized = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only; also a DHMC prerequisite
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name     = var.name
    Exposure = var.public ? "public" : "private"
  }

  volume_tags = {
    Name = var.name
  }

  lifecycle {
    # A new AL2023 release should not silently replace a running instance on the
    # next apply. Rolling the AMI is a deliberate change (set ami_id, or taint).
    ignore_changes = [ami]
  }
}

resource "aws_eip" "this" {
  count = var.public ? 1 : 0

  domain   = "vpc"
  instance = aws_instance.this.id

  tags = {
    Name     = var.name
    Exposure = "public"
  }
}
