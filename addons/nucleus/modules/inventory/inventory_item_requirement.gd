class_name NucleusInventoryItemRequirement
extends NucleusActionRequirement
## Gates a GameplayAction by the amount of one item in an Inventory.

@export var inventory: NucleusInventory
@export var item_id: StringName
@export_range(1, 1000000, 1, "or_greater")
var amount: int = 1


func _ready() -> void:
	if inventory == null:
		inventory = _find_inventory()

	if inventory == null:
		NucleusLog.error(
			"%s requires a NucleusInventory." % get_path(),
			&"InventoryItemRequirement",
		)
		return

	inventory.changed.connect(_on_inventory_changed)


func _exit_tree() -> void:
	if (
		inventory != null
		and inventory.changed.is_connected(
			_on_inventory_changed
		)
	):
		inventory.changed.disconnect(
			_on_inventory_changed
		)


func check(_context: Dictionary) -> Error:
	if inventory == null:
		return ERR_UNCONFIGURED

	if item_id == &"" or amount <= 0:
		return ERR_INVALID_PARAMETER

	if not inventory.has_item(
		item_id,
		amount,
	):
		return ERR_UNAVAILABLE

	return OK


func _on_inventory_changed() -> void:
	notify_availability_changed()


func _find_inventory() -> NucleusInventory:
	var root: Node = get_parent()

	while root:
		if root is NucleusInventory:
			return root as NucleusInventory

		for node: Node in NucleusNodeUtils.descendants(root):
			if node is NucleusInventory:
				return node as NucleusInventory

		root = root.get_parent()

	return null
