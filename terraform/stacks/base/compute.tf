# -----------------------------------------------------------------------------
# Public instance: serves HTTP/HTTPS from the internet
# -----------------------------------------------------------------------------

resource "aws_security_group" "public_web" {
  name        = "${var.name}-public-web"
  description = "Internet-facing web instance"
  vpc_id      = module.network.vpc_id

  tags = { Name = "${var.name}-public-web", Exposure = "public" }
}

#trivy:ignore:AWS-0107 This instance exists to serve the internet on 80/443. Scoped by public_ingress_cidrs; see README, R3.
resource "aws_vpc_security_group_ingress_rule" "public_web" {
  for_each = {
    for pair in setproduct(var.public_ingress_cidrs, [80, 443]) : "${pair[1]}-${pair[0]}" => {
      cidr = pair[0]
      port = pair[1]
    }
  }

  security_group_id = aws_security_group.public_web.id
  description       = "TCP ${each.value.port} from ${each.value.cidr}"
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
  cidr_ipv4         = each.value.cidr

  tags = { Exposure = "public" }
}

#trivy:ignore:AWS-0104 Needs outbound HTTP/HTTPS for OS packages and the SSM endpoint. Restricted to 80/443; see README, R3.
resource "aws_vpc_security_group_egress_rule" "public_web" {
  for_each = toset(["80", "443"])

  security_group_id = aws_security_group.public_web.id
  description       = "TCP ${each.key} to the internet"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.key)
  to_port           = tonumber(each.key)
  cidr_ipv4         = "0.0.0.0/0"
}

module "public_instance" {
  source = "../../modules/instance"

  name               = "${var.name}-public-web"
  public             = true
  subnet_id          = module.network.public_subnet_ids[0]
  security_group_ids = [aws_security_group.public_web.id]
  instance_type      = var.instance_type
  user_data          = file("${path.module}/templates/public-web.sh")

  # No instance profile: it needs no AWS permissions. Session Manager comes from DHMC.
}

# -----------------------------------------------------------------------------
# Private instance: no inbound path at all, operated through Session Manager
# -----------------------------------------------------------------------------

resource "aws_security_group" "private" {
  name        = "${var.name}-private"
  description = "Private instance: no ingress, egress to VPC endpoints and S3 only"
  vpc_id      = module.network.vpc_id

  tags = { Name = "${var.name}-private", Exposure = "private" }
}

# No ingress rules. Session Manager connections are outbound from the agent.

resource "aws_vpc_security_group_egress_rule" "private_endpoints" {
  for_each = toset(module.network.private_subnet_cidrs)

  security_group_id = aws_security_group.private.id
  description       = "HTTPS to interface endpoints in ${each.key}"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.key
}

resource "aws_vpc_security_group_egress_rule" "private_s3" {
  security_group_id = aws_security_group.private.id
  description       = "HTTPS to S3 through the gateway endpoint"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = module.network.s3_prefix_list_id
}

module "private_instance" {
  source = "../../modules/instance"

  name                 = "${var.name}-private"
  public               = false
  subnet_id            = module.network.private_subnet_ids[0]
  security_group_ids   = [aws_security_group.private.id]
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.private.name
}
