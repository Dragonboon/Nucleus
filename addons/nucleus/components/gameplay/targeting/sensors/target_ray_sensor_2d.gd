class_name NucleusTargetRaySensor2D
extends Node
## Adapts one native RayCast2D into targeting candidate registration.

signal sensed_target_changed(
	current: NucleusTargetable,
	previous: NucleusTargetable,
)

@export var agent: NucleusTargetingAgent
@export var ray_cast: RayCast2D
@export var sensor_enabled: bool = true:
	set(value):
		if sensor_enabled == value:
			return

		sensor_enabled = value

		if is_node_ready() and not sensor_enabled:
			_clear_current()

@export var force_update_each_physics_frame: bool = false

var _tracker: NucleusTargetSensorTracker
var _current_target: NucleusTargetable
var _current_collider: Node


func _ready() -> void:
	if ray_cast == null:
		ray_cast = get_parent() as RayCast2D

	if agent == null:
		agent = NucleusTargetResolver.find_agent(self)

	if ray_cast == null or agent == null:
		NucleusLog.error(
			"%s requires RayCast2D and TargetingAgent." % get_path(),
			&"TargetRaySensor2D",
		)
		set_physics_process(false)
		return

	_tracker = NucleusTargetSensorTracker.new(
		agent,
		self,
	)


func _exit_tree() -> void:
	if _tracker:
		_tracker.clear()


func _physics_process(_delta: float) -> void:
	if not sensor_enabled:
		_clear_current()
		return

	if force_update_each_physics_frame:
		ray_cast.force_raycast_update()

	if not ray_cast.is_colliding():
		_clear_current()
		return

	var collider: Object = ray_cast.get_collider()

	if not collider is Node:
		_clear_current()
		return

	var collider_node := collider as Node

	if _current_collider == collider_node:
		return

	var previous: NucleusTargetable = _current_target
	_tracker.clear()
	_current_collider = collider_node
	_current_target = _tracker.register_source(
		collider_node
	)

	if _current_target != previous:
		sensed_target_changed.emit(
			_current_target,
			previous,
		)


func _clear_current() -> void:
	if _current_collider == null and _current_target == null:
		return

	var previous: NucleusTargetable = _current_target

	if _tracker:
		_tracker.clear()

	_current_collider = null
	_current_target = null

	if previous:
		sensed_target_changed.emit(
			null,
			previous,
		)
