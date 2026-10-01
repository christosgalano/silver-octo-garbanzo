# Wiring tests for the stack, with a mocked provider. They check the decisions
# that matter most if someone copy-pastes this: what is public and what is not.

mock_provider "aws" {
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:eu-central-1:111122223333:log-group:/vpc/test" }
  }

  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::111122223333:role/test" }
  }

  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:eu-central-1:111122223333:key/test" }
  }

  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::test" }
  }

  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

override_data {
  target = data.aws_caller_identity.current
  values = { account_id = "111122223333" }
}

override_data {
  target = data.aws_region.current
  values = { region = "eu-central-1" }
}

override_data {
  target = data.aws_partition.current
  values = { partition = "aws" }
}

override_data {
  target = module.network.data.aws_region.current
  values = { region = "eu-central-1" }
}

override_data {
  target = module.network.data.aws_availability_zones.this
  values = { names = ["eu-central-1a", "eu-central-1b"] }
}

override_data {
  target = module.public_instance.data.aws_ssm_parameter.al2023
  values = { insecure_value = "ami-0123456789abcdef0" }
}

override_data {
  target = module.private_instance.data.aws_ssm_parameter.al2023
  values = { insecure_value = "ami-0123456789abcdef0" }
}

variables {
  name = "acme-test"
}

run "exposure" {
  command = apply

  assert {
    condition     = module.public_instance.public_ip != null && module.private_instance.public_ip == null
    error_message = "Only the public instance may have a public IP."
  }

  assert {
    condition     = length([for r in aws_vpc_security_group_ingress_rule.public_web : r if !contains([80, 443], r.from_port)]) == 0
    error_message = "The public instance may only accept 80 and 443."
  }

  assert {
    condition     = aws_iam_role.private.permissions_boundary == "arn:aws:iam::111122223333:policy/acme-workload-boundary"
    error_message = "The private instance role must carry the workload boundary."
  }

  assert {
    condition     = alltrue([for r in aws_vpc_security_group_ingress_rule.public_web : r.security_group_id == aws_security_group.public_web.id])
    error_message = "Internet ingress may only attach to the public web security group."
  }
}
