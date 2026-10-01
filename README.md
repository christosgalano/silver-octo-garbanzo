# Base environment: AWS + Terraform

The brief: stand up a small AWS base environment as code, and set up the working practices a new team will copy for the next two years. I treated the second half as the real deliverable. The infrastructure is deliberately small. Most of the effort went into making sure that when someone copy-pastes this without reading it, the unsafe version fails in CI before a reviewer ever has to spot it.

What's here:

- **Networking:** a VPC across two AZs with public and private subnets. The private tier has no route to the internet at all.
- **Public instance:** EC2 in a public subnet behind an Elastic IP, serving HTTP (nginx) on 80, with 443 open as well.
- **Private instance:** EC2 in a private subnet. No inbound rules, no SSH, no internet. Operated through Session Manager.
- **S3 bucket:** for artefacts and logs. Private, versioned, KMS-encrypted, TLS-only.
- **IAM role:** for the private instance, which can read that bucket and nothing else.
- **Pipeline:** GitHub Actions with OIDC to AWS. Trivy and conftest gate every PR. Merges to main apply through an approved GitHub Environment.

## Layout

```text
bootstrap/                 one-off account setup (state bucket, OIDC roles, boundary, DHMC, budget)
terraform/
  modules/                 small reusable building blocks
    network/  instance/  bucket/
  stacks/base/             wires the modules into one environment
  environments/dev/        config only: backend, provider, terraform.tfvars
policy/terraform/          Rego policies + tests, evaluated by conftest against the plan
.github/
  workflows/ci.yaml        PR: static checks, Trivy, policy tests, plan + conftest
  workflows/cd.yaml        main: plan + conftest, then apply after approval
  actions/terraform-setup/ shared "install, assume role, init" steps
scripts/configure-github.sh   repo variables, dev environment, branch ruleset
```

**Why a stack plus thin environments.** An environment folder holds only what differs between environments: backend key, provider settings and `terraform.tfvars`. All the wiring lives once, in `stacks/base`. Adding `prod` means copying a folder of four small files and changing values, not copying wiring that then drifts. The modules stay small and single-purpose, so the stack reads top to bottom.

**Why not Terragrunt.** One account, one environment and one state file don't need it. Plain Terraform with thin roots gets most of the DRY benefit without another tool for the team to learn. I'd revisit once there are several accounts or regions, or stacks that depend on each other's outputs. Terragrunt earns its place there, especially for generating backend blocks and ordering applies. I've mostly worked with plain Terraform layouts like this one, so that's also the setup I can support best from day one.

## Running it

### Prerequisites

- Terraform >= 1.10 (CI pins 1.16.4), AWS CLI v2, `gh` and `jq`.
- Admin credentials for the target account, ideally an SSO profile, for the one-off bootstrap only.
- Optional: `pre-commit install`, which runs fmt, terraform-docs, opa fmt/test and Trivy before each commit.

