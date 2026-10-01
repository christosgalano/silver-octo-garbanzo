# METADATA
# scope: package
# description: |
#   Network exposure rules for security groups. Opening something to the internet
#   has to be an explicit, tagged decision, limited to web ports, and never admin
#   ports.
# entrypoint: true
package terraform.aws.security_group

import data.terraform.util.resources

_rule_types := {"aws_vpc_security_group_ingress_rule"}

_admin_ports := {22, 3389}

_web_ports := {80, 443}

_ingress_rules := resources.changed_by_types(_rule_types, input)

# METADATA
# title: No admin ports from the internet.
# description: SSH (22) and RDP (3389) must never be open to the internet. Use Session Manager instead.
deny contains msg if {
	some rule in _ingress_rules
	_world_open(rule.change.after)
	some port in _admin_ports
	_covers_port(rule.change.after, port)
	msg := resources.message(rule, rego.metadata.rule().description)
}

# METADATA
# title: Internet ingress must be tagged public.
# description: Ingress from 0.0.0.0/0 or ::/0 is only allowed on rules tagged Exposure=public, so exposure is an explicit decision visible in the code.
deny contains msg if {
	some rule in _ingress_rules
	_world_open(rule.change.after)
	not _tagged_public(rule.change.after)
	msg := resources.message(rule, rego.metadata.rule().description)
}

# METADATA
# title: Internet ingress only on web ports.
# description: Ingress from 0.0.0.0/0 or ::/0 is only allowed on TCP 80 or 443, one port per rule.
deny contains msg if {
	some rule in _ingress_rules
	_world_open(rule.change.after)
	not _single_web_port(rule.change.after)
	msg := resources.message(rule, rego.metadata.rule().description)
}

# METADATA
# title: Use standalone rule resources.
# description: Define security group rules with aws_vpc_security_group_ingress_rule / egress_rule, not inline blocks or aws_security_group_rule, so every rule is checked and tagged on its own.
deny contains msg if {
	some rc in resources.changed_by_types({"aws_security_group", "aws_security_group_rule"}, input)
	_legacy_rules(rc)
	msg := resources.message(rc, rego.metadata.rule().description)
}

_legacy_rules(rc) if rc.type == "aws_security_group_rule"

_legacy_rules(rc) if {
	rc.type == "aws_security_group"
	count(object.get(rc.change.after, "ingress", [])) + count(object.get(rc.change.after, "egress", [])) > 0
}

_world_open(after) if after.cidr_ipv4 == "0.0.0.0/0"

_world_open(after) if after.cidr_ipv6 == "::/0"

_covers_port(after, _) if after.ip_protocol in {"-1", "all"}

_covers_port(after, port) if {
	after.from_port <= port
	after.to_port >= port
}

_tagged_public(after) if after.tags.Exposure == "public"

_single_web_port(after) if {
	after.ip_protocol == "tcp"
	after.from_port == after.to_port
	after.from_port in _web_ports
}
