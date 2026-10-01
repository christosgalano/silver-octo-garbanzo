# Unit tests with a mocked provider: no AWS credentials, nothing created.
# `apply` here runs against the mock, so computed values are known.

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

  override_data {
    target = data.aws_availability_zones.this
    values = { names = ["eu-central-1a", "eu-central-1b", "eu-central-1c"] }
  }

  override_data {
    target = data.aws_region.current
    values = { region = "eu-central-1" }
  }
}

variables {
  name                     = "acme-test"
  account_id               = "111122223333"
  kms_key_arn              = "arn:aws:kms:eu-central-1:111122223333:key/test"
  permissions_boundary_arn = "arn:aws:iam::111122223333:policy/acme-workload-boundary"
}

run "two_az_layout" {
  command = apply

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.private) == 2
    error_message = "Expected one public and one private subnet per AZ."
  }

  assert {
    condition     = alltrue([for s in aws_subnet.public : s.map_public_ip_on_launch == false])
    error_message = "Public subnets must not hand out public IPs automatically."
  }

  assert {
    condition     = length(aws_vpc_endpoint.ssm) == 3
    error_message = "Session Manager needs the ssm, ssmmessages and ec2messages endpoints."
  }

  assert {
    condition     = aws_iam_role.flow_logs.permissions_boundary == var.permissions_boundary_arn
    error_message = "The flow logs role must carry the permissions boundary."
  }
}

run "single_az_endpoints" {
  command = apply

  variables {
    interface_endpoints_multi_az = false
  }

  assert {
    condition     = alltrue([for e in aws_vpc_endpoint.ssm : length(e.subnet_ids) == 1])
    error_message = "With multi-AZ off, interface endpoints should sit in one subnet."
  }
}

run "endpoints_optional" {
  command = plan

  variables {
    enable_ssm_endpoints = false
  }

  assert {
    condition     = length(aws_vpc_endpoint.ssm) == 0 && length(aws_security_group.endpoints) == 0
    error_message = "No interface endpoints or endpoint security group when disabled."
  }
}

run "rejects_single_az" {
  command = plan

  variables {
    az_count = 1
  }

  expect_failures = [var.az_count]
}
