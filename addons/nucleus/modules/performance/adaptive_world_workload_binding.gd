class_name NucleusAdaptiveWorldWorkloadBinding
extends Node
## Opt-in budgets for NONCRITICAL scene-owned world work.
## Reacts to the existing adaptive controller; never samples frames itself.
## No new task runner, stream admission logic, or rendering-scale writer.

signal workload_changed(pressure: float, budgets: Dictionary)
signal binding_state_changed(active: bool, reason: StringName)

const _OWNER_KEY: StringName = &"nucleus_adaptive_world_workload_owner"

@export var controller: NucleusAdaptivePerformanceController
@export var profile: NucleusAdaptiveWorldWorkloadProfile
@export var background_queue: NucleusMaterializationQueue
@export var background_stream: NucleusWorldStreamLifecycle
@export var background_terrain: NucleusTerrainStreamer3D
@export var scatter_regions: Array[NucleusScatterRegion3D] = []
@export var start_enabled: bool = false

var _enabled: bool = false
var _entries: Array[Dictionary] = []
var _pressure: float = 0.0


func _ready() -> void:
	if profile == null:
		profile = NucleusAdaptiveWorldWorkloadProfile.new()
	if is_instance_valid(controller):
		controller.decision_observed.connect(_on_decision)
		controller.adaptation_enabled_changed.connect(_on_controller_enabled)
		controller.observation_reset.connect(_on_controller_reset)
	if start_enabled:
		enable_binding()


func _exit_tree() -> void:
	disable_binding()
	if is_instance_valid(controller):
		if controller.decision_observed.is_connected(_on_decision):
			controller.decision_observed.disconnect(_on_decision)
		if controller.adaptation_enabled_changed.is_connected(_on_controller_enabled):
			controller.adaptation_enabled_changed.disconnect(_on_controller_enabled)
		if controller.observation_reset.is_connected(_on_controller_reset):
			controller.observation_reset.disconnect(_on_controller_reset)


## Explicit consent. Capture authored budgets without mutating them.
func enable_binding() -> Error:
	if _enabled:
		return OK
	if (
		not is_inside_tree() or not is_instance_valid(controller)
		or not controller.is_adaptation_enabled()
		or profile == null or not profile.validate().is_empty()
		or controller.profile == null
		or not controller.profile.validate().is_empty()
	):
		return ERR_UNCONFIGURED
	var candidates: Array[Dictionary] = _collect_entries()
	if candidates.is_empty():
		return ERR_UNCONFIGURED
	for entry: Dictionary in candidates:
		var target: Node = entry["target"]
		if not is_instance_valid(target) or not target.is_inside_tree():
			return ERR_UNAVAILABLE
		var owner: Node = _owner_for(target)
		if owner != null and owner != self:
			return ERR_BUSY
	for entry: Dictionary in candidates:
		var target: Node = entry["target"]
		target.set_meta(_OWNER_KEY, weakref(self))
	_entries = candidates
	_enabled = true
	binding_state_changed.emit(true, &"enabled")
	var span: float = (
		controller.profile.maximum_render_scale
		- controller.profile.minimum_render_scale
	)
	if span > 0.0001:
		var severity: float = clampf(
			(controller.profile.maximum_render_scale - controller.get_suggested_scale())
			/ span, 0.0, 1.0
		)
		_apply_pressure(severity)
	return OK


func disable_binding() -> void:
	if not _enabled:
		return
	for entry: Dictionary in _entries:
		var target: Node = entry["target"]
		if not is_instance_valid(target) or _owner_for(target) != self:
			continue
		var before: Dictionary = entry["before"]
		var applied: Dictionary = entry["applied"]
		for property: StringName in before:
			# Never overwrite a game-authored change made after our last write.
			if target.get(property) == applied[property]:
				target.set(property, before[property])
		target.remove_meta(_OWNER_KEY)
	_entries.clear()
	_enabled = false
	_pressure = 0.0
	binding_state_changed.emit(false, &"disabled")


func is_binding_enabled() -> bool:
	return _enabled


func get_pressure() -> float:
	return _pressure


