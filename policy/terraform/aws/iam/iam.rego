# METADATA
# scope: package
# description: |
#   IAM rules for roles and policies created by this repository. They mirror what
#   the apply role enforces in AWS (permissions boundary) so the mistake fails on
#   the PR instead of as an AccessDenied halfway through an apply.
# entrypoint: true
package terraform.aws.iam

import data.terraform.util.resources

_roles := resources.changed_by_type("aws_iam_role", input)

_policies := resources.changed_by_types({"aws_iam_role_policy", "aws_iam_policy"}, input)

# METADATA
# title: Roles carry a permissions boundary.
# description: IAM roles must set permissions_boundary to the workload boundary policy.
deny contains msg if {
	some role in _roles
	not _has_workload_boundary(role)
	msg := resources.message(role, rego.metadata.rule().description)
}

# METADATA
# title: No wildcard actions.
# description: IAM policies must not allow "*" or "<service>:*". List the actions the workload needs.
deny contains msg if {
	some policy in _policies
	resources.known(policy, "policy")
	some statement in _statements(policy.change.after.policy)
	statement.Effect == "Allow"
	some action in _as_array(statement.Action)
	_wildcard_action(action)
	msg := resources.message(policy, rego.metadata.rule().description)
}

# METADATA
# title: No anonymous trust.
# description: Role trust policies must not allow any principal ("*") to assume the role.
deny contains msg if {
	some role in _roles
	resources.known(role, "assume_role_policy")
	some statement in _statements(role.change.after.assume_role_policy)
	statement.Effect == "Allow"
	_anonymous(statement.Principal)
	msg := resources.message(role, rego.metadata.rule().description)
}

# METADATA
# title: Unreviewable policy.
# description: Policy document is only known after apply, so it cannot be checked here. Build ARNs from names so the document is known at plan time.
warn contains msg if {
	some policy in _policies
	not resources.known(policy, "policy")
	msg := resources.message(policy, rego.metadata.rule().description)
}

_has_workload_boundary(role) if endswith(role.change.after.permissions_boundary, ":policy/acme-workload-boundary")

# A boundary that is only known after apply is still a boundary; the apply role
# checks the exact ARN.
_has_workload_boundary(role) if role.change.after_unknown.permissions_boundary == true

_statements(document) := _as_array(json.unmarshal(document).Statement)

_as_array(value) := value if is_array(value)

_as_array(value) := [value] if not is_array(value)

_wildcard_action("*")

_wildcard_action(action) if endswith(action, ":*")

_anonymous("*")

_anonymous(principal) if {
	some value in _as_array(principal.AWS)
	value == "*"
}
