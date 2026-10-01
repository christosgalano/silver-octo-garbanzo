package terraform.aws.iam_test

import data.terraform.aws.iam

boundary := "arn:aws:iam::111122223333:policy/acme-workload-boundary"

ec2_trust := json.marshal({"Version": "2012-10-17", "Statement": [{
	"Effect": "Allow",
	"Action": "sts:AssumeRole",
	"Principal": {"Service": "ec2.amazonaws.com"},
}]})

valid_role := {
	"address": "module.base.aws_iam_role.private",
	"mode": "managed",
	"type": "aws_iam_role",
	"change": {
		"actions": ["create"],
		"after": {"permissions_boundary": boundary, "assume_role_policy": ec2_trust},
		"after_unknown": {},
	},
}

read_policy := json.marshal({"Version": "2012-10-17", "Statement": [{
	"Effect": "Allow",
	"Action": ["s3:GetObject", "s3:ListBucket"],
	"Resource": "arn:aws:s3:::bucket/*",
}]})

valid_policy := {
	"address": "module.base.aws_iam_role_policy.read_artifacts",
	"mode": "managed",
	"type": "aws_iam_role_policy",
	"change": {"actions": ["create"], "after": {"policy": read_policy}, "after_unknown": {}},
}

with_after(rc, properties) := object.union(rc, {"change": {"after": object.union(rc.change.after, properties)}})

denials(rc) := result if {
	result := iam.deny with input as {"resource_changes": [rc]}
}

warnings(rc) := result if {
	result := iam.warn with input as {"resource_changes": [rc]}
}

policy_doc(statement) := json.marshal({"Version": "2012-10-17", "Statement": statement})

test_valid_role if {
	count(denials(valid_role)) == 0
}

test_valid_policy if {
	count(denials(valid_policy)) == 0
	count(warnings(valid_policy)) == 0
}

test_role_without_boundary_denied if {
	some msg in denials(with_after(valid_role, {"permissions_boundary": null}))
	contains(msg, "permissions_boundary")
}

test_role_with_other_boundary_denied if {
	some msg in denials(with_after(valid_role, {"permissions_boundary": "arn:aws:iam::111122223333:policy/admin"}))
	contains(msg, "permissions_boundary")
}

test_role_with_unknown_boundary_allowed if {
	rc := object.union(with_after(valid_role, {"permissions_boundary": null}), {"change": {"after_unknown": {"permissions_boundary": true}}})
	count(denials(rc)) == 0
}

test_star_action_denied if {
	doc := policy_doc([{"Effect": "Allow", "Action": "*", "Resource": "*"}])
	some msg in denials(with_after(valid_policy, {"policy": doc}))
	contains(msg, "must not allow")
}

test_service_wildcard_denied if {
	doc := policy_doc([{"Effect": "Allow", "Action": ["s3:GetObject", "s3:*"], "Resource": "*"}])
	some msg in denials(with_after(valid_policy, {"policy": doc}))
	contains(msg, "must not allow")
}

test_single_statement_object_handled if {
	doc := json.marshal({"Version": "2012-10-17", "Statement": {"Effect": "Allow", "Action": "iam:*", "Resource": "*"}})
	some msg in denials(with_after(valid_policy, {"policy": doc}))
	contains(msg, "must not allow")
}

test_wildcard_in_deny_allowed if {
	doc := policy_doc([{"Effect": "Deny", "Action": "s3:*", "Resource": "*"}])
	count(denials(with_after(valid_policy, {"policy": doc}))) == 0
}

test_partial_wildcard_allowed if {
	doc := policy_doc([{"Effect": "Allow", "Action": "s3:Get*", "Resource": "*"}])
	count(denials(with_after(valid_policy, {"policy": doc}))) == 0
}

test_unknown_policy_warns if {
	rc := {
		"address": "module.base.aws_iam_role_policy.decrypt_artifacts",
		"mode": "managed",
		"type": "aws_iam_role_policy",
		"change": {"actions": ["create"], "after": {"policy": null}, "after_unknown": {"policy": true}},
	}
	count(denials(rc)) == 0
	some msg in warnings(rc)
	contains(msg, "only known after apply")
}

test_anonymous_trust_denied if {
	trust := policy_doc([{"Effect": "Allow", "Action": "sts:AssumeRole", "Principal": {"AWS": "*"}}])
	some msg in denials(with_after(valid_role, {"assume_role_policy": trust}))
	contains(msg, "any principal")
}

test_bare_star_principal_denied if {
	trust := policy_doc([{"Effect": "Allow", "Action": "sts:AssumeRole", "Principal": "*"}])
	some msg in denials(with_after(valid_role, {"assume_role_policy": trust}))
	contains(msg, "any principal")
}