func get_budget_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in _entries:
		var target: Node = entry["target"]
		if not is_instance_valid(target):
			continue
		var values: Dictionary = {}
		var original: Dictionary = entry["before"]
		for property: StringName in original:
			values[property] = target.get(property)
		result[str(target.get_path())] = values
	return result


func _collect_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	_add_entry(result, background_queue, [
		&"max_steps_per_frame", &"frame_budget_usec",
	])
	_add_entry(result, background_stream, [&"max_load_requests_per_frame"])
	_add_entry(result, background_terrain, [&"max_new_chunks_per_update"])
	for region: NucleusScatterRegion3D in scatter_regions:
		_add_entry(result, region, [
			&"partition_transforms_per_frame", &"batches_per_frame",
		])
	return result


func _add_entry(
	result: Array[Dictionary], target: Node, properties: Array[StringName],
) -> void:
	if target == null:
		return
	for prior: Dictionary in result:
		if prior["target"] == target:
			return
	var original: Dictionary = {}
	for property: StringName in properties:
		original[property] = target.get(property)
	result.append({
		"target": target, "before": original, "applied": original.duplicate(),
	})


func _owner_for(target: Node) -> Node:
	if not target.has_meta(_OWNER_KEY):
		return null
	var reference: Variant = target.get_meta(_OWNER_KEY)
	if not reference is WeakRef:
		return null
	var owner: Node = (reference as WeakRef).get_ref() as Node
	if not is_instance_valid(owner):
		target.remove_meta(_OWNER_KEY)
		return null
	return owner


func _on_decision(decision: Dictionary) -> void:
	if not _enabled or not controller.is_adaptation_enabled():
		return
	if controller.profile == null or not controller.profile.validate().is_empty():
		disable_binding()
		return
	var scale: float = float(decision.get("render_scale", NAN))
	if not is_finite(scale):
		return
	var span: float = (
		controller.profile.maximum_render_scale
		- controller.profile.minimum_render_scale
	)
	if span <= 0.0001:
		return
	_apply_pressure(clampf(
		(controller.profile.maximum_render_scale - scale) / span, 0.0, 1.0
	))


func _apply_pressure(value: float) -> void:
	if not _enabled or not is_finite(value):
		return
	# Preflight every property to prevent half-applied updates on external edits.
	for entry: Dictionary in _entries:
		var target: Node = entry["target"]
		if not is_instance_valid(target) or _owner_for(target) != self:
			disable_binding()
			return
		var applied: Dictionary = entry["applied"]
		for property: StringName in applied:
			if target.get(property) != applied[property]:
				disable_binding()
				return
	_pressure = clampf(value, 0.0, 1.0)
	for entry: Dictionary in _entries:
		var target: Node = entry["target"]
		var original: Dictionary = entry["before"]
		var applied: Dictionary = entry["applied"]
		for property: StringName in original:
			var next_value: int = _compute_budget(
				property, int(original[property]), _pressure
			)
			target.set(property, next_value)
			applied[property] = next_value
	workload_changed.emit(_pressure, get_budget_snapshot())


func _compute_budget(property: StringName, original: int, pressure: float) -> int:
	if property == &"frame_budget_usec":
		if original == 0: # Zero is the existing queue's unlimited-time policy.
			return 0
		return mini(original, maxi(
			profile.minimum_queue_usec,
			ceili(float(original) * lerpf(1.0, profile.queue_fraction, pressure))
		))
	var fraction: float = 1.0
	match property:
		&"max_steps_per_frame":
			fraction = profile.queue_fraction
		&"max_load_requests_per_frame":
			fraction = profile.background_load_fraction
		&"max_new_chunks_per_update":
			fraction = profile.terrain_build_fraction
		&"partition_transforms_per_frame", &"batches_per_frame":
			fraction = profile.scatter_fraction
	return maxi(1, mini(original, ceili(
		float(original) * lerpf(1.0, fraction, pressure)
	)))


func _on_controller_enabled(enabled: bool) -> void:
	if not enabled:
		disable_binding()


func _on_controller_reset() -> void:
	if _enabled:
		_apply_pressure(0.0)
