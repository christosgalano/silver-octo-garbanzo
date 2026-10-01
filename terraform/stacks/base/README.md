# base stack

Everything one environment needs, wired together: KMS key, network, artefacts bucket, the public web instance and the private instance with its read-only role. Environments call this stack with their own values and nothing else.

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

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| artifacts | ../../modules/bucket | n/a |
| network | ../../modules/network | n/a |
| private\_instance | ../../modules/instance | n/a |
| public\_instance | ../../modules/instance | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_instance_profile.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.decrypt_artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.read_artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_security_group.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.public_web](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.private_endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.private_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.public_web](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.public_web](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.decrypt_artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.private_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.read_artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name prefix for the environment, e.g. acme-dev. | `string` | n/a | yes |
| artifacts\_force\_destroy | Allow destroy to empty the artefacts bucket. Only ever true in throwaway environments. | `bool` | `false` | no |
| az\_count | Number of availability zones. | `number` | `2` | no |
| instance\_type | Instance type for both instances. | `string` | `"t3.micro"` | no |
| interface\_endpoints\_multi\_az | Put SSM interface endpoints in every AZ. False keeps them in the private instance's AZ only, which is cheaper and loses nothing while there is one private instance. | `bool` | `true` | no |
| permissions\_boundary\_name | Name of the IAM policy (created by bootstrap/) that every role in this stack must carry as its permissions boundary. | `string` | `"acme-workload-boundary"` | no |
| public\_ingress\_cidrs | CIDRs allowed to reach the public instance on 80/443. | `list(string)` | ```[ "0.0.0.0/0" ]``` | no |
| vpc\_cidr | VPC CIDR block. | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| artifacts\_bucket | Artefacts and logs bucket name. |
| private\_instance\_id | Private instance ID. Connect with: aws ssm start-session --target <id> |
| public\_instance\_id | Public instance ID. |
| public\_instance\_ip | Elastic IP of the public instance. |
| vpc\_id | VPC ID. |
<!-- END_TF_DOCS -->
