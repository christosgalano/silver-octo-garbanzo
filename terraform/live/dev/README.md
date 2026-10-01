# dev

Root module for the dev environment. Backend, provider and one call to the base stack; values live in `terraform.tfvars`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10, < 2.0 |
| aws | ~> 6.67 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| base | ../../stacks/base | n/a |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| artifacts\_force\_destroy | Allow destroy to empty the artefacts bucket. | `bool` | n/a | yes |
| az\_count | Number of availability zones. | `number` | n/a | yes |
| environment | Environment name. | `string` | n/a | yes |
| instance\_type | Instance type for both instances. | `string` | n/a | yes |
| interface\_endpoints\_multi\_az | Put SSM interface endpoints in every AZ. | `bool` | n/a | yes |
| owner | Team that owns the environment (tag). | `string` | n/a | yes |
| project | Project name, used in resource names and tags. | `string` | n/a | yes |
| public\_ingress\_cidr | CIDR allowed to reach the public instance on 80/443. | `string` | n/a | yes |
| region | AWS region. | `string` | n/a | yes |
| vpc\_cidr | VPC CIDR block. | `string` | n/a | yes |
| allowed\_account\_ids | Accounts this configuration may run against. Null means no check; CI always sets it via TF\_VAR\_allowed\_account\_ids. | `list(string)` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| artifacts\_bucket | Artefacts and logs bucket name. |
| private\_instance\_id | Private instance ID. Connect with: aws ssm start-session --target <id> |
| public\_instance\_id | Public instance ID. |
| public\_instance\_ip | Elastic IP of the public instance. |
| vpc\_id | VPC ID. |
<!-- END_TF_DOCS -->
