# instance

One EC2 instance with the house defaults: IMDSv2 only, encrypted gp3 root volume, no SSH key, no automatic public IP. `public = true` adds an Elastic IP and tags it `Exposure=public`, so exposure is always an explicit input.

The AMI is resolved once (latest Amazon Linux 2023) and then ignored, so a new AMI release never replaces a running instance by surprise.

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
| [aws_eip.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_ssm_parameter.al2023](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Instance name. | `string` | n/a | yes |
| security\_group\_ids | Security groups to attach. | `list(string)` | n/a | yes |
| subnet\_id | Subnet to launch into. | `string` | n/a | yes |
| ami\_id | AMI to use. Defaults to the latest Amazon Linux 2023 at first apply. | `string` | `null` | no |
| detailed\_monitoring | Enable 1-minute CloudWatch metrics (extra cost). | `bool` | `false` | no |
| iam\_instance\_profile | Instance profile name. Leave null for no instance role; Session Manager works through DHMC either way. | `string` | `null` | no |
| instance\_type | EC2 instance type. | `string` | `"t3.micro"` | no |
| public | Whether the instance is internet-facing. Public instances get an Elastic IP and are tagged Exposure=public. | `bool` | `false` | no |
| root\_volume\_size | Root volume size in GiB. | `number` | `8` | no |
| user\_data | Cloud-init user data. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| id | Instance ID. |
| private\_ip | Private IP address. |
| public\_ip | Elastic IP, or null for private instances. |
<!-- END_TF_DOCS -->
