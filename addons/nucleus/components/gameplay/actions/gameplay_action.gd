class_name NucleusGameplayAction
extends Node
## Scene-owned executable gameplay action.
##
## The action orchestrates requirements, costs, cooldown, and effects. The
## concrete gameplay consequence can also listen to [signal executed].

signal availability_changed(available: bool)
signal execution_started(context: Dictionary)
signal execution_committed(context: Dictionary)
signal executed(context: Dictionary)
signal execution_rejected(
	stage: int,
	source: Node,
	error: Error,
)
signal execution_failed(
	effect: NucleusActionEffect,
	error: Error,
)

enum RejectionStage {
	NONE,
	DISABLED,
	BUSY,
	COOLDOWN,
	REQUIREMENT,
	COST,
	EFFECT,
	BLOCKED,
}

@export var action_id: StringName
@export var tags: Array[StringName] = []
@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return

		enabled = value

		if is_node_ready():
			_refresh_availability()

@export_group("Composition")
@export var parts_root: Node
@export var cooldown: NucleusCooldown

var _requirements: Array[NucleusActionRequirement] = []
var _costs: Array[NucleusActionCost] = []
var _effects: Array[NucleusActionEffect] = []

var _executing: bool = false
var _last_available: bool = false
var _blockers: Dictionary[StringName, bool] = {}


func _ready() -> void:
	if parts_root == null:
		parts_root = self

	_discover_parts()
	_connect_parts()

	_last_available = can_execute()
	availability_changed.emit(_last_available)


func _exit_tree() -> void:
	_disconnect_parts()


func get_action_id() -> StringName:
	return (
		action_id
		if action_id != &""
		else StringName(name)
	)


func has_tag(tag: StringName) -> bool:
	return tag in tags


func add_blocker(blocker_id: StringName) -> Error:
	if blocker_id == &"":
		return ERR_INVALID_PARAMETER

	if _blockers.has(blocker_id):
		return OK

	_blockers[blocker_id] = true
	_refresh_availability()

	return OK


func remove_blocker(blocker_id: StringName) -> bool:
	if not _blockers.has(blocker_id):
		return false

	_blockers.erase(blocker_id)
	_refresh_availability()

	return true


func has_blocker(blocker_id: StringName) -> bool:
	return _blockers.has(blocker_id)


func is_blocked() -> bool:
	return not _blockers.is_empty()


func get_blockers() -> Array[StringName]:
	var result: Array[StringName] = []

	for blocker_id: StringName in _blockers:
		result.append(blocker_id)

	return result


func can_execute(context: Dictionary = {}) -> bool:
	return get_execution_error(context) == OK


func get_execution_error(
	context: Dictionary = {},
) -> Error:
	var validation: Dictionary = _validate(context)
	var error: Error = validation["error"]
	return error


func try_execute(
	context: Dictionary = {},
) -> Error:
	var safe_context: Dictionary = context.duplicate(true)
	var validation: Dictionary = _validate(safe_context)
	var error: Error = validation["error"]

	if error != OK:
		execution_rejected.emit(
			int(validation["stage"]),
			validation["source"],
			error,
		)
		return error

	_executing = true
	execution_started.emit(safe_context)

	var paid_costs: Array[NucleusActionCost] = []

	for cost: NucleusActionCost in _costs:
		error = cost.pay(safe_context)

		if error != OK:
			_refund_costs(
				paid_costs,
				safe_context,
			)
			_executing = false
			execution_rejected.emit(
				RejectionStage.COST,
				cost,
				error,
			)
			_refresh_availability()
			return error

		paid_costs.append(cost)

	if cooldown:
		cooldown.start()

	execution_committed.emit(safe_context)

	for effect: NucleusActionEffect in _effects:
		error = effect.apply(safe_context)

		if error != OK:
			_executing = false
			execution_failed.emit(
				effect,
				error,
			)
			_refresh_availability()
			return error

	_executing = false
	executed.emit(safe_context)
	_refresh_availability()

	return OK


func capture_state() -> Dictionary:
	var state: Dictionary = {
		"enabled": enabled,
	}

	if cooldown:
		state["cooldown"] = cooldown.capture_state()

	return state


func restore_state(data: Dictionary) -> void:
	enabled = bool(data.get("enabled", enabled))

	if cooldown and data.has("cooldown"):
		cooldown.restore_state(
			data["cooldown"]
		)

	_refresh_availability()


func refresh_parts() -> void:
	_disconnect_parts()
	_discover_parts()
	_connect_parts()
	_refresh_availability()


