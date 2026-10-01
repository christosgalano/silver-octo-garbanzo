package terraform.aws.instance_test

import data.terraform.aws.instance

valid_instance := {
	"address": "module.base.module.private_instance.aws_instance.this",
	"mode": "managed",
	"type": "aws_instance",
	"change": {
		"actions": ["create"],
		"after": {
			"instance_type": "t3.micro",
			"associate_public_ip_address": false,
			"metadata_options": [{"http_tokens": "required"}],
			"tags": {"Name": "acme-dev-private", "Exposure": "private"},
		},
		"after_unknown": {},
	},
}

instance_with(properties) := object.union(valid_instance, {"change": {"after": object.union(valid_instance.change.after, properties)}})

denials(properties) := result if {
	result := instance.deny with input as {"resource_changes": [instance_with(properties)]}
}

test_valid_instance if {
	count(denials({})) == 0
}

test_public_exposure_allowed if {
	count(denials({"tags": {"Exposure": "public"}})) == 0
}

test_large_instance_type_denied if {
	some msg in denials({"instance_type": "m7i.4xlarge"})
	contains(msg, "Instance type must be one of")
}

test_missing_exposure_denied if {
	untagged := json.remove(valid_instance, ["change/after/tags/Exposure"])
	some msg in instance.deny with input as {"resource_changes": [untagged]}
	contains(msg, "Exposure=public or Exposure=private")
}

test_null_tags_denied if {
	some msg in denials({"tags": null})
	contains(msg, "Exposure=public or Exposure=private")
}

test_unknown_exposure_denied if {
	some msg in denials({"tags": {"Exposure": "internal"}})
	contains(msg, "Exposure=public or Exposure=private")
}

test_imdsv1_denied if {
	some msg in denials({"metadata_options": [{"http_tokens": "optional"}]})
	contains(msg, "IMDSv2")
}

test_missing_metadata_options_denied if {
	some msg in denials({"metadata_options": []})
	contains(msg, "IMDSv2")
}

test_automatic_public_ip_denied if {
	some msg in denials({"associate_public_ip_address": true})
	contains(msg, "automatic public IP")
}

test_message_has_address if {
	some msg in denials({"instance_type": "m7i.4xlarge"})
	startswith(msg, "module.base.module.private_instance.aws_instance.this: ")
}
