# METADATA
# scope: package
# description: |
#   Catches renamed for_each/count keys. Without a moved block Terraform plans a
#   destroy and a create of the same resource, and runs them in parallel. For
#   things like security group rules the create fails as a duplicate while the
#   old rule is still there, and the destroy then leaves nothing behind.
# entrypoint: true
package terraform.util.rename

# METADATA
# title: Renamed instance keys need a moved block.
# description: One key of this resource is being destroyed while another key of the same resource is being created. This is almost certainly a rename, so add a moved block instead of destroying and recreating.
deny contains msg if {
	some removed in _by_action("delete")
	some added in _by_action("create")
	removed.address != added.address
	_base(removed.address) == _base(added.address)
	msg := sprintf("%s: %s Replaced by %s.", [removed.address, rego.metadata.rule().description, added.address])
}

_by_action(action) := [rc |
	some rc in input.resource_changes
	rc.mode == "managed"
	rc.change.actions == [action]
	regex.match(`\[[^\]]*\]$`, rc.address)
]

_base(address) := regex.replace(address, `\[[^\]]*\]$`, "")