func _validate(context: Dictionary) -> Dictionary:
	if not enabled:
		return _rejection(
			RejectionStage.DISABLED,
			self,
			ERR_UNAVAILABLE,
		)

	if is_blocked():
		return _rejection(
			RejectionStage.BLOCKED,
			self,
			ERR_UNAVAILABLE,
		)

	if _executing:
		return _rejection(
			RejectionStage.BUSY,
			self,
			ERR_BUSY,
		)

	if cooldown and not cooldown.is_ready():
		return _rejection(
			RejectionStage.COOLDOWN,
			cooldown,
			ERR_BUSY,
		)

	for requirement: NucleusActionRequirement in _requirements:
		var error: Error = requirement.check(context)

		if error != OK:
			return _rejection(
				RejectionStage.REQUIREMENT,
				requirement,
				error,
			)

	for cost: NucleusActionCost in _costs:
		var error: Error = cost.can_pay(context)

		if error != OK:
			return _rejection(
				RejectionStage.COST,
				cost,
				error,
			)

	for effect: NucleusActionEffect in _effects:
		var error: Error = effect.can_apply(context)

		if error != OK:
			return _rejection(
				RejectionStage.EFFECT,
				effect,
				error,
			)

	return _rejection(
		RejectionStage.NONE,
		null,
		OK,
	)


func _rejection(
	stage: int,
	source: Node,
	error: Error,
) -> Dictionary:
	return {
		"stage": stage,
		"source": source,
		"error": error,
	}


func _discover_parts() -> void:
	_requirements.clear()
	_costs.clear()
	_effects.clear()

	if parts_root == null:
		return

	for node: Node in NucleusNodeUtils.descendants(
		parts_root,
		true,
	):
		if node == self:
			continue

		if node is NucleusActionRequirement:
			_requirements.append(
				node as NucleusActionRequirement
			)
		elif node is NucleusActionCost:
			_costs.append(
				node as NucleusActionCost
			)
		elif node is NucleusActionEffect:
			_effects.append(
				node as NucleusActionEffect
			)
		elif cooldown == null and node is NucleusCooldown:
			cooldown = node as NucleusCooldown


func _connect_parts() -> void:
	if cooldown:
		if not cooldown.started.is_connected(
			_on_cooldown_changed
		):
			cooldown.started.connect(
				_on_cooldown_changed
			)

		if not cooldown.became_ready.is_connected(
			_on_cooldown_ready
		):
			cooldown.became_ready.connect(
				_on_cooldown_ready
			)

		if not cooldown.canceled.is_connected(
			_on_cooldown_canceled
		):
			cooldown.canceled.connect(
				_on_cooldown_canceled
			)

	for requirement: NucleusActionRequirement in _requirements:
		if not requirement.availability_changed.is_connected(
			_refresh_availability
		):
			requirement.availability_changed.connect(
				_refresh_availability
			)

	for cost: NucleusActionCost in _costs:
		if not cost.affordability_changed.is_connected(
			_refresh_availability
		):
			cost.affordability_changed.connect(
				_refresh_availability
			)


func _disconnect_parts() -> void:
	if cooldown:
		if cooldown.started.is_connected(
			_on_cooldown_changed
		):
			cooldown.started.disconnect(
				_on_cooldown_changed
			)

		if cooldown.became_ready.is_connected(
			_on_cooldown_ready
		):
			cooldown.became_ready.disconnect(
				_on_cooldown_ready
			)

		if cooldown.canceled.is_connected(
			_on_cooldown_canceled
		):
			cooldown.canceled.disconnect(
				_on_cooldown_canceled
			)

	for requirement: NucleusActionRequirement in _requirements:
		if requirement.availability_changed.is_connected(
			_refresh_availability
		):
			requirement.availability_changed.disconnect(
				_refresh_availability
			)

	for cost: NucleusActionCost in _costs:
		if cost.affordability_changed.is_connected(
			_refresh_availability
		):
			cost.affordability_changed.disconnect(
				_refresh_availability
			)


func _refund_costs(
	paid_costs: Array[NucleusActionCost],
	context: Dictionary,
) -> void:
	for index: int in range(
		paid_costs.size() - 1,
		-1,
		-1,
	):
		paid_costs[index].refund(context)


func _refresh_availability(
	_argument: Variant = null,
) -> void:
	var available: bool = can_execute()

	if available == _last_available:
		return

	_last_available = available
	availability_changed.emit(available)


func _on_cooldown_changed(_duration: float) -> void:
	_refresh_availability()


func _on_cooldown_ready() -> void:
	_refresh_availability()


func _on_cooldown_canceled() -> void:
	_refresh_availability()
