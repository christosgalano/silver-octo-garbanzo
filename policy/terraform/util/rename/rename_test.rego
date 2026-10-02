package terraform.util.rename_test

import data.terraform.util.rename

rc(address, actions) := {
	"address": address,
	"mode": "managed",
	"type": "aws_vpc_security_group_ingress_rule",
	"change": {"actions": actions},
}

test_renamed_key_denied if {
	plan := {"resource_changes": [
		rc("module.base.aws_vpc_security_group_ingress_rule.public_web[\"443-0.0.0.0/0\"]", ["delete"]),
		rc("module.base.aws_vpc_security_group_ingress_rule.public_web[\"443\"]", ["create"]),
	]}
	some msg in rename.deny with input as plan
	contains(msg, "add a moved block")
	contains(msg, "public_web[\"443\"]")
}

test_unrelated_delete_and_create_allowed if {
	plan := {"resource_changes": [
		rc("module.base.aws_vpc_security_group_ingress_rule.old[\"a\"]", ["delete"]),
		rc("module.base.aws_vpc_security_group_ingress_rule.new[\"a\"]", ["create"]),
	]}
	count(rename.deny) == 0 with input as plan
}

test_create_only_allowed if {
	plan := {"resource_changes": [rc("module.base.aws_vpc_security_group_ingress_rule.public_web[\"443\"]", ["create"])]}
	count(rename.deny) == 0 with input as plan
}

test_replace_allowed if {
	plan := {"resource_changes": [rc("module.base.aws_vpc_security_group_ingress_rule.public_web[\"443\"]", ["delete", "create"])]}
	count(rename.deny) == 0 with input as plan
}
