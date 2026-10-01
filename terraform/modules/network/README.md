# network

VPC across `az_count` AZs with public and private subnets, an internet gateway for the public tier only, and no internet route at all from the private tier. Private subnets reach AWS through VPC endpoints: an S3 gateway endpoint (free) and, optionally, the three interface endpoints Session Manager needs.

Also takes over the VPC's default security group and leaves it empty, and sends flow logs to an encrypted CloudWatch log group.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10, < 2.0 |
| aws | >= 6.0, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | >= 6.0, < 7.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_default_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_flow_log.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_endpoint.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_security_group_ingress_rule.endpoints_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_availability_zones.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_iam_policy_document.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.flow_logs_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| account\_id | AWS account ID, used for confused-deputy conditions. | `string` | n/a | yes |
| kms\_key\_arn | KMS key used to encrypt the flow log group. | `string` | n/a | yes |
| name | Name prefix for every resource in the network. | `string` | n/a | yes |
| permissions\_boundary\_arn | Permissions boundary attached to IAM roles created by this module. | `string` | n/a | yes |
| az\_count | Number of availability zones to spread subnets across. | `number` | `2` | no |
| cidr\_block | VPC CIDR, which must be a /16. Each subnet gets a /20 carved out of it. | `string` | `"10.0.0.0/16"` | no |
| enable\_ssm\_endpoints | Create the ssm and ssmmessages interface endpoints so private instances can use Session Manager without internet access. | `bool` | `true` | no |
| flow\_log\_retention\_days | Retention for VPC flow logs. | `number` | `30` | no |
| interface\_endpoints\_multi\_az | Place interface endpoints in every private subnet (true) or only the first (false, cheaper). | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| private\_subnet\_cidrs | Private subnet CIDR blocks, in AZ order. |
| private\_subnet\_ids | Private subnet IDs, in AZ order. |
| public\_subnet\_ids | Public subnet IDs, in AZ order. |
| s3\_prefix\_list\_id | Prefix list of the S3 gateway endpoint, for security group egress rules. |
| vpc\_cidr\_block | VPC CIDR block. |
| vpc\_id | VPC ID. |
<!-- END_TF_DOCS -->
