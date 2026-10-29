class_name NucleusInventoryItemCost
extends NucleusActionCost
## Transactional GameplayAction cost for homogeneous/fungible inventory items.
##
## Unique stateful items should use a game-specific cost that selects an exact
## stack/instance instead of consuming by item_id.

@export var inventory: NucleusInventory
@export var item_id: StringName
@export_range(1, 1000000, 1, "or_greater")
var amount: int = 1

var _paid_amount: int = 0


func _ready() -> void:
	if inventory == null:
		inventory = _find_inventory()

	if inventory == null:
		NucleusLog.error(
			"%s requires a NucleusInventory." % get_path(),
			&"InventoryItemCost",
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


func can_pay(_context: Dictionary) -> Error:
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


func pay(_context: Dictionary) -> Error:
	var check_error: Error = can_pay(_context)

	if check_error != OK:
		return check_error

	_paid_amount = inventory.remove_item(
		item_id,
		amount,
	)

	if _paid_amount != amount:
		if _paid_amount > 0:
			inventory.add_item_by_id(
				item_id,
				_paid_amount,
			)

		_paid_amount = 0
		return ERR_CANT_ACQUIRE_RESOURCE

	return OK


func refund(_context: Dictionary) -> void:
	if inventory == null or _paid_amount <= 0:
		return

	var restored: int = inventory.add_item_by_id(
		item_id,
		_paid_amount,
	)

	if restored != _paid_amount:
		NucleusLog.warning(
			"InventoryItemCost refund restored %d of %d '%s'."
			% [restored, _paid_amount, item_id],
			&"InventoryItemCost",
		)

	_paid_amount = 0


func _on_inventory_changed() -> void:
	notify_affordability_changed()


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
