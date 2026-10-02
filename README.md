# Base environment: AWS + Terraform

A small AWS base environment as code, plus the working practices a new team can copy. The infrastructure is deliberately small. Most of the effort went into making sure that when someone copy-pastes this without reading it, the unsafe version fails in CI before a reviewer has to spot it.

## What it builds

- **Network:** a VPC across two AZs with public and private subnets. The private tier has no route to the internet.
- **Public instance:** an EC2 instance with an Elastic IP serving HTTP. Port 443 is open, but there's no certificate yet.
- **Private instance:** an EC2 instance with no inbound rules, no SSH and no internet. I reach it through Session Manager over VPC endpoints, so there's no NAT and no bastion.
- **S3 bucket:** private, versioned, KMS-encrypted and TLS-only. The private instance's IAM role can read it and nothing else.

## How it's laid out

- `terraform/modules/` holds small single-purpose modules: network, instance and bucket.
- `terraform/stacks/base/` wires them together once.
- `terraform/live/dev/` holds only what differs per environment. Adding `prod` means copying a thin folder, not copying wiring that then drifts.
- `policy/` has the Rego policies and their tests, evaluated against the plan.
- `.github/` has the CI and CD workflows, the shared actions and the change detection.

I didn't use Terragrunt. One account, one environment and one state file don't need it.

## Guardrails

Every PR runs formatting, validation, tflint and a docs check. Changed modules get `terraform test`. Trivy looks for generic AWS misconfiguration in the code, and conftest checks our own rules against the resolved plan. Those rules cover:

- security groups: world ingress only on web ports and only when tagged, never SSH or RDP;
- instances: approved types, IMDSv2, no automatic public IPs;
- IAM: the permissions boundary on every role, no wildcards;
- tags: the mandatory ones on everything that can have them;
- renames: destroying one `for_each` key while creating another of the same resource fails until a `moved` block is added.

Pull requests from forks are not planned and fail the gate, because their code would run as the plan role.

CI only runs what a change touches, and the branch ruleset requires a single **CI gate** check. Every plan and apply is reported in the job summary and as a PR comment.

[PR #6](https://github.com/christosgalano/silver-octo-garbanzo/pull/6) stays open on purpose as evidence. It opens SSH to the world, and both scanners fail it.

Every suppression is inline, next to the resource, with its reason. The full list is under **Accepted findings** below.

## Accepted findings (R3)

| Finding | Where | Why accepted |
| --- | --- | --- |
| AWS-0104: unrestricted egress | public instance security group | The instance needs outbound HTTP/HTTPS for OS packages and the SSM endpoint. Egress is limited to ports 80 and 443. |
| AWS-0089: no server access logging (expires 2027-03-31) | artifacts bucket | Access logging needs a separate log bucket and extra storage and operations. Accepted for dev. Revisit for production. |
| AWS-0089: no server access logging | state bucket (`bootstrap/`, outside this repo) | Deliberately omitted for this assessment. Production should add CloudTrail S3 data events, which are not configured here. |
| AWS-0132: SSE-S3 instead of a customer-managed KMS key | state bucket (`bootstrap/`, outside this repo) | Access is limited to the pipeline roles and admins. Production would use a CMK. |

No blanket suppressions, no `.trivyignore`.

## Delivery

GitHub Actions authenticates to AWS with OIDC, so there are no stored keys. PRs plan with a read-only role. After merge, CD plans `main` again, re-checks policy, waits for approval on the `dev` environment and then applies that exact saved plan. The gate is enforced both in GitHub and in the AWS role trust. There's no destroy workflow on purpose.

## What it doesn't protect against

- Changes made in the console. There's no drift detection yet.
- PR authors, who effectively run code as the read-only plan role during plan.
- A broad apply role for EC2, KMS and logs. That's fine for a dedicated dev account, not for a shared one.
- Values only known after apply, which the policies can't check.
- Missing HTTPS (no domain or certificate) and missing high availability.
- Admins bypassing the ruleset. That's intentional, for break-glass.
- Root on the instances, which runs as the Systems Manager role rather than the instance role.

## Next steps

With more time I'd add Session Manager logging, put an ALB with ACM in front of the web tier, and add nightly drift detection. After that I'd tighten the apply role and move to an account per environment, add more policy rules, and publish the policies as an OPA bundle.
