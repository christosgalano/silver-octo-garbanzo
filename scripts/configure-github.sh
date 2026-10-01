#!/usr/bin/env bash
# Wires the GitHub side to what bootstrap/ created:
#   - repository variables the workflows read (no secrets: OIDC needs none)
#   - the `dev` environment: required reviewer, deployments from main only,
#     and the apply role ARN as an environment variable
#   - a ruleset on main: PR required, CI checks required, no force pushes
#
# Usage: scripts/configure-github.sh [reviewer-login]
# Needs: gh (authenticated, repo admin), terraform, jq. Run from the repo root
# after `terraform apply` in bootstrap/.
set -euo pipefail

repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
reviewer=${1:-$(gh api user --jq .login)}
reviewer_id=$(gh api "users/${reviewer}" --jq .id)

out() { terraform -chdir=bootstrap output -raw "$1"; }
region=$(out region)
apply_role=$(terraform -chdir=bootstrap output -json apply_role_arns | jq -r '.dev')

echo "Configuring ${repo} (reviewer: ${reviewer}, region: ${region})"

gh variable set AWS_REGION --repo "$repo" --body "$region"
gh variable set AWS_ACCOUNT_ID --repo "$repo" --body "$(out account_id)"
gh variable set TF_STATE_BUCKET --repo "$repo" --body "$(out state_bucket)"
gh variable set AWS_PLAN_ROLE_ARN --repo "$repo" --body "$(out plan_role_arn)"

# Environment: one reviewer, custom branch policy limited to main.
jq -n --argjson id "$reviewer_id" '{
  wait_timer: 0,
  prevent_self_review: false,
  reviewers: [{type: "User", id: $id}],
  deployment_branch_policy: {protected_branches: false, custom_branch_policies: true}
}' | gh api -X PUT "repos/${repo}/environments/dev" --input - >/dev/null

existing=$(gh api "repos/${repo}/environments/dev/deployment-branch-policies" --jq '.branch_policies[].name')
grep -qx main <<<"$existing" || gh api -X POST "repos/${repo}/environments/dev/deployment-branch-policies" \
  -f name=main -f type=branch >/dev/null

gh variable set AWS_APPLY_ROLE_ARN --repo "$repo" --env dev --body "$apply_role"

# Ruleset on main. Check names must match the job names in ci.yaml.
ruleset=$(jq -n '{
  name: "main",
  target: "branch",
  enforcement: "active",
  conditions: {ref_name: {include: ["~DEFAULT_BRANCH"], exclude: []}},
  rules: [
    {type: "deletion"},
    {type: "non_fast_forward"},
    {type: "pull_request", parameters: {
      required_approving_review_count: 0,
      dismiss_stale_reviews_on_push: true,
      require_code_owner_review: false,
      require_last_push_approval: false,
      required_review_thread_resolution: true
    }},
    {type: "required_status_checks", parameters: {
      strict_required_status_checks_policy: true,
      required_status_checks: [
        {context: "Format, validate, lint, docs"},
        {context: "Trivy misconfiguration scan"},
        {context: "Policy lint and unit tests"},
        {context: "Plan and policy check (dev)"}
      ]
    }}
  ]
}')

id=$(gh api "repos/${repo}/rulesets" --jq '.[] | select(.name == "main") | .id')
if [[ -n "$id" ]]; then
  gh api -X PUT "repos/${repo}/rulesets/${id}" --input - <<<"$ruleset" >/dev/null
else
  gh api -X POST "repos/${repo}/rulesets" --input - <<<"$ruleset" >/dev/null
fi

echo "Done."
