class_name NucleusValuePoolEffect
extends NucleusActionEffect
## Applies a one-shot delta to a NucleusValuePool.

@export var target_pool: NucleusValuePool
@export var delta: float = 0.0
@export var allow_overflow: bool = false
@export var require_full_application: bool = false


func _ready() -> void:
	if target_pool == null:
		target_pool = _find_value_pool()

	if target_pool == null:
		NucleusLog.error(
			"%s requires a NucleusValuePool." % get_path(),
			&"ValuePoolEffect",
		)


func can_apply(_context: Dictionary) -> Error:
	if target_pool == null:
		return ERR_UNCONFIGURED

	if not require_full_application or is_zero_approx(delta):
		return OK

	if delta > 0.0:
		var upper_bound: float = (
			target_pool.maximum_value
			+ target_pool.overflow_limit
			if allow_overflow
			else target_pool.maximum_value
		)
		var capacity: float = upper_bound - target_pool.value

		return (
			OK
			if capacity + 0.000001 >= delta
			else ERR_UNAVAILABLE
		)

	var available: float = (
		target_pool.value
		- target_pool.minimum_value
	)

	return (
		OK
		if available + 0.000001 >= absf(delta)
		else ERR_UNAVAILABLE
	)


func apply(context: Dictionary) -> Error:
	var error: Error = can_apply(context)

	if error != OK:
		return error

	if delta > 0.0:
		target_pool.increase(
			delta,
			allow_overflow,
		)
	elif delta < 0.0:
		target_pool.decrease(absf(delta))

	return OK


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
