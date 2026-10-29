@tool
class_name NucleusNavigationFollower2D
extends Node
## Efficient path-following intent around Godot NavigationAgent2D.
##
## This component does not move a CharacterBody2D. Consumers read output_velocity
## or observe velocity_ready and retain ownership of locomotion.

signal target_changed(position: Vector2)
signal target_cleared
signal desired_velocity_changed(velocity: Vector2)
signal velocity_ready(velocity: Vector2)
signal destination_finished(
	reached_target: bool,
	final_position: Vector2,
)
signal navigation_link_reached(details: Dictionary)

@export var agent: NavigationAgent2D:
	set(value):
		_disconnect_agent()
		agent = value
		_connect_agent()
		update_configuration_warnings()

@export var origin: Node2D:
	set(value):
		origin = value
		update_configuration_warnings()

@export var target_node: Node2D

@export_group("Movement intent")
@export_range(0.0, 100000.0, 0.01, "or_greater")
var movement_speed: float = 200.0
@export var synchronize_agent_max_speed: bool = true

@export_group("Repath")
@export_range(0.0, 100000.0, 0.01, "or_greater")
var target_repath_distance: float = 8.0
@export_range(0.0, 60.0, 0.01, "or_greater")
var minimum_repath_interval: float = 0.20
## Assign before tree entry. Only path requests are scheduled; movement stays fixed-step.
@export var update_scheduler: NucleusUpdateScheduler
var _scheduler_token: int = -1
var _repath_permitted: bool = false

@export_group("Behavior")
@export var active: bool = true:
	set(value):
		active = value

		if is_node_ready() and not Engine.is_editor_hint():
			set_physics_process(active)

var desired_velocity: Vector2 = Vector2.ZERO
var output_velocity: Vector2 = Vector2.ZERO

var _manual_target: Vector2 = Vector2.ZERO
var _has_target: bool = false
var _has_requested_target: bool = false
var _last_requested_target: Vector2 = Vector2.ZERO
var _repath_elapsed: float = 0.0
var _finished_emitted: bool = false


func _enter_tree() -> void:
	if is_node_ready() and not Engine.is_editor_hint():
		_connect_agent()
		_register_repath_schedule()


func _ready() -> void:
	if origin == null:
		origin = get_parent() as Node2D

	if Engine.is_editor_hint():
		set_physics_process(false)
		return

	_connect_agent()
	_register_repath_schedule()
	set_physics_process(active)

	if target_node != null:
		follow_node(target_node)


func _exit_tree() -> void:
	if is_instance_valid(update_scheduler) and _scheduler_token != -1:
		update_scheduler.unregister_task(_scheduler_token)
	_scheduler_token = -1
	_repath_permitted = false
	_disconnect_agent()


func _physics_process(delta: float) -> void:
	if not active or not _is_configured():
		return

	if target_node != null and not is_instance_valid(target_node):
		clear_target()

	if not _has_target:
		_stop_output()
		return

	if not _navigation_map_ready():
		_stop_output()
		return

	_repath_elapsed += delta

	var target_position: Vector2 = (
		target_node.global_position
		if target_node != null
		else _manual_target
	)

	if _scheduler_token == -1 or _repath_permitted:
		_repath_permitted = false
		if _should_request_target(target_position):
			_request_target(target_position)
	if not _has_requested_target:
		_stop_output()
		return

	var next_position: Vector2 = agent.get_next_path_position()

	if agent.is_navigation_finished():
		_stop_output()

		if not _finished_emitted:
			_finished_emitted = true
			destination_finished.emit(
				agent.is_target_reached(),
				agent.get_final_position(),
			)

		return

	_finished_emitted = false

	var direction: Vector2 = (
		origin.global_position
		.direction_to(next_position)
	)
	_publish_desired_velocity(
		direction * maxf(
			0.0,
			movement_speed,
		)
	)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if agent == null:
		warnings.append("Assign a NavigationAgent2D.")

	var resolved_origin: Node2D = (
		origin
		if origin != null
		else get_parent() as Node2D
	)

	if resolved_origin == null:
		warnings.append(
			"Assign a Node2D origin or parent this follower under one."
		)

	return warnings


