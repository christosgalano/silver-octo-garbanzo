package terraform.util.resources_test

import data.terraform.util.resources as r

rc(type, actions) := {
	"address": $"{type}.this",
	"mode": "managed",
	"type": type,
	"change": {"actions": actions, "after": {"name": "x"}, "after_unknown": {}},
}

plan := {"resource_changes": [
	rc("aws_instance", ["create"]),
	rc("aws_s3_bucket", ["update"]),
	rc("aws_vpc", ["delete"]),
	rc("aws_eip", ["no-op"]),
	object.union(rc("aws_ami", ["read"]), {"mode": "data"}),
]}

test_changed_keeps_creates_and_updates if {
	types := {c.type | some c in r.changed(plan)}
	types == {"aws_instance", "aws_s3_bucket"}
}

test_changed_includes_replacements if {
	replaced := {"resource_changes": [rc("aws_instance", ["delete", "create"])]}
	count(r.changed(replaced)) == 1
}

test_changed_by_type if {
	count(r.changed_by_type("aws_instance", plan)) == 1
	count(r.changed_by_type("aws_vpc", plan)) == 0
}

test_changed_by_types if {
	count(r.changed_by_types({"aws_instance", "aws_s3_bucket"}, plan)) == 2
}

test_known if {
	r.known(rc("aws_instance", ["create"]), "name")
}

test_unknown if {
	unknown := object.union(rc("aws_instance", ["create"]), {"change": {"after": {"name": null}, "after_unknown": {"name": true}}})
	not r.known(unknown, "name")
}

test_message if {
	r.message(rc("aws_instance", ["create"]), "bad") == "aws_instance.this: bad"
}
