package terraform.aws.security_group_test

import data.terraform.aws.security_group

# A compliant internet-facing rule: HTTPS, tagged public.
valid_rule := {
	"address": "module.base.aws_vpc_security_group_ingress_rule.public_web[\"443-0.0.0.0/0\"]",
	"mode": "managed",
	"type": "aws_vpc_security_group_ingress_rule",
	"change": {
		"actions": ["create"],
		"after": {
			"cidr_ipv4": "0.0.0.0/0",
			"cidr_ipv6": null,
			"ip_protocol": "tcp",
			"from_port": 443,
			"to_port": 443,
			"tags": {"Exposure": "public"},
		},
		"after_unknown": {},
	},
}

rule_with(properties) := object.union(valid_rule, {"change": {"after": object.union(valid_rule.change.after, properties)}})

input_with(rc) := {"resource_changes": [rc]}

denials(properties) := result if {
	result := security_group.deny with input as input_with(rule_with(properties))
}

test_valid_public_https if {
	count(security_group.deny) == 0 with input as input_with(valid_rule)
}

test_valid_public_http if {
	count(denials({"from_port": 80, "to_port": 80})) == 0
}

test_internal_cidr_needs_no_tag if {
	count(denials({"cidr_ipv4": "10.0.0.0/16", "tags": null, "from_port": 5432, "to_port": 5432})) == 0
}

test_ssh_from_internet_denied if {
	some msg in denials({"from_port": 22, "to_port": 22})
	contains(msg, "SSH (22) and RDP (3389) must never be open")
}

test_rdp_inside_range_denied if {
	some msg in denials({"from_port": 3000, "to_port": 4000})
	contains(msg, "SSH (22) and RDP (3389)")
}

test_all_protocols_denied if {
	some msg in denials({"ip_protocol": "-1", "from_port": null, "to_port": null})
	contains(msg, "SSH (22) and RDP (3389)")
}

test_ipv6_world_open_counts if {
	some msg in denials({"cidr_ipv4": null, "cidr_ipv6": "::/0", "from_port": 22, "to_port": 22})
	contains(msg, "SSH (22)")
}

test_untagged_world_open_denied if {
	some msg in denials({"tags": null})
	contains(msg, "tagged Exposure=public")
}

test_wrong_tag_value_denied if {
	some msg in denials({"tags": {"Exposure": "private"}})
	contains(msg, "tagged Exposure=public")
}

test_non_web_port_denied if {
	some msg in denials({"from_port": 8080, "to_port": 8080})
	contains(msg, "only allowed on TCP 80 or 443")
}

test_message_has_address if {
	some msg in denials({"from_port": 22, "to_port": 22})
	startswith(msg, "module.base.aws_vpc_security_group_ingress_rule.public_web")
}

test_deleted_rule_ignored if {
	deleted := object.union(rule_with({"from_port": 22, "to_port": 22}), {"change": {"actions": ["delete"]}})
	count(security_group.deny) == 0 with input as input_with(deleted)
}

test_inline_rules_denied if {
	sg := {
		"address": "aws_security_group.legacy",
		"mode": "managed",
		"type": "aws_security_group",
		"change": {"actions": ["create"], "after": {"ingress": [{"from_port": 22}], "egress": []}, "after_unknown": {}},
	}
	some msg in security_group.deny with input as input_with(sg)
	contains(msg, "not inline blocks")
}

test_group_without_inline_rules_allowed if {
	sg := {
		"address": "aws_security_group.ok",
		"mode": "managed",
		"type": "aws_security_group",
		"change": {"actions": ["create"], "after": {"ingress": [], "egress": []}, "after_unknown": {}},
	}
	count(security_group.deny) == 0 with input as input_with(sg)
}

test_legacy_rule_resource_denied if {
	legacy := {
		"address": "aws_security_group_rule.legacy",
		"mode": "managed",
		"type": "aws_security_group_rule",
		"change": {"actions": ["create"], "after": {}, "after_unknown": {}},
	}
	some msg in security_group.deny with input as input_with(legacy)
	contains(msg, "aws_security_group_rule")
}
