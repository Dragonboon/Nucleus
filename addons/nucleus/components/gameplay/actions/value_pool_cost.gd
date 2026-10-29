class_name NucleusValuePoolCost
extends NucleusActionCost
## Pays an action cost from an existing NucleusValuePool.

@export var target_pool: NucleusValuePool
@export_range(0.0, 1.0e12, 0.01, "or_greater")
var amount: float = 1.0
@export_range(0.0, 1.0e12, 0.01, "or_greater")
var reserve: float = 0.0

var _last_paid_amount: float = 0.0


func _ready() -> void:
	if target_pool == null:
		target_pool = _find_value_pool()

	if target_pool == null:
		NucleusLog.error(
			"%s requires a NucleusValuePool." % get_path(),
			&"ValuePoolCost",
		)
		return

	target_pool.value_changed.connect(
		_on_pool_value_changed
	)


func _exit_tree() -> void:
	if (
		target_pool
		and target_pool.value_changed.is_connected(
			_on_pool_value_changed
		)
	):
		target_pool.value_changed.disconnect(
			_on_pool_value_changed
		)


func can_pay(_context: Dictionary) -> Error:
	if target_pool == null:
		return ERR_UNCONFIGURED

	if amount <= 0.0:
		return OK

	var available: float = (
		target_pool.value
		- target_pool.minimum_value
		- maxf(0.0, reserve)
	)

	return (
		OK
		if available + 0.000001 >= amount
		else ERR_UNAVAILABLE
	)


func pay(context: Dictionary) -> Error:
	_last_paid_amount = 0.0

	var error: Error = can_pay(context)

	if error != OK:
		return error

	if amount <= 0.0:
		return OK

	var delta: float = target_pool.decrease(amount)
	_last_paid_amount = maxf(0.0, -delta)

	if _last_paid_amount + 0.000001 < amount:
		return ERR_UNAVAILABLE

	return OK


func refund(_context: Dictionary) -> void:
	if target_pool == null or _last_paid_amount <= 0.0:
		return

	target_pool.increase(_last_paid_amount, true)
	_last_paid_amount = 0.0


func _find_value_pool() -> NucleusValuePool:
	var root: Node = get_parent()

	while root:
		var pools: Array[NucleusValuePool] = []

		if root is NucleusValuePool:
			pools.append(root as NucleusValuePool)

		for node: Node in NucleusNodeUtils.descendants(root):
			if node is NucleusValuePool:
				pools.append(node as NucleusValuePool)

		if pools.size() == 1:
			return pools[0]

		if pools.size() > 1:
			NucleusLog.warning(
				"%s found multiple value pools; assign target_pool explicitly."
				% get_path(),
				&"GameplayAction",
			)
			return null

		root = root.get_parent()

	return null


func _on_pool_value_changed(
	_value: float,
	_previous_value: float,
	_delta: float,
) -> void:
	notify_affordability_changed()
