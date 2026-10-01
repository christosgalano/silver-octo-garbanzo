locals {
  azs = slice(data.aws_availability_zones.this.names, 0, var.az_count)

  # /20 per subnet: public from the bottom of the range, private from the middle.
  public_subnets  = { for i, az in local.azs : az => cidrsubnet(var.cidr_block, 4, i) }
  private_subnets = { for i, az in local.azs : az => cidrsubnet(var.cidr_block, 4, i + 8) }

  # Interface endpoints are billed per AZ. One AZ is enough while there is a single
  # private instance; flip interface_endpoints_multi_az when that stops being true.
  endpoint_subnet_ids = var.interface_endpoints_multi_az ? values(aws_subnet.private)[*].id : [aws_subnet.private[local.azs[0]].id]

  ssm_endpoints = var.enable_ssm_endpoints ? toset(["ssm", "ssmmessages"]) : toset([])
}

data "aws_availability_zones" "this" {
  state = "available"
}

data "aws_region" "current" {}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true # required for private DNS on interface endpoints

  tags = { Name = var.name }
}

# Take ownership of the default security group and leave it with no rules, so
# anything launched without an explicit group gets no traffic at all.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-default-deny" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = var.name }
}

# -----------------------------------------------------------------------------
# Subnets and routing
# -----------------------------------------------------------------------------

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  # Public addresses are opt-in per resource (an EIP), never automatic.
  map_public_ip_on_launch = false

  tags = { Name = "${var.name}-public-${each.key}", Tier = "public" }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = { Name = "${var.name}-private-${each.key}", Tier = "private" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "${var.name}-public" }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# No default route on purpose: private subnets have no path to the internet.
# AWS services are reached through VPC endpoints only.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-private" }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# -----------------------------------------------------------------------------
# VPC endpoints
# -----------------------------------------------------------------------------

# Gateway endpoints are free; this is how private instances reach S3.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = { Name = "${var.name}-s3" }
}

resource "aws_security_group" "endpoints" {
  count = var.enable_ssm_endpoints ? 1 : 0

  name        = "${var.name}-endpoints"
  description = "HTTPS from private subnets to interface endpoints"
  vpc_id      = aws_vpc.this.id

  tags = { Name = "${var.name}-endpoints" }
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_https" {
  for_each = var.enable_ssm_endpoints ? local.private_subnets : {}

  security_group_id = aws_security_group.endpoints[0].id
  description       = "HTTPS from private subnet ${each.key}"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = local.ssm_endpoints

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = local.endpoint_subnet_ids
  security_group_ids  = [aws_security_group.endpoints[0].id]

  tags = { Name = "${var.name}-${each.key}" }
}

# -----------------------------------------------------------------------------
# Flow logs
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/vpc/${var.name}/flow-logs"
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = var.kms_key_arn
}

resource "aws_flow_log" "this" {
  vpc_id                   = aws_vpc.this.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn             = aws_iam_role.flow_logs.arn
  max_aggregation_interval = 600

  tags = { Name = var.name }
}

data "aws_iam_policy_document" "flow_logs_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    # Confused-deputy protection: only flow logs from this account.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

data "aws_iam_policy_document" "flow_logs" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flow_logs.arn}:*"]
  }
}

resource "aws_iam_role" "flow_logs" {
  name                 = "${var.name}-flow-logs"
  assume_role_policy   = data.aws_iam_policy_document.flow_logs_trust.json
  permissions_boundary = var.permissions_boundary_arn
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "write-flow-logs"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs.json
}
