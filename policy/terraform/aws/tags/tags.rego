# METADATA
# scope: package
# description: |
#   Every taggable resource carries the house tags, so cost and ownership can be
#   traced. The provider's default_tags normally take care of this; the rule
#   catches a root module that forgets them.
# entrypoint: true
package terraform.aws.tags

import data.terraform.util.resources

_required := {"Project", "Environment", "Owner", "ManagedBy"}

# METADATA
# title: Required tags.
# description: Taggable resources must carry the Project, Environment, Owner and ManagedBy tags.
deny contains msg if {
	some rc in resources.changed(input)
	_taggable(rc)
	missing := _required - _tag_keys(rc.change.after)
	count(missing) > 0
	msg := sprintf("%s (missing: %s)", [
		resources.message(rc, rego.metadata.rule().description),
		concat(", ", sort(missing)),
	])
}

# tags_all exists on every resource type that supports tags. If it is only known
# after apply we cannot judge it, so leave it alone.
_taggable(rc) if {
	"tags_all" in object.keys(rc.change.after)
	not rc.change.after_unknown.tags_all
}

_tag_keys(after) := object.keys(after.tags_all) if is_object(after.tags_all)

_tag_keys(after) := set() if not is_object(after.tags_all)