func follow_node(node: Node2D) -> Error:
	if node == null:
		return ERR_INVALID_PARAMETER

	target_node = node
	_manual_target = node.global_position
	_has_target = true
	_has_requested_target = false
	_repath_elapsed = minimum_repath_interval
	_finished_emitted = false

	if _scheduler_token == -1 and _is_configured() and _navigation_map_ready():
		_request_target(node.global_position)

	return OK


func set_target_position(
	position: Vector2,
) -> Error:
	target_node = null
	_manual_target = position
	_has_target = true
	_has_requested_target = false
	_repath_elapsed = minimum_repath_interval
	_finished_emitted = false

	if _scheduler_token == -1 and _is_configured() and _navigation_map_ready():
		_request_target(position)

	return OK


func clear_target() -> void:
	_repath_permitted = false
	target_node = null
	_has_target = false
	_has_requested_target = false
	_finished_emitted = false
	_stop_output()
	target_cleared.emit()


func has_target() -> bool:
	return _has_target


func get_target_position() -> Vector2:
	if target_node != null and is_instance_valid(target_node):
		return target_node.global_position

	return _manual_target


func request_repath() -> void:
	_has_requested_target = false
	_repath_elapsed = minimum_repath_interval


func _should_request_target(
	position: Vector2,
) -> bool:
	var displacement: float = (
		_last_requested_target.distance_to(position)
		if _has_requested_target
		else 0.0
	)

	return NucleusNavigationPolicy.should_repath(
		displacement,
		target_repath_distance,
		_repath_elapsed,
		minimum_repath_interval,
		_has_requested_target,
	)


func _request_target(position: Vector2) -> void:
	if synchronize_agent_max_speed:
		agent.max_speed = maxf(
			0.0,
			movement_speed,
		)

	agent.target_position = position
	_last_requested_target = position
	_has_requested_target = true
	_repath_elapsed = 0.0
	_finished_emitted = false
	target_changed.emit(position)


func _publish_desired_velocity(
	velocity: Vector2,
) -> void:
	if desired_velocity != velocity:
		desired_velocity = velocity
		desired_velocity_changed.emit(
			desired_velocity
		)

	if agent != null and agent.avoidance_enabled:
		agent.velocity = desired_velocity
		return

	output_velocity = desired_velocity
	velocity_ready.emit(output_velocity)


func _stop_output() -> void:
	_publish_desired_velocity(Vector2.ZERO)

	if agent != null and agent.avoidance_enabled:
		agent.velocity = Vector2.ZERO
	else:
		output_velocity = Vector2.ZERO


func _on_velocity_computed(
	safe_velocity: Vector2,
) -> void:
	output_velocity = safe_velocity
	velocity_ready.emit(output_velocity)


func _on_link_reached(
	details: Dictionary,
) -> void:
	navigation_link_reached.emit(
		details.duplicate()
	)


func _connect_agent() -> void:
	if (
		Engine.is_editor_hint()
		or agent == null
		or not is_inside_tree()
	):
		return

	if not agent.velocity_computed.is_connected(
		_on_velocity_computed
	):
		agent.velocity_computed.connect(
			_on_velocity_computed
		)

	if not agent.link_reached.is_connected(
		_on_link_reached
	):
		agent.link_reached.connect(
			_on_link_reached
		)


func _disconnect_agent() -> void:
	if agent == null or not is_instance_valid(agent):
		return

	if agent.velocity_computed.is_connected(
		_on_velocity_computed
	):
		agent.velocity_computed.disconnect(
			_on_velocity_computed
		)

	if agent.link_reached.is_connected(
		_on_link_reached
	):
		agent.link_reached.disconnect(
			_on_link_reached
		)


func _is_configured() -> bool:
	return agent != null and origin != null


func _navigation_map_ready() -> bool:
	if agent == null:
		return false

	var navigation_map: RID = agent.get_navigation_map()

	return (
		navigation_map.is_valid()
		and NavigationServer2D.map_get_iteration_id(
			navigation_map
		) > 0
	)


func _register_repath_schedule() -> void:
	if _scheduler_token != -1 or minimum_repath_interval <= 0.0:
		return
	if not is_instance_valid(update_scheduler):
		return
	_scheduler_token = update_scheduler.register_task(
		_allow_repath, minimum_repath_interval,
	)


func _allow_repath(_elapsed: float) -> void:
	if is_inside_tree() and can_process() and active and _has_target:
		_repath_permitted = true
