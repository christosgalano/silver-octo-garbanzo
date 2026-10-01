# Base environment: AWS + Terraform

A small AWS base environment as code, plus the working practices a new team can copy. The infrastructure is deliberately small; the effort went into making sure an unsafe copy-paste fails in CI before a reviewer has to spot it.

## What it builds

- **Network:** a VPC across two AZs with public and private subnets. The private tier has no internet route.
- **Public instance:** EC2 with an Elastic IP serving HTTP, HTTPS port open.
- **Private instance:** EC2 with no inbound rules, no SSH and no internet, reached through Session Manager over VPC endpoints (no NAT, no bastion).
- **S3 bucket:** private, versioned, KMS-encrypted, TLS-only. The private instance's IAM role can read it and nothing else.

## Structure

- `terraform/modules/`: small single-purpose modules (network, instance, bucket).
- `terraform/stacks/base/`: wires the modules together once.
- `terraform/live/dev/`: environment config only, so adding `prod` means copying a thin folder rather than drifting wiring.
- `policy/`: Rego policies with unit tests, evaluated against the plan.
- `.github/`: CI and CD workflows, shared actions and change detection.

Terragrunt isn't used: one account, one environment and one state file don't need it.

## Guardrails

Every PR runs formatting, validation, tflint and docs checks, `terraform test` on changed modules, Trivy for generic AWS misconfiguration, and conftest for house rules evaluated on the resolved plan. Policies cover:

- security groups (world ingress only on tagged web ports, never SSH/RDP);
- instances (approved types, IMDSv2, no automatic public IPs);
- IAM (permissions boundary on every role, no wildcards);
- mandatory tags.

CI is change-aware and a single **CI gate** check is required by the branch ruleset. Every plan and apply is reported in the job summary and as a PR comment. [PR #6](https://github.com/christosgalano/silver-octo-garbanzo/pull/6) stays open on purpose as evidence: it opens SSH to the world and both scanners fail it.

Every suppression is inline with its reason (egress for package installs, bucket access logging, state bucket logging and encryption). One expires on 2027-03-31.

## Delivery

GitHub Actions authenticates to AWS with OIDC, so there are no stored keys. PRs plan with a read-only role. After merge, CD re-plans `main`, re-checks policy, waits for approval on the `dev` environment, then applies that exact saved plan. The gate is enforced in both GitHub and the AWS role trust. There is no destroy workflow on purpose.

Cost if left running is roughly $35–40/month, mostly the SSM endpoints and two small instances.

## Known limits

- Console changes aren't detected (no drift detection yet).
- PR authors run code under the read-only plan role during plan.
- The apply role is broad for EC2, KMS and logs, which is fine for a dedicated dev account.
- Values only known after apply aren't policy-checked.
- No real HTTPS (no domain or certificate) and no high availability.
- Admins can bypass the ruleset (break-glass).
- Root on the instances runs as the Systems Manager role.

## Next steps

Configure Session Manager logging, add an ALB with ACM, add drift detection, tighten the apply role and move to an account per environment, add further policy rules, and publish the policies as an OPA bundle.