### 1. Bootstrap the account (once, by a human)

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars   # set budget_alert_email
terraform init
terraform apply
```

This creates:

- **State bucket:** versioned, TLS-only, with `prevent_destroy`.
- **GitHub OIDC provider.**
- **Plan role:** read-only, assumable from PRs and from `main`.
- **`dev` apply role:** assumable only from the `dev` GitHub Environment.
- **Permissions boundary:** every role the pipeline creates must carry it.
- **Session Manager's Default Host Management Configuration (DHMC).**
- **Monthly budget:** $20, with alerts.

Bootstrap state stays local and git-ignored for now. Moving it into the state bucket is on the next-steps list.

### 2. Wire up GitHub

```bash
scripts/configure-github.sh            # reviewer defaults to you
```

This sets the repository variables. It creates the `dev` environment with a required reviewer, deployments from `main` only, and the apply role ARN. It also adds a ruleset on `main` that requires a PR and all four CI checks. Nothing in GitHub is a secret: OIDC means there are no AWS keys to store.

> Environments with required reviewers and enforced rulesets on a **private** repo need a paid GitHub plan. On GitHub Free, make the repo public or the protections are not enforced.

### 3. Use it

Open a PR. CI posts the plan and the policy results as a comment. After merge, CD plans again and waits for approval on `dev`, then applies that exact saved plan.

Running a plan locally works with your own credentials:

```bash
cd terraform/environments/dev
terraform init -backend-config="bucket=tfstate-acme-<account-id>"
terraform plan
```

### 4. Tear down

```bash
cd terraform/environments/dev && terraform destroy     # admin credentials
```

There's no destroy workflow on purpose. Destroying an environment is rare, so it should be done by a person with full context, not by a button in a pipeline. The bootstrap stays: the state bucket has `prevent_destroy`.

**Cost.** Left running, dev costs roughly $45–50/month in eu-central-1. Most of that is the three SSM interface endpoints (~$26) and the two t3.micro instances (~$17). The plan is to apply, capture the evidence and destroy the same day; the bootstrap costs effectively nothing (budget alarm, empty bucket, IAM).

## Private instance access (item 3)

**Decision:** AWS Systems Manager Session Manager, through VPC interface endpoints, with no NAT gateway. The instance has no inbound rules at all, no SSH key and no route to the internet.

How it fits together:

- **The connection is outbound.** The SSM Agent on the instance dials out to the `ssm`, `ssmmessages` and `ec2messages` endpoints. A shell (`aws ssm start-session --target <id>`) rides on that, so there is nothing to scan and no port to leave open.
- **Access is IAM.** Who can open a session is an IAM permission on `ssm:StartSession`. That gives you MFA, SSO and CloudTrail, instead of SSH keys handed around a team.
- **Logs and artefacts:** read them in a session, or pull them from S3 through the free gateway endpoint.
- **The instance role stays clean.** Session Manager permissions come from **Default Host Management Configuration**, a regional setting where Systems Manager uses its own role for every IMDSv2 instance. So the private instance's role does exactly what the brief asks: read the bucket (plus `kms:Decrypt` via S3 only, because the objects are KMS-encrypted). It has no SSM permissions mixed in. DHMC only kicks in when the instance profile doesn't grant `ssm:UpdateInstanceInformation`, and a conftest rule could enforce that next.

Alternatives I considered:

| Option | Why not |
| --- | --- |
| Bastion host | Another internet-facing box to patch, SSH keys to manage, port 22 open somewhere. It's exactly what the guardrails are meant to stop. |
| SSM through a NAT gateway | Works, and is simpler, but gives the private instance general internet egress it doesn't need. Also ~$32/month plus data. |
| EC2 Instance Connect Endpoint | Free and IAM-gated, but still SSH: port 22 from the endpoint's security group and keys pushed per session. No session logging to S3 out of the box. A reasonable second choice. |

**Trade-offs I'm accepting:**

- Interface endpoints cost money per AZ. In dev they sit in one AZ only (`interface_endpoints_multi_az = false`). With one private instance in one AZ, a second endpoint AZ buys nothing.
- DHMC is account-and-region wide, which is why it lives in `bootstrap/` and not in an environment. It can take up to 30 minutes after first enabling before instances register.
- The private instance can't install packages from the internet. That's intended. A real workload would bake an AMI or use S3/VPC-endpoint-hosted repos.
- Session logging to S3/CloudWatch isn't configured yet. It's on the next-steps list.

## Guardrails (R1, R2)

Three layers, all before anything is applied:

| Layer | Runs on | Catches |
| --- | --- | --- |
| `terraform fmt/validate`, tflint (AWS ruleset), terraform-docs check | PR | Broken or sloppy code, invalid instance types, stale module docs |
| **Trivy** (`trivy config`) | PR, and pre-commit | Generic AWS misconfiguration in the HCL: public buckets, open security groups, missing encryption, IMDSv1, and so on. Any finding at any severity fails the job. |
| **conftest** (Rego in `policy/`) | PR and CD, on the **plan JSON** | House rules, evaluated on resolved values. See below. |

Why both Trivy and conftest:

- **Trivy** knows AWS best practice but not our conventions, and it reads HCL.
- **conftest** reads the plan, so it sees values after variables, modules and `for_each` are resolved. That's where a world-open rule built from a variable shows up.

The policies:

- **Security groups:**
  - Ingress from `0.0.0.0/0` or `::/0` only on TCP 80/443, and only on rules tagged `Exposure=public`.
  - Never 22 or 3389 from anywhere.
  - No inline rules or `aws_security_group_rule`, so every rule gets checked on its own.
- **Instances:**
  - Approved types only: a cost guard against a typo burning the budget.
  - `Exposure` tag required.
  - IMDSv2 required.
  - No automatic public IPs.
- **IAM:**
  - Every role carries the workload permissions boundary. This mirrors what the apply role enforces in AWS, so the mistake fails on the PR instead of as an AccessDenied mid-apply.
  - No `*` or `service:*` actions.
  - No `*` principals in trust policies.
  - Policy documents that are only known after apply produce a **warning**.
- **Tags:** every taggable resource carries `Project`, `Environment`, `Owner` and `ManagedBy`.

Policies have unit tests (`opa test`, 100% coverage, CI fails below 90%) and are linted with Regal. The structure follows my [opa-template-repo](https://github.com/christosgalano/opa-template-repo).

I dropped Checkov, which came with my template. Trivy covers the same AWS checks, and two scanners mean two suppression formats and twice the noise for the same signal.

**Evidence (R2):** see [`docs/evidence/`](docs/evidence/) and the open PR from the `demo/non-compliant` branch. It opens SSH to the world on the private instance and switches off one bucket public-access setting. Trivy and conftest both fail it, independently.

## Plan and apply (R4)

- **PRs:** `terraform plan` runs with the read-only plan role and `-lock=false`. A plan can't block an apply, and the plan role never needs write access to state. The plan and the conftest output are posted on the PR.
- **Apply runs automatically after merge, behind a human gate.** CD plans `main` again (the merge result can differ from the PR head), re-runs conftest on that plan, and uploads it. The apply job then waits for approval on the `dev` environment and applies that exact saved plan. If state changed in between, Terraform rejects the stale plan rather than applying something nobody saw.

Why not fully automatic: even in dev, the pause costs one click and buys a look at the real plan before it touches the account. Why not manual-only: if applies are run from laptops, state and `main` drift apart. I've been bitten by exactly that, a branch apply silently reverted by the next deploy from `main`.

The gate is enforced twice:

- In GitHub: the environment's required reviewer and its main-only branch rule.
- In AWS: the apply role trusts only `environment:dev` tokens. The trust uses GitHub's immutable subject claims (`repo:owner@<id>/repo@<id>:…`), so a renamed or re-created repository with the same name can't inherit it. The first CI run failed exactly here: the trust policy still had the name-only format and STS refused the token.

A workflow on another branch can't get a token the apply role accepts.

## Suppressions and accepted findings (R3)

Every suppression is inline, directly above the resource, with the reason, so it shows up in the same diff as the code it covers. There's no `.trivyignore` and no blanket skips.

| # | Finding | Where | Why accepted |
| --- | --- | --- | --- |
| 1 | `AWS-0107` security group allows ingress from the public internet | `stacks/base/compute.tf`, `public_web` ingress | It's the point of the public instance: the brief asks for HTTP/HTTPS from the internet. Limited to 80/443, tagged `Exposure=public`, and conftest enforces both. `public_ingress_cidrs` can narrow it. |
| 2 | `AWS-0104` security group allows egress to the public internet | `stacks/base/compute.tf`, `public_web` egress | The public instance needs OS packages and the SSM endpoint. Limited to 80/443. The proper fix is a proxy or package mirror; not worth it for one dev instance. |
| 3 | `AWS-0089` bucket access logging disabled | `modules/bucket/main.tf` | Needs a second bucket for the logs, which then needs its own story. CloudTrail data events are the better fit for "who read what". **Expires 2027-03-31:** after that date CI fails again until someone decides properly. |
| 4 | `AWS-0089` access logging disabled on the state bucket | `bootstrap/state.tf` | One state file, two pipeline roles and admins. CloudTrail management events already record who touched it. |
| 5 | `AWS-0132` state bucket uses SSE-S3, not a customer-managed key | `bootstrap/state.tf` | Access is controlled by IAM, and the plan role is denied object reads anywhere else. A CMK adds a key policy to maintain for little extra protection here. I'd revisit if state starts holding real secrets. |

Not suppressions, but worth listing:

- **conftest warnings** for `decrypt_artifacts` and the flow-log role policy. Both reference ARNs that only exist after apply, so the policy can't inspect them. I built the S3 ARNs from names instead, so `read_artifacts` is fully checked. These two stay as warnings.
- **Regal `with-outside-test-context`** is ignored for `*_test.rego` only. The test helpers wrap `with`, and they are only called from tests.

## What this does not protect against

- **Changes outside Terraform.** Someone with console access can still open a port. There's no scheduled drift detection yet.
- **Anyone who can open a PR can run code with the plan role.** Providers and external data sources execute during plan. The role is read-only, can't read objects outside the state bucket, and can't decrypt or read secrets. It can still read account metadata.
- **The apply role is broad within its services.** It has `ec2:*`, `kms:*` and `logs:*` account-wide. IAM is fenced by name prefix and the permissions boundary, and S3 by bucket prefix, but EC2 and KMS aren't fenced. Fine for a dedicated dev account, not for a shared one.
- **Only what's in the plan.** Values only known after apply aren't policy-checked (they surface as warnings). The policies also don't look at runtime: AMI patch level, what nginx serves, application vulnerabilities.
- **HTTPS isn't actually terminated.** 443 is open, but there's no certificate, because there's no domain. In a real setup the instance would sit behind an ALB with ACM, in a private subnet.
- **Admins can bypass the ruleset.** That's intentional for break-glass, but it means "CI is required" holds for everyone except the people who can change the rule.
- **No high availability.** One instance of each, in one AZ.

## What I'd do next with more time

1. Move bootstrap state into the state bucket (`terraform init -migrate-state`) and add a plan-only CI check for `bootstrap/`.
2. Configure Session Manager preferences: session logs to S3/CloudWatch, idle timeout, and `run as` a non-root user.
3. Put an ALB + ACM in front of the web tier and move the instance into a private subnet. The public subnet would then hold only the ALB.
4. Scheduled drift detection (nightly `plan -detailed-exitcode` that opens an issue).
5. Tighten the apply role with tag-based conditions on EC2 and KMS, and move to a dedicated account per environment under AWS Organizations, with SCPs as the outer fence.
6. A conftest rule that instance profiles never grant `ssm:UpdateInstanceInformation` (which would silently bypass DHMC), and one for S3 public-access-block completeness.
7. Publish the policies as an OPA bundle so other repos consume the same rules, as in my template repo.

## Where I used AI

I used AI (Claude) as a pair while building this:

- To check AWS details I wanted to be sure of, mainly the DHMC prerequisites and precedence, and Trivy's inline-ignore syntax.
- To review the IAM policies and Rego for gaps.
- To help draft and tighten this README.

The design decisions, the trade-offs and the suppressions are mine, and I'm happy to walk through any of them.
