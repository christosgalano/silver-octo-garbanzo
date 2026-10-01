# Unit tests with a mocked provider: no AWS credentials, nothing created.

mock_provider "aws" {
  override_data {
    target = data.aws_ssm_parameter.al2023
    values = { insecure_value = "ami-0123456789abcdef0" }
  }
}

variables {
  name               = "acme-test"
  subnet_id          = "subnet-0123456789abcdef0"
  security_group_ids = ["sg-0123456789abcdef0"]
}

run "private_defaults" {
  command = plan

  assert {
    condition     = aws_instance.this.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be required."
  }

  assert {
    condition     = aws_instance.this.root_block_device[0].encrypted
    error_message = "Root volume must be encrypted."
  }

  assert {
    condition     = length(aws_eip.this) == 0
    error_message = "Private instances must not get an Elastic IP."
  }

  assert {
    condition     = aws_instance.this.tags.Exposure == "private"
    error_message = "Private instances must be tagged Exposure=private."
  }
}

run "public_gets_eip" {
  command = plan

  variables {
    public = true
  }

  assert {
    condition     = length(aws_eip.this) == 1
    error_message = "Public instances must get exactly one Elastic IP."
  }

  assert {
    condition     = aws_instance.this.tags.Exposure == "public"
    error_message = "Public instances must be tagged Exposure=public."
  }
}

run "requires_security_group" {
  command = plan

  variables {
    security_group_ids = []
  }

  expect_failures = [var.security_group_ids]
}
