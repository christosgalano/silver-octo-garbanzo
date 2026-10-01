package terraform.aws.tags_test

import data.terraform.aws.tags

house_tags := {"Project": "acme", "Environment": "dev", "Owner": "platform", "ManagedBy": "terraform"}

rc(after, after_unknown) := {
	"address": "module.base.module.network.aws_vpc.this",
	"mode": "managed",
	"type": "aws_vpc",
	"change": {"actions": ["create"], "after": after, "after_unknown": after_unknown},
}

denials(resource) := result if {
	result := tags.deny with input as {"resource_changes": [resource]}
}

test_all_tags_present if {
	count(denials(rc({"tags_all": house_tags}, {}))) == 0
}

test_extra_tags_fine if {
	count(denials(rc({"tags_all": object.union(house_tags, {"Name": "x"})}, {}))) == 0
}

test_missing_tags_listed if {
	some msg in denials(rc({"tags_all": {"Project": "acme"}}, {}))
	contains(msg, "missing: Environment, ManagedBy, Owner")
}

test_null_tags_all_denied if {
	count(denials(rc({"tags_all": null}, {}))) == 1
}

test_untaggable_resource_ignored if {
	count(denials(rc({"name": "x"}, {}))) == 0
}

test_unknown_tags_ignored if {
	count(denials(rc({"tags_all": null}, {"tags_all": true}))) == 0
}
