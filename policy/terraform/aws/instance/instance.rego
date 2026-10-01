# METADATA
# scope: package
# description: |
#   House rules for EC2 instances: declared exposure, IMDSv2 (Session Manager
#   depends on it), no automatic public IPs, and instance types from an approved
#   list so a typo cannot burn the budget.
# entrypoint: true
package terraform.aws.instance

import data.terraform.util.resources

# Small, burstable types only. Anything bigger is a conversation, not a PR.
_allowed_types := {"t3.micro", "t3.small", "t4g.micro", "t4g.small"}

_instances := resources.changed_by_type("aws_instance", input)

# METADATA
# title: Approved instance types only.
# description: Instance type must be one of t3.micro, t3.small, t4g.micro, t4g.small.
deny contains msg if {
	some instance in _instances
	not instance.change.after.instance_type in _allowed_types
	msg := resources.message(instance, rego.metadata.rule().description)
}

# METADATA
# title: Exposure must be declared.
# description: Instances must be tagged Exposure=public or Exposure=private.
deny contains msg if {
	some instance in _instances
	not object.get(instance.change.after, ["tags", "Exposure"], "") in {"public", "private"}
	msg := resources.message(instance, rego.metadata.rule().description)
}

# METADATA
# title: IMDSv2 required.
# description: Instances must require IMDSv2 (metadata_options.http_tokens = "required"). Session Manager access through DHMC depends on it.
deny contains msg if {
	some instance in _instances
	not _imdsv2_required(instance.change.after)
	msg := resources.message(instance, rego.metadata.rule().description)
}

# METADATA
# title: No automatic public IPs.
# description: Instances must not get an automatic public IP. Public instances use an Elastic IP so the exposure is explicit in the plan.
deny contains msg if {
	some instance in _instances
	instance.change.after.associate_public_ip_address == true
	msg := resources.message(instance, rego.metadata.rule().description)
}

_imdsv2_required(after) if {
	some options in after.metadata_options
	options.http_tokens == "required"
}
