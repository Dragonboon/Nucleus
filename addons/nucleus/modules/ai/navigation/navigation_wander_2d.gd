@tool
class_name NucleusNavigationWander2D
extends Node
## Optional patrol/wander goal producer for NavigationFollower2D.

@export var follower: NucleusNavigationFollower2D:
	set(value):
		_disconnect_follower()
		follower = value
		_connect_follower()
		update_configuration_warnings()

@export var anchor: Node2D
@export_range(0.0, 100000.0, 0.01, "or_greater")
var radius: float = 300.0
@export_range(0.0, 3600.0, 0.01, "or_greater")
var minimum_wait: float = 1.0
@export_range(0.0, 3600.0, 0.01, "or_greater")
var maximum_wait: float = 3.0
@export_range(1, 64, 1)
var sample_attempts: int = 8

@export_group("Randomness")
@export var use_fixed_seed: bool = false
@export var fixed_seed: int = 0

@export_group("Behavior")
@export var active: bool = true:
	set(value):
		active = value

		if is_node_ready() and not Engine.is_editor_hint():
			set_physics_process(active)

var _rng := RandomNumberGenerator.new()
var _wait_remaining: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		return

	_connect_follower()

	if use_fixed_seed:
		_rng.seed = fixed_seed
	else:
		_rng.randomize()

	set_physics_process(active)
	_schedule_next()


func _exit_tree() -> void:
	_disconnect_follower()


func _physics_process(delta: float) -> void:
	if not active or follower == null:
		return

	if follower.has_target():
		return

	_wait_remaining = maxf(
		0.0,
		_wait_remaining - delta,
	)

	if _wait_remaining > 0.0:
		return

	if not _pick_destination():
		_schedule_next()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if follower == null:
		warnings.append("Assign a NucleusNavigationFollower2D.")

	if maximum_wait < minimum_wait:
		warnings.append(
			"maximum_wait must be greater than or equal to minimum_wait."
		)

	return warnings


func start_wandering() -> void:
	active = true
	set_physics_process(true)

	if follower != null and not follower.has_target():
		_schedule_next()


func stop_wandering(
	clear_follower_target: bool = true,
) -> void:
	active = false
	set_physics_process(false)

	if clear_follower_target and follower != null:
		follower.clear_target()


func _pick_destination() -> bool:
	if (
		follower.agent == null
		or follower.origin == null
	):
		return false

	var navigation_map: RID = follower.agent.get_navigation_map()

	if (
		not navigation_map.is_valid()
		or NavigationServer2D.map_get_iteration_id(
			navigation_map
		) <= 0
	):
		return false

	var center: Vector2 = (
		anchor.global_position
		if anchor != null
		else follower.origin.global_position
	)
	var destination: Vector2 = (
		NucleusNavigationQueries2D.random_point_in_radius(
			navigation_map,
			center,
			radius,
			_rng,
			follower.agent.navigation_layers,
			sample_attempts,
		)
	)
	follower.set_target_position(destination)
	return true


func _schedule_next() -> void:
	var low: float = minf(
		minimum_wait,
		maximum_wait,
	)
	var high: float = maxf(
		minimum_wait,
		maximum_wait,
	)
	_wait_remaining = _rng.randf_range(
		low,
		high,
	)


func _on_destination_finished(
	_reached_target: bool,
	_final_position: Vector2,
) -> void:
	if follower != null:
		follower.clear_target()

	_schedule_next()


func _connect_follower() -> void:
	if (
		Engine.is_editor_hint()
		or follower == null
		or not is_inside_tree()
	):
		return

	if not follower.destination_finished.is_connected(
		_on_destination_finished
	):
		follower.destination_finished.connect(
			_on_destination_finished
		)


func _disconnect_follower() -> void:
	if follower == null or not is_instance_valid(follower):
		return

	if follower.destination_finished.is_connected(
		_on_destination_finished
	):
		follower.destination_finished.disconnect(
			_on_destination_finished
		)
